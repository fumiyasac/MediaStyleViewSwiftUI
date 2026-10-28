//go:build integration

// MySQL を使う Integration Test。
//
// 実行には Migration 済みのテスト用 MySQL が必要（`make test-integration`）。
// build tag `integration` を付けているため、通常の `go test ./...` では実行されない
// （Unit Test は DB なしで実行可能、Integration のみ MySQL を必要とする構成）。
//
// 既存データを壊さないよう、テスト専用 ID(itest-*) のみを作成・削除する。
package mysql

import (
	"context"
	"testing"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/config"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/database"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/stretchr/testify/require"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func openTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	cfg, err := config.Load()
	require.NoError(t, err)
	db, err := database.Open(cfg)
	require.NoError(t, err)
	return db
}

// cleanup はテスト専用 ID(itest-*) のみを削除する（既存 seed データを保護）。
func cleanup(t *testing.T, db *gorm.DB) {
	t.Helper()
	require.NoError(t, db.Exec("DELETE FROM daily_recipe_entries WHERE id LIKE 'itest-%'").Error)
	require.NoError(t, db.Exec("DELETE FROM recipe_steps WHERE recipe_id LIKE 'itest-%'").Error)
	require.NoError(t, db.Exec("DELETE FROM recipe_ingredients WHERE recipe_id LIKE 'itest-%'").Error)
	require.NoError(t, db.Exec("DELETE FROM recipes WHERE id LIKE 'itest-%'").Error)
}

func TestIntegration_MigrationTablesExist(t *testing.T) {
	db := openTestDB(t)
	for _, tbl := range []string{"recipes", "recipe_ingredients", "recipe_steps", "daily_recipe_entries"} {
		var count int64
		err := db.Raw(
			"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?",
			tbl,
		).Scan(&count).Error
		require.NoError(t, err)
		require.Equalf(t, int64(1), count, "table %s should exist (migration applied)", tbl)
	}
}

func TestIntegration_RecipeSaveAndFetchWithOrder(t *testing.T) {
	db := openTestDB(t)
	cleanup(t, db)
	defer cleanup(t, db)

	require.NoError(t, db.Create(&RecipeModel{
		ID: "itest-recipe-01", Title: "テスト飯", Summary: "s", Category: "japanese",
		CookingMinutes: 10, Calories: 100, Servings: 1,
	}).Error)
	// 材料・手順をわざと position の逆順で挿入し、取得時に昇順で返ることを確認する。
	require.NoError(t, db.Create(&RecipeIngredientModel{RecipeID: "itest-recipe-01", Position: 1, Text: "塩"}).Error)
	require.NoError(t, db.Create(&RecipeIngredientModel{RecipeID: "itest-recipe-01", Position: 0, Text: "米"}).Error)
	require.NoError(t, db.Create(&RecipeStepModel{RecipeID: "itest-recipe-01", Position: 1, Text: "炊く"}).Error)
	require.NoError(t, db.Create(&RecipeStepModel{RecipeID: "itest-recipe-01", Position: 0, Text: "研ぐ"}).Error)

	repo := NewRecipeRepository(db)
	r, err := repo.FindByID(context.Background(), "itest-recipe-01")
	require.NoError(t, err)
	require.Equal(t, []string{"米", "塩"}, r.Ingredients) // position 昇順
	require.Equal(t, []string{"研ぐ", "炊く"}, r.Steps)
}

func TestIntegration_CalendarRangeAndForeignKey(t *testing.T) {
	db := openTestDB(t)
	cleanup(t, db)
	defer cleanup(t, db)

	require.NoError(t, db.Create(&RecipeModel{ID: "itest-recipe-01", Title: "A", Summary: "s", Category: "japanese", CookingMinutes: 1, Calories: 1, Servings: 1}).Error)
	require.NoError(t, db.Create(&RecipeModel{ID: "itest-recipe-02", Title: "B", Summary: "s", Category: "western", CookingMinutes: 1, Calories: 1, Servings: 1}).Error)

	mustDate := func(s string) domain.Date { d, _ := domain.ParseDate(s); return d }
	require.NoError(t, db.Create(&DailyRecipeEntryModel{ID: "itest-daily-1", PublicationDate: mustDate("2026-10-01").Time(), RecipeID: "itest-recipe-01", DisplayOrder: 0}).Error)
	require.NoError(t, db.Create(&DailyRecipeEntryModel{ID: "itest-daily-2", PublicationDate: mustDate("2026-10-05").Time(), RecipeID: "itest-recipe-02", DisplayOrder: 0}).Error)
	require.NoError(t, db.Create(&DailyRecipeEntryModel{ID: "itest-daily-3", PublicationDate: mustDate("2026-11-01").Time(), RecipeID: "itest-recipe-01", DisplayOrder: 0}).Error)

	calRepo := NewCalendarRepository(db)
	entries, err := calRepo.FindEntries(context.Background(), mustDate("2026-10-01"), mustDate("2026-10-31"))
	require.NoError(t, err)
	// 10 月範囲は 2 件（11/01 は範囲外、両端含むで 10/01 と 10/05）
	var got []string
	for _, e := range entries {
		if e.Entry.ID == "itest-daily-1" || e.Entry.ID == "itest-daily-2" {
			got = append(got, e.Entry.PublicationDate.String())
		}
	}
	require.Equal(t, []string{"2026-10-01", "2026-10-05"}, got)

	// Foreign Key: 存在しない recipe_id の掲載割当は挿入できない。
	err = db.Create(&DailyRecipeEntryModel{ID: "itest-daily-bad", PublicationDate: mustDate("2026-10-02").Time(), RecipeID: "itest-no-such-recipe", DisplayOrder: 0}).Error
	require.Error(t, err)
}

func TestIntegration_UpsertIdempotent(t *testing.T) {
	db := openTestDB(t)
	cleanup(t, db)
	defer cleanup(t, db)

	upsert := func() error {
		return db.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "id"}}, UpdateAll: true}).
			Omit("Ingredients", "Steps").
			Create(&RecipeModel{ID: "itest-recipe-01", Title: "A", Summary: "s", Category: "japanese", CookingMinutes: 1, Calories: 1, Servings: 1}).Error
	}
	require.NoError(t, upsert())
	require.NoError(t, upsert()) // 2 回目でも重複しない

	var count int64
	require.NoError(t, db.Model(&RecipeModel{}).Where("id = ?", "itest-recipe-01").Count(&count).Error)
	require.Equal(t, int64(1), count)
}

// usecase 経由でも FindByID が機能することを軽く確認する。
func TestIntegration_UseCaseGetByID(t *testing.T) {
	db := openTestDB(t)
	cleanup(t, db)
	defer cleanup(t, db)
	require.NoError(t, db.Create(&RecipeModel{ID: "itest-recipe-01", Title: "A", Summary: "s", Category: "japanese", CookingMinutes: 1, Calories: 1, Servings: 1}).Error)

	uc := usecase.NewRecipeUseCase(NewRecipeRepository(db))
	r, err := uc.GetByID(context.Background(), "itest-recipe-01")
	require.NoError(t, err)
	require.Equal(t, "itest-recipe-01", r.ID)

	_, err = uc.GetByID(context.Background(), "itest-no-such")
	require.ErrorIs(t, err, domain.ErrRecipeNotFound)
}
