//
//  RecipeDetailSnapshotTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// Recipe DetailのVisual Regression。非同期ロードやスクロール連動（Parallax/Collapse）は対象にせず、
// 実コンポーネントを固定データで同期描画する:
//  - RecipeDetailContent: 本文カード（分類/タイトル/概要/メタ/材料/手順/調理記録/追加ボタン）
//  - RecipeHeroView: 初期状態(scrollOffset=0)のHero（バンドル画像）
// Zoom遷移やアニメーションの滑らかさはSimulatorの手動確認で担保する。

@testable import AppFeature
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("Recipe DetailのSnapshot")
struct RecipeDetailSnapshotTests {

    // 本文カード（スクロールの中身。全高を撮るためsizeThatFits）
    @Test("本文カード（材料・手順・調理記録 / Light）")
    func detailContentLight() {
        let view = RecipeDetailContent(
            recipe: SnapshotFixture.detailRecipe(),
            mealLogs: SnapshotFixture.detailMealLogs(),
            onAddTap: {}
        )
        .frame(width: 390)
        .background(Color(.systemBackground))

        assertSnapshot(
            of: view,
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .sizeThatFits,
                traits: SnapshotConfig.light
            )
        )
    }

    // 本文カード（Dark Mode）。配色対応の回帰検出用（追加ケース）
    @Test("本文カード（Dark）")
    func detailContentDark() {
        let view = RecipeDetailContent(
            recipe: SnapshotFixture.detailRecipe(),
            mealLogs: SnapshotFixture.detailMealLogs(),
            onAddTap: {}
        )
        .frame(width: 390)
        .background(Color(.systemBackground))

        assertSnapshot(
            of: view,
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .sizeThatFits,
                traits: SnapshotConfig.dark
            )
        )
    }

    // Hero（初期状態）。Reduce Motion相当でStretch/Parallaxを無効化した静的表示を撮る
    @Test("Hero初期表示（バンドル画像 / Light）")
    func heroInitialLight() {
        let view = RecipeHeroView(
            recipe: SnapshotFixture.detailRecipe(),
            scrollOffset: 0,
            expandedHeight: 320,
            reduceMotion: true
        )
        .frame(width: 390, height: 320)

        assertSnapshot(
            of: view,
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .sizeThatFits,
                traits: SnapshotConfig.light
            )
        )
    }
}
