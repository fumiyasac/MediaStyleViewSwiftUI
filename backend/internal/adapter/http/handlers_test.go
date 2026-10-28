package httpadapter

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/domain"
	"github.com/fumiyasac/MediaStyleViewSwiftUI/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
)

// --- Fake Repository（HTTP + UseCase を実 DB なしで検証する）---

type fakeRecipeRepo struct {
	list    usecase.RecipeListResult
	listErr error
	byID    map[string]domain.Recipe
}

func (f *fakeRecipeRepo) List(context.Context, usecase.RecipeListFilter) (usecase.RecipeListResult, error) {
	return f.list, f.listErr
}
func (f *fakeRecipeRepo) FindByID(_ context.Context, id string) (domain.Recipe, error) {
	r, ok := f.byID[id]
	if !ok {
		return domain.Recipe{}, domain.ErrRecipeNotFound
	}
	return r, nil
}

type fakeCalRepo struct {
	entries []usecase.CalendarEntry
	err     error
	pingErr error
}

func (f *fakeCalRepo) FindEntries(context.Context, domain.Date, domain.Date) ([]usecase.CalendarEntry, error) {
	return f.entries, f.err
}
func (f *fakeCalRepo) Ping(context.Context) error { return f.pingErr }

// setup はルーターを Fake 付きで組み立てる。
func setup(recipeRepo *fakeRecipeRepo, calRepo *fakeCalRepo) *gin.Engine {
	gin.SetMode(gin.TestMode)
	recipeUC := usecase.NewRecipeUseCase(recipeRepo)
	calUC := usecase.NewCalendarUseCase(calRepo)
	return NewRouter(
		NewRecipeHandler(recipeUC),
		NewCalendarHandler(calUC),
		NewHealthHandler(calRepo),
	)
}

func do(r *gin.Engine, method, target string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, target, nil)
	r.ServeHTTP(w, req)
	return w
}

func TestRecipeList_OK(t *testing.T) {
	r := setup(&fakeRecipeRepo{list: usecase.RecipeListResult{
		Items: []domain.Recipe{{ID: "recipe-01", Title: "鮭の塩麹焼き", Category: domain.CategoryJapanese}},
		Total: 1,
	}}, &fakeCalRepo{})

	w := do(r, http.MethodGet, "/api/v1/recipes?limit=10&offset=0")
	require.Equal(t, http.StatusOK, w.Code)

	var body struct {
		Items      []map[string]any `json:"items"`
		Pagination map[string]any   `json:"pagination"`
	}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
	require.Len(t, body.Items, 1)
	require.Equal(t, "recipe-01", body.Items[0]["id"])
	require.EqualValues(t, 10, body.Pagination["limit"])
	require.EqualValues(t, 1, body.Pagination["total"])
}

func TestRecipeList_EmptyReturnsArray(t *testing.T) {
	r := setup(&fakeRecipeRepo{list: usecase.RecipeListResult{Items: nil, Total: 0}}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/recipes")
	require.Equal(t, http.StatusOK, w.Code)
	// null ではなく [] であること
	require.Contains(t, w.Body.String(), `"items":[]`)
}

func TestRecipeList_InvalidLimit(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/recipes?limit=abc")
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Contains(t, w.Body.String(), "INVALID_PAGINATION")
}

func TestRecipeList_RepoErrorBecomes500(t *testing.T) {
	r := setup(&fakeRecipeRepo{listErr: errors.New("db down")}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/recipes")
	require.Equal(t, http.StatusInternalServerError, w.Code)
	require.Contains(t, w.Body.String(), "INTERNAL_ERROR")
	// 内部エラー詳細(SQL/接続情報)を漏らさない
	require.NotContains(t, w.Body.String(), "db down")
}

func TestRecipeDetail_OK(t *testing.T) {
	r := setup(&fakeRecipeRepo{byID: map[string]domain.Recipe{
		"recipe-01": {ID: "recipe-01", Title: "鮭の塩麹焼き", Ingredients: []string{"生鮭 2切れ"}, Steps: []string{"焼く"}},
	}}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/recipes/recipe-01")
	require.Equal(t, http.StatusOK, w.Code)
	require.Contains(t, w.Body.String(), "生鮭 2切れ")
}

func TestRecipeDetail_NotFound(t *testing.T) {
	r := setup(&fakeRecipeRepo{byID: map[string]domain.Recipe{}}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/recipes/recipe-xx")
	require.Equal(t, http.StatusNotFound, w.Code)
	require.Contains(t, w.Body.String(), "RECIPE_NOT_FOUND")
}

func TestCalendar_OK(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{entries: []usecase.CalendarEntry{
		{
			Entry:  domain.DailyRecipeEntry{ID: "daily-2026-10-01-recipe-01", PublicationDate: domain.Date{Year: 2026, Month: 10, Day: 1}, RecipeID: "recipe-01"},
			Recipe: domain.Recipe{ID: "recipe-01", Title: "鮭の塩麹焼き", Category: domain.CategoryJapanese},
		},
	}})
	w := do(r, http.MethodGet, "/api/v1/calendar?from=2026-10-01&to=2026-10-31")
	require.Equal(t, http.StatusOK, w.Code)
	require.Contains(t, w.Body.String(), "2026-10-01")
}

func TestCalendar_EmptyReturnsArray(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{entries: nil})
	w := do(r, http.MethodGet, "/api/v1/calendar?from=2026-10-01&to=2026-10-31")
	require.Equal(t, http.StatusOK, w.Code)
	require.Contains(t, w.Body.String(), `"items":[]`)
}

func TestCalendar_InvalidDate(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/calendar?from=2026-13-01&to=2026-10-31")
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Contains(t, w.Body.String(), "INVALID_DATE")
}

func TestCalendar_FromAfterTo(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/calendar?from=2026-10-31&to=2026-10-01")
	require.Equal(t, http.StatusBadRequest, w.Code)
	require.Contains(t, w.Body.String(), "INVALID_DATE_RANGE")
}

func TestCalendar_MissingParams(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/api/v1/calendar?from=2026-10-01")
	require.Equal(t, http.StatusBadRequest, w.Code)
}

func TestHealthz(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{})
	w := do(r, http.MethodGet, "/healthz")
	require.Equal(t, http.StatusOK, w.Code)
	require.Contains(t, w.Body.String(), `"status":"ok"`)
}

func TestReadyz_DBUp(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{pingErr: nil})
	w := do(r, http.MethodGet, "/readyz")
	require.Equal(t, http.StatusOK, w.Code)
}

func TestReadyz_DBDown(t *testing.T) {
	r := setup(&fakeRecipeRepo{}, &fakeCalRepo{pingErr: errors.New("no db")})
	w := do(r, http.MethodGet, "/readyz")
	require.Equal(t, http.StatusServiceUnavailable, w.Code)
	require.Contains(t, w.Body.String(), "SERVICE_UNAVAILABLE")
}
