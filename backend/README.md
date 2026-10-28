# Daily Recipe Calendar — Go Backend API

既存 iOS アプリ「Daily Recipe Calendar + Cooking Log」の **Recipe / Calendar** を提供する Go 製 REST API です。
Gin + GORM + MySQL + Docker で構成し、Swagger で仕様を確認できます。

> **公開範囲について**: 認証・認可は実装していません。**ローカル開発・学習/検証用途** を想定しており、
> API や Swagger UI を**インターネットへ直接公開しないでください**。MySQL はホストへ公開しない設定です。

## 技術スタック

| 領域 | 採用 |
|---|---|
| 言語 | Go 1.23 |
| HTTP | Gin v1.10.0 |
| ORM | GORM v1.25.12 / driver/mysql v1.5.7 |
| DB | MySQL 8.4 (utf8mb4 / InnoDB) |
| Migration | golang-migrate (`migrate/migrate:v4.17.1`) |
| API Doc | swaggo/swag v1.16.4 + gin-swagger（Swagger 2.0） |
| Test | 標準 testing + testify + net/http/httptest |
| Container | Docker / Docker Compose（プロジェクト名 `recipe_calendar`） |

## アーキテクチャ（Clean Architecture 風・依存は内向き一方向）

```
HTTP Request → Gin Handler → UseCase → Repository Interface(ports) → GORM Repository → MySQL
                 (adapter/http)  (usecase)                           (adapter/persistence/mysql)
```

- **domain**: Recipe / DailyRecipeEntry / Date / Category / Error。gin・gorm・HTTP に非依存。
- **usecase**: 一覧/詳細/カレンダー取得・入力検証・Domain→エラー。Repository は interface(ports.go) 経由。
- **adapter/http**: Query/Path 取得・検証・UseCase 呼出・HTTP Status 決定・DTO 変換。
- **adapter/persistence/mysql**: GORM Model（Domain と分離）・SQL・Domain 変換。
- **infrastructure**: config（環境変数）/ database（GORM 接続・Pool）。

## クイックスタート

```bash
cd backend
cp .env.example .env            # パスワード等は必要に応じて変更（.env はコミットしない）

docker compose up -d --build    # MySQL + API 起動（MySQL healthy 後に API 起動）
make migrate-up                 # スキーマ適用（golang-migrate）
make seed                       # レシピ/掲載割当を投入（冪等・再実行可能）
```

ポート 8080 が他プロセスと競合する場合は `API_HOST_PORT` を変更:

```bash
API_HOST_PORT=8081 docker compose up -d --build
```

### 動作確認

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
curl "http://localhost:8080/api/v1/recipes?limit=10&offset=0"
curl "http://localhost:8080/api/v1/recipes?category=japanese"
curl "http://localhost:8080/api/v1/recipes/recipe-01"
curl "http://localhost:8080/api/v1/calendar?from=2026-10-01&to=2026-10-31"
```

Swagger UI: <http://localhost:8080/swagger/index.html>

停止: `make down`（データ volume は保持）。

## Endpoint

| Method | Path | 概要 |
|---|---|---|
| GET | `/healthz` | プロセス生存確認（DB 非依存） |
| GET | `/readyz` | MySQL 疎通確認（不可なら 503） |
| GET | `/api/v1/recipes` | 一覧（`category` / `limit`(既定20,最大100) / `offset`） |
| GET | `/api/v1/recipes/{id}` | 詳細（材料・手順・画像参照。無ければ 404） |
| GET | `/api/v1/calendar` | 掲載割当（`from`/`to` 必須, YYYY-MM-DD, 両端含む, 最大92日） |

エラーは `{"error":{"code","message"}}` 形式。空配列は `null` でなく `[]` を返します。

## 環境変数

`APP_ENV` / `HTTP_PORT` / `MYSQL_HOST` / `MYSQL_PORT` / `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD`
（compose では `MYSQL_ROOT_PASSWORD` / `API_HOST_PORT` も使用）。不足・不正値があると起動時に明示エラーで中断します。
パスワードや DSN はログへ出力しません。

## 日付（DATE）の扱い

掲載日は「時刻を持たない暦日」です。GORM 接続は `loc=UTC&parseTime=true`、`domain.Date` は年月日のみを保持し、
UTC で読み書きします。これにより MySQL `DATE` ↔ Go `time.Time` ↔ Swift の日付キー(`yyyy-MM-dd`)が 1 日ずれません。

## Migration

スキーマは **golang-migrate のバージョン付き SQL**（`migrations/`）で管理し、**API 起動時に AutoMigrate しません**。

```bash
make migrate-up        # 最新まで適用（compose の migrate サービス, MySQL healthy 後）
make migrate-down      # 1 つ戻す
make migrate-version   # 現在の適用バージョン
```

- 適用履歴は MySQL の `schema_migrations` テーブルで管理され、二重適用されません。
- **MySQL は DDL がトランザクション非対応** です。Migration の途中で失敗すると `dirty` 状態になり得ます。
  その場合は原因を修正し、`migrate force <version>` で dirty を解除してから再実行してください
  （down の破壊的変更にも注意）。

## Seed

```bash
make seed    # seed/recipes.json, seed/daily_recipe_entries.json を投入
```

- **冪等**: 同じ Recipe ID は `ON DUPLICATE KEY UPDATE`、材料・手順は `recipe_id` で全削除→再挿入。再実行で重複しません。
- **原子性**: 1 トランザクションで投入し、途中失敗はロールバック。
- API 起動時には投入しません（明示実行のみ）。
- 既存 iOS の Fixture（24 レシピ・recipe-01〜24）の ID/タイトル/材料/手順を再利用しています。

## テスト

```bash
make test               # Unit Test（DB 不要）
make test-race          # Unit Test + race detector
make test-integration   # Integration Test（実 MySQL。先に up → migrate-up が必要）
make fmt                # gofmt -w
make vet                # go vet
make swagger            # Swagger 仕様(docs/)を再生成
```

- **Unit Test** は Repository の Fake を使い MySQL 無しで動作（UseCase / Handler / Domain）。
- **Integration Test** は build tag `integration` で分離。実 MySQL を使い、テスト専用 ID(`itest-*`) のみ
  作成/削除するため既存 seed データを破壊しません（厳密な分離が必要なら `MYSQL_DATABASE` をテスト用 DB に向けてください）。

## Swagger 再生成

ハンドラ/`main.go` のアノテーションを変更したら `make swagger` で `docs/` を再生成し、差分をコミットしてください
（出力は Swagger 2.0）。

## iOS 側との関係

本 Backend は Recipe/掲載割当のみを所有します。**MealLog（調理記録）は iOS の SwiftData が所有** し、本 API では扱いません。
Swift 側の Remote Repository 接続は次段階で行う想定で、本 PR では iOS コードは変更していません。
