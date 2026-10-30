//
//  MonthKeyTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// MonthKeyの日付範囲(dateKeyRange)の検証。末日が実在日付(28/29/30/31)になることを確認する。
// Remote(Go API)の /calendar?to= は実在日付を要求するため、11月に "-31" を渡さないことが重要。

@testable import AppFeature
import Foundation
import Testing

@Suite("MonthKey: 月範囲の末日")
struct MonthKeyTests {

    @Test("30日の月は末日が30(存在しない-31にしない)")
    func thirtyDayMonth() {
        let range = MonthKey(value: "2026-11").dateKeyRange
        #expect(range.lowerBound == DateKey(value: "2026-11-01"))
        #expect(range.upperBound == DateKey(value: "2026-11-30"))
    }

    @Test("31日の月は末日が31")
    func thirtyOneDayMonth() {
        #expect(MonthKey(value: "2026-10").dateKeyRange.upperBound == DateKey(value: "2026-10-31"))
    }

    @Test("平年2月は末日が28")
    func februaryCommonYear() {
        #expect(MonthKey(value: "2026-02").dateKeyRange.upperBound == DateKey(value: "2026-02-28"))
    }

    @Test("閏年2月は末日が29")
    func februaryLeapYear() {
        #expect(MonthKey(value: "2028-02").dateKeyRange.upperBound == DateKey(value: "2028-02-29"))
    }
}
