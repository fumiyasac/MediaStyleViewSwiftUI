# 0004. Calendar Feature を MVVM + StateMachine へ統合する

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 4（Calendar Feature Integration）
- 前提: PR #6（Recipe/MealLog Domain・Repository）、PR #7（StateMachine基盤）、PR #8（SwiftData永続化 / ADR 0003）

## Context

既存のCalendar画面（連続月スクロール・タブ・イベントドット・一覧検索）を維持したまま、
Recipe Fixtureの日別レシピと SwiftData の調理記録(MealLog)を、PR #7 の一方向データフロー経由で
描画へ反映させたい。Swift 6 strict concurrency（`swiftLanguageModes: [.v6]`）を維持する。

既存StateMachineは単一の `currentRequestID` と単一の読込状態しか持たず、連続スクロールで
複数月が同時に見える状況では、月Bの読込が月Aのデータを上書きしてしまう（単一requestID問題）。

## Decision

1. **CalendarViewModelの所有**: `CalendarRootView` が `@State` で1インスタンスだけ保持する。
   画面再描画でも再生成されず、月タブ・一覧タブで同じViewModel/Stateを共有できる。
2. **Repositoryの生成・注入**: 公開型 `CalendarFeatureDependencies`(Composition Root)が
   `FixtureRecipeRepository` と `SwiftDataMealLogRepository`(本番)/`InMemoryMealLogRepository`(代替)を
   組み立て `DefaultCalendarUseCase` を生成する。App起動時に**一度だけ**生成して `ContentView` へ渡し、
   ModelContainerの多重生成を防ぐ。Preview/TestはInMemoryへ差し替える。
3. **複数月の読み込み方針 / Stateのデータ保持戦略**: Stateを
   `months: [MonthKey: CalendarMonthLoad]` の月ごとキャッシュに拡張（単一requestID問題への最小拡張）。
   各月が自前の `recipeEntries` / `mealLogs` / `phase` / `requestID` を持ち、別月の読込で他月は壊れない。
   データは `phase` と分離して保持し、読込中/失敗でも直前表示を失わない。
4. **月ごとのキャッシュ・重複リクエスト対策**: Reducerは、ある月が `loading`/`loaded` の間は
   新規読込Effectを出さない（重複読込・画面再表示での無限読込を抑制）。`idle`/`failed` のみ読み込む（失敗時は再試行可）。
   完了Actionは「その月の」requestIDと照合し、古い結果で上書きしない。
5. **日付キーとTimeZone**: `MonthKey`/`DateKey` は `DateKeyCalendar`(Asia/Tokyo固定)で一元生成し、
   Fixture側・SwiftData側・ViewData生成側で解釈を揃える。掲載日(`DailyRecipeEntry.dateKey`)と
   調理日(`MealLogSummary.dateKey`)は別フィールドで扱い、同一視しない。
6. **ViewDataの導入**: `CalendarDayViewData`(表示専用値型)と `CalendarDayViewDataFactory` を追加。
   `CalendarDayCellView` はDomain/State/Repositoryを知らず、フラットな表示値だけで描画する。
7. **SwiftDataの変更をUIへ反映する方法**: `@ModelActor` Repository → `MealLogSummary`(Sendable値型)
   → UseCase → 完了Action → Reducer → State → ViewData → View。`@Model` EntityはPresentation層へ渡さない。

## Reducerが扱うActionとEffect

- intent: `onAppear` / `selectDate(Date)` / `loadMonth(Date)`（requestID/MonthKey採番はViewModel）
- 内部: `beginLoading(requestID:monthKey:month:)` → Effect `loadMonth(requestID:monthKey:month:)`
- 完了: `loadSucceeded(requestID:monthKey:payload:)` / `loadFailed(requestID:monthKey:message:)`

## Alternatives

- **View から直接 `@Query` / `modelContext` を使う**: Presentation が SwiftData に密結合し、
  非Sendableな Entity が State/ViewModel に漏れる。一方向データフロー・差し替え可能性と相反（ADR 0003参照）→不採用。
- **単一requestID・単一読込状態のまま**: 連続スクロールで月間データが互いに上書きされる→不採用。
- **汎用キャッシュ/状態管理ライブラリ導入**: 要件に対し過剰→不採用。必要最小の `[MonthKey: CalendarMonthLoad]` のみ。
- **読み込み専用の新DTO追加**: 既存 `DailyRecipeEntry`/`MealLogSummary` で表現可能なため不採用（`CalendarMonthPayload` は両者を束ねるだけの薄い集約）。

## Consequences

- 既存のスクロール/今日復帰/タブ復帰の位置復元/イベントドット/一覧検索は無改変で維持。
- 月単位で独立にロード・キャッシュされ、別月の読込が互いを壊さない。
- SwiftDataの調理記録が0件でも正常描画（本番ストア空で確認）。RepositoryエラーはUI全体を壊さず該当月の `failed` に留まる。

### デメリット・トレードオフ

- `months` が訪問した月だけ増える（事実上の軽量キャッシュ）。無効化/上限管理は未実装（必要になれば後続で対応）。
- 連続スクロールで各月の `onAppear` が読込をトリガーするため、起動直後にリスト先頭側の数ヶ月(過去)が
  一度だけ読み込まれる（結果は空で安価）。重複はReducerが抑制。
- SwiftDataの外部変更をUIへ自動反映する仕組み(`@Query`相当)は持たないため、変更反映は再ロード契機が必要（後続）。

## Swift 6 Concurrency への配慮

- `CalendarViewModel` は `@MainActor` 隔離。State更新はMainActor上のみ。
- State/Action/Effect/Payload/Domain は Sendable 値型。`@Model` Entity は `@ModelActor` 隔離外へ出さない。
- Effectは月ごとにTask管理し、同月再読込では前Taskを `cancel()`（別月Taskは止めない）。`[weak self]` で保持しない。
- `CancellationError` は画面エラーにせず、`requestID` 照合で古い結果の反映も防ぐ。
- `@unchecked Sendable` / `@preconcurrency` / `nonisolated(unsafe)` は不使用。Concurrency警告は0。
