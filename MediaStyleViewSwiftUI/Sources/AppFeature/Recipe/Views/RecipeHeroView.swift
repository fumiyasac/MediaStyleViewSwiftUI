//
//  RecipeHeroView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/25.
//

// Recipe Detailの背面に固定表示するHero。レシピの実写真(Asset Catalog, Bundle.module)を主役に置き、
// 画像が無いレシピはカテゴリ色グラデーション＋SF Symbolのプレースホルダーへフォールバックする。
// スクロール量(scrollOffset)からRecipeHeroMetricsでStretch/Parallaxを求め、背面固定Heroの
// フレーム高さ(Stretch)とオフセット(Parallax)で表現する（ScrollViewのレイアウトは動かさない）。
//
// 配置方針: このHeroはScrollViewの外側(ZStack背面)に固定し、不透明な本文がその上をスクロールして覆う。
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
        // PullDownは下方向へフレームを伸ばして隙間を埋める（背面固定なので本文は動かない）
        let stretch = reduceMotion ? 0 : metrics.stretchAmount
        // 上スクロール時は本文より緩やかに上へ逃がす（遅延）
        let parallaxShift = reduceMotion ? 0 : -(max(0, scrollOffset) * parallaxFactor)

        heroContent
            .frame(maxWidth: .infinity)
            .frame(height: expandedHeight + stretch, alignment: .top)
            .offset(y: parallaxShift)
            .clipped()
    }

    // MARK: - Private View

    @ViewBuilder
    private var heroContent: some View {
        if let uiImage = Self.loadImage(for: recipe.id) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                // 戻るボタン等の可読性のため、上部に控えめなスクリムを敷く
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [.black.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(recipe.title)（\(recipe.category.displayName)）の写真")
        } else {
            placeholder
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(recipe.title)（\(recipe.category.displayName)）の写真プレースホルダー")
        }
    }

    // 画像が無いレシピ向けのプレースホルダー（カテゴリ色グラデーション＋シンボル）
    private var placeholder: some View {
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
        }
    }

    // MARK: - Private Function

    // レシピIDに対応するHero画像をBundle.moduleのAsset Catalogから読み込む（無ければnil）。
    // ローカルアセットのため同期読み込みで十分（ネットワーク/非同期ロードは不要）。
    static func loadImage(for recipeID: RecipeID) -> UIImage? {
        UIImage(named: recipeID.rawValue, in: .module, with: nil)
    }

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
