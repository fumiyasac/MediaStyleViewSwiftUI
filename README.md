# MediaStyleViewSwiftUI

[ING] - SwiftUI+MVVM+StateMachineで作るUIサンプル実装例

## テスト

Unit TestはSwift Testing、Visual RegressionはSwift Testing + [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) で実装しています。

```sh
# 全テスト（Unit + Snapshot）
xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Snapshotのみ
xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppFeatureTests/CalendarSnapshotTests \
  -only-testing:AppFeatureTests/TimelineSnapshotTests \
  -only-testing:AppFeatureTests/RecipeDetailSnapshotTests \
  -only-testing:AppFeatureTests/MealLogEditorSnapshotTests
```

### Snapshot Testing

主要4画面（Calendar月表示 / Timeline / Recipe Detail / MealLog Editor）のレイアウト・文字・余白・表示要素の
意図しない変更を検出します。アニメーション（Parallax / Collapse / Zoom遷移）の滑らかさはSnapshotの対象外で、
Simulatorの手動確認で担保します。

- 実装: `Tests/AppFeatureTests/Snapshot/`
- 基準画像: `Tests/AppFeatureTests/Snapshot/__Snapshots__/`（Git管理。SPMのリソース処理対象外に`exclude`）
- 依存: `swift-snapshot-testing`（テストターゲット限定。本番`AppFeature`には依存させない）

#### 基準環境（これを変えると文字描画・Safe Area等が変わり差分が出る）

| 項目 | 値 |
|---|---|
| デバイスサイズ | iPhone 13 Pro（390×844pt, @3x。実行Simulator機種に依存しない固定サイズ） |
| iOS Runtime | 基準画像を生成したRuntimeに紐づく（CIでは同一Runtimeが必要） |
| Color Scheme | Light（第一基準）／Dark は追加ケース |
| Dynamic Type | 既定（.large） |
| Locale / Calendar / TimeZone | ja_JP / Gregorian(日曜始まり) / Asia/Tokyo |
| 固定日付 | 2024-06（過去月。`CalendarDateUtil.isToday`=実日付依存の「今日」強調が入らないようにするため） |

設定は `SnapshotTestConfiguration.swift`、固定データは `SnapshotFixtureFactory.swift` に集約しています。

#### 基準画像の生成・更新手順

1. 対象のSnapshotテストを追加/変更する。
2. 初回（基準画像が無い）は実行すると自動記録され、テストは**失敗**する（記録モード）。
3. 生成された `__Snapshots__/.../<test>.1.png` を**目視確認**する。
4. 妥当なら基準画像をコミットする。再実行すると**成功**する（差分比較モード）。
5. 意図的なUI変更時のみ、該当する基準画像を削除→再記録→目視→コミットして更新する。

通常実行・CIでは基準画像を自動で書き換えません（記録は基準が無い場合のみ）。基準画像の更新は、実際のUI変更内容と
対応している必要があります。不安定なテストは許容差分を広げて通すのではなく、原因（非同期描画・現在日時依存・フォント等）を
調査してください。

## Remote Repository（Go Backend API連携）

Go Backend API（Phase 12 / ADR 0012, `http://localhost:8080`）から `Recipe` / `DailyRecipeEntry` を
取得する Swift 側のネットワーク層・データ層を用意しています。設計の詳細は
[ADR 0013](docs/adr/0013-swift-remote-repository-go-backend-api-boundary.md) を参照してください。

- 既存の `RecipeRepository` Protocol に準拠する形で取得元(Fixture/Remote)を切り替えます（UseCase/ViewModel/UI は無変更）。
- Calendar / Timeline / Recipe Detail を Remote(Go API)と接続しつつ、MealLog は取得元に関わらず SwiftData のままです。
  詳細は [ADR 0014](docs/adr/0014-remote-recipe-integration-calendar-timeline-detail.md) を参照してください。
- **通常起動の既定取得元は `fixture`**。Remote は Debug で明示選択したときだけ使います。
- 層構成: `HTTPClient`(送受信) → `APIClient`(Endpoint生成/Status→型付きエラー/Decode) →
  `RecipeDTOMapper`(DTO→Domain) → `RemoteRecipeRepository`(既存Protocolへ準拠)。
- 実装: `Sources/AppFeature/Networking/`、`Sources/AppFeature/Recipe/Data/Remote/`、
  取得元選択は `CalendarFeatureDependencies` と `RecipeDataSource`。

### 取得元(Fixture / Remote)の切り替え

Composition Root(`CalendarFeatureDependencies`)が起動時に 1 度だけ取得元を決め、全画面で同一の
Repository インスタンスを共有します。Debug では環境変数 `RECIPE_DATA_SOURCE` で選択できます
（既定 `fixture` / Release は常に `fixture`）。

Xcode の Scheme → Run → Arguments → Environment Variables に設定します。

```text
RECIPE_DATA_SOURCE=fixture   # 同梱データ（既定・従来どおり）
RECIPE_DATA_SOURCE=remote    # Go API（localhost:8080）から取得
```

Remote で動作確認するときは、先に Docker Compose で Backend(MySQL + Go API)を起動してください。

### 接続先の設定 / ATS

`APIConfiguration`（`baseURL` / `timeout`）を注入します。Base URL はコードに直接埋め込まず、
開発既定は `.localDevelopment`（`http://localhost:8080`）です。実機・Release では適切な接続先を注入してください。

ATS はグローバル無効化せず、アプリの `Info.plist` で `NSAllowsLocalNetworking` のみ許可しています
（localhost 等ローカル宛ての平文 HTTP だけを許可し、インターネット宛ての保護は維持）。

Remote 取得が失敗した場合は Fixture へ暗黙フォールバックしません。通信障害クラス（未接続/タイムアウト/5xx）
では保存済みキャッシュを表示し、それ以外（400/404/Decoding/Mapping）やキャッシュ無しはエラー表示＋再試行で可視化します。

### オフラインキャッシュ（永続キャッシュと通信障害からの復旧）

Remote モードでは、正常取得した Recipe と Calendar 掲載情報を端末へ永続キャッシュし、オフライン時に
保存済みデータを表示します。設計の詳細は
[ADR 0015](docs/adr/0015-offline-recipe-cache-and-recovery.md) を参照してください。

- 方式: Codable + JSON File + actor（Application Support 配下。atomic write / Schema Version / 取得日時を保持）。
- 層: `CachedRecipeRepository`（Remote と Cache を調停）→ `RecipeCacheStore`（`FileRecipeCacheStore` actor）。
  MealLog は従来どおり SwiftData で、キャッシュ削除（`removeAll`）の影響を受けません。
- 取得戦略: Network-first + Cache フォールバック。オンラインは常に最新を取得・保存し、通信障害時のみ
  期限内の保存済み（Stale）を表示します。空配列も「取得済みの空」として保存し、未取得範囲とは区別します。
- 鮮度: Fresh（24h 以内）/ Stale（〜30 日）/ Expired（30 日超は不使用）。保存済み表示中は画面に
  「保存済みデータを表示中（取得日時）」のバナーを出し、最新と混同させません（最新/Fixture では非表示）。
- 失敗分類: 404 は「見つからない」として扱い古い詳細を出し続けません。Decoding/Mapping はキャッシュで
  隠さず伝搬します。Cancellation はフォールバックのトリガーにしません。
- 実装: `Sources/AppFeature/Recipe/Data/Cache/`

実 API に対する「取得→キャッシュ→オフライン表示」の統合検証（オプトイン）:

```sh
TEST_RUNNER_RUN_REMOTE_INTEGRATION=1 xcodebuild test -scheme AppFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppFeatureTests/CacheLiveIntegrationTests
```

### テスト

- Unit Test: `FakeHTTPClient` を使い実 API に依存せず検証（`Tests/AppFeatureTests/Remote/`）。
- Contract Test: 実 API から取得した JSON を DTO が Decode できるか検証（`RecipeAPIContractTests`）。
- Integration Test: 実 API への接続はオプトイン（既定は無効）。稼働中の Backend に対して実行する場合:

```sh
# 事前に Backend を起動（docker compose 等、http://localhost:8080 で待受）
TEST_RUNNER_RUN_REMOTE_INTEGRATION=1 xcodebuild test -scheme AppFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppFeatureTests/RemoteRecipeIntegrationTests
```

API が未起動の通常テスト実行では Integration Test は skip され、失敗しません。
