package mysql

import "time"

// GORM Model 群。
//
// Domain Model とは分けて定義する。理由:
//   - 永続化都合のタグ(gorm:"...")・FK・タイムスタンプ列などを Domain に混入させないため。
//   - 永続化方式が変わっても Domain/UseCase を変更しないため（変換は converter.go に閉じる）。
//
// スキーマは golang-migrate の SQL で管理し、GORM の AutoMigrate は使わない。
// そのためここでは TableName/column を明示し、実テーブルと厳密に一致させる。

// RecipeModel は recipes テーブル。
type RecipeModel struct {
	ID             string  `gorm:"column:id;primaryKey"`
	Title          string  `gorm:"column:title"`
	Summary        string  `gorm:"column:summary"`
	Category       string  `gorm:"column:category"`
	CookingMinutes int     `gorm:"column:cooking_minutes"`
	Calories       int     `gorm:"column:calories"`
	Servings       int     `gorm:"column:servings"`
	ImageReference *string `gorm:"column:image_reference"` // NULL 許容
	CreatedAt      time.Time
	UpdatedAt      time.Time

	// 関連（詳細取得時に position 昇順で Preload する）
	Ingredients []RecipeIngredientModel `gorm:"foreignKey:RecipeID;references:ID"`
	Steps       []RecipeStepModel       `gorm:"foreignKey:RecipeID;references:ID"`
}

// TableName は GORM の複数形化に頼らず実テーブル名を固定する。
func (RecipeModel) TableName() string { return "recipes" }

// RecipeIngredientModel は recipe_ingredients テーブル。
// Swift の材料は「材料名 分量」の自由文 1 行なので、単一の text 列で保持する。
type RecipeIngredientModel struct {
	ID       uint64 `gorm:"column:id;primaryKey;autoIncrement"`
	RecipeID string `gorm:"column:recipe_id"`
	Position int    `gorm:"column:position"`
	Text     string `gorm:"column:content"`
}

func (RecipeIngredientModel) TableName() string { return "recipe_ingredients" }

// RecipeStepModel は recipe_steps テーブル。手順も Swift の [String] に合わせ自由文。
type RecipeStepModel struct {
	ID       uint64 `gorm:"column:id;primaryKey;autoIncrement"`
	RecipeID string `gorm:"column:recipe_id"`
	Position int    `gorm:"column:position"`
	Text     string `gorm:"column:content"`
}

func (RecipeStepModel) TableName() string { return "recipe_steps" }

// DailyRecipeEntryModel は daily_recipe_entries テーブル。
// publication_date は DATE 型。接続ロケール UTC で time.Time として読み書きし、
// 変換時に UTC の年月日のみを使うことで Swift の日付キーと 1 日ずれないようにする。
type DailyRecipeEntryModel struct {
	ID              string    `gorm:"column:id;primaryKey"`
	PublicationDate time.Time `gorm:"column:publication_date;type:date"`
	RecipeID        string    `gorm:"column:recipe_id"`
	DisplayOrder    int       `gorm:"column:display_order"`
	CreatedAt       time.Time
	UpdatedAt       time.Time

	// カレンダー取得時に参照レシピ概要を Preload する
	Recipe RecipeModel `gorm:"foreignKey:RecipeID;references:ID"`
}

func (DailyRecipeEntryModel) TableName() string { return "daily_recipe_entries" }
