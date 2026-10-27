//
//  SnapshotFixtureFactory.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// Snapshotテスト用の決定的なFixture。現在日時・乱数・実行環境に依存しない固定値のみを使う。
// SwiftDataストアやRepository通信は発生させず、SendableなDomain Model / ViewDataだけを組み立てる。
// 既存のRecipeFixtureDataの固定レシピ（固定タイトル・材料・手順・バンドル画像）を再利用する。

@testable import AppFeature
import Foundation

enum SnapshotFixture {

    // 固定Calendar（Asia/Tokyo）と固定基準日。
    // 「今日」ハイライト(CalendarDateUtil.isToday=実日付依存)が入らないよう、過去の月(2024年6月)を基準にして
    // Snapshotを決定的にする（過去日は永遠に「今日」にならない）。選択リングは選択日で制御する。
    static let calendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
    static let referenceDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!

    // MARK: - 基本要素

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // 既存Fixtureの固定レシピ（画像はAsset Catalogのバンドル画像）
    static func recipe(_ id: String) -> Recipe {
        RecipeFixtureData.recipes.first { $0.id == RecipeID(id) }!
    }

    static func entry(_ dateKey: String, _ recipe: String) -> DailyRecipeEntry {
        DailyRecipeEntry(
            id: DailyRecipeEntryID("daily-\(dateKey)-\(recipe)"),
            dateKey: DateKey(value: dateKey),
            recipeID: RecipeID(recipe)
        )
    }

    static func mealLog(
        _ dateKey: String,
        _ recipe: String,
        cookedAt: Date,
        rating: Int,
        memo: String,
        servings: Int = 2
    ) -> MealLogSummary {
        MealLogSummary(
            id: MealLogID(),
            recipeID: RecipeID(recipe),
            dateKey: DateKey(value: dateKey),
            cookedAt: cookedAt,
            rating: rating,
            memo: memo,
            servings: servings
        )
    }

    // MARK: - Calendar

    // 2026年10月の月グリッド
    static func octoberGrid() -> CalendarMonthGrid {
        let base = CalendarMonthGrid.startOfMonth(for: referenceDate)
        return CalendarMonthGrid(baseMonth: base, offset: 0)!
    }

    // 掲載レシピマーカー複数＋調理記録マーカー1件を持つ2024年6月のState（選択リングは6/15）
    static func calendarState() -> CalendarFeatureState {
        var state = CalendarFeatureState.initial(referenceDate: referenceDate)
        state.months[MonthKey(value: "2024-06")] = CalendarMonthLoad(
            recipeEntries: [
                entry("2024-06-05", "recipe-01"),
                entry("2024-06-15", "recipe-07"),
                entry("2024-06-22", "recipe-05"),
                entry("2024-06-28", "recipe-11"),
            ],
            mealLogs: [
                mealLog("2024-06-15", "recipe-05", cookedAt: date(2024, 6, 15, 19), rating: 4, memo: "")
            ],
            phase: .loaded,
            requestID: nil
        )
        return state
    }

    // MARK: - Timeline

    // レシピ掲載と調理記録が混在する固定Payload
    static func timelinePayload() -> TimelinePayload {
        TimelinePayload(
            dailyEntries: [
                entry("2024-06-22", "recipe-07"),
                entry("2024-06-21", "recipe-05"),
            ],
            mealLogs: [
                mealLog("2024-06-22", "recipe-07", cookedAt: date(2024, 6, 22, 20), rating: 5, memo: "外はカリッと中はもちもち")
            ],
            recipes: [recipe("recipe-07"), recipe("recipe-05")]
        )
    }

    // MARK: - Recipe Detail

    // 詳細のサンプルレシピ（マルゲリータ＝画像あり・材料/手順あり）とその調理記録
    static func detailRecipe() -> Recipe { recipe("recipe-07") }
    static func detailMealLogs() -> [MealLogSummary] {
        [
            mealLog("2024-06-22", "recipe-07", cookedAt: date(2024, 6, 22, 20), rating: 5, memo: "外はカリッと中はもちもち"),
            mealLog("2024-06-15", "recipe-07", cookedAt: date(2024, 6, 15, 19), rating: 4, memo: "チーズ増量が正解"),
        ]
    }
}
