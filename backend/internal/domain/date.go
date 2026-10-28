package domain

import (
	"fmt"
	"time"
)

// Date は「暦日（Calendar Day）」を表す業務上の日付。
//
// なぜ time.Time をそのまま使わないか:
//   - レシピの掲載日は「時刻」を持たない純粋な日付であり、time.Time の時刻成分や
//     タイムゾーン変換によって Swift 側の日付キー(yyyy-MM-dd)と 1 日ずれるのを防ぐため、
//     年月日だけを保持する値型として扱う。
//   - MySQL の DATE 型 / Swift の DateKey(文字列 yyyy-MM-dd) と 1:1 で対応する。
type Date struct {
	Year  int
	Month int
	Day   int
}

// dateLayout は Swift 側 DateKey と一致させる書式。
const dateLayout = "2006-01-02"

// ParseDate は "YYYY-MM-DD" 文字列を Date へ変換する。
// 時刻やタイムゾーンは一切解釈しない（UTC 固定で年月日のみ取り出す）。
func ParseDate(s string) (Date, error) {
	t, err := time.Parse(dateLayout, s)
	if err != nil {
		return Date{}, fmt.Errorf("invalid date %q: %w", s, ErrInvalidDate)
	}
	return Date{Year: t.Year(), Month: int(t.Month()), Day: t.Day()}, nil
}

// NewDateFromTime は永続化層(time.Time)から Date を取り出す。
// DATE 列は接続ロケール UTC の 00:00:00 として読み取るため、UTC の年月日をそのまま使う。
func NewDateFromTime(t time.Time) Date {
	u := t.UTC()
	return Date{Year: u.Year(), Month: int(u.Month()), Day: u.Day()}
}

// String は "YYYY-MM-DD" を返す（JSON やログ出力・DB クエリで利用）。
func (d Date) String() string {
	return fmt.Sprintf("%04d-%02d-%02d", d.Year, d.Month, d.Day)
}

// Time は永続化・比較用に UTC 00:00:00 の time.Time を返す。
// 常に UTC 固定にすることで、保存→取得の往復で日付がずれない。
func (d Date) Time() time.Time {
	return time.Date(d.Year, time.Month(d.Month), d.Day, 0, 0, 0, 0, time.UTC)
}

// After は d が other より後の日付かどうか。
func (d Date) After(other Date) bool { return d.Time().After(other.Time()) }

// Compare は d<other で負、等しいと 0、d>other で正を返す（安定ソート用）。
func (d Date) Compare(other Date) int {
	switch {
	case d.Time().Before(other.Time()):
		return -1
	case d.Time().After(other.Time()):
		return 1
	default:
		return 0
	}
}
