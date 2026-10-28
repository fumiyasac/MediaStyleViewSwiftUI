package httpadapter

import (
	"net/http"
	"strconv"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/http/dto"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

// RecipeHandler はレシピ関連エンドポイントのハンドラ。
// UseCase のみに依存し、SQL/GORM を直接扱わない。
type RecipeHandler struct {
	uc *usecase.RecipeUseCase
}

// NewRecipeHandler は UseCase を注入して生成する。
func NewRecipeHandler(uc *usecase.RecipeUseCase) *RecipeHandler {
	return &RecipeHandler{uc: uc}
}

// List godoc
//
//	@Summary		レシピ一覧を取得
//	@Description	カテゴリ絞り込みとページングでレシピ概要の一覧を返す。limit 既定 20 / 最大 100。
//	@Tags			recipes
//	@Produce		json
//	@Param			category	query		string	false	"カテゴリ (japanese/western/chinese/italian/dessert/healthy)"
//	@Param			limit		query		int		false	"取得件数 (既定 20, 最大 100)"
//	@Param			offset		query		int		false	"オフセット (既定 0)"
//	@Success		200			{object}	dto.RecipeListResponse
//	@Failure		400			{object}	dto.ErrorResponse
//	@Failure		500			{object}	dto.ErrorResponse
//	@Router			/api/v1/recipes [get]
func (h *RecipeHandler) List(c *gin.Context) {
	// Query Parameter の取得。数値として不正なら 400（SQL へ渡す前に弾く）。
	limit, ok := parseOptionalInt(c, "limit")
	if !ok {
		writeError(c, http.StatusBadRequest, "INVALID_PAGINATION", "limit must be an integer.")
		return
	}
	offset, ok := parseOptionalInt(c, "offset")
	if !ok {
		writeError(c, http.StatusBadRequest, "INVALID_PAGINATION", "offset must be an integer.")
		return
	}

	result, err := h.uc.List(c.Request.Context(), usecase.ListInput{
		Category: c.Query("category"),
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		respondDomainError(c, err)
		return
	}

	// 空配列は [] で返す（make で非 nil）。
	items := make([]dto.RecipeSummary, 0, len(result.Items))
	for _, r := range result.Items {
		items = append(items, toSummaryDTO(r))
	}

	c.JSON(http.StatusOK, dto.RecipeListResponse{
		Items: items,
		Pagination: dto.Pagination{
			// 正規化後の値を返したいので UseCase と同じ既定を反映する。
			Limit:  normalizedLimit(limit),
			Offset: offset,
			Total:  result.Total,
		},
	})
}

// GetByID godoc
//
//	@Summary		レシピ詳細を取得
//	@Description	材料・手順（順序保持）と画像参照を含む詳細を返す。存在しない ID は 404。
//	@Tags			recipes
//	@Produce		json
//	@Param			id	path		string	true	"Recipe ID"	example(recipe-01)
//	@Success		200	{object}	dto.RecipeDetail
//	@Failure		404	{object}	dto.ErrorResponse
//	@Failure		500	{object}	dto.ErrorResponse
//	@Router			/api/v1/recipes/{id} [get]
func (h *RecipeHandler) GetByID(c *gin.Context) {
	id := c.Param("id")
	recipe, err := h.uc.GetByID(c.Request.Context(), id)
	if err != nil {
		respondDomainError(c, err)
		return
	}
	c.JSON(http.StatusOK, toDetailDTO(recipe))
}

// parseOptionalInt は query が空なら 0, 数値なら値, それ以外は ok=false を返す。
func parseOptionalInt(c *gin.Context, key string) (int, bool) {
	raw := c.Query(key)
	if raw == "" {
		return 0, true
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return 0, false
	}
	return v, true
}

// normalizedLimit は UseCase のクランプ結果をレスポンスの pagination.limit に反映する。
func normalizedLimit(limit int) int {
	switch {
	case limit <= 0:
		return usecase.DefaultRecipeLimit
	case limit > usecase.MaxRecipeLimit:
		return usecase.MaxRecipeLimit
	default:
		return limit
	}
}
