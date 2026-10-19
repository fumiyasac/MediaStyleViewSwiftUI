//
//  CalendarDateUtil.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 日付の表示判定。データソースは受け取り、Fixtureに依存させない。

import Foundation

enum CalendarDateUtil {

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    static func dayNumber(of date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    static func isSunday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    static func isSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
    }

    // その月に属する日か（他月の余白セルと区別）
    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    // サンプルデータ上でイベントを持つ日か判定し、該当イベントのカテゴリ色を返す
    static func categories(on date: Date) -> [CalendarCategory] {
        CalendarSampleData.days
            .first { calendar.isDate($0.date, inSameDayAs: date) }?
            .events.map(\.category) ?? []
    }
}
