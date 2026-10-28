package domain

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestParseDate(t *testing.T) {
	d, err := ParseDate("2026-10-01")
	require.NoError(t, err)
	require.Equal(t, Date{Year: 2026, Month: 10, Day: 1}, d)
	require.Equal(t, "2026-10-01", d.String())
}

func TestParseDate_Invalid(t *testing.T) {
	for _, s := range []string{"2026-13-01", "2026/10/01", "", "2026-10-1", "abc"} {
		_, err := ParseDate(s)
		require.ErrorIs(t, err, ErrInvalidDate, "input=%q", s)
	}
}

func TestNewDateFromTime_UTCStable(t *testing.T) {
	// UTC 00:00:00 の DATE は年月日がそのまま取れる（1 日ずれない）。
	tm := time.Date(2026, 10, 31, 0, 0, 0, 0, time.UTC)
	require.Equal(t, "2026-10-31", NewDateFromTime(tm).String())
}

func TestDateCompareAndAfter(t *testing.T) {
	a := Date{2026, 10, 1}
	b := Date{2026, 10, 2}
	require.True(t, b.After(a))
	require.False(t, a.After(b))
	require.Equal(t, -1, a.Compare(b))
	require.Equal(t, 0, a.Compare(a))
	require.Equal(t, 1, b.Compare(a))
}

func TestParseCategory(t *testing.T) {
	for _, s := range []string{"japanese", "western", "chinese", "italian", "dessert", "healthy"} {
		c, err := ParseCategory(s)
		require.NoError(t, err)
		require.Equal(t, Category(s), c)
	}
	_, err := ParseCategory("unknown")
	require.ErrorIs(t, err, ErrInvalidCategory)
}
