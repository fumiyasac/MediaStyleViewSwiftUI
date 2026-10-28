package domain

import "errors"

// ドメイン層のエラー。
//
// ここでは HTTP ステータスや SQL 固有の情報に依存させない。
// HTTP への変換は adapter/http 層で行う（Domain → HTTP Status の一方向変換）。
// これにより永続化方式や公開プロトコルが変わっても業務エラーの意味は保たれる。
var (
	// ErrRecipeNotFound は指定 ID のレシピが存在しないことを表す。
	ErrRecipeNotFound = errors.New("recipe not found")

	// ErrInvalidDate は日付文字列が yyyy-MM-dd として不正なことを表す。
	ErrInvalidDate = errors.New("invalid date")

	// ErrInvalidDateRange は from > to など期間指定が不正なことを表す。
	ErrInvalidDateRange = errors.New("invalid date range")

	// ErrDateRangeTooLong は取得期間が上限を超えたことを表す。
	ErrDateRangeTooLong = errors.New("date range too long")

	// ErrInvalidCategory はサポート外のカテゴリ指定を表す。
	ErrInvalidCategory = errors.New("invalid category")

	// ErrInvalidPagination は limit/offset が不正なことを表す。
	ErrInvalidPagination = errors.New("invalid pagination")
)
