# Daily Recipe Calendar Backend — 開発タスク
#
# Go はコンテナ(golang:1.23)経由で実行する（ホストに Go 未インストールでも動くようにするため）。
# DB/Migration/Seed は Docker Compose を利用する。
#
# 事前に `cp .env.example .env` を実行しておくこと（.env はコミットしない）。

-include .env
export

COMPOSE        := docker compose
GO_IMAGE       := golang:1.23-alpine
MODCACHE_VOL   := recipe_calendar_gomod
NET            := recipe_calendar_default
MIGRATE_IMAGE  := migrate/migrate:v4.17.1
SWAG_VERSION   := v1.16.4
DB_URL         := mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@tcp(mysql:3306)/$(MYSQL_DATABASE)

# ホストから Go をコンテナで動かす共通ランナー
GORUN := docker run --rm -v "$(CURDIR)":/app -v $(MODCACHE_VOL):/go/pkg/mod -w /app $(GO_IMAGE)

.PHONY: up down logs migrate-up migrate-down migrate-version seed \
        test test-race test-integration fmt vet swagger tidy help

help:
	@echo "up/down/logs, migrate-up/migrate-down/migrate-version, seed, test/test-race/test-integration, fmt/vet/tidy, swagger"

# --- Docker Compose（API + MySQL） ---
up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f api

# --- Migration（golang-migrate / compose） ---
# up は compose の migrate サービス(既定 command=up)を使う。MySQL healthy 後に実行される。
migrate-up:
	$(COMPOSE) --profile tools run --rm migrate

# down/version は migrate イメージを compose ネットワーク上で直接実行する。
migrate-down:
	docker run --rm --network $(NET) -v "$(CURDIR)/migrations":/migrations:ro $(MIGRATE_IMAGE) \
	  -path=/migrations -database="$(DB_URL)" down 1

migrate-version:
	docker run --rm --network $(NET) -v "$(CURDIR)/migrations":/migrations:ro $(MIGRATE_IMAGE) \
	  -path=/migrations -database="$(DB_URL)" version

# --- Seed（明示実行。API 起動時には投入しない） ---
# api イメージを再利用しつつ、ENTRYPOINT を seeder へ上書きして実行する。
seed:
	$(COMPOSE) run --rm --entrypoint /app/seeder api

# --- Go: test / lint / docs ---
tidy:
	$(GORUN) sh -c "apk add --no-cache git >/dev/null 2>&1 && go mod tidy"

test:
	$(GORUN) sh -c "apk add --no-cache git >/dev/null 2>&1 && go test ./..."

test-race:
	$(GORUN) sh -c "apk add --no-cache git gcc musl-dev >/dev/null 2>&1 && go test -race ./..."

# Integration Test は Migration 済みの MySQL が必要（先に up → migrate-up）。
# compose ネットワーク上で MYSQL_HOST=mysql として実行する。テスト専用 ID(itest-*)のみ作成/削除する。
test-integration:
	docker run --rm --network $(NET) -v "$(CURDIR)":/app -v $(MODCACHE_VOL):/go/pkg/mod -w /app \
	  -e MYSQL_HOST=mysql -e MYSQL_PORT=3306 -e MYSQL_DATABASE=$(MYSQL_DATABASE) \
	  -e MYSQL_USER=$(MYSQL_USER) -e MYSQL_PASSWORD=$(MYSQL_PASSWORD) \
	  $(GO_IMAGE) sh -c "apk add --no-cache git >/dev/null 2>&1 && go test -tags=integration ./internal/adapter/persistence/mysql/..."

fmt:
	$(GORUN) gofmt -w .

vet:
	$(GORUN) sh -c "apk add --no-cache git >/dev/null 2>&1 && go vet ./..."

# Swagger 仕様(docs/)を再生成する。
swagger:
	$(GORUN) sh -c "apk add --no-cache git >/dev/null 2>&1 && go run github.com/swaggo/swag/cmd/swag@$(SWAG_VERSION) init -g cmd/api/main.go -o docs --parseDependency --parseInternal"
