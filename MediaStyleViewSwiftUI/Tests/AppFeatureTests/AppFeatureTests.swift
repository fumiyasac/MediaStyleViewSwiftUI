//
//  AppFeatureTests.swift
//  
//
//  Created by 酒井文也 on 2023/02/16.
//

@testable import AppFeature
import Foundation
import XCTest

final class AppFeatureTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1
        return calendar
    }

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

    func testFixtureHasEventsForToday() {
        let today = CalendarSampleData.days[0]
        XCTAssertFalse(today.events.isEmpty)
        XCTAssertEqual(
            CalendarDateUtil.categories(on: today.date).count,
            today.events.count
        )
    }
}
