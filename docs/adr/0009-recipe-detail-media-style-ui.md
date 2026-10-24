# 0009. Recipe DetailのScroll-driven Media Style UI設計

- Status: Accepted
- Date: 2026-10-25
- 関連PR: Phase 9（Recipe Detail Media Style UI: Parallax Hero / Collapsing Header）
- 前提: PR #6〜#13（Recipe/MealLog/Calendar/Timeline・Swift Testing移行・Calendar整理 / ADR 0003〜0008）

## Context

Recipe Detailを、写真を主役としたメディア風の閲覧体験へ発展させる。Parallax Hero・Pull-down Stretch・
Collapsing Header・Compact Titleをスクロール位置に連動して表現しつつ、既存のRecipe Detail機能
（読込/表示/MealLog Editor連携/保存反映/Navigation）とSwift 6安全性・スクロール性能を最優先で維持する。

本PRのためにDeployment Targetを **iOS 18** へ引き上げ、スクロール取得に `onScrollGeometryChange`(iOS 18+)を採用する
（ユーザー方針）。Recipe Domainに画像プロパティは無いため、Heroはカテゴリ色グラデーション＋SF Symbolの
プレースホルダーを主役に置く（永続化やDomainは変更しない）。

## Decision

1. **スクロール位置の取得**: `onScrollGeometryChange(for: CGFloat.self)` で
   `contentOffset.y + contentInsets.top`（先頭からのスクロール量）だけを抽出する。
   全ScrollGeometryや位置全体をStateへ送らず、必要な1値のみをView @Stateへ反映する。
   符号は「正=上スクロール(Collapsing)／負=PullDown(Stretch)／0=先頭」に統一する。

2. **Geometry計算の責務分離（StateMachineに載せない）**:
   スクロール量→描画パラメータの変換は純粋値型 `RecipeHeroMetrics` と静的関数
   `make(scrollOffset:expandedHeight:collapsedHeight:parallaxFactor:maxStretch:)` に閉じ込める。
   `collapsedHeaderHeight(...)`（最小高さクランプ）と `compactTitleVisible(...)`（ヒステリシス）も純粋関数。
   ReducerやViewModelにGeometry/アニメーションを一切追加しない。これによりSwift Testingで決定的に検証できる。

3. **ParallaxとStretchの計算**:
   - Stretch = PullDown量（`-scrollOffset`、`maxStretch`で上限クランプ）。極端な拡大を防ぐ。
   - Parallax = 上スクロール量 × `parallaxFactor`(0.35)。Heroを本文より緩やかに動かす遅延量。
   - collapseProgress = `scrollOffset / (expandedHeight - collapsedHeight)` を 0...1 にクランプ。
   - 不正な高さ（負値・collapsed>expanded）は安全側へ寄せ、NaN/負値/極端値を出さない。

4. **Collapsing Headerの表示戦略（固定Hero + 被せる本文）**:
   HeroはScrollViewの外側(ZStack背面)に固定し、不透明な本文(角丸トップ)がその上をスクロールして覆う。
   これにより下方向の重なりや上方向の隙間が生じない。HeroはStretchを下端基準の`scaleEffect`、Parallaxを`offset`の
   **描画変換のみ**で表現し、スクロールコンテンツのレイアウトサイズを毎フレーム変えない。
   Compact Titleは、折りたたみが進んだら `navigationTitle` をレシピ名へ切り替え、`toolbarBackground` を可視化する。
   展開時はタイトル空＋背景透過でHeroを見せる。システムの戻るボタンを使うためSafe Area・常時操作性・
   タイトル二重化（principal併用しない）を回避できる。閾値は `compactTitleVisible` のヒステリシス
   （表示0.9/非表示0.6）で点滅を防ぐ。

5. **Viewの責務分離**:
   - `RecipeDetailScreen`: 画面組み立て・ViewModel接続・ScrollView構成・onScrollGeometryChange・Navigation・Editor導線。
   - `RecipeHeroView`: Heroプレースホルダー描画・Stretch/Parallaxの視覚表現・クリッピング。
   - `RecipeHeroMetrics`(PresentationSupport): スクロール量→描画パラメータの純粋計算とUnit Test可能性。
   - `RecipeDetailContent`(private): 本文（scrollOffsetに依存しない）。別Viewに切り出し、スクロール中に
     scrollOffsetが変化しても本文bodyを再評価させない（材料・手順の再描画を避ける）。
   `RecipeCollapsingHeaderView` は新設せず、システムのnavigation bar（戻るボタン＋Compact Title＋背景）を
   コンパクトヘッダとして用いる（過剰な分割を避ける）。

6. **StateMachineとの境界**:
   - StateMachine/ViewModel: Recipe読込状態・取得成功/失敗・保存済みMealLog・Editor連携・非同期成否。
   - View @State: scrollOffset・Stretch/Parallax・collapseProgress・Compact Title表示。
   スクロール位置でViewModelを毎フレーム更新しない。

7. **Swift 6 Actor Isolation**:
   `onScrollGeometryChange` の変換クロージャは `ScrollGeometry` からCGFloatを取り出す純粋処理で、
   MainActor隔離値を不正にキャプチャしない。`RecipeHeroMetrics` はSendableな値型。
   `@unchecked Sendable`/`nonisolated(unsafe)`/`@preconcurrency`/不要な`Task.detached` は未使用。

8. **Reduce Motion対応**:
   `@Environment(\.accessibilityReduceMotion)` を参照し、有効時はStretch/Parallaxを無効化（静的Hero）、
   Compact Title切替のアニメーションも付けない。レイアウト・操作・内容理解はアニメーション非依存。

## Alternatives

- **iOS 17維持 + GeometryReader/PreferenceKey**: 当初案だが、方針によりDeployment Targetを18へ上げ
  `onScrollGeometryChange` を採用（必要値のみ抽出でき、PreferenceKey配線より簡潔）。
- **Hero=ScrollView内の先頭要素**: PullDownのStretchは綺麗だが、上スクロール時のParallaxで重なり/隙間の制御が難しい。
  背面固定＋被せる本文の方が破綻しない（採用）。
- **Compact Titleをprincipal toolbarに常設**: タイトル二重化とちらつきの懸念。`navigationTitle`切替＋
  `toolbarBackground`可視化でシンプルにした。
- **matchedGeometryEffect / NavigationTransition Zoom**: 本PRでは扱わない（次PR）。

## Consequences

- 既存のRecipe Detail機能（読込/表示/Editor/保存反映/Navigation）を保ったまま、料理メディアらしい閲覧体験を追加。
- Geometry計算が純粋関数に分離され、スクロール挙動をUnit Test（11ケース）で回帰検証できる。
- 本文を別Viewへ分離したため、スクロール中の再描画は Hero/ヘッダ周辺に限定される。

### トレードオフ・既知の制約

- Deployment Targetを iOS 18 へ引き上げた（App Target含む）。iOS 17以前は非対応。
- Heroは実写ではなくカテゴリ色プレースホルダー（Recipe Domainに画像が無いため）。実画像対応は将来課題。
- Compact Title出現時、スクロール途中で本文の大タイトルと短時間併存しうる（重なりはせず、iOSの大タイトル遷移に類似）。
- Pull-down Stretchはドラッグ中の過渡表現で、静止スクショでの採取が難しい（コード/計算で担保）。
- 画面遷移のZoom表現は本PRに含めない。

## 検証

- Swift Testing: `RecipeHeroMetricsTests`（0量で初期/PullDownでStretch正/上スクロールでCollapse/進捗0..1/
  飽和安定/閾値付近の健全性/決定性/最小高さ非下回り/Stretch上限/不正高さ安全/Compact Titleヒステリシス）。
  既存のRecipe Detail/MealLog/Calendar/Timelineの回帰テストも維持。合計 111 tests / 18 suites passed。
- App `xcodebuild build`（iOS 18 Simulator）→ `** BUILD SUCCEEDED **`。
- Simulator手動: Timeline→Recipe Detail遷移、フルブリードHero表示、上スクロールでParallax+Collapse+Compact Title出現、
  戻るボタン操作、本文の可読性を確認。Pull-down Stretchの過渡・Reduce Motion/Dynamic Type/VoiceOver・iPad/物理デバイスは未検証（後述）。
