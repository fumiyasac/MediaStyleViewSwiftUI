//
//  CalendarDayViewData.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 1日分のセル表示専用の値型。CalendarDayCellViewがDomain ModelやState/Repositoryの
// 内部構造を知らずに描画できるよう、表示に必要な判定結果だけをフラットに持つ。
// Calendarの責務はRecipeとMealLogに一本化したため、旧イベント（work/health等）のカテゴリは持たない。
//
// 注意:
//  - hasRecipe: その日に「レシピ掲載がある」か（DailyRecipeEntry.dateKey一致）
//  - hasMealLog: その日に「調理記録が存在する」か（MealLogSummary.dateKey一致）
//    ※掲載レシピを実際に作ったかどうかではなく、調理記録の有無を表す
//  - 掲載日と調理日は別物なので別フラグにしている

import Foundation

// MARK: - CalendarDayViewData

struct CalendarDayViewData: Sendable, Equatable {

    // MARK: - Property

    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let isSunday: Bool
    let isSaturday: Bool
    let isHoliday: Bool
    // レシピ掲載日マーカー
    let hasRecipe: Bool
    // 調理記録マーカー
    let hasMealLog: Bool
}

// MARK: - CalendarDayViewDataFactory

// State(月ごとのRecipe/MealLog)から、セル表示用の値型を組み立てるPresentation層のFactory。
// 日付キーの導出はCalendar(TimeZone内包)を一元化して行い、Fixture/SwiftData側のキーと突き合わせる。
struct CalendarDayViewDataFactory {

    // MARK: - Property

    // 日付キー/月キーの導出に使うCalendar（データ生成側と揃える）
    private let calendar: Calendar

    // MARK: - Initializer

    init(calendar: Calendar = DateKeyCalendar.default) {
        self.calendar = calendar
    }

    // MARK: - Function

    // 指定日のセル表示データを組み立てる。
    // - state: 月ごとのRecipe/MealLog読込結果と選択中日付
    func make(
        date: Date,
        state: CalendarFeatureState
    ) -> CalendarDayViewData {
        let dateKey = DateKey(date: date, calendar: calendar)
        let monthKey = MonthKey(date: date, calendar: calendar)
        let load = state.monthLoad(monthKey)

        return CalendarDayViewData(
            date: date,
            dayNumber: CalendarDateUtil.dayNumber(of: date),
            isToday: CalendarDateUtil.isToday(date),
            isSelected: CalendarDateUtil.isSameDay(date, state.selectedDate),
            isSunday: CalendarDateUtil.isSunday(date),
            isSaturday: CalendarDateUtil.isSaturday(date),
            isHoliday: CalendarDateUtil.isHoliday(date),
            hasRecipe: load.recipeEntries.contains { $0.dateKey == dateKey },
            hasMealLog: load.mealLogs.contains { $0.dateKey == dateKey }
        )
    }
}
