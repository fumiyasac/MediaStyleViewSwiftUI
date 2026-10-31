# Daily Recipe Calendar

カレンダーを起点にレシピを閲覧し、材料と調理手順を確認し、作った料理の記録を残して振り返るための iOS アプリ。レシピは Go 製 API（MySQL）から取得し、オフライン閲覧用に端末側で永続キャッシュする。調理記録は SwiftData によりローカル保存する。

SwiftUI、Swift 6 Concurrency、MVVM + StateMachine、SwiftData、Go（Gin/GORM）、MySQL、Docker を扱う個人開発のポートフォリオ作品である。

Status: v1.0 相当。ローカル実行・学習用途を想定しており、認証は実装していない。

## Overview

- Calendar: 日ごとの掲載レシピと調理記録をマーカーで一覧し、連続スクロールで前後の月を参照する。
- Recipe Detail: 写真を主役とする Parallax Hero と Collapsing Header で、材料と調理手順を提示する。
- Cooking Log: 作った料理を調理日・評価・メモ付きで保存する（SwiftData）。
- Timeline: 掲載レシピと調理履歴を日付別に俯瞰し、検索とフィルタで絞り込む。
- Remote + Offline: Go API から取得したレシピを永続キャッシュし、通信障害時は取得日時付きで保存済みデータを表示する。
- Fixture モード: バックエンドを起動しなくても同梱データで全画面が動作する（既定）。

## Features

- カレンダー上での掲載レシピ（🍴マーカー）と調理済み日の一覧表示
- レシピ詳細での材料・分量・手順の閲覧、写真メディア風のスクロール表現
- 評価（★）とメモ付きの調理記録、保存結果の Calendar / Timeline への反映
- タイムラインでの検索と種別フィルタ（すべて／レシピ／作った記録）
- Go API からのレシピ取得（Fixture / Remote を起動時に選択）
- オフライン時の保存済みデータ表示と、復旧後の再取得
- アクセシビリティ対応（Dynamic Type、VoiceOver、Reduce Motion、Dark Mode）

## Screenshots

実機 Simulator（iPhone 17 Pro）から取得した実アプリ画面である。

| Calendar | Timeline | Recipe Detail |
|---|---|---|
| ![Calendar](docs/media/screenshots/01-calendar.png) | ![Timeline](docs/media/screenshots/02-timeline.png) | ![Recipe Detail](docs/media/screenshots/03-recipe-detail.png) |

| MealLog Editor | Collapsing Header | Offline（保存済み表示） |
|---|---|---|
| ![MealLog Editor](docs/media/screenshots/04-meal-log-editor.png) | ![Collapsing Header](docs/media/screenshots/05-recipe-detail-collapsed.png) | ![Offline](docs/media/screenshots/06-offline-state.png) |

## Demo

デモ動画は未収録である。録画シナリオと手順は [docs/demo-recording-guide.md](docs/demo-recording-guide.md) に記載した。

## Tech Stack

| 領域 | 使用技術 |
|---|---|
| iOS 言語 / UI | Swift 6（言語モード Swift 6）、SwiftUI、Observation |
| 並行性 / 永続化 | Swift Concurrency（async/await、actor）、SwiftData |
| テスト | Swift Testing、[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)（テストターゲット限定） |
| その他 iOS | 祝祭日判定に [CalculateCalendarLogic](https://github.com/fumiyasac/handMadeCalendarAdvance) |
| Backend | Go 1.23、Gin、GORM、MySQL 8.4 |
| Infra / Docs | Docker、Docker Compose、golang-migrate、Swagger 2.0、ADR |

iOS Deployment Target は iOS 18.0 以上。検証環境は Xcode 26.5、Swift 6.3.2、iPhone 17 Pro Simulator。

## Architecture

アプリ本体（`App/`）と機能パッケージ（`AppFeature`）に分割したマルチモジュール構成を採る。Presentation は MVVM + StateMachine、データ取得は Repository パターンで Fixture / Remote / Cache を差し替える。MealLog は取得元に関わらず SwiftData を使う。

```mermaid
flowchart TD
    subgraph iOS["iOS App (SwiftUI)"]
        V["Views: Calendar / Timeline / RecipeDetail / MealLogEditor"]
        VM["ViewModel + StateMachine (State/Action/Effect/Reducer)"]
        UC["UseCase (Calendar / Timeline / RecipeDetail)"]
        V --> VM --> UC
        UC --> REPO["RecipeRepository (protocol)"]
        UC --> MLREPO["MealLogRepository (protocol)"]
        REPO --> FIX["FixtureRecipeRepository"]
        REPO --> CACHED["CachedRecipeRepository"]
        CACHED --> REMOTE["RemoteRecipeRepository"]
        CACHED --> STORE["RecipeCacheStore (FileRecipeCacheStore actor)"]
        REMOTE --> API["APIClient / URLSession"]
        MLREPO --> SD["SwiftData MealLog Repository (@ModelActor)"]
        STORE --> JSON[("JSON files (Application Support)")]
        SD --> SDB[("SwiftData store")]
    end
    subgraph Backend["Go Backend (Docker)"]
        GIN["Gin Handler"] --> GUC["UseCase"] --> GORM["GORM Repository"] --> DB[("MySQL")]
    end
    API -->|"HTTP /api/v1"| GIN
```

取得元（Fixture / Remote）は Composition Root の `CalendarFeatureDependencies` が起動時に 1 度だけ決定し、全画面で同一インスタンスを共有する。Debug では環境変数 `RECIPE_DATA_SOURCE` で選択でき、既定は `fixture` である。

## Data Flow

### Recipe 取得（MySQL から SwiftUI まで）

```mermaid
flowchart LR
    DB[("MySQL")] --> GORM["GORM"] --> GUC["Go UseCase"] --> GIN["Gin Handler"]
    GIN -->|"JSON (camelCase)"| URL["URLSession"]
    URL --> DTO["DTO + RecipeDTOMapper"] --> REPO["RecipeRepository"]
    REPO --> SUC["Swift UseCase"] --> SM["StateMachine"] --> UI["SwiftUI"]
```

### MealLog 保存

```mermaid
flowchart LR
    RD["Recipe Detail"] --> ED["MealLog Editor"] --> VM["ViewModel / Effect"]
    VM --> MREPO["MealLogRepository"] --> SD["SwiftData (@ModelActor)"]
    SD --> R["保存結果"] --> CAL["Calendar へ反映"]
    R --> TL["Timeline へ反映 (reload)"]
```

### Offline Recovery（Network-first + Cache フォールバック）

```mermaid
flowchart TD
    REQ["読み込み要求"] --> TRY{"Remote 取得"}
    TRY -->|"成功"| SAVE["キャッシュ更新 → 最新を表示 (origin: remote)"]
    TRY -->|"通信障害(未接続/timeout/5xx)"| HASC{"保存済みキャッシュあり?"}
    HASC -->|"あり(期限内)"| STALE["保存済みを表示 + バナー (origin: cache)"]
    HASC -->|"なし"| ERR["エラー表示 + 再試行"]
    TRY -->|"404 / Decoding / Mapping"| PROP["エラーとして扱う(キャッシュで隠さない)"]
    TRY -->|"Cancellation"| IGN["画面エラーにしない(フォールバックしない)"]
    ERR -->|"API 復旧 → Retry"| TRY
```

詳細は [ADR 0015](docs/adr/0015-offline-recipe-cache-and-recovery.md) を参照。

## Getting Started

### 前提

- macOS、Xcode 26.x、iOS 18 以上の Simulator
- Docker および Docker Compose（Backend 用。Go はコンテナ経由で実行するためホスト側にインストール不要）

### Fixture モード（Backend なしで動かす最短手順）

1. `MediaStyleViewSwiftUI/App/MediaStyleViewSwiftUI.xcodeproj` を Xcode で開く。
2. Swift Package 依存は自動解決される。
3. `MediaStyleViewSwiftUI` スキームと iPhone 17 Pro（iOS 18 以上）を選択する。
4. Run する。既定は Fixture モードのため、ネットワーク接続なしで Calendar / Timeline / Recipe Detail / MealLog Editor が動作する。

### Backend（Docker Compose）

`backend/` ディレクトリで実行する。詳細は [backend/README.md](backend/README.md) を参照。

```bash
cd backend
cp .env.example .env             # 設定ファイルを作成する（.env はコミットしない）
make up                          # MySQL と Go API を起動する
make migrate-up                  # Migration を適用する
make seed                        # Seed データ（レシピ）を投入する
curl -s http://localhost:8080/healthz           # ヘルスチェック
open http://localhost:8080/swagger/index.html   # Swagger UI
```

### iOS を Remote モードで動かす

1. 上記で Backend を起動し、`http://localhost:8080` で待ち受けている状態にする。
2. Xcode の Scheme → Run → Arguments → Environment Variables に次を追加する。

   ```text
   RECIPE_DATA_SOURCE = remote
   ```

3. Run すると Calendar / Timeline / Recipe Detail が MySQL 由来のデータを表示する。
4. 接続先は `APIConfiguration` で管理する（既定は `http://localhost:8080`）。Base URL をコードへ直接書かない方針を採る。ATS はグローバル無効化せず、`NSAllowsLocalNetworking` のみ許可している。

### Troubleshooting

| 症状 | 確認ポイント |
|---|---|
| Docker が起動しない | Docker Desktop の状態、`docker compose ps` の出力 |
| MySQL へ接続できない | `make up` 後に MySQL が healthy になるまで待つ。`.env` の値を確認する |
| Migration 未適用 | `make migrate-up`、`make migrate-version` で状態を確認する |
| Seed データがない | `make seed`。API 起動時には自動投入されない仕様である |
| Simulator から localhost に繋がらない | Simulator は Mac の localhost に到達可能。実機は Mac の LAN アドレスを注入する |
| HTTP 通信が失敗する | `App/.../Info.plist` の `NSAllowsLocalNetworking` を確認する |
| Remote でデータが表示されない | `RECIPE_DATA_SOURCE=remote` と Backend 起動を確認する。失敗時に Fixture へ自動切替はしない |
| キャッシュだけ表示される | 通信障害時の保存済み表示である。復旧後に Retry（再読み込み）で最新へ更新される |
| Swagger UI が開けない | `make up` 後に `http://localhost:8080/swagger/index.html` を開く |

## Backend API

ベースパスは `/api/v1`。エラーレスポンスは `{"error":{"code","message"}}` 形式を返す。Swagger 定義（2.0）は `backend/docs/` に生成され、`http://localhost:8080/swagger/index.html` で閲覧できる。

| Method | Path | 概要 |
|---|---|---|
| GET | `/healthz` | Liveness |
| GET | `/readyz` | Readiness（DB 接続確認） |
| GET | `/api/v1/recipes?limit&offset&category` | レシピ一覧（ページング） |
| GET | `/api/v1/recipes/{id}` | レシピ詳細（材料・手順） |
| GET | `/api/v1/calendar?from&to` | 期間の掲載割当（最大 92 日） |

## Testing

```bash
# iOS: 全テスト（Unit + Snapshot）
xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# iOS: 実 API への結合テスト（オプトイン、Backend 起動が前提）
TEST_RUNNER_RUN_REMOTE_INTEGRATION=1 xcodebuild test -scheme AppFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppFeatureTests/CacheLiveIntegrationTests \
  -only-testing:AppFeatureTests/RemoteRecipeIntegrationTests

# Go: Docker 経由（ホストに Go 不要）
cd backend
make vet && make test && make test-race
make up && make migrate-up && make test-integration    # MySQL 結合（テスト専用 ID のみ使用）
```

Unit は Swift Testing、画面の視覚回帰は Snapshot Testing を使う（基準環境と更新手順は [ADR 0011](docs/adr/0011-visual-regression-snapshot-testing.md) に記載）。実 API に依存しない Unit テストは Fake（HTTPClient / Repository）で実装している。最新の検証結果は [docs/verification-report.md](docs/verification-report.md) を参照。

## Design Decisions

設計判断は Architecture Decision Record（`docs/adr/`）に記録している。主なものは次のとおり。

- MVVM + StateMachine への統合: [0004](docs/adr/0004-integrate-calendar-feature-with-statemachine.md)
- SwiftData を View 層から隔離: [0003](docs/adr/0003-isolate-swiftdata-from-view-layer.md)
- レシピ中心のカレンダーと Timeline: [0008](docs/adr/0008-recipe-centric-calendar.md) / [0006](docs/adr/0006-recipe-meallog-timeline.md)
- メディア風 Recipe Detail と Zoom 遷移: [0009](docs/adr/0009-recipe-detail-media-style-ui.md) / [0010](docs/adr/0010-recipe-zoom-navigation-transition.md)
- Snapshot Testing: [0011](docs/adr/0011-visual-regression-snapshot-testing.md)
- Go Backend API: [0012](docs/adr/0012-go-backend-recipe-calendar-api.md)
- Remote Repository 境界と画面統合: [0013](docs/adr/0013-swift-remote-repository-go-backend-api-boundary.md) / [0014](docs/adr/0014-remote-recipe-integration-calendar-timeline-detail.md)
- オフラインキャッシュと復旧: [0015](docs/adr/0015-offline-recipe-cache-and-recovery.md)

技術的な要点は次のとおり。

- StateMachine: Reducer は純粋関数、非同期 I/O は Effect / ViewModel に分離する。requestID で古い結果を破棄し、月単位のキャッシュで連続スクロールの破綻を避ける。
- Swift 6 Concurrency: ViewModel は `@MainActor`、Domain と State は Sendable、SwiftData Repository は `@ModelActor` とする。Task Cancellation を適切に扱い、`@unchecked Sendable` は使わない。
- Repository パターン: Fixture / Remote / Cache を同一 Protocol で差し替える。DTO と Domain を Mapper で分離する。
- Offline: Network-first + Cache フォールバック方式を採る。Fresh / Stale / Expired による鮮度管理、通信失敗とデータ 0 件の区別、Cancellation をフォールバックのトリガーにしない設計を徹底する。

## Project Development History

機能単位で段階的に開発した。主な節目は次のとおり。

- Recipe Domain と Fixture、Calendar + StateMachine、Recipe Detail と MealLog Editor、Timeline の実装
- メディア風 Recipe Detail、Zoom Navigation、Snapshot Testing の導入
- Go Backend（Gin / GORM / MySQL / Docker / Swagger）、Swift Remote Repository、Calendar / Timeline / Detail の Remote 統合
- 永続オフラインキャッシュと通信障害からの復旧
- v1.0 ショーケース整備

## Limitations

- 認証と認可は未実装である。ローカル開発用途を前提とし、MySQL はホストに公開しない構成を採る。
- レシピの作成および編集 API は提供しない（読み取り専用）。MealLog の Remote 同期も未対応で、ローカル SwiftData のみを使う。
- 画像は同梱 Asset（Recipe ID 由来）で解決する。Remote 画像配信や独自のダウンロード基盤は実装していない。
- CI（GitHub Actions 等）は未整備である。
- 既知の Snapshot 失敗が 1 件存在する（MealLog Editor 入力フォームの基準画像ドリフト）。詳細は [verification-report](docs/verification-report.md) を参照。
- 同梱レシピ写真のライセンスは未確認である。再配布前の確認が必要である（[LICENSE](LICENSE) を参照）。

## Future Work

- オフラインの二段階表示（cache-first 表示 → バックグラウンド再取得）とネットワーク復旧検知による Retry ヒント
- MealLog の Remote 同期、アカウント連携、認証
- レシピの作成および編集、画像アップロードと CDN 配信
- CI（ビルド、テスト、Lint）の整備

## License

[MIT](LICENSE)。同梱レシピ画像は対象外のため、再配布前にライセンスを確認する必要がある。
