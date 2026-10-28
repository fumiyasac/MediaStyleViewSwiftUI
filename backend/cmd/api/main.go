// Daily Recipe Calendar Backend API のエントリポイント。
//
// main では「組み立て(配線)」のみを行い、業務ロジックや SQL は書かない。
// 起動の各段階（Config→DB→Repository→UseCase→Handler→Router→HTTP Server→Shutdown）を明確に分離する。
//
//	@title			Daily Recipe Calendar Backend API
//	@version		1.0
//	@description	既存 iOS アプリ「Daily Recipe Calendar + Cooking Log」の Recipe/Calendar を提供する Backend API。
//	@description	認証・認可は実装しておらず、ローカル開発・学習/検証用途を想定する（インターネットへ直接公開しない）。
//	@BasePath		/
//	@schemes		http
//	@host			localhost:8080
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	httpadapter "github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/http"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/persistence/mysql"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/config"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/database"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

func main() {
	// 1. Config 読み込み（不足・不正は即エラー終了）。
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config error: %v", err)
	}
	if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// 2. MySQL 接続 / 3. GORM 初期化。
	db, err := database.Open(cfg)
	if err != nil {
		// 接続失敗の詳細に DSN(パスワード)を含めない。
		log.Fatalf("failed to connect database")
	}

	// 4. Repository 生成。
	recipeRepo := mysql.NewRecipeRepository(db)
	calendarRepo := mysql.NewCalendarRepository(db)

	// 5. UseCase 生成。
	recipeUC := usecase.NewRecipeUseCase(recipeRepo)
	calendarUC := usecase.NewCalendarUseCase(calendarRepo)

	// 6. Handler 生成（readyz は DB 疎通に calendarRepo を HealthChecker として利用）。
	recipeH := httpadapter.NewRecipeHandler(recipeUC)
	calendarH := httpadapter.NewCalendarHandler(calendarUC)
	healthH := httpadapter.NewHealthHandler(calendarRepo)

	// 7. Router 組み立て。
	router := httpadapter.NewRouter(recipeH, calendarH, healthH)

	// 8. HTTP Server 起動（Read/Write Timeout を設定）。
	srv := &http.Server{
		Addr:         ":" + cfg.HTTPPort,
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("listening on :%s (env=%s)", cfg.HTTPPort, cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	// 9. Graceful Shutdown。
	// SIGTERM/SIGINT を受けたら処理中リクエストの完了を待ってから終了する（Docker 停止時の切断を防ぐ）。
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
	log.Println("server stopped")
}
