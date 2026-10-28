package domain

// Category はレシピの分類。
//
// 値は Swift 側 RecipeCategory の「enum ケース名」と一致させる（japanese/western/...）。
// Swift の rawValue は日本語表示名(和食 等)だが、API のキーとしては安定した英語ケース名を使う。
type Category string

const (
	CategoryJapanese Category = "japanese"
	CategoryWestern  Category = "western"
	CategoryChinese  Category = "chinese"
	CategoryItalian  Category = "italian"
	CategoryDessert  Category = "dessert"
	CategoryHealthy  Category = "healthy"
)

// validCategories はサポートするカテゴリ集合。順序は Swift の定義順。
var validCategories = map[Category]struct{}{
	CategoryJapanese: {},
	CategoryWestern:  {},
	CategoryChinese:  {},
	CategoryItalian:  {},
	CategoryDessert:  {},
	CategoryHealthy:  {},
}

// ParseCategory は文字列を検証して Category へ変換する。サポート外は ErrInvalidCategory。
func ParseCategory(s string) (Category, error) {
	c := Category(s)
	if _, ok := validCategories[c]; !ok {
		return "", ErrInvalidCategory
	}
	return c, nil
}

// Recipe はレシピ Master の業務モデル（GORM/HTTP に非依存）。
//
// なぜ GORM Model と分離するか:
//
//	永続化方式(MySQL/別ストア)が変わっても UseCase への影響を抑えるため、
//	業務モデルは永続化タグやDB都合のフィールドを持たない純粋な Go 値型にする。
//
// Recipe.ID は Swift 側の RecipeID(recipe-01 等)と一致させる。
// これにより iOS が将来 Remote Repository へ接続した際、既存の画像アセット名や
// 掲載割当との突き合わせがそのまま使える。
type Recipe struct {
	ID             string
	Title          string
	Summary        string
	Category       Category
	CookingMinutes int
	Calories       int
	Servings       int
	// Ingredients/Steps は Swift の [String] に対応する自由文。順序を保持する。
	Ingredients []string
	Steps       []string
	// ImageReference は画像参照（存在する場合）。
	// 現行 Swift の Recipe には画像プロパティが無いが、iOS は RecipeID をキーに
	// バンドル画像(recipe-01.jpg 等)を読み込むため、その参照キー(= Recipe ID)を入れる。
	// 画像が無い場合は空文字。
	ImageReference string
}
