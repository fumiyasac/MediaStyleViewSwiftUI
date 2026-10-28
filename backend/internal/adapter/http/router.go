package httpadapter

import (
	// docs は swag が生成する Swagger 仕様を副作用 import で登録する。
	// 生成前はこの import があるとビルドできないため、make swagger 実行後に有効になる。
	_ "github.com/fumiyasac/MediaStyleViewSwiftUI/backend/docs"
	"github.com/gin-gonic/gin"
	swaggerfiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
)

// NewRouter は Gin のルーティングを組み立てる。
//
// Handler は外側から注入する（依存は HTTP→UseCase→Repository の一方向）。
// Recovery ミドルウェアで panic を 500 へ変換し、プロセスを落とさない。
func NewRouter(recipeH *RecipeHandler, calendarH *CalendarHandler, healthH *HealthHandler) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// ヘルスチェック（認証不要・DB 非依存/依存を明確に分ける）
	r.GET("/healthz", healthH.Healthz)
	r.GET("/readyz", healthH.Readyz)

	// Swagger UI: http://localhost:8080/swagger/index.html
	r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerfiles.Handler))

	// 公開 API（v1）
	v1 := r.Group("/api/v1")
	{
		v1.GET("/recipes", recipeH.List)
		v1.GET("/recipes/:id", recipeH.GetByID)
		v1.GET("/calendar", calendarH.GetRange)
	}

	return r
}
