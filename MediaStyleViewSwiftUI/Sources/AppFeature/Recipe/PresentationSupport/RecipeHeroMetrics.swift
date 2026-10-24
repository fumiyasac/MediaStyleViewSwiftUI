//
//  RecipeHeroMetrics.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/25.
//

// Recipe DetailのHero（スクロール連動のStretch/Parallax/Collapse）の描画パラメータを、
// スクロール量から純粋に算出する値型と関数。副作用を持たずSwift Testingで単体検証できる。
// Viewはここで得たパラメータを適用するだけで、計算ロジックをView内へ書き連ねない。
//
// 符号の約束（scrollOffset）:
//  - 0   : 先頭（静止）
//  - 正  : 上方向へスクロール（Collapsing）
//  - 負  : 下方向へPullDown（Stretch）

import CoreGraphics

// MARK: - RecipeHeroMetrics

struct RecipeHeroMetrics: Sendable, Equatable {

    // PullDown量（>= 0）。Heroを下方向の引っ張りに合わせて拡大するために使う。
    let stretchAmount: CGFloat
    // 上スクロール時にHeroを本文より緩やかに動かすための遅延オフセット（>= 0）。
    let parallaxOffset: CGFloat
    // 折りたたみ進捗（0...1）。0=完全展開、1=完全折りたたみ。
    let collapseProgress: CGFloat
}

extension RecipeHeroMetrics {

    // スクロール量からHeroの描画パラメータを求める純粋関数。
    // - scrollOffset: 先頭からのスクロール量（正=上スクロール/負=PullDown）
    // - expandedHeight: 展開時のHero高さ
    // - collapsedHeight: 折りたたみ後に残すヘッダの最小高さ
    // - parallaxFactor: 上スクロール量に対するParallax遅延の割合（0...1目安）
    // - maxStretch: Stretchの上限（極端な拡大を防ぐ）
    static func make(
        scrollOffset: CGFloat,
        expandedHeight: CGFloat,
        collapsedHeight: CGFloat = 0,
        parallaxFactor: CGFloat = 0.35,
        maxStretch: CGFloat = 160
    ) -> RecipeHeroMetrics {
        // 不正な高さを吸収する（負値やcollapsed>expandedを安全側へ寄せる）
        let safeExpanded = max(expandedHeight, 1)
        let safeCollapsed = min(max(collapsedHeight, 0), safeExpanded)
        let collapseRange = max(safeExpanded - safeCollapsed, 1)

        // PullDown（負のoffset）→ Stretch。上限でクランプし極端な拡大を防ぐ。
        let pullDown = scrollOffset < 0 ? -scrollOffset : 0
        let stretch = min(pullDown, max(maxStretch, 0))

        // 上スクロール（正のoffset）→ Parallax遅延。
        let parallax = scrollOffset > 0 ? scrollOffset * max(parallaxFactor, 0) : 0

        // 折りたたみ進捗は上スクロール時のみ進み、0...1にクランプ。
        let rawProgress = scrollOffset > 0 ? scrollOffset / collapseRange : 0
        let progress = min(max(rawProgress, 0), 1)

        return RecipeHeroMetrics(
            stretchAmount: stretch,
            parallaxOffset: parallax,
            collapseProgress: progress
        )
    }

    // 折りたたみ後も最小高さを下回らないヘッダ高さ（item: ヘッダーの最小高さを下回らない）。
    static func collapsedHeaderHeight(
        expandedHeight: CGFloat,
        collapsedHeight: CGFloat,
        collapseProgress: CGFloat
    ) -> CGFloat {
        let safeExpanded = max(expandedHeight, 1)
        let safeCollapsed = min(max(collapsedHeight, 0), safeExpanded)
        let progress = min(max(collapseProgress, 0), 1)
        let height = safeExpanded - (safeExpanded - safeCollapsed) * progress
        return max(height, safeCollapsed)
    }

    // Compact Title表示の判定。閾値付近の点滅を避けるためヒステリシスを設ける。
    // 表示中は下側閾値まで、非表示中は上側閾値を超えたら切り替える。
    static func compactTitleVisible(
        collapseProgress: CGFloat,
        isCurrentlyCompact: Bool,
        lowerThreshold: CGFloat = 0.6,
        upperThreshold: CGFloat = 0.9
    ) -> Bool {
        if isCurrentlyCompact {
            return collapseProgress >= lowerThreshold
        } else {
            return collapseProgress >= upperThreshold
        }
    }
}
