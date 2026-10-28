package mysql

import "github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"

// GORM Model → Domain Model への変換を一箇所に集約する。
// これにより DB スキーマと Domain の差異が converter に閉じ、UseCase/HTTP に漏れない。

// toDomainRecipe は RecipeModel を domain.Recipe へ変換する。
// 材料・手順は呼び出し側で position 昇順に Preload 済みである前提で順序を保持する。
func toDomainRecipe(m RecipeModel) domain.Recipe {
	ingredients := make([]string, 0, len(m.Ingredients))
	for _, ing := range m.Ingredients {
		ingredients = append(ingredients, ing.Text)
	}
	steps := make([]string, 0, len(m.Steps))
	for _, st := range m.Steps {
		steps = append(steps, st.Text)
	}

	imageRef := ""
	if m.ImageReference != nil {
		imageRef = *m.ImageReference
	}

	return domain.Recipe{
		ID:             m.ID,
		Title:          m.Title,
		Summary:        m.Summary,
		Category:       domain.Category(m.Category),
		CookingMinutes: m.CookingMinutes,
		Calories:       m.Calories,
		Servings:       m.Servings,
		Ingredients:    ingredients,
		Steps:          steps,
		ImageReference: imageRef,
	}
}

// toDomainEntry は DailyRecipeEntryModel を domain.DailyRecipeEntry へ変換する。
// DATE 列(UTC)を年月日のみの domain.Date に落とす。
func toDomainEntry(m DailyRecipeEntryModel) domain.DailyRecipeEntry {
	return domain.DailyRecipeEntry{
		ID:              m.ID,
		PublicationDate: domain.NewDateFromTime(m.PublicationDate),
		RecipeID:        m.RecipeID,
		DisplayOrder:    m.DisplayOrder,
	}
}
