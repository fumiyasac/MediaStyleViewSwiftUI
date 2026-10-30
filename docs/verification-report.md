# Verification Report — v1.0 Showcase

PR #22（ポートフォリオ最終化）時点での検証結果の記録。実行して確認した結果のみを記載し、
未実施・未確認の項目は「未検証」として明示する。

## 検証メタ情報

| 項目 | 値 |
|---|---|
| 検証日 | 2026-10-30 (JST) |
| 分岐元 master Commit | `b0619bbba9b45cf110941d41836f2cca7d2c9b57`（PR #21 マージ） |
| 作業ブランチ | `docs/portfolio-showcase-finalization` |
| macOS | darwin 25.2.0 |
| Xcode | 26.5 (17F42) |
| Swift | 6.3.2（言語モード Swift 6, iOS Deployment Target 18.0） |
| Simulator | iPhone 17 Pro（iOS 26.x ランタイム） |
| Go | 1.23（`golang:1.23-alpine` コンテナ経由。ホストに Go 未インストール） |
| Docker | 28.1.1 / Docker Compose v2.35.1 |
| Backend 構成 | Docker Compose プロジェクト `recipe_calendar`（MySQL 8.4 + Go API） |

## Swift ビルド / テスト

- コマンド: `xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- 結果: **222 テスト中 221 passed / 1 failed**（41 スイート）
- 失敗: `MealLogEditorSnapshotTests / 入力フォーム（調理日・評価・メモ / Light）`
  - 既存の Snapshot 基準画像ドリフト（compact DatePicker の描画差）で、clean master でも同様に失敗する既知事象。
    本 PR の変更（アプリロジック）とは無関係。基準画像は本 PR では更新しない（ADR 0011 の方針）。
- iOS アプリ本体（`App/MediaStyleViewSwiftUI.xcodeproj` の `MediaStyleViewSwiftUI` スキーム）: **BUILD SUCCEEDED**

### Snapshot Testing

- Calendar / Timeline / Recipe Detail のスナップショットはすべて成功。
- MealLog Editor の 1 件のみ上記の既知ドリフトで失敗。

## Go ビルド / テスト（Docker 経由）

| コマンド | 結果 |
|---|---|
| `make vet`（`go vet ./...`） | 成功（指摘なし） |
| `make test`（`go test ./...`） | 成功（http / domain / usecase パッケージ ok） |
| `make test-race`（`go test -race ./...`） | 成功（データ競合の検出なし） |
| `make test-integration`（MySQL 結合） | 成功（`internal/adapter/persistence/mysql` ok、テスト専用 ID のみ使用） |

## Docker / MySQL / API スモークテスト

- `docker compose up -d`：MySQL healthy / API 起動。
- Migration：`migrations/000001..000003` 適用済み。Seed：レシピ 24 件。
- エンドポイント（`http://localhost:8080`）:

| Endpoint | 結果 |
|---|---|
| `GET /healthz` | 200 |
| `GET /readyz` | 200 |
| `GET /api/v1/recipes?limit=1` | 200（`pagination.total = 24`） |
| `GET /api/v1/recipes/recipe-01` | 200（ingredients 4 / steps 4） |
| `GET /api/v1/calendar?from=2026-10-01&to=2026-10-07` | 200（items 8） |
| `GET /swagger/doc.json` / `GET /swagger/index.html` | 200 / 200 |

## iOS + Go 結合（実機 Simulator から実 API）

- オプトイン統合テスト（`TEST_RUNNER_RUN_REMOTE_INTEGRATION=1`）: **8 テスト全通過**
  - `RemoteRecipeIntegrationTests`（一覧 / 詳細 / 404→nil / calendar / Calendar・Timeline UseCase 経由 E2E）
  - `CacheLiveIntegrationTests`（取得→キャッシュ→オフライン表示 / 詳細も同様）
- GUI 実機確認（iPhone 17 Pro, Simulator）:
  - Scenario A（正常利用）: Remote モードで Calendar / Timeline / Recipe Detail が MySQL 由来データを表示。✅
  - Scenario B（オフライン）: 取得後に API 停止 → アプリ再起動 → Timeline が保存済みデータを表示し、
    「保存済みデータを表示中（取得日時）」バナーを提示。✅（`docs/media/screenshots/06-offline-state.png`）
  - Scenario C（API 復旧）: 復旧後の再取得で最新へ更新・エラー解消（UseCase レベル統合テストで確認）。✅（GUI 目視は一部）
  - Scenario D（Fixture）: Go API なしで Calendar / Timeline / Recipe Detail / MealLog Editor が動作。✅
    （`docs/media/screenshots/01〜05`）

## 永続キャッシュの実機確認

- Remote モードで Timeline / Calendar を表示すると、端末の Application Support 配下に
  `RecipeCache/localhost_8080/recipe-list.json`, `entries-<from>_<to>.json` が生成されることを確認。
- API 停止後の再起動で、これらの保存済みデータから Timeline を復元できることを確認。

## スクリーンショット（すべて実機 Simulator から取得）

| ファイル | 画面 |
|---|---|
| `docs/media/screenshots/01-calendar.png` | Calendar（掲載マーカー・今日強調） |
| `docs/media/screenshots/02-timeline.png` | Timeline（日付別・掲載レシピ） |
| `docs/media/screenshots/03-recipe-detail.png` | Recipe Detail（Parallax Hero・材料・手順） |
| `docs/media/screenshots/04-meal-log-editor.png` | MealLog Editor（調理日・評価・メモ） |
| `docs/media/screenshots/05-recipe-detail-collapsed.png` | Collapsing Header（Compact Title） |
| `docs/media/screenshots/06-offline-state.png` | Offline（保存済みデータ表示バナー） |

## 本 PR で発見し修正した不具合

- **Calendar の月範囲が実在しない日付を生成していた**（`MonthKey.dateKeyRange` が末尾を常に `-31`）。
  Fixture では文字列比較で問題にならないが、Remote の `GET /api/v1/calendar?to=2026-11-31` は実在日付を要求するため
  30 日月・2 月で **HTTP 400** となり、該当月の掲載が Remote モードで読み込めなかった。
  末日を実在日（28/29/30/31）に修正し、`MonthKeyTests` を追加。修正後、`?to=2026-11-30` が 200 になることを実 API で確認。

## 未検証 / 既知の問題

- **MealLog Editor の Snapshot 1 件が失敗**（既知の基準画像ドリフト。アプリ動作には影響なし）。
- **デモ動画は未作成**。スクリプト操作での安定録画が本環境で難しいため、録画手順を `docs/demo-recording-guide.md` に記載。
- **CI 未整備**（GitHub Actions 等なし）。README に「Build Passing」等の未連動バッジは付けない。
- **Scenario C（API 復旧）の GUI 目視は一部のみ**。復旧→最新更新のロジックは UseCase 統合テストで担保。
- **バンドルされているレシピ写真のライセンス未確認**（`RecipeImages.xcassets`）。公開・再配布前に要確認（LICENSE 参照）。
- **認証・認可は未実装**（ローカル開発用途限定。MySQL はホストに公開していない）。
