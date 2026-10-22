//
//  DateKey.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 「yyyy-MM-dd」で日付を一意に表す値型。Date(絶対時刻)ではなく暦日でレシピや調理ログを
// 束ねるためのキー。どの暦日に属するかはTimeZoneに依存するため、生成に使うCalendarを
// 明示的に受け取り、端末TZの違いでキーがズレないようにする（CalendarとTimeZoneの影響を考慮）。

import Foundation

// MARK: - DateKey

struct DateKey: Hashable, Sendable, Comparable, CustomStringConvertible {

    // MARK: - Property

    // "yyyy-MM-dd" 形式の文字列。辞書順と日付順が一致するため比較・ソートに使える
    let value: String

    var description: String { value }

    // MARK: - Initializer

    // 文字列から直接生成する（Fixtureや永続化キーの復元用）
    init(value: String) {
        self.value = value
    }

    // Dateと、TimeZoneを内包したCalendarから暦日キーを生成する。
    // DateFormatterのlocale依存を避けるため、年月日成分をゼロ埋めして組み立てる。
    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.value = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    // MARK: - Comparable

    static func < (lhs: DateKey, rhs: DateKey) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - DateKeyCalendar

// 日付キー生成に使うCalendarを集約する。端末TZに左右されないよう、既定はAsia/Tokyoに固定する。
// 必要に応じてTimeZoneを注入でき、テストや他地域対応時に差し替えられる。
enum DateKeyCalendar {

    // 既定の基準TimeZone（日本のレシピアプリ想定でJSTに固定）
    static let defaultTimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    // 日付成分の抽出だけに使うため、locale非依存なグレゴリオ暦を組み立てる
    static func make(timeZone: TimeZone = defaultTimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        return calendar
    }

    // 既定TimeZoneのCalendar（使い回し用）
    static let `default`: Calendar = make()
}
