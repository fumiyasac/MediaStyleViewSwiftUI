package domain

// DailyRecipeEntry は「どの掲載日に、どのレシピが、どの表示順で載るか」の割当。
//
// 掲載日(PublicationDate)は調理日(iOS の MealLog の cookedAt)とは別物。
//   - 掲載日: レシピカレンダー上で献立が提示される日。本 Backend が所有する。
//   - 調理日: ユーザーが実際に作った記録の日。iOS の SwiftData が所有し、本 Backend は扱わない。
//
// 同じ Recipe が複数日に載ること、同じ日に複数 Recipe が載ることの両方を許可する。
// 同日複数件の安定した並びのため DisplayOrder を持つ（Swift の DailyRecipeEntry には
// DisplayOrder は無いが、Backend 側で同日内の決定的な順序付けに用いる）。
type DailyRecipeEntry struct {
	ID              string
	PublicationDate Date
	RecipeID        string
	DisplayOrder    int
}
