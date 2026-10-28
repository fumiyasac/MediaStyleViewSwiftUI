package usecase

import (
	"context"
	"errors"
	"testing"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/stretchr/testify/require"
)

// fakeRecipeRepo は MySQL を使わず UseCase を検証するための Fake。
type fakeRecipeRepo struct {
	listResult RecipeListResult
	listErr    error
	byID       map[string]domain.Recipe
	findErr    error
	lastFilter RecipeListFilter
}

func (f *fakeRecipeRepo) List(_ context.Context, filter RecipeListFilter) (RecipeListResult, error) {
	f.lastFilter = filter
	return f.listResult, f.listErr
}

func (f *fakeRecipeRepo) FindByID(_ context.Context, id string) (domain.Recipe, error) {
	if f.findErr != nil {
		return domain.Recipe{}, f.findErr
	}
	r, ok := f.byID[id]
	if !ok {
		return domain.Recipe{}, domain.ErrRecipeNotFound
	}
	return r, nil
}

func TestRecipeUseCase_List(t *testing.T) {
	repo := &fakeRecipeRepo{listResult: RecipeListResult{
		Items: []domain.Recipe{{ID: "recipe-01", Title: "鮭の塩麹焼き", Category: domain.CategoryJapanese}},
		Total: 1,
	}}
	uc := NewRecipeUseCase(repo)

	res, err := uc.List(context.Background(), ListInput{Limit: 20, Offset: 0})
	require.NoError(t, err)
	require.Len(t, res.Items, 1)
	require.Equal(t, 1, res.Total)
}

func TestRecipeUseCase_List_LimitDefaultsAndClamps(t *testing.T) {
	repo := &fakeRecipeRepo{}
	uc := NewRecipeUseCase(repo)

	_, err := uc.List(context.Background(), ListInput{Limit: 0})
	require.NoError(t, err)
	require.Equal(t, DefaultRecipeLimit, repo.lastFilter.Limit) // 未指定は既定

	_, err = uc.List(context.Background(), ListInput{Limit: 1000})
	require.NoError(t, err)
	require.Equal(t, MaxRecipeLimit, repo.lastFilter.Limit) // 上限超過はクランプ
}

func TestRecipeUseCase_List_InvalidCategory(t *testing.T) {
	uc := NewRecipeUseCase(&fakeRecipeRepo{})
	_, err := uc.List(context.Background(), ListInput{Category: "unknown"})
	require.ErrorIs(t, err, domain.ErrInvalidCategory)
}

func TestRecipeUseCase_List_NegativeOffset(t *testing.T) {
	uc := NewRecipeUseCase(&fakeRecipeRepo{})
	_, err := uc.List(context.Background(), ListInput{Offset: -1})
	require.ErrorIs(t, err, domain.ErrInvalidPagination)
}

func TestRecipeUseCase_GetByID(t *testing.T) {
	repo := &fakeRecipeRepo{byID: map[string]domain.Recipe{
		"recipe-01": {ID: "recipe-01", Title: "鮭の塩麹焼き", Ingredients: []string{"生鮭 2切れ"}},
	}}
	uc := NewRecipeUseCase(repo)

	r, err := uc.GetByID(context.Background(), "recipe-01")
	require.NoError(t, err)
	require.Equal(t, "recipe-01", r.ID)
	require.Equal(t, []string{"生鮭 2切れ"}, r.Ingredients)
}

func TestRecipeUseCase_GetByID_NotFound(t *testing.T) {
	uc := NewRecipeUseCase(&fakeRecipeRepo{byID: map[string]domain.Recipe{}})
	_, err := uc.GetByID(context.Background(), "recipe-xx")
	require.ErrorIs(t, err, domain.ErrRecipeNotFound)
}

func TestRecipeUseCase_RepositoryErrorPropagates(t *testing.T) {
	sentinel := errors.New("db down")
	uc := NewRecipeUseCase(&fakeRecipeRepo{listErr: sentinel})
	_, err := uc.List(context.Background(), ListInput{})
	require.ErrorIs(t, err, sentinel)
}
