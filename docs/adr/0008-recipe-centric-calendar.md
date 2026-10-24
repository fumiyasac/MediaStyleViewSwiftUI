# 0008. Calendarの責務をRecipe/MealLogへ一本化（旧イベント表示の廃止）

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 8（Legacy Calendar Cleanup & Recipe-Centric Calendar UI）
- 前提: PR #6〜#12（Recipe/MealLog/Calendar/Timeline・Swift Testing移行 / ADR 0003〜0007）

## Context

Calendarは当初「Apple標準カレンダー風のイベント表示サンプル」として実装され、月グリッドのセルに
work/health等のダミーイベントのカテゴリ色ドットを表示していた。アプリは「Daily Recipe Calendar + Cooking Log」へ
発展し、カレンダー上で意味を持つのは**レシピ掲載日**と**調理記録のある日**だけになった。

ADR 0007 では `CalendarSampleData`（＋ `CalendarEvent`）が月グリッドのドットへ実行時供給されていたため削除を見送り、
「ダミードット廃止はプロダクト判断、合意後に次PRで整理」と記していた。本PRでそのUX判断が確定し（ダミードット廃止）、
実行する。

## Decision

1. **旧イベントのカテゴリ色ドットを廃止する**:
   `CalendarDayCellView` から中央下のカテゴリドット描画（`eventCategories.prefix(4)` のHStack）を削除し、
   `CalendarDayViewData.eventCategories` フィールドを削除する。`CalendarDayViewDataFactory.make` から
   `events:` 引数を外し、`CalendarDateUtil.categories(on:in:)` を削除する。
2. **旧イベントのモデルとFixtureを削除する**:
   `CalendarSampleData.swift` と `CalendarEvent.swift`（`CalendarEvent` / `CalendarCategory` / `CalendarDay`）を削除する。
   これらは旧一覧UI（Phase 7で削除済み）とドット供給のためだけに存在し、他に用途が無い。
3. **日付計算モデルは保持する**:
   `CalendarMonthGrid`（月グリッドの日付計算）と `CalendarDateUtil` の日判定（日番号/今日/曜日/祝祭日/同一日）は
   Recipe/MealLog表示に必須のため維持する。`CalendarDay`（旧イベントの入れ物）は日付計算に使われておらず、
   `CalendarMonthGrid` とは別物のため、まとめて削除してよい（削除しても月グリッド計算に影響しない）。
4. **データ供給経路を整理する**:
   `CalendarSampleData.days` → `CalendarFeatureDependencies.days` → `CalendarRootView` → `CalendarMonthScreen`
   → `CalendarMonthView` → `CalendarMonthGridView` の `[CalendarDay]` 引き回しを全廃する。
   カレンダーの状態供給は既存の `CalendarViewModel`（`CalendarUseCase` 経由で Recipe/MealLog Repository）に一本化する。
   新しいRepositoryは作らない。
5. **維持するマーカーと意味の区別**:
   レシピ掲載マーカー（右上・`fork.knife`）と調理記録マーカー（左上・`checkmark.seal.fill`）は維持し、
   「掲載日」と「調理日」を区別する。同日に両方あれば両方表示する。今日の赤丸・選択リング・曜日色・祝日色も維持。
6. **アクセシビリティの意味付け**:
   セル全体を1つのアクセシビリティ要素にまとめ、「10月24日、今日、選択中、レシピ掲載あり、調理記録あり」のように
   日付と状態を読み上げる（従来は各マーカー個別のラベルのみだった）。文言はアプリ既存方針に合わせハードコードの日本語。

## Alternatives

- **ドット描画だけ消してモデルは残す**: `CalendarEvent`/`CalendarSampleData` が完全に未使用になるため、
  デッドコードを残すことになり不採用。
- **`CalendarDay` を日付計算用に流用して残す**: 日付計算は `CalendarMonthGrid` が担っており重複。流用しない。
- **StateMachineの再設計**: 旧イベントはView層の表示のみで State/Action/Effect/Reducer に痕跡が無いため、
  StateMachineは変更不要（再設計しない）。

## Consequences

- カレンダーはRecipeとMealLogだけが意味を持つ表示になり、旧イベント管理アプリ由来のノイズが消えた。
- セルの表示データ（`CalendarDayViewData`）が掲載/調理の2フラグ＋日付状態だけになり、Factoryの引数も減って見通しが良い。
- View階層から `[CalendarDay]` の引き回しが消え、データ供給が `ViewModel`→`UseCase`→Repository に一本化された。

### 保持したもの（削除しなかった理由）

- `CalendarMonthGrid`：月グリッドの日付計算に必須。
- `CalendarDateUtil` の日判定群：Factoryとテストが使用。
- Recipe `FixtureRecipeRepository` / MealLog `InMemoryRepository` / `SwiftDataMealLogRepository` / SwiftDataテスト用Fixture：現行機能の中核。
- Timelineの日付フォーマット/セクション表示：Timeline側の責務で旧イベントと無関係。

## テストと検証

- `CalendarDayViewDataTests`：Recipeのみ/MealLogのみ/両方(同日)/複数掲載/複数記録/掲載日≠調理日/月末・月初・年跨ぎ/
  TimeZone境界/選択状態を Swift Testing で検証（`events:` 引数の除去に追随、同日両マーカーのケースを追加）。
- 旧 `CalendarCategoryTests`（カテゴリ抽出）は対象機能ごと削除。
- `xcodebuild test -scheme AppFeature`（iPhone 17 Pro）→ `** TEST SUCCEEDED **` / 100 tests / 17 suites。
- App `xcodebuild build` → `** BUILD SUCCEEDED **`。
- Simulator手動確認：月グリッドでカテゴリ色ドットが消え、レシピ掲載マーカー（右上）・今日の赤丸・曜日色・7列グリッド・
  月スクロール・今日復帰が維持されることを確認。MealLog緑マーカーは唯一の記録日(10/24)が今日の赤丸と重なり本確認では
  判別困難（overlayコードは不変）＝実機個別確認は未検証。
