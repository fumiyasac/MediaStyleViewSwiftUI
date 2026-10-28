# 0013. Swift Remote RepositoryとGo Backend APIの境界設計

- ステータス: 承認
- 日付: 2026-10-29
- 関連: [0003](0003-isolate-swiftdata-from-view-layer.md) / [0008](0008-recipe-centric-calendar.md) / [0012](0012-go-backend-recipe-calendar-api.md)

## コンテキスト

Phase 12（ADR 0012, PR #18）で、Recipe / Calendar を提供する Go Backend API を構築した
（Gin / GORM / MySQL / Docker、`http://localhost:8080`）。本フェーズ（Phase 13）では、
既存 SwiftUI アプリがこの API から `Recipe` / `DailyRecipeEntry` を取得できる
Swift 側のネットワーク層・データ層の土台を用意する。

前提・制約は次の通り。

- 既存の `RecipeRepository` Protocol（`allRecipes` / `recipe(for:)` / `dailyEntries(for:)` /
  `allDailyEntries`）は **変更しない**。UseCase / ViewModel / UI はこの境界越しに動く（ADR 0004/0008）。
- 本 PR では **本番の取得元を Remote に切り替えない**。既定は `FixtureRecipeRepository` のまま
  （切り替えは次 PR）。Remote を選べる Composition Root の口だけ用意する。
- Swift 6 の並行性（Sendable / actor 隔離）に適合させ、`@unchecked Sendable` /
  `nonisolated(unsafe)` / `@preconcurrency` / 不要な `Task.detached` / 共有可変状態のスタブを使わない。
- API の Base URL をコードへ直接埋め込まない（環境ごとに注入可能に）。ATS をグローバルに無効化しない。
- 失敗時に Fixture へ暗黙フォールバックしない。キャンセルはサーバー障害と区別する。

## 決定

### レイヤ構成

HTTP の送受信・型付き API 呼び出し・DTO↔Domain 変換・Repository 準拠を 4 層に分離する。

```
RecipeRepository(既存Protocol)
        ▲  準拠
RemoteRecipeRepository     ── Protocol と API 形状の差分を吸収
        │ 使用
   APIClient               ── Endpoint生成 / Status→型付きエラー / Decode
        │ 使用
   HTTPClient(Protocol)    ── 送受信のみ（URLSessionHTTPClient / テストは Fake）
        │
   URLSession
```

- **`HTTPClient` Protocol**: 送受信だけを担う最小境界。`URLSessionHTTPClient` が実装し、
  Unit Test では実ネットワークへ出ない `FakeHTTPClient` に差し替える。
- **`APIClient`**: `APIEndpoint` から `URLComponents` で `URLRequest` を組み立て（文字列連結しない）、
  HTTP Status を `APIClientError` へ 1 箇所で変換し、JSON を DTO へ Decode する。
- **DTO 群**（`RecipeSummaryDTO` / `RecipeDetailDTO` / `RecipeListResponseDTO` /
  `CalendarResponseDTO` / `APIErrorResponseDTO`）: API 契約（フィールド名・任意/必須）を表す
  `Decodable & Sendable` の値型。Domain とは分離する。
- **`RecipeDTOMapper`**: DTO→Domain の変換を集約。変換不能を明示的に `mapping` エラーにする。
- **`RemoteRecipeRepository`**: 既存 `RecipeRepository` にそのまま準拠し、Protocol と API の
  差分（ページング・レンジ・404 の扱い）を吸収する。

### JSON キーと camelCase

Go 側 DTO の `json` タグが camelCase（`cookingMinutes` / `imageReference` /
`publicationDate` / `displayOrder`）のため、`JSONDecoder` の `keyDecodingStrategy` は既定
（`.useDefaultKeys`）のままプロパティ名を一致させる。`.convertFromSnakeCase` は使わない。

### カテゴリの対応付け

Domain の `RecipeCategory` は `rawValue` が日本語表示名（`"和食"` 等）である一方、API は英語キー
（`"japanese"` 等）を返す。`RecipeCategory(rawValue:)` では変換できないため、Mapper に
英語キー→ケースの明示的な対応表を持たせ、未知キーは `mapping` エラーにする。

### Protocol と API 形状の差分の吸収

| Protocol メソッド | API 対応 | 吸収方法 |
|---|---|---|
| `allRecipes()` | `GET /recipes`（limit/offset ページング） | `pagination.total` に達するまで全ページ取得して連結。1ページ目を全件とみなさない。 |
| `recipe(for:)` | `GET /recipes/{id}` | 200→変換。404(RECIPE_NOT_FOUND)→`nil`（「存在しない」は正常系）。 |
| `dailyEntries(for:)` | `GET /calendar?from&to` | `from=to=当日` で呼ぶ。 |
| `allDailyEntries()` | 対応エンドポイントなし（レンジは最大92日） | 基準日 ±45日（計91日 ≦ 92日）の有限ウィンドウで取得。無制限の全期間ではない旨をコード/本ADRに明示。 |

`allDailyEntries()` は API に「全期間」の概念が無いため、カレンダー/タイムライン UI の走査要件を
満たす範囲に限定した妥協である。本番採用（次 PR）で要件に合わせて調整する。

### 落とす情報（意図的）

- `imageReference`: Domain の `Recipe` は画像プロパティを持たない（アセットは ID 由来で解決する方針）。
- `displayOrder`: `DailyRecipeEntry` に順序フィールドが無い。並び順は配列順で表現する。

### エラーと中断

- `APIClientError` で HTTP Status（400/404/500 系）・ネットワーク・タイムアウト・Decode・Mapping を型で区別する。
- Task キャンセル由来の `URLError(.cancelled)` は `URLSessionHTTPClient` で `CancellationError` に変換し、
  上位までそのまま伝搬させる。既存 ViewModel が `CancellationError` を画面エラーにしない設計と整合する。
- 失敗時に Fixture へ暗黙フォールバックしない（原因を隠さず呼び出し側へ伝搬）。

### 接続先の注入

`APIConfiguration`（`baseURL` / `timeout`）を値型として注入する。開発既定 `.localDevelopment` は
`http://localhost:8080`。実機・Release 用の URL はコードに埋め込まず、使用時に注入する。
ATS はグローバル無効化しない（localhost の HTTP 到達は Simulator で可能）。

### Composition Root

`CalendarFeatureDependencies.remote(configuration:)` を追加する。本番 `init()` は **Fixture のまま**。
`remote` ファクトリは公開シグネチャに internal な `APIConfiguration` を露出させないため internal とし、
AppFeature 内部および `@testable import` から到達できるようにする（次 PR の本番切替に備えた口）。

## テスト方針

- **Unit Test（Swift Testing）**: `FakeHTTPClient`（実 API 非依存）で APIClient / Mapper /
  RemoteRepository を検証（計32ケース）。リクエスト記録は `actor RequestRecorder` に閉じ、
  共有可変状態を安全に扱う。
- **Contract Test**: 実 API から取得したレスポンス JSON（`APIFixtureJSON`）を DTO が取りこぼさず
  Decode できるか検証。API 仕様の破れを検知する。
- **Integration Test**: 実 API への接続はオプトイン（`.enabled(if:)`、
  `TEST_RUNNER_RUN_REMOTE_INTEGRATION=1` のときだけ実行）。API 未起動の通常 Unit Test を失敗させない。

## 影響・非対象

- 変更なし: Calendar/Timeline/RecipeDetail/MealLogEditor の UI、Parallax/Collapse/Zoom、
  SwiftData スキーマ、MealLog Repository、Snapshot 基準画像、Go Backend の Domain/GORM/Migration。
- 本番取得元は Fixture のまま（Remote 切替は次 PR）。

## 代替案

- **Protocol を API 形状へ寄せて変更する**: UseCase/ViewModel/既存テストへ波及し、Fixture 実装も壊れる。
  差分吸収を Repository 実装に閉じる本決定の方が影響範囲が小さい。
- **DTO を使わず Domain を直接 Decodable にする**: API 契約が Domain に漏れ、API 変更の影響が
  UI まで波及する。Mapper で境界を切る方が疎結合。
- **失敗時に Fixture フォールバック**: 障害を隠し、実データ未取得に気付けない。明示的なエラー伝搬を選ぶ。
