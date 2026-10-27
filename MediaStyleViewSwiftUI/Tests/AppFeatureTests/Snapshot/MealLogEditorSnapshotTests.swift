//
//  MealLogEditorSnapshotTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// MealLog EditorのVisual Regression。入力フォーム（調理日/評価/メモ）の通常表示を固定値で描画する。
// 保存の非同期処理やSwiftData永続化は対象外（InMemory Repositoryを注入するが描画では使わない）。
// 調理日はcompact DatePickerで固定日付を表示するため「今日」依存はない。

@testable import AppFeature
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("MealLog EditorのSnapshot")
struct MealLogEditorSnapshotTests {

    @Test("入力フォーム（調理日・評価・メモ / Light）")
    func editorFormLight() {
        let view = MealLogEditorSheet(
            recipeID: RecipeID("recipe-07"),
            recipeTitle: SnapshotFixture.detailRecipe().title,
            defaultCookedAt: SnapshotFixture.date(2024, 6, 15, 12),
            repository: InMemoryMealLogRepository(calendar: SnapshotFixture.calendar),
            onSaved: { _ in }
        )

        assertSnapshot(
            of: view,
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .device(config: SnapshotConfig.device),
                traits: SnapshotConfig.light
            )
        )
    }
}
