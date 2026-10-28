package mysql

import (
	"context"
	"errors"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"gorm.io/gorm"
)

// RecipeRepository は usecase.RecipeRepository の GORM/MySQL 実装。
type RecipeRepository struct {
	db *gorm.DB
}

// NewRecipeRepository は *gorm.DB を受けて生成する。
func NewRecipeRepository(db *gorm.DB) *RecipeRepository {
	return &RecipeRepository{db: db}
}

// コンパイル時にインターフェース充足を保証する。
var _ usecase.RecipeRepository = (*RecipeRepository)(nil)

// List はカテゴリ絞り込み・ページングでレシピ一覧を返す（概要のみ。材料/手順は含めない）。
// 総件数は同じ絞り込み条件で別途 Count する。並びは id 昇順で安定させる。
func (r *RecipeRepository) List(ctx context.Context, filter usecase.RecipeListFilter) (usecase.RecipeListResult, error) {
	base := r.db.WithContext(ctx).Model(&RecipeModel{})
	if filter.Category != nil {
		base = base.Where("category = ?", string(*filter.Category))
	}

	var total int64
	if err := base.Count(&total).Error; err != nil {
		return usecase.RecipeListResult{}, err
	}

	var models []RecipeModel
	q := r.db.WithContext(ctx).Order("id ASC").Limit(filter.Limit).Offset(filter.Offset)
	if filter.Category != nil {
		q = q.Where("category = ?", string(*filter.Category))
	}
	if err := q.Find(&models).Error; err != nil {
		return usecase.RecipeListResult{}, err
	}

	items := make([]domain.Recipe, 0, len(models))
	for _, m := range models {
		items = append(items, toDomainRecipe(m))
	}
	return usecase.RecipeListResult{Items: items, Total: int(total)}, nil
}

// FindByID は材料・手順を position 昇順で Preload した詳細を返す。
// 見つからない場合は domain.ErrRecipeNotFound（gorm.ErrRecordNotFound を業務エラーへ変換）。
func (r *RecipeRepository) FindByID(ctx context.Context, id string) (domain.Recipe, error) {
	var m RecipeModel
	err := r.db.WithContext(ctx).
		Preload("Ingredients", func(db *gorm.DB) *gorm.DB { return db.Order("position ASC") }).
		Preload("Steps", func(db *gorm.DB) *gorm.DB { return db.Order("position ASC") }).
		Where("id = ?", id).
		First(&m).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return domain.Recipe{}, domain.ErrRecipeNotFound
	}
	if err != nil {
		return domain.Recipe{}, err
	}
	return toDomainRecipe(m), nil
}
