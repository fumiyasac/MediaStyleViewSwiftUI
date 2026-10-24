//
//  RecipeHeroView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/25.
//

// Recipe Detailの背面に固定表示するHero。実画像は未提供のため、カテゴリ色のグラデーション＋
// SF Symbolをプレースホルダーとして主役に置く。スクロール量(scrollOffset)から
// RecipeHeroMetricsでStretch/Parallaxパラメータを求め、描画変換のみで表現する（レイアウトは不変）。
//
// 配置方針: このHeroはScrollViewの外側(ZStack背面)に固定し、不透明な本文がその上をスクロールする。
// これにより下方向の重なりや上方向の隙間が生じず、Hero領域はコンテンツに自然に覆われる。
//
// Reduce Motion有効時はStretch/Parallaxを無効化し、静的なHeroとして表示する。

import SwiftUI

struct RecipeHeroView: View {

    // MARK: - Property

    let recipe: Recipe
    // 先頭からのスクロール量（正=上スクロール/負=PullDown）
    let scrollOffset: CGFloat
    // 展開時のHero高さ
    let expandedHeight: CGFloat
    // Reduce Motion（有効時はStretch/Parallaxを抑制）
    let reduceMotion: Bool
    // 上スクロール量に対するParallax遅延の割合
    private let parallaxFactor: CGFloat = 0.35

    // MARK: - Body

    var body: some View {
        let metrics = RecipeHeroMetrics.make(
            scrollOffset: scrollOffset,
            expandedHeight: expandedHeight,
            parallaxFactor: parallaxFactor
        )
        // PullDownは下端を基準に上方向へ拡大（overscrollの隙間を埋める）
        let stretchScale = reduceMotion ? 1 : (expandedHeight + metrics.stretchAmount) / expandedHeight
        // 上スクロール時は本文より緩やかに上へ逃がす（遅延）
        let parallaxShift = reduceMotion ? 0 : -(max(0, scrollOffset) * parallaxFactor)

        heroContent
            .frame(maxWidth: .infinity)
            .frame(height: expandedHeight)
            .scaleEffect(stretchScale, anchor: .top)
            .offset(y: parallaxShift)
            .clipped()
    }

    // MARK: - Private View

    private var heroContent: some View {
        let base = Self.heroColor(for: recipe.category)
        return ZStack {
            LinearGradient(
                colors: [base.opacity(0.95), base.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: recipe.category.symbolName)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                // シンボルはグラデーションよりさらに緩やかにParallaxさせ、奥行きを出す
                .offset(y: reduceMotion ? 0 : -(max(0, scrollOffset) * parallaxFactor * 0.4))
        }
        // VoiceOver: 実写ではないため「写真プレースホルダー」と明示（装飾ではなく内容説明）
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipe.title)（\(recipe.category.displayName)）の写真プレースホルダー")
    }

    // MARK: - Private Function

    // カテゴリ別のプレースホルダー色（DomainをSwiftUIへ結合させないためView側でマップ）
    static func heroColor(for category: RecipeCategory) -> Color {
        switch category {
        case .japanese: return Color(red: 0.90, green: 0.45, blue: 0.35)
        case .western: return Color(red: 0.85, green: 0.55, blue: 0.25)
        case .chinese: return Color(red: 0.80, green: 0.30, blue: 0.30)
        case .italian: return Color(red: 0.40, green: 0.65, blue: 0.45)
        case .dessert: return Color(red: 0.85, green: 0.45, blue: 0.65)
        case .healthy: return Color(red: 0.40, green: 0.70, blue: 0.55)
        }
    }
}
