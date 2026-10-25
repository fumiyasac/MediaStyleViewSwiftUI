# 0010. Recipe DetailへのZoom Navigation TransitionとSource Identity

- Status: Accepted
- Date: 2026-10-26
- 関連PR: Phase 10（Recipe Zoom Navigation Transition）
- 前提: PR #6〜#15（Recipe/MealLog/Calendar/Timeline・Media Style UI / ADR 0003〜0009）

## Context

PR #14のRecipe Detail Media Style UI（実写真Hero / Parallax / Collapsing Header）を維持したまま、
TimelineのレシピカードからRecipe Detailへの遷移にZoom Navigation Transition（iOS 18 `navigationTransition(.zoom)`）を
導入し、カードと詳細の視覚的連続性（タップで拡大／戻るで縮小）を持たせる。Deployment Targetは既にiOS 18のため、
本PRのために引き上げは不要。StateMachine/Repository/SwiftData Schemaは変更しない。

同じRecipeが複数の掲載日・複数の場所（Calendar/Timeline）に現れるため、Recipe Master IDだけでは遷移元カードを
一意に識別できない。遷移元Viewを正しく識別できるSource Identityの設計が要点になる。

## Decision

1. **採用API（iOS 18）**:
   遷移元に `matchedTransitionSource(id:in:)`、遷移先に `navigationTransition(.zoom(sourceID:in:))` を用いる。
   既存の型付き `CalendarRoute` と各タブの `NavigationStack(path:)` を再利用する。`matchedGeometryEffect` は併用しない。

2. **Transition Source Identity（`RecipeTransitionSourceID`）**:
   「どの献立か(Recipe Master ID)」と「どのカードか(画面上の遷移元View)」は別概念。純粋なHashable値型
   `RecipeTransitionSourceID(origin, recipeID, entryKey)` を新設する。
   - Timeline: `entryKey = TimelineEntryViewData.id`（掲載割当ID/MealLog IDベースで一意。Recipe Master IDとは別物）。
   - Calendar: `entryKey = dayKey.value`（将来のPreview Card用）。
   - `origin`(calendar/timeline)で場所を区別し、同一Recipe・同一日でもCalendar/Timelineが衝突しない。
   - 既存の安定IDから決定的に生成し、View再描画でUUIDを作らない。純関数Factory（`.timeline(entry:)`/`.calendar(recipeID:dayKey:)`）。
   - SwiftData EntityやNamespaceを保持しない。

3. **Routeへの埋め込み**:
   `CalendarRoute.recipeDetail(recipeID:, publicationDayKey:, sourceID:)` に `sourceID: RecipeTransitionSourceID?` を追加する。
   遷移先はRouteのsourceIDを見てZoomを適用する（nilなら標準Navigation）。

4. **Namespaceの所有**:
   CalendarとTimelineは独立したタブで各々 `NavigationStack` を持つ。Timelineの `NavigationStack`（＝`TimelineScreen`）が
   `@Namespace` を所有し、同一タブ内の遷移元（行）と遷移先（詳細）に同じNamespaceを渡す。タブを跨いで共有しない。
   NamespaceはSwiftUI固有のUI情報として扱い、Reducer/ViewModel/Domain/Repositoryへは渡さない。

5. **Timeline → Recipe DetailのZoom**:
   `TimelineDaySectionView` の各行Buttonに `matchedTransitionSource(id: .timeline(entry:), in: namespace)` を付与。
   `handleTapEntry` はsourceID付きRouteをpushし、`path.last != route` で二重pushを防ぐ。
   遷移先 `RecipeDetailScreen` に、sourceIDがあり かつ Reduce Motion無効のときのみ `navigationTransition(.zoom(...))` を適用。

6. **フォールバック（Source無し/Reduce Motion/Deep Link）**:
   sourceIDがnil、またはReduce Motion有効時は `navigationTransition` を適用せず標準Push/Popにフォールバックする。
   すべての遷移で無条件にZoomを指定しない。遷移元が画面外・検索/フィルタ変更・データ更新で消えても、
   `matchedTransitionSource` が見つからなければSwiftUIが標準遷移に退避するため、誤ったカードへ縮小しない。

7. **Calendar側の対応範囲**:
   `CalendarDayCellView` は日付数字＋マーカーの小さなセルで、Recipe Heroの遷移元として自然でない。
   日付セルをRecipeカードへ改造しない方針のため、本PRでは **Calendarは標準Navigation（sourceID: nil）** とする。
   Calendar用のFactory `RecipeTransitionSourceID.calendar(...)` は用意済みで、Preview Card導入時に接続する（後続PR）。

8. **ZoomとParallax/Collapsing Headerの関係**:
   Recipe Detailは変更しない。遷移はDetailを通常の初期スクロール位置（scrollOffset=0）で表示するため、
   Parallax/Stretch（`onScrollGeometryChange`駆動）はZoom中に発火せず競合しない。Zoom完了後にスクロール操作で
   Parallax/Stretch/Collapsing Header/Compact Titleが通常どおり動作する。

9. **StateMachineとの責務分離**:
   Namespace/Source ID/Zoom適用可否/Navigation Path/スクロール位置はView側。Recipe取得状態/保存済みMealLog/
   保存成否はStateMachine側。ReducerへGeometryやアニメーション進捗を渡さない。ViewModelを肥大化させない。

## Alternatives

- **Recipe Master IDをSource IDに直接使用**: 同一Recipeの複数掲載を区別できず、戻り時に誤ったカードへ縮小しうるため不採用。
- **matchedGeometryEffectで自前Zoom**: Navigation遷移には `navigationTransition(.zoom)` が標準で、二重利用は不要（併用しない）。
- **Calendarの日付セルを遷移元に**: 小さなセルからHeroへのZoomは不自然。日付セルの改造も避ける方針のため見送り（Preview Cardは後続）。
- **タブ跨ぎでNamespace共有**: タブが別NavigationStackのため不要かつ破綻要因。各タブ独立で持つ。

## Consequences

- Timelineのカードと詳細に視覚的連続性が生まれ、戻り操作まで自然になる。
- Source Identityが純粋値型＋Factoryに分離され、一意性/安定性/複数掲載の区別をUnit Testで担保できる。
- 既存のRoute・NavigationStack・StateMachine・Repository・SwiftDataは不変。Detail画面も無改修。

### トレードオフ・既知の制約

- Zoomは iOS 18 の標準API依存。Reduce Motion / sourceID無し / Deep Link は標準遷移へフォールバック。
- Calendar→DetailのZoomは本PR対象外（標準Navigation）。Preview Card経由のZoomは後続PR。
- Timelineの `handleTapEntry` はRecipe項目とMealLog項目の両方が詳細へ遷移する既存挙動を踏襲（本PRでは変更しない）。

## 検証

- Swift Testing: `RecipeTransitionSourceIDTests`（同一項目→同一ID / 複数掲載→別ID / Calendar・Timeline区別 /
  決定性 / 異Recipe→別ID / Route構築：recipeID・掲載日Context・source無しフォールバック・複数掲載の別Route・
  深い階層でのRoute一意性）。既存のRecipe Detail/MealLog/Calendar/Timelineの回帰テストも維持。合計121 tests / 19 suites。
- App `xcodebuild build`（iOS 18 Simulator）→ `** BUILD SUCCEEDED **`（Sendable警告なし）。
- Simulator手動: Timelineのマルゲリータカードから正しいRecipe Detail（ピザHero）へZoom遷移することを確認。
  Zoomアニメーションのmid-frame採取・戻りの縮小・スクロール位置維持・Reduce Motion・複数掲載の戻り先・Calendar各操作・
  Dynamic Type/VoiceOver・物理デバイスは自動操作の制約により**未検証**（戻り/スクロール維持は標準NavigationStack挙動で不変）。
