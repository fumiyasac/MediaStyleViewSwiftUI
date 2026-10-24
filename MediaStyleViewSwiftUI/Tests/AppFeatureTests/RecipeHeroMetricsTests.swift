//
//  RecipeHeroMetricsTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/25.
//

// Recipe DetailのHero描画パラメータ計算(RecipeHeroMetrics)の単体検証。
// スクロール量からStretch/Parallax/Collapseを決定的に求める純粋関数をSwift Testingで担保する。

@testable import AppFeature
import CoreGraphics
import Testing

@Suite("Recipe Hero のスクロール連動パラメータ計算")
struct RecipeHeroMetricsTests {

    private let expanded: CGFloat = 320
    private let collapsed: CGFloat = 60

    // 1. スクロール量0で初期状態（Stretch/Parallax/Progressすべて0）
    @Test("スクロール量0で初期状態になる")
    func zeroOffsetIsInitial() {
        let m = RecipeHeroMetrics.make(scrollOffset: 0, expandedHeight: expanded, collapsedHeight: collapsed)
        #expect(m.stretchAmount == 0)
        #expect(m.parallaxOffset == 0)
        #expect(m.collapseProgress == 0)
    }

    // 2. 下方向Pull-down（負のoffset）でStretch量が正になる
    @Test("下方向Pull-downでStretch量が正・Progressは0のまま")
    func pullDownProducesStretch() {
        let m = RecipeHeroMetrics.make(scrollOffset: -40, expandedHeight: expanded, collapsedHeight: collapsed)
        #expect(m.stretchAmount == 40)
        #expect(m.parallaxOffset == 0)
        #expect(m.collapseProgress == 0)
    }

    // 3. 上方向スクロール（正のoffset）でCollapsingが進み、Parallaxも発生
    @Test("上方向スクロールでCollapsingが進む")
    func scrollUpAdvancesCollapse() {
        let small = RecipeHeroMetrics.make(scrollOffset: 50, expandedHeight: expanded, collapsedHeight: collapsed)
        let large = RecipeHeroMetrics.make(scrollOffset: 150, expandedHeight: expanded, collapsedHeight: collapsed)
        #expect(large.collapseProgress > small.collapseProgress)
        #expect(small.parallaxOffset > 0)
        #expect(small.stretchAmount == 0)
    }

    // 4. 折りたたみ進捗は常に0...1に収まる
    @Test("折りたたみ進捗は0...1に収まる")
    func progressClampedToUnitRange() {
        for offset in stride(from: CGFloat(-200), through: 2000, by: 37) {
            let m = RecipeHeroMetrics.make(scrollOffset: offset, expandedHeight: expanded, collapsedHeight: collapsed)
            #expect(m.collapseProgress >= 0)
            #expect(m.collapseProgress <= 1)
        }
    }

    // 5. 完全に折りたたまれた後も値が安定する（進捗1で飽和し続ける）
    @Test("完全折りたたみ後も進捗は1で安定する")
    func fullyCollapsedIsStable() {
        let range = expanded - collapsed
        let atFull = RecipeHeroMetrics.make(scrollOffset: range, expandedHeight: expanded, collapsedHeight: collapsed)
        let beyond = RecipeHeroMetrics.make(scrollOffset: range + 500, expandedHeight: expanded, collapsedHeight: collapsed)
        #expect(atFull.collapseProgress == 1)
        #expect(beyond.collapseProgress == 1)
    }

    // 6. スクロール閾値付近でも異常値（NaN/負値/極端値）を出さない
    @Test("閾値付近でも異常値を出さない")
    func noAbnormalValuesNearThreshold() {
        let range = expanded - collapsed
        for delta in stride(from: CGFloat(-5), through: 5, by: 0.5) {
            let m = RecipeHeroMetrics.make(scrollOffset: range * 0.9 + delta, expandedHeight: expanded, collapsedHeight: collapsed)
            #expect(m.collapseProgress.isFinite)
            #expect(m.stretchAmount >= 0)
            #expect(m.parallaxOffset >= 0)
        }
    }

    // 7. 入力が同じなら計算結果が同じ（決定性）
    @Test("入力が同じなら結果も同じ（決定性）")
    func deterministic() {
        let a = RecipeHeroMetrics.make(scrollOffset: 123, expandedHeight: expanded, collapsedHeight: collapsed)
        let b = RecipeHeroMetrics.make(scrollOffset: 123, expandedHeight: expanded, collapsedHeight: collapsed)
        #expect(a == b)
    }

    // 8. 折りたたみ後もヘッダーの最小高さ（collapsedHeight）を下回らない
    @Test("ヘッダーの最小高さを下回らない")
    func headerHeightNeverBelowCollapsed() {
        for progress in stride(from: CGFloat(0), through: 1.5, by: 0.1) {
            let h = RecipeHeroMetrics.collapsedHeaderHeight(
                expandedHeight: expanded,
                collapsedHeight: collapsed,
                collapseProgress: progress
            )
            #expect(h >= collapsed)
            #expect(h <= expanded)
        }
    }

    // Stretchは上限でクランプされ、極端な拡大にならない
    @Test("Stretchは上限でクランプされる")
    func stretchIsCapped() {
        let m = RecipeHeroMetrics.make(scrollOffset: -10_000, expandedHeight: expanded, collapsedHeight: collapsed, maxStretch: 160)
        #expect(m.stretchAmount == 160)
    }

    // 不正な高さ（負値・collapsed>expanded）でも破綻しない
    @Test("不正な高さでも破綻しない")
    func invalidHeightsAreSafe() {
        let negative = RecipeHeroMetrics.make(scrollOffset: 100, expandedHeight: -50, collapsedHeight: -10)
        #expect(negative.collapseProgress >= 0)
        #expect(negative.collapseProgress <= 1)

        let inverted = RecipeHeroMetrics.make(scrollOffset: 100, expandedHeight: 100, collapsedHeight: 500)
        #expect(inverted.collapseProgress >= 0)
        #expect(inverted.collapseProgress <= 1)
    }

    // Compact Title判定はヒステリシスで閾値付近の点滅を防ぐ
    @Test("Compact Title判定はヒステリシスで点滅しない")
    func compactTitleHysteresis() {
        // 非表示→上側閾値(0.9)を超えないと表示にならない
        #expect(RecipeHeroMetrics.compactTitleVisible(collapseProgress: 0.7, isCurrentlyCompact: false) == false)
        #expect(RecipeHeroMetrics.compactTitleVisible(collapseProgress: 0.95, isCurrentlyCompact: false) == true)
        // 表示中→下側閾値(0.6)を下回るまで表示を維持
        #expect(RecipeHeroMetrics.compactTitleVisible(collapseProgress: 0.7, isCurrentlyCompact: true) == true)
        #expect(RecipeHeroMetrics.compactTitleVisible(collapseProgress: 0.5, isCurrentlyCompact: true) == false)
    }
}
