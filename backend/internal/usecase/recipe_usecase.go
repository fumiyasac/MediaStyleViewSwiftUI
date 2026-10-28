package usecase

import (
	"context"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
)

// Pagination の既定値・上限。
//
// 上限を設けるのは、無制限な offset/limit による過大なレスポンスや DB 負荷を防ぐため。
const (
	DefaultRecipeLimit = 20
	MaxRecipeLimit     = 100
)

// RecipeUseCase はレシピ関連のユースケース。HTTP/DB には依存しない。
type RecipeUseCase struct {
	repo RecipeRepository
}

// NewRecipeUseCase は依存(Repository ポート)を注入して生成する。
func NewRecipeUseCase(repo RecipeRepository) *RecipeUseCase {
	return &RecipeUseCase{repo: repo}
}

// ListInput は一覧取得の入力（検証前の生値）。
type ListInput struct {
	// Category が空文字のときは全カテゴリ。
	Category string
	Limit    int
	Offset   int
}

// List はレシピ一覧を取得する。
// category を検証し、limit/offset を正規化してから Repository を呼ぶ。
func (u *RecipeUseCase) List(ctx context.Context, in ListInput) (RecipeListResult, error) {
	filter := RecipeListFilter{}

	if in.Category != "" {
		c, err := domain.ParseCategory(in.Category)
		if err != nil {
			return RecipeListResult{}, err
		}
		filter.Category = &c
	}

	// offset は 0 以上のみ許可（負値は不正入力）。
	if in.Offset < 0 {
		return RecipeListResult{}, domain.ErrInvalidPagination
	}
	filter.Offset = in.Offset

	// limit は未指定(<=0)で既定値、上限超過はクランプ（エラーにせず最大値に丸める）。
	switch {
	case in.Limit <= 0:
		filter.Limit = DefaultRecipeLimit
	case in.Limit > MaxRecipeLimit:
		filter.Limit = MaxRecipeLimit
	default:
		filter.Limit = in.Limit
	}

	return u.repo.List(ctx, filter)
}

// GetByID はレシピ詳細（材料・手順を含む）を取得する。
// 見つからない場合は domain.ErrRecipeNotFound を伝搬する（Handler が 404 に変換）。
func (u *RecipeUseCase) GetByID(ctx context.Context, id string) (domain.Recipe, error) {
	return u.repo.FindByID(ctx, id)
}
