// Package httpadapter は Gin による HTTP 入出力（ルーティング/ハンドラ/変換）。
// パッケージ名を net/http と区別するため httpadapter とする。
package httpadapter

import (
	"errors"
	"net/http"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/http/dto"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

// writeError は共通エラー形式でレスポンスする。
func writeError(c *gin.Context, status int, code, message string) {
	c.JSON(status, dto.ErrorResponse{Error: dto.ErrorBody{Code: code, Message: message}})
}

// respondDomainError は Domain/UseCase のエラーを適切な HTTP Status へ変換する。
//
// Domain はステータスを知らないため、変換責務は HTTP 層に集約する。
// 内部エラーの詳細(SQL 全文・接続情報・スタックトレース)はレスポンスへ出さない。
func respondDomainError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, domain.ErrRecipeNotFound):
		writeError(c, http.StatusNotFound, "RECIPE_NOT_FOUND", "Recipe was not found.")
	case errors.Is(err, domain.ErrInvalidDate):
		writeError(c, http.StatusBadRequest, "INVALID_DATE", "Date must be in YYYY-MM-DD format.")
	case errors.Is(err, domain.ErrInvalidDateRange):
		writeError(c, http.StatusBadRequest, "INVALID_DATE_RANGE", "`from` must be on or before `to`.")
	case errors.Is(err, domain.ErrDateRangeTooLong):
		writeError(c, http.StatusBadRequest, "DATE_RANGE_TOO_LONG", "Requested date range is too long.")
	case errors.Is(err, domain.ErrInvalidCategory):
		writeError(c, http.StatusBadRequest, "INVALID_CATEGORY", "Unsupported category.")
	case errors.Is(err, domain.ErrInvalidPagination):
		writeError(c, http.StatusBadRequest, "INVALID_PAGINATION", "limit/offset is invalid.")
	default:
		writeError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error.")
	}
}

// --- Domain → DTO 変換 ---

func toSummaryDTO(r domain.Recipe) dto.RecipeSummary {
	return dto.RecipeSummary{
		ID:             r.ID,
		Title:          r.Title,
		Summary:        r.Summary,
		Category:       string(r.Category),
		CookingMinutes: r.CookingMinutes,
		Calories:       r.Calories,
		Servings:       r.Servings,
	}
}

func toDetailDTO(r domain.Recipe) dto.RecipeDetail {
	var imageRef *string
	if r.ImageReference != "" {
		v := r.ImageReference
		imageRef = &v
	}
	// 空配列は null ではなく [] で返す（make で非 nil を保証）。
	ingredients := r.Ingredients
	if ingredients == nil {
		ingredients = []string{}
	}
	steps := r.Steps
	if steps == nil {
		steps = []string{}
	}
	return dto.RecipeDetail{
		ID:             r.ID,
		Title:          r.Title,
		Summary:        r.Summary,
		Category:       string(r.Category),
		CookingMinutes: r.CookingMinutes,
		Calories:       r.Calories,
		Servings:       r.Servings,
		ImageReference: imageRef,
		Ingredients:    ingredients,
		Steps:          steps,
	}
}

func toCalendarEntryDTO(e usecase.CalendarEntry) dto.CalendarEntry {
	return dto.CalendarEntry{
		ID:              e.Entry.ID,
		PublicationDate: e.Entry.PublicationDate.String(),
		DisplayOrder:    e.Entry.DisplayOrder,
		Recipe:          toSummaryDTO(e.Recipe),
	}
}
