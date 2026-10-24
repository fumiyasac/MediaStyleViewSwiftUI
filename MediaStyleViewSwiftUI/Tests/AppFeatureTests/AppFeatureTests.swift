//
//  AppFeatureTests.swift
//
//
//  Created by 酒井文也 on 2023/02/16.
//

// 月グリッド構成・イベントカテゴリ抽出・曜日/祝日の表示色・祝祭日判定の検証。
// Swift Testing へ移行済み（テストごとに値型Suiteが生成されるため共有可変状態を持たない）。

@testable import AppFeature
import Foundation
import SwiftUI
import Testing

// テスト用のGregorian Calendar（本体と同じ日曜始まり設定）。
// immutableなSendable値のためファイルスコープで共有しても並列実行で安全。
private let gregorianSundayFirst: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "ja_JP")
    calendar.firstWeekday = 1
    return calendar
}()

// MARK: - CalendarMonthGrid

@Suite("月グリッドの構成")
struct CalendarMonthGridTests {

    private let calendar = gregorianSundayFirst

    @Test("7列グリッドで10月は31日分のセルと先頭4つの空白を持つ")
    func monthGridHasSevenColumnsAndCorrectDays() throws {
        let base = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let grid = try #require(CalendarMonthGrid(baseMonth: base, offset: 0))

        #expect(grid.cells.count % 7 == 0)
        #expect(grid.cells.compactMap { $0 }.count == 31)
        #expect(grid.cells.prefix(4).filter { $0 == nil }.count == 4)
    }

    @Test("1月は年始フラグと年サフィックスを持つ")
    func januaryYearSuffix() throws {
        let base = try #require(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let january = try #require(CalendarMonthGrid(baseMonth: base, offset: 1))
        #expect(january.isYearStart)
        #expect(january.yearSuffixText != nil)
    }

    @Test("平年2月は28日分のセルを持ち7列グリッドとして成立する")
    func februaryNonLeapHas28Days() throws {
        let base = try #require(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let grid = try #require(CalendarMonthGrid(baseMonth: base, offset: 0))

        #expect(grid.cells.compactMap { $0 }.count == 28)
        #expect(grid.cells.count % 7 == 0)
    }

    @Test("うるう年2月は29日分のセルを持つ")
    func februaryLeapYearHas29Days() throws {
        let base = try #require(calendar.date(from: DateComponents(year: 2028, month: 2, day: 1)))
        let grid = try #require(CalendarMonthGrid(baseMonth: base, offset: 0))

        #expect(grid.cells.compactMap { $0 }.count == 29)
        #expect(grid.cells.count % 7 == 0)
    }

    @Test("1日が日曜の月は先頭に余白セルが入らず先頭セルが1日になる")
    func sundayStartMonthHasNoLeadingBlank() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        // 1日が日曜(weekday=1)の月を前方に探す
        var sundayStartGrid: CalendarMonthGrid?
        for offset in 0..<24 {
            let grid = try #require(CalendarMonthGrid(baseMonth: start, offset: offset))
            if calendar.component(.weekday, from: grid.monthStart) == 1 {
                sundayStartGrid = grid
                break
            }
        }

        let grid = try #require(sundayStartGrid)
        let firstCell = try #require(grid.cells.first)
        let firstDate = try #require(firstCell)
        #expect(CalendarDateUtil.isSameDay(firstDate, grid.monthStart))
    }
}

// MARK: - CalendarDateUtil.categories(on:in:)

@Suite("イベントカテゴリ抽出")
struct CalendarCategoryTests {

    private let calendar = gregorianSundayFirst

    @Test("本日のサンプルにはイベントが存在し、カテゴリ数が一致する")
    func fixtureHasEventsForToday() {
        let today = CalendarSampleData.days[0]
        #expect(!today.events.isEmpty)
        #expect(
            CalendarDateUtil.categories(on: today.date, in: CalendarSampleData.days).count == today.events.count
        )
    }

    @Test("注入したdaysから、その日のイベントが属するカテゴリ一覧を返す")
    func categoriesReturnInjectedDaysCategories() {
        let days = CalendarSampleData.days
        let today = days[0]
        #expect(CalendarDateUtil.categories(on: today.date, in: days) == today.events.map(\.category))
    }

    @Test("イベントが無い日付には空配列を返す")
    func categoriesReturnEmptyForDateWithoutEvents() throws {
        let days = CalendarSampleData.days
        let farFuture = try #require(calendar.date(byAdding: .year, value: 5, to: days[0].date))
        #expect(CalendarDateUtil.categories(on: farFuture, in: days).isEmpty)
    }
}

// MARK: - CalendarTheme.weekdayColor

@Suite("曜日・祝日の表示色")
struct CalendarThemeTests {

    @Test("日曜はアクセント赤になる")
    func weekdayColorSundayIsAccent() {
        #expect(
            CalendarTheme.weekdayColor(isSunday: true, isSaturday: false, default: .secondary) == CalendarTheme.accent
        )
    }

    @Test("土曜は土曜色（青）になる")
    func weekdayColorSaturdayIsSaturdayColor() {
        #expect(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: true, default: .secondary) == CalendarTheme.saturday
        )
    }

    @Test("平日は引数で渡した既定色をそのまま使う（一覧.secondary / 月セル.primaryの差を保つ）")
    func weekdayColorWeekdayUsesDefault() {
        #expect(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: false, default: Color.primary) == Color.primary
        )
        #expect(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: false, default: Color.secondary) == Color.secondary
        )
    }

    @Test("祝祭日は日曜と同じアクセント赤になる")
    func weekdayColorHolidayIsAccent() {
        #expect(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: false, isHoliday: true, default: .secondary) == CalendarTheme.accent
        )
    }
}

// MARK: - CalendarDateUtil.isHoliday

@Suite("祝祭日判定")
struct CalendarHolidayTests {

    private let calendar = gregorianSundayFirst

    // 祝祭日（元日・建国記念の日）と、祝日のない平日(2026/6/2 火曜)をまとめて検証する。
    @Test("指定日の祝祭日判定", arguments: [
        (2026, 1, 1, true),
        (2026, 2, 11, true),
        (2026, 6, 2, false),
    ])
    func isHoliday(year: Int, month: Int, day: Int, expected: Bool) throws {
        let date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        #expect(CalendarDateUtil.isHoliday(date) == expected)
    }
}
