//
//  MonthKey.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 月を一意に表すキー（"yyyy-MM"）。月ごとの読み込み状態・キャッシュのDictionaryキーとDateKeyの
// 月判定に使う。DateKeyと同じくCalendar(TimeZone内包)から生成し、Fixture/SwiftData側の日付キーと
// 解釈がズレないよう一元化する（既定はDateKeyCalendar=Asia/Tokyo）。

import Foundation

struct MonthKey: Hashable, Sendable, Comparable, CustomStringConvertible {

    // MARK: - Property

    // "yyyy-MM"。辞書順＝月順のため比較・ソートに使える
    let value: String

    var description: String { value }

    // MARK: - Initializer

    init(value: String) {
        self.value = value
    }

    // Dateと、TimeZoneを内包したCalendarから月キーを生成する
    init(date: Date, calendar: Calendar = DateKeyCalendar.default) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.value = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    // MARK: - Derived

    // この月の日別キー(DateKey)がとり得る閉区間（"yyyy-MM-01"..."yyyy-MM-<末日>"）。
    // 末日はその月の実際の日数(28/29/30/31)にする。
    // 以前は末尾を常に "-31" にしていたが、Remote(Go API)の /calendar?to= は実在日付を要求するため、
    // 11月などに "2026-11-31" を渡すと 400 になる。実在する末日を使うことでFixture/Remote双方で正しく動く。
    var dateKeyRange: ClosedRange<DateKey> {
        let last = Self.lastDay(ofMonth: value)
        return DateKey(value: "\(value)-01")...DateKey(value: String(format: "%@-%02d", value, last))
    }

    // "yyyy-MM" からその月の末日(28/29/30/31)を求める。閏年もグレゴリオ暦で正しく扱う。
    // 日数計算のみでTimeZoneに依存しないため、固定のグレゴリオ暦を使う。
    private static func lastDay(ofMonth value: String) -> Int {
        let parts = value.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            return 31
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    // MARK: - Comparable

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.value < rhs.value
    }
}
