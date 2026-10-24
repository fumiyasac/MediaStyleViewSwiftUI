//
//  CalendarDayViewDataTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// CalendarDayViewDataFactoryの変換テスト（掲載日/調理日判定・境界条件・TimeZone）。
// Swift Testing へ移行済み。

@testable import AppFeature
import Foundation
import Testing

@Suite("カレンダー日セルの表示データ変換")
struct CalendarDayViewDataTests {

    private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
    private let utc = DateKeyCalendar.make(timeZone: TimeZone(identifier: "UTC")!)
    private let factory = CalendarDayViewDataFactory(calendar: DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!))

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        tokyo.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func entry(_ dateKey: String) -> DailyRecipeEntry {
        DailyRecipeEntry(id: DailyRecipeEntryID("daily-\(dateKey)"), dateKey: DateKey(value: dateKey), recipeID: RecipeID("recipe-01"))
    }

    private func mealLog(_ dateKey: String) -> MealLogSummary {
        MealLogSummary(id: MealLogID(), recipeID: RecipeID("recipe-01"), dateKey: DateKey(value: dateKey), cookedAt: date(2026, 3, 1), rating: 4, memo: "", servings: 1)
    }

    // 月ごとStateを組み立てるヘルパー
    private func state(monthKey: String, entries: [DailyRecipeEntry] = [], logs: [MealLogSummary] = [], selected: Date) -> CalendarFeatureState {
        var s = CalendarFeatureState.initial(referenceDate: selected)
        s.months[MonthKey(value: monthKey)] = CalendarMonthLoad(recipeEntries: entries, mealLogs: logs, phase: .loaded, requestID: nil)
        return s
    }

    // 11. レシピ掲載日を正しく判定できる
    @Test("レシピ掲載日を正しく判定できる")
    func hasRecipe() {
        let target = date(2026, 3, 10)
        let s = state(monthKey: "2026-03", entries: [entry("2026-03-10")], selected: target)
        let vd = factory.make(date: target, state: s, events: [])
        #expect(vd.hasRecipe)
        #expect(!vd.hasMealLog)
    }

    // 12. 調理記録の存在日を正しく判定できる
    @Test("調理記録の存在日を正しく判定できる")
    func hasMealLog() {
        let target = date(2026, 3, 10)
        let s = state(monthKey: "2026-03", logs: [mealLog("2026-03-10")], selected: target)
        let vd = factory.make(date: target, state: s, events: [])
        #expect(vd.hasMealLog)
        #expect(!vd.hasRecipe)
    }

    // 13. 掲載日と調理日が異なる場合も正しく処理できる
    @Test("掲載日と調理日が異なる場合も正しく処理できる")
    func recipeAndMealLogOnDifferentDays() {
        let s = state(monthKey: "2026-03", entries: [entry("2026-03-05")], logs: [mealLog("2026-03-20")], selected: date(2026, 3, 1))

        let recipeDay = factory.make(date: date(2026, 3, 5), state: s, events: [])
        #expect(recipeDay.hasRecipe)
        #expect(!recipeDay.hasMealLog)

        let mealLogDay = factory.make(date: date(2026, 3, 20), state: s, events: [])
        #expect(!mealLogDay.hasRecipe)
        #expect(mealLogDay.hasMealLog)
    }

    // 14. Recipeが0件でもViewDataを生成できる
    @Test("Recipeが0件でもViewDataを生成できる")
    func emptyStateProducesViewData() {
        let target = date(2026, 3, 10)
        let vd = factory.make(date: target, state: .initial(referenceDate: target), events: [])
        #expect(!vd.hasRecipe)
        #expect(!vd.hasMealLog)
        #expect(vd.dayNumber == 10)
    }

    // 15. 複数Recipeが同じ日に割り当てられても破綻しない
    @Test("複数Recipeが同じ日に割り当てられても破綻しない")
    func multipleRecipesSameDay() {
        let target = date(2026, 3, 10)
        let s = state(monthKey: "2026-03", entries: [entry("2026-03-10"), entry("2026-03-10")], selected: target)
        let vd = factory.make(date: target, state: s, events: [])
        #expect(vd.hasRecipe)
    }

    // 16. 同日に複数MealLogが存在しても正しく判定できる
    @Test("同日に複数MealLogが存在しても正しく判定できる")
    func multipleMealLogsSameDay() {
        let target = date(2026, 3, 10)
        let s = state(monthKey: "2026-03", logs: [mealLog("2026-03-10"), mealLog("2026-03-10")], selected: target)
        let vd = factory.make(date: target, state: s, events: [])
        #expect(vd.hasMealLog)
    }

    // 17. 月末・月初と年跨ぎを処理できる
    @Test("月末・月初と年跨ぎを処理できる")
    func monthBoundaryAndYearCrossing() {
        // 2026-12-31 と 2027-01-01 でそれぞれ別のMonthKeyを引く
        let decState = state(monthKey: "2026-12", entries: [entry("2026-12-31")], selected: date(2026, 12, 31))
        let dec31 = factory.make(date: date(2026, 12, 31), state: decState, events: [])
        #expect(dec31.hasRecipe)

        let janState = state(monthKey: "2027-01", entries: [entry("2027-01-01")], selected: date(2027, 1, 1))
        let jan1 = factory.make(date: date(2027, 1, 1), state: janState, events: [])
        #expect(jan1.hasRecipe)

        // 12月のStateで1月を引いても誤検知しない（別MonthKey）
        let jan1WithDecState = factory.make(date: date(2027, 1, 1), state: decState, events: [])
        #expect(!jan1WithDecState.hasRecipe)
    }

    // 18. Calendar/TimeZoneの境界条件。同一instantでもTZで属する暦日が変わる
    @Test("Calendar/TimeZoneの境界条件で属する暦日が変わる")
    func timeZoneBoundary() {
        // UTC 2026-03-09 15:00 は JSTでは 2026-03-10
        let instant = utc.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 15))!
        let s = state(monthKey: "2026-03", entries: [entry("2026-03-10")], selected: instant)

        // JST基準のFactoryでは 2026-03-10 と解釈し、掲載ありと判定できる
        let jstFactory = CalendarDayViewDataFactory(calendar: tokyo)
        #expect(jstFactory.make(date: instant, state: s, events: []).hasRecipe)

        // UTC基準のFactoryでは 2026-03-09 と解釈するため掲載なし
        let utcFactory = CalendarDayViewDataFactory(calendar: utc)
        #expect(!utcFactory.make(date: instant, state: s, events: []).hasRecipe)
    }

    // 選択状態・今日判定が反映される
    @Test("選択状態が反映される")
    func selectionFlag() {
        let target = date(2026, 3, 10)
        let s = state(monthKey: "2026-03", selected: target)
        #expect(factory.make(date: target, state: s, events: []).isSelected)
        #expect(!factory.make(date: date(2026, 3, 11), state: s, events: []).isSelected)
    }
}
