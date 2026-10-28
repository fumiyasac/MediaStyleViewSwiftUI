package mysql

import (
	"context"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"gorm.io/gorm"
)

// CalendarRepository は usecase.CalendarRepository / usecase.HealthChecker の GORM 実装。
type CalendarRepository struct {
	db *gorm.DB
}

// NewCalendarRepository は *gorm.DB を受けて生成する。
func NewCalendarRepository(db *gorm.DB) *CalendarRepository {
	return &CalendarRepository{db: db}
}

var (
	_ usecase.CalendarRepository = (*CalendarRepository)(nil)
	_ usecase.HealthChecker      = (*CalendarRepository)(nil)
)

// FindEntries は [from, to]（両端含む）の掲載割当を参照レシピ概要つきで返す。
//
// publication_date は DATE なので、"YYYY-MM-DD" 文字列で BETWEEN 比較する。
// time.Time を渡すと接続ロケール次第で境界日がずれるため、文字列比較で日付の両端を確実に含める。
// 並びは (掲載日, 表示順, recipe_id) で安定化する。
func (r *CalendarRepository) FindEntries(ctx context.Context, from, to domain.Date) ([]usecase.CalendarEntry, error) {
	var models []DailyRecipeEntryModel
	err := r.db.WithContext(ctx).
		Preload("Recipe").
		Where("publication_date BETWEEN ? AND ?", from.String(), to.String()).
		Order("publication_date ASC, display_order ASC, recipe_id ASC").
		Find(&models).Error
	if err != nil {
		return nil, err
	}

	entries := make([]usecase.CalendarEntry, 0, len(models))
	for _, m := range models {
		entries = append(entries, usecase.CalendarEntry{
			Entry:  toDomainEntry(m),
			Recipe: toDomainRecipe(m.Recipe),
		})
	}
	return entries, nil
}

// Ping は DB への疎通確認（readyz 用）。
func (r *CalendarRepository) Ping(ctx context.Context) error {
	sqlDB, err := r.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.PingContext(ctx)
}
