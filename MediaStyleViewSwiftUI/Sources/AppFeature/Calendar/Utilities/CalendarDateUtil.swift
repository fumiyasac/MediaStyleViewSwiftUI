//
//  CalendarDateUtil.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 日付の表示判定。データソースは引数で受け取り、Fixture（CalendarSampleData）に依存させない。

import CalculateCalendarLogic
import Foundation

enum CalendarDateUtil {

    // MARK: - Property

    // 共有Calendarを参照する（個別生成しない）
    private static let calendar = CalendarFactory.shared

    // MARK: - Function

    // 日付の「日」成分（例: 19）
    static func dayNumber(of date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    // 本日かどうか
    static func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    // 日曜かどうか（曜日カラー切り替え用）
    static func isSunday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    // 土曜かどうか（曜日カラー切り替え用）
    static func isSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
    }

    // 日本の祝祭日かどうか。自作パッケージCalculateCalendarLogicに判定を委ねる。
    // CalculateCalendarLogicは状態を持たないstructで生成コストが無いため、都度生成して使う。
    static func isHoliday(_ date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return false
        }
        return CalculateCalendarLogic().judgeJapaneseHoliday(year: year, month: month, day: day)
    }

    // 2つの日付が同一日かどうか
    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    // 指定日にイベントを持つ場合、その日のイベントが属するカテゴリ一覧を返す。
    // データソースはFixtureに固定せず引数daysで受け取り、Root注入と同じ配列を使えるようにする。
    static func categories(on date: Date, in days: [CalendarDay]) -> [CalendarCategory] {
        days
            .first { calendar.isDate($0.date, inSameDayAs: date) }?
            .events.map(\.category) ?? []
    }
}
