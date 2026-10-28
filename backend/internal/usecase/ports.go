package usecase

import (
	"context"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
)

// ポート（Repository インターフェース）。
//
// UseCase は具体的な永続化実装(GORM/MySQL)ではなく、このインターフェースに依存する。
// これにより UseCase は DB やフレームワークを知らずにテスト可能になり（Fake 差し替え）、
// 永続化方式の変更が UseCase へ波及しない（依存は外側→内側の一方向）。

// RecipeListFilter はレシピ一覧の取得条件。
type RecipeListFilter struct {
	// Category が nil のときは全カテゴリ。
	Category *domain.Category
	Limit    int
	Offset   int
}

// RecipeListResult は一覧取得の結果（総件数つき）。
type RecipeListResult struct {
	Items []domain.Recipe
	Total int
}

// CalendarEntry は掲載割当と、その参照先レシピ（概要）をまとめたもの。
type CalendarEntry struct {
	Entry  domain.DailyRecipeEntry
	Recipe domain.Recipe
}

// RecipeRepository はレシピ Master の読み取りポート。
type RecipeRepository interface {
	// List は filter に一致するレシピを limit/offset で返し、合わせて総件数を返す。
	List(ctx context.Context, filter RecipeListFilter) (RecipeListResult, error)
	// FindByID は ID 一致のレシピ（材料・手順を含む）を返す。無ければ domain.ErrRecipeNotFound。
	FindByID(ctx context.Context, id string) (domain.Recipe, error)
}

// CalendarRepository は掲載割当の読み取りポート。
type CalendarRepository interface {
	// FindEntries は [from, to]（両端含む）の掲載割当を、参照レシピ概要つきで返す。
	// 並びは (掲載日 昇順, 表示順 昇順, RecipeID 昇順) の安定順。
	FindEntries(ctx context.Context, from, to domain.Date) ([]CalendarEntry, error)
}

// HealthChecker は依存サービス(DB)の疎通確認ポート（readyz 用）。
type HealthChecker interface {
	// Ping は DB へ到達できるかを確認する。到達不可なら error。
	Ping(ctx context.Context) error
}
