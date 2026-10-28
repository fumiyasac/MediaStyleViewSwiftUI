package httpadapter

import (
	"net/http"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/http/dto"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
)

// CalendarHandler は掲載カレンダー関連エンドポイントのハンドラ。
type CalendarHandler struct {
	uc *usecase.CalendarUseCase
}

// NewCalendarHandler は UseCase を注入して生成する。
func NewCalendarHandler(uc *usecase.CalendarUseCase) *CalendarHandler {
	return &CalendarHandler{uc: uc}
}

// GetRange godoc
//
//	@Summary		掲載カレンダーを取得
//	@Description	指定期間 [from, to]（両端含む）の掲載割当を、参照レシピ概要つきで返す。0 件なら空配列。
//	@Tags			calendar
//	@Produce		json
//	@Param			from	query		string	true	"開始日 (YYYY-MM-DD)"	example(2026-10-01)
//	@Param			to		query		string	true	"終了日 (YYYY-MM-DD)"	example(2026-10-31)
//	@Success		200		{object}	dto.CalendarResponse
//	@Failure		400		{object}	dto.ErrorResponse
//	@Failure		500		{object}	dto.ErrorResponse
//	@Router			/api/v1/calendar [get]
func (h *CalendarHandler) GetRange(c *gin.Context) {
	fromRaw := c.Query("from")
	toRaw := c.Query("to")
	// from/to は必須。
	if fromRaw == "" || toRaw == "" {
		writeError(c, http.StatusBadRequest, "INVALID_DATE", "`from` and `to` are required (YYYY-MM-DD).")
		return
	}

	from, err := domain.ParseDate(fromRaw)
	if err != nil {
		respondDomainError(c, err)
		return
	}
	to, err := domain.ParseDate(toRaw)
	if err != nil {
		respondDomainError(c, err)
		return
	}

	entries, err := h.uc.GetRange(c.Request.Context(), from, to)
	if err != nil {
		respondDomainError(c, err)
		return
	}

	items := make([]dto.CalendarEntry, 0, len(entries))
	for _, e := range entries {
		items = append(items, toCalendarEntryDTO(e))
	}

	c.JSON(http.StatusOK, dto.CalendarResponse{
		Items: items,
		Range: dto.CalendarRange{From: from.String(), To: to.String(), Total: len(items)},
	})
}
