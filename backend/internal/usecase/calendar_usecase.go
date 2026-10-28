package usecase

import (
	"context"
	"sort"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
)

// MaxCalendarRangeDays は calendar 取得の最大期間（両端含む日数）。
// 過大な範囲取得を防ぐため 92 日（約 3 か月）を上限にする。
const MaxCalendarRangeDays = 92

// CalendarUseCase は掲載カレンダー関連のユースケース。
type CalendarUseCase struct {
	repo CalendarRepository
}

// NewCalendarUseCase は Repository ポートを注入して生成する。
func NewCalendarUseCase(repo CalendarRepository) *CalendarUseCase {
	return &CalendarUseCase{repo: repo}
}

// GetRange は [from, to]（両端含む）の掲載割当を取得する。
//
// 入力検証:
//   - from/to は呼び出し側で "YYYY-MM-DD" から domain.Date へ変換済みを受け取る。
//   - from > to は不正（ErrInvalidDateRange）。
//   - 期間が上限を超えたら ErrDateRangeTooLong。
//
// 0 件の場合は空スライスを返す（nil ではなく空、Handler 側で [] にシリアライズ）。
func (u *CalendarUseCase) GetRange(ctx context.Context, from, to domain.Date) ([]CalendarEntry, error) {
	if from.After(to) {
		return nil, domain.ErrInvalidDateRange
	}
	if daysInclusive(from, to) > MaxCalendarRangeDays {
		return nil, domain.ErrDateRangeTooLong
	}

	entries, err := u.repo.FindEntries(ctx, from, to)
	if err != nil {
		return nil, err
	}

	// Repository 側でも安定順を保証するが、UseCase でも (日付, 表示順, RecipeID) で安定化しておく。
	sort.SliceStable(entries, func(i, j int) bool {
		if c := entries[i].Entry.PublicationDate.Compare(entries[j].Entry.PublicationDate); c != 0 {
			return c < 0
		}
		if entries[i].Entry.DisplayOrder != entries[j].Entry.DisplayOrder {
			return entries[i].Entry.DisplayOrder < entries[j].Entry.DisplayOrder
		}
		return entries[i].Entry.RecipeID < entries[j].Entry.RecipeID
	})

	if entries == nil {
		entries = []CalendarEntry{}
	}
	return entries, nil
}

// daysInclusive は両端を含む日数を返す（from==to なら 1）。
func daysInclusive(from, to domain.Date) int {
	const day = 24 * 60 * 60
	diff := int(to.Time().Unix()-from.Time().Unix()) / day
	return diff + 1
}
