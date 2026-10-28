# 0012. Daily Recipe Calendar Backend における Go + Gin + GORM + MySQL の採用と責務分離

- Status: Accepted
- Date: 2026-10-28
- 関連PR: Phase 12（Go Backend API Foundation）
- 前提: PR #6〜#17（iOS 側 Recipe/MealLog/Calendar/Timeline・Snapshot Testing / ADR 0003〜0011）

## Context

iOS アプリ「Daily Recipe Calendar + Cooking Log」のレシピ/掲載データはこれまで iOS 内の Fixture で提供していた。
将来の Remote Repository 接続に備え、Recipe と掲載カレンダーを提供する独立した Backend API を新設する。
本 PR は Backend 単体で実行・検証できる基盤までを対象とし、認証・認可・MealLog 同期・ユーザー管理は実装しない。

## Decision

1. **技術選定**: Go 1.23 + Gin + GORM + MySQL 8.4 + Docker/Compose。Migration は golang-migrate、API 仕様は swaggo。
2. **Clean Architecture 風の依存方向**: HTTP→UseCase→Repositoryインターフェース→GORM実装→MySQL の内向き一方向。
3. **Domain と GORM Model を分離**: 業務モデルは永続化タグ/FK を持たず、変換は persistence 層の converter に閉じる。
4. **Versioned Migration**: スキーマは SQL で管理し、API 起動時に AutoMigrate しない。
5. **Seed は別コマンド**: 冪等・原子的に投入。起動時自動投入はしない。
6. **認証なし・ローカル限定**: MySQL をホスト非公開、API/Swagger をインターネット非公開前提とする。

### Go を採用する理由
単一バイナリ・軽量コンテナ・高速起動・標準 testing の充実。iOS とは別言語だが Backend 単体で完結し、学習題材としても明快。

### Gin を利用する理由
軽量で広く使われる HTTP フレームワーク。ルーティング・Recovery ミドルウェア・gin-swagger 連携が揃い、Handler を薄く保てる。

### GORM を利用する理由
MySQL ドライバ・関連 Preload・`ON DUPLICATE KEY UPDATE`(clause.OnConflict)・トランザクションを宣言的に扱える。
一方で Domain を GORM に縛らないため、Model 分離と converter を挟む。

### MySQL を採用する理由
掲載日(DATE)・関連(材料/手順/掲載割当)・Foreign Key・索引を素直に表現でき、ローカル Docker で容易に再現できる。
utf8mb4 で日本語を安全に保存する。

### Clean Architecture に近い依存構造
UseCase は `usecase/ports.go` の Repository インターフェースに依存し、GORM/Gin を知らない。
これにより MySQL 無しの Unit Test（Fake 差し替え）が可能になり、永続化や公開プロトコルの変更が UseCase へ波及しない。

### GORM Model と Domain Model の分離
`RecipeModel` 等（gorm タグ・タイムスタンプ・FK あり）と `domain.Recipe`（純粋値型）を分け、変換は converter.go に集約。
HTTP へは GORM Model を返さず DTO へ変換する（内部構造を API 契約に漏らさない）。

### Swagger による API 仕様管理
swaggo のアノテーションを Handler/main に付け、`make swagger` で `docs/`（Swagger 2.0）を生成、Swagger UI で確認する。
swaggo は OpenAPI 3.x ではなく Swagger 2.0 出力であることを理解して採用した（3.x が必要なら別ツールを別途検討）。

### Versioned Migration（AutoMigrate 不採用）
`golang-migrate` の up/down SQL で明示管理し、`schema_migrations` で履歴・二重適用防止。
AutoMigrate を起動時に走らせないことで、スキーマ変更をレビュー可能にし、通常起動と分離する。
MySQL は DDL がトランザクション非対応のため、失敗時の dirty 状態と `force` 復旧を README に明記。

### Seed データ管理
既存 iOS Fixture（recipe-01〜24）の ID/内容を JSON に再利用。`ON DUPLICATE KEY UPDATE` と
`recipe_id` 全削除→再挿入で冪等化し、1 トランザクションで原子的に投入。起動時自動投入はしない。

### 認証・認可を今回実装しない判断と公開範囲の制限
ローカル開発・学習/検証用途に限定するため、認証/ユーザー管理/MealLog 同期は先行実装しない（YAGNI）。
その代わり MySQL はホスト非公開、API/Swagger はインターネット非公開を前提とする運用制約を文書化した。

### Unit Test / Integration Test の方針
Unit は DB 不要（Repository Fake）で UseCase/Handler(httptest)/Domain を検証。
Integration は build tag `integration` で分離し実 MySQL で Migration/CRUD/順序/範囲検索/FK/冪等を検証。
通常の `go test ./...` は DB 不要で完結し、Integration のみ MySQL を要する。

### Swift 側 Repository との将来の接続
API の Recipe ID は Swift の RecipeID と一致させ、掲載日は日付キー(yyyy-MM-dd)に合わせた。
iOS は将来 `RecipeRepository` の Remote 実装から本 API を呼べる。MealLog は iOS(SwiftData)所有のまま分離を維持する。

## Alternatives

- **言語/FW**: Node/Express や Rails も候補だが、単一バイナリ・型安全・学習性から Go+Gin を採用。
- **ORM なし(database/sql)**: 冗長になりやすく、GORM の Preload/OnConflict を活かす方を採用（Domain 分離で結合は限定）。
- **AutoMigrate**: 手軽だがレビュー不能・暗黙のスキーマ変更リスクがあり不採用。
- **OpenAPI 3.x 先行**: swaggo は 2.0。3.x は別ツールが必要で、今回は 2.0 で十分と判断。
- **MealLog を MySQL へ移行**: 本 PR の範囲外（iOS 所有を維持）。

## Consequences

- Backend 単体で起動・Migration・Seed・API 応答・Swagger 確認・テストが可能になった。
- Domain/UseCase が DB/HTTP に非依存で、テスト容易性と変更耐性が高い。
- iOS は変更不要のまま、将来の Remote 接続点が用意された。

### トレードオフ

- レイヤ分割と DTO/converter による記述量の増加（小規模 API には重め）。責務の明確化を優先した。
- GORM 採用で ORM 固有の挙動（Preload/OnConflict 等）に依存。Domain 分離で影響範囲は限定。
- Swagger 2.0 のため 3.x 固有機能は使えない。
- 認証がないため公開範囲をローカルに限定する運用前提が必須。

## 検証（本 PR 時点）

- `gofmt`/`go vet`/`go test ./...`/`go test -race ./...` 成功（Unit: domain/usecase/http）。
- Integration Test（実 MySQL, `-tags=integration`）成功（テーブル存在/CRUD順序/範囲検索/FK/冪等）。
- `docker compose config/build/up` 成功、Migration 適用(version 3)、Seed 投入(24 recipes/35 entries)。
- curl で全 Endpoint の正常/異常(404/400/503)・空配列`[]`・同日複数掲載・日付非ズレを確認。Swagger UI 到達(200)。
- ホスト 8080 が別プロセス使用中のため、検証は `API_HOST_PORT=8081` で実施（既定は 8080）。
