// Seed コマンド。seed/*.json のレシピと掲載割当を MySQL へ投入する。
//
// 設計方針:
//   - API サーバーとは別プロセス（起動時に自動投入しない）。`go run ./cmd/seed` で明示実行。
//   - 冪等: 同じ Recipe ID に対して何度実行しても重複レコードを作らない（ON DUPLICATE KEY UPDATE /
//     材料・手順は recipe_id で全削除→再挿入）。これにより開発環境の再構築時に安全に再実行できる。
//   - 原子性: 1 トランザクションで投入し、途中失敗時はロールバックして不整合を残さない。
package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/adapter/persistence/mysql"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/config"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/infrastructure/database"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// seedRecipe は recipes.json の 1 件。
type seedRecipe struct {
	ID             string   `json:"id"`
	Title          string   `json:"title"`
	Summary        string   `json:"summary"`
	Category       string   `json:"category"`
	CookingMinutes int      `json:"cookingMinutes"`
	Calories       int      `json:"calories"`
	Servings       int      `json:"servings"`
	ImageReference string   `json:"imageReference"`
	Ingredients    []string `json:"ingredients"`
	Steps          []string `json:"steps"`
}

// seedEntry は daily_recipe_entries.json の 1 件。
type seedEntry struct {
	ID              string `json:"id"`
	PublicationDate string `json:"publicationDate"`
	RecipeID        string `json:"recipeId"`
	DisplayOrder    int    `json:"displayOrder"`
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config error: %v", err)
	}
	db, err := database.Open(cfg)
	if err != nil {
		log.Fatalf("failed to connect database")
	}

	seedDir := os.Getenv("SEED_DIR")
	if seedDir == "" {
		seedDir = "./seed"
	}

	recipes, err := loadRecipes(filepath.Join(seedDir, "recipes.json"))
	if err != nil {
		log.Fatalf("load recipes: %v", err)
	}
	entries, err := loadEntries(filepath.Join(seedDir, "daily_recipe_entries.json"))
	if err != nil {
		log.Fatalf("load daily entries: %v", err)
	}

	// 入力段階でカテゴリ・日付を検証し、不正なら投入前に中断する。
	for _, r := range recipes {
		if _, err := domain.ParseCategory(r.Category); err != nil {
			log.Fatalf("recipe %s has invalid category %q", r.ID, r.Category)
		}
	}
	for _, e := range entries {
		if _, err := domain.ParseDate(e.PublicationDate); err != nil {
			log.Fatalf("entry %s has invalid date %q", e.ID, e.PublicationDate)
		}
	}

	// 1 トランザクションで冪等投入（失敗時はロールバック）。
	err = db.Transaction(func(tx *gorm.DB) error {
		for _, r := range recipes {
			if err := upsertRecipe(tx, r); err != nil {
				return err
			}
		}
		for _, e := range entries {
			if err := upsertEntry(tx, e); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		log.Fatalf("seed failed (rolled back): %v", err)
	}

	log.Printf("seed completed: %d recipes, %d daily entries", len(recipes), len(entries))
}

// upsertRecipe はレシピ本体を Upsert し、材料・手順を recipe_id で全削除→再挿入する（順序・冪等を保証）。
func upsertRecipe(tx *gorm.DB, r seedRecipe) error {
	var imageRef *string
	if r.ImageReference != "" {
		v := r.ImageReference
		imageRef = &v
	}
	model := mysql.RecipeModel{
		ID:             r.ID,
		Title:          r.Title,
		Summary:        r.Summary,
		Category:       r.Category,
		CookingMinutes: r.CookingMinutes,
		Calories:       r.Calories,
		Servings:       r.Servings,
		ImageReference: imageRef,
	}
	// INSERT ... ON DUPLICATE KEY UPDATE（主キー衝突時は更新）。
	if err := tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		UpdateAll: true,
	}).Omit("Ingredients", "Steps").Create(&model).Error; err != nil {
		return err
	}

	if err := tx.Where("recipe_id = ?", r.ID).Delete(&mysql.RecipeIngredientModel{}).Error; err != nil {
		return err
	}
	for i, text := range r.Ingredients {
		ing := mysql.RecipeIngredientModel{RecipeID: r.ID, Position: i, Text: text}
		if err := tx.Create(&ing).Error; err != nil {
			return err
		}
	}

	if err := tx.Where("recipe_id = ?", r.ID).Delete(&mysql.RecipeStepModel{}).Error; err != nil {
		return err
	}
	for i, text := range r.Steps {
		st := mysql.RecipeStepModel{RecipeID: r.ID, Position: i, Text: text}
		if err := tx.Create(&st).Error; err != nil {
			return err
		}
	}
	return nil
}

// upsertEntry は掲載割当を Upsert する。
func upsertEntry(tx *gorm.DB, e seedEntry) error {
	d, _ := domain.ParseDate(e.PublicationDate) // 事前検証済み
	model := mysql.DailyRecipeEntryModel{
		ID:              e.ID,
		PublicationDate: d.Time(),
		RecipeID:        e.RecipeID,
		DisplayOrder:    e.DisplayOrder,
	}
	return tx.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		UpdateAll: true,
	}).Omit("Recipe").Create(&model).Error
}

func loadRecipes(path string) ([]seedRecipe, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var recipes []seedRecipe
	if err := json.Unmarshal(b, &recipes); err != nil {
		return nil, err
	}
	return recipes, nil
}

func loadEntries(path string) ([]seedEntry, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var entries []seedEntry
	if err := json.Unmarshal(b, &entries); err != nil {
		return nil, err
	}
	return entries, nil
}
