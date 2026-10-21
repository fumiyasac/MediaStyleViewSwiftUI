//
//  AppFeatureTests.swift
//
//
//  Created by 酒井文也 on 2023/02/16.
//

@testable import AppFeature
import Foundation
import SwiftUI
import XCTest

final class AppFeatureTests: XCTestCase {

    // テスト用のCalendar（本体と同じ日曜始まり設定）
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1
        return calendar
    }

    // MARK: - CalendarMonthGrid

    func testMonthGridHasSevenColumnsAndCorrectDays() throws {
        let base = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let grid = try XCTUnwrap(CalendarMonthGrid(baseMonth: base, offset: 0))

        XCTAssertEqual(grid.cells.count % 7, 0)
        XCTAssertEqual(grid.cells.compactMap { $0 }.count, 31)
        XCTAssertEqual(grid.cells.prefix(4).filter { $0 == nil }.count, 4)
    }

    func testJanuaryYearSuffix() throws {
        let base = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 1)))
        let january = try XCTUnwrap(CalendarMonthGrid(baseMonth: base, offset: 1))
        XCTAssertTrue(january.isYearStart)
        XCTAssertNotNil(january.yearSuffixText)
    }

    // 平年2月は28日分のセルを持ち、7列グリッドとして成立する
    func testFebruaryNonLeapHas28Days() throws {
        let base = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        let grid = try XCTUnwrap(CalendarMonthGrid(baseMonth: base, offset: 0))

        XCTAssertEqual(grid.cells.compactMap { $0 }.count, 28)
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    // うるう年2月は29日分のセルを持つ
    func testFebruaryLeapYearHas29Days() throws {
        let base = try XCTUnwrap(calendar.date(from: DateComponents(year: 2028, month: 2, day: 1)))
        let grid = try XCTUnwrap(CalendarMonthGrid(baseMonth: base, offset: 0))

        XCTAssertEqual(grid.cells.compactMap { $0 }.count, 29)
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    // 1日が日曜の月は先頭に余白セルが入らず、先頭セルが1日になる
    func testSundayStartMonthHasNoLeadingBlank() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        // 1日が日曜(weekday=1)の月を前方に探す
        var sundayStartGrid: CalendarMonthGrid?
        for offset in 0..<24 {
            let grid = try XCTUnwrap(CalendarMonthGrid(baseMonth: start, offset: offset))
            if calendar.component(.weekday, from: grid.monthStart) == 1 {
                sundayStartGrid = grid
                break
            }
        }

        let grid = try XCTUnwrap(sundayStartGrid)
        let firstCell = try XCTUnwrap(grid.cells.first)
        let firstDate = try XCTUnwrap(firstCell)
        XCTAssertTrue(CalendarDateUtil.isSameDay(firstDate, grid.monthStart))
    }

    // MARK: - CalendarDateUtil.categories(on:in:)

    func testFixtureHasEventsForToday() {
        let today = CalendarSampleData.days[0]
        XCTAssertFalse(today.events.isEmpty)
        XCTAssertEqual(
            CalendarDateUtil.categories(on: today.date, in: CalendarSampleData.days).count,
            today.events.count
        )
    }

    // 注入したdaysから、その日のイベントが属するカテゴリ一覧を返す
    func testCategoriesReturnInjectedDaysCategories() {
        let days = CalendarSampleData.days
        let today = days[0]
        XCTAssertEqual(
            CalendarDateUtil.categories(on: today.date, in: days),
            today.events.map(\.category)
        )
    }

    // イベントが無い日付には空配列を返す
    func testCategoriesReturnEmptyForDateWithoutEvents() throws {
        let days = CalendarSampleData.days
        let farFuture = try XCTUnwrap(calendar.date(byAdding: .year, value: 5, to: days[0].date))
        XCTAssertTrue(CalendarDateUtil.categories(on: farFuture, in: days).isEmpty)
    }

    // MARK: - CalendarTheme.weekdayColor

    // 日曜はアクセント赤になる
    func testWeekdayColorSundayIsAccent() {
        XCTAssertEqual(
            CalendarTheme.weekdayColor(isSunday: true, isSaturday: false, default: .secondary),
            CalendarTheme.accent
        )
    }

    // 土曜は土曜色（青）になる
    func testWeekdayColorSaturdayIsSaturdayColor() {
        XCTAssertEqual(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: true, default: .secondary),
            CalendarTheme.saturday
        )
    }

    // 平日は引数で渡した既定色をそのまま使う（一覧.secondary / 月セル.primaryの差を保つ）
    func testWeekdayColorWeekdayUsesDefault() {
        XCTAssertEqual(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: false, default: Color.primary),
            Color.primary
        )
        XCTAssertEqual(
            CalendarTheme.weekdayColor(isSunday: false, isSaturday: false, default: Color.secondary),
            Color.secondary
        )
    }

    // 祝祭日は日曜と同じアクセント赤になる
    func testWeekdayColorHolidayIsAccent() {
        XCTAssertEqual(
            CalendarTheme.weekdayColor(
                isSunday: false, isSaturday: false, isHoliday: true, default: .secondary
            ),
            CalendarTheme.accent
        )
    }

    // MARK: - CalendarDateUtil.isHoliday

    // 元日（1/1）は祝祭日と判定される
    func testIsHolidayForNewYearsDay() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        XCTAssertTrue(CalendarDateUtil.isHoliday(date))
    }

    // 建国記念の日（2/11）は祝祭日と判定される
    func testIsHolidayForNationalFoundationDay() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 11)))
        XCTAssertTrue(CalendarDateUtil.isHoliday(date))
    }

    // 祝祭日の無い平日は祝祭日と判定されない（2026/6/2は火曜で祝日なし）
    func testIsHolidayFalseForOrdinaryWeekday() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)))
        XCTAssertFalse(CalendarDateUtil.isHoliday(date))
    }
}
