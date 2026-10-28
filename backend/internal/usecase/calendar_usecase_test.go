package usecase

import (
	"context"
	"testing"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/stretchr/testify/require"
)

type fakeCalendarRepo struct {
	entries []CalendarEntry
	err     error
}

func (f *fakeCalendarRepo) FindEntries(_ context.Context, _, _ domain.Date) ([]CalendarEntry, error) {
	return f.entries, f.err
}

func d(y, m, day int) domain.Date { return domain.Date{Year: y, Month: m, Day: day} }

func entry(id string, date domain.Date, recipeID string, order int) CalendarEntry {
	return CalendarEntry{
		Entry:  domain.DailyRecipeEntry{ID: id, PublicationDate: date, RecipeID: recipeID, DisplayOrder: order},
		Recipe: domain.Recipe{ID: recipeID},
	}
}

func TestCalendarUseCase_GetRange(t *testing.T) {
	repo := &fakeCalendarRepo{entries: []CalendarEntry{
		entry("e2", d(2026, 10, 2), "recipe-02", 0),
		entry("e1", d(2026, 10, 1), "recipe-01", 0),
	}}
	uc := NewCalendarUseCase(repo)

	res, err := uc.GetRange(context.Background(), d(2026, 10, 1), d(2026, 10, 31))
	require.NoError(t, err)
	require.Len(t, res, 2)
	// 日付昇順で安定化される
	require.Equal(t, "2026-10-01", res[0].Entry.PublicationDate.String())
	require.Equal(t, "2026-10-02", res[1].Entry.PublicationDate.String())
}

func TestCalendarUseCase_GetRange_InvalidRange(t *testing.T) {
	uc := NewCalendarUseCase(&fakeCalendarRepo{})
	_, err := uc.GetRange(context.Background(), d(2026, 10, 31), d(2026, 10, 1))
	require.ErrorIs(t, err, domain.ErrInvalidDateRange)
}

func TestCalendarUseCase_GetRange_TooLong(t *testing.T) {
	uc := NewCalendarUseCase(&fakeCalendarRepo{})
	// 93 日は上限(92)超過
	_, err := uc.GetRange(context.Background(), d(2026, 1, 1), d(2026, 4, 3))
	require.ErrorIs(t, err, domain.ErrDateRangeTooLong)
}

func TestCalendarUseCase_GetRange_Empty(t *testing.T) {
	uc := NewCalendarUseCase(&fakeCalendarRepo{entries: nil})
	res, err := uc.GetRange(context.Background(), d(2026, 10, 1), d(2026, 10, 31))
	require.NoError(t, err)
	require.NotNil(t, res) // nil ではなく空スライス
	require.Len(t, res, 0)
}

func TestCalendarUseCase_GetRange_SameRecipeMultipleDays(t *testing.T) {
	repo := &fakeCalendarRepo{entries: []CalendarEntry{
		entry("a", d(2026, 10, 1), "recipe-01", 0),
		entry("b", d(2026, 10, 5), "recipe-01", 0), // 同じレシピが別日
	}}
	uc := NewCalendarUseCase(repo)
	res, err := uc.GetRange(context.Background(), d(2026, 10, 1), d(2026, 10, 31))
	require.NoError(t, err)
	require.Len(t, res, 2)
	require.Equal(t, "recipe-01", res[0].Entry.RecipeID)
	require.Equal(t, "recipe-01", res[1].Entry.RecipeID)
}

func TestCalendarUseCase_GetRange_MultipleRecipesSameDay(t *testing.T) {
	repo := &fakeCalendarRepo{entries: []CalendarEntry{
		entry("y", d(2026, 10, 4), "recipe-16", 1),
		entry("x", d(2026, 10, 4), "recipe-04", 0),
	}}
	uc := NewCalendarUseCase(repo)
	res, err := uc.GetRange(context.Background(), d(2026, 10, 1), d(2026, 10, 31))
	require.NoError(t, err)
	require.Len(t, res, 2)
	// 同日は display_order 昇順で安定化
	require.Equal(t, 0, res[0].Entry.DisplayOrder)
	require.Equal(t, 1, res[1].Entry.DisplayOrder)
}
