// Package dto は HTTP リクエスト/レスポンスの入出力表現。
//
// GORM Model や Domain Model をそのまま JSON にせず、公開 API 専用の DTO へ変換する。
// これにより内部構造の変更が API 契約へ漏れず、Swagger 上の型も安定する。
package dto

// RecipeSummary はレシピ一覧・カレンダーで返す概要。
type RecipeSummary struct {
	ID             string `json:"id" example:"recipe-01"`
	Title          string `json:"title" example:"鮭の塩麹焼き"`
	Summary        string `json:"summary" example:"塩麹でふっくら仕上げる定番の焼き魚"`
	Category       string `json:"category" example:"japanese"`
	CookingMinutes int    `json:"cookingMinutes" example:"25"`
	Calories       int    `json:"calories" example:"320"`
	Servings       int    `json:"servings" example:"2"`
}

// RecipeDetail はレシピ詳細（材料・手順・画像参照を含む）。
type RecipeDetail struct {
	ID             string `json:"id" example:"recipe-01"`
	Title          string `json:"title" example:"鮭の塩麹焼き"`
	Summary        string `json:"summary" example:"塩麹でふっくら仕上げる定番の焼き魚"`
	Category       string `json:"category" example:"japanese"`
	CookingMinutes int    `json:"cookingMinutes" example:"25"`
	Calories       int    `json:"calories" example:"320"`
	Servings       int    `json:"servings" example:"2"`
	// ImageReference は画像参照キー（存在しない場合は null）。iOS は RecipeID をキーに画像を解決する。
	ImageReference *string  `json:"imageReference" example:"recipe-01"`
	Ingredients    []string `json:"ingredients"`
	Steps          []string `json:"steps"`
}

// Pagination は一覧のページング情報。
type Pagination struct {
	Limit  int `json:"limit" example:"20"`
	Offset int `json:"offset" example:"0"`
	Total  int `json:"total" example:"24"`
}

// RecipeListResponse は GET /api/v1/recipes のレスポンス。
type RecipeListResponse struct {
	Items      []RecipeSummary `json:"items"`
	Pagination Pagination      `json:"pagination"`
}

// CalendarEntry は掲載割当 1 件（参照レシピ概要つき）。
type CalendarEntry struct {
	ID              string        `json:"id" example:"daily-2026-10-01-recipe-01"`
	PublicationDate string        `json:"publicationDate" example:"2026-10-01"`
	DisplayOrder    int           `json:"displayOrder" example:"0"`
	Recipe          RecipeSummary `json:"recipe"`
}

// CalendarRange は取得期間のメタ情報。
type CalendarRange struct {
	From  string `json:"from" example:"2026-10-01"`
	To    string `json:"to" example:"2026-10-31"`
	Total int    `json:"total" example:"31"`
}

// CalendarResponse は GET /api/v1/calendar のレスポンス。
type CalendarResponse struct {
	Items []CalendarEntry `json:"items"`
	Range CalendarRange   `json:"range"`
}

// ErrorBody はエラー詳細。
type ErrorBody struct {
	Code    string `json:"code" example:"RECIPE_NOT_FOUND"`
	Message string `json:"message" example:"Recipe was not found."`
}

// ErrorResponse は全エラー共通のレスポンス形式。
type ErrorResponse struct {
	Error ErrorBody `json:"error"`
}

// HealthResponse は /healthz・/readyz のレスポンス。
type HealthResponse struct {
	Status string `json:"status" example:"ok"`
}
