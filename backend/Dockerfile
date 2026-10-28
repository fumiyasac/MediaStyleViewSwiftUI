# ---- build stage: Go をコンパイルする（ビルドツールは最終イメージへ含めない） ----
FROM golang:1.23-alpine AS build

WORKDIR /src
RUN apk add --no-cache git

# 依存を先に解決してキャッシュを効かせる
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# CGO 無効の静的バイナリ。-s -w でサイズ削減。
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/seeder ./cmd/seed

# ---- run stage: 小さい実行用イメージ（非 root 実行） ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata \
    && adduser -D -u 10001 appuser

WORKDIR /app
COPY --from=build /out/api /app/api
COPY --from=build /out/seeder /app/seeder
# Seed 用 JSON（seeder は SEED_DIR 既定の ./seed を読む）
COPY seed /app/seed

USER appuser
EXPOSE 8080

# SIGTERM は api 側で受けて Graceful Shutdown する
ENTRYPOINT ["/app/api"]
