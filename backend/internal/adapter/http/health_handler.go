package httpadapter

import (
	"context"
	"net/http"
	"time"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/http/dto"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

// HealthHandler は生存/準備確認のハンドラ。
type HealthHandler struct {
	checker usecase.HealthChecker
}

// NewHealthHandler は DB 疎通確認用の HealthChecker を注入して生成する。
func NewHealthHandler(checker usecase.HealthChecker) *HealthHandler {
	return &HealthHandler{checker: checker}
}

// Healthz godoc
//
//	@Summary		プロセス生存確認
//	@Description	API プロセスが起動しているかを返す。DB には依存しない。
//	@Tags			health
//	@Produce		json
//	@Success		200	{object}	dto.HealthResponse
//	@Router			/healthz [get]
func (h *HealthHandler) Healthz(c *gin.Context) {
	// DB へ依存しない純粋なプロセス生存確認。
	c.JSON(http.StatusOK, dto.HealthResponse{Status: "ok"})
}

// Readyz godoc
//
//	@Summary		依存サービス準備確認
//	@Description	MySQL へ接続可能かを確認する。利用不可なら 503 を返す。
//	@Tags			health
//	@Produce		json
//	@Success		200	{object}	dto.HealthResponse
//	@Failure		503	{object}	dto.ErrorResponse
//	@Router			/readyz [get]
func (h *HealthHandler) Readyz(c *gin.Context) {
	// DB 疎通に短いタイムアウトを設ける（ぶら下がり防止）。
	ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
	defer cancel()

	if err := h.checker.Ping(ctx); err != nil {
		// DB 利用不可を成功扱いにせず 503。内部エラーの詳細は出さない。
		writeError(c, http.StatusServiceUnavailable, "SERVICE_UNAVAILABLE", "Database is not ready.")
		return
	}
	c.JSON(http.StatusOK, dto.HealthResponse{Status: "ok"})
}
