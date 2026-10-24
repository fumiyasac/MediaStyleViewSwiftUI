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

    // この月の日別キー(DateKey)がとり得る閉区間（"yyyy-MM-01"..."yyyy-MM-31"）。
    // "yyyy-MM-dd"は辞書順＝日付順のため、月内の全日をこの範囲で捕捉できる（Feb等も問題なし）。
    var dateKeyRange: ClosedRange<DateKey> {
        DateKey(value: "\(value)-01")...DateKey(value: "\(value)-31")
    }

    // MARK: - Comparable

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.value < rhs.value
    }
}
