//
//  CalendarEvent.swift
//  MediaStyleViewSwiftUI
//
//  Apple標準カレンダーアプリの「一覧（リスト）表示」再現用モデル
//

import SwiftUI

// MARK: - カレンダー種別（イベントに紐づく色付きカテゴリ）

enum CalendarCategory: String, CaseIterable {
    case work = "仕事"
    case personal = "プライベート"
    case family = "家族"
    case health = "健康"
    case holiday = "祝日"

    // Apple純正カレンダーに近しいカテゴリカラー
    var color: Color {
        switch self {
        case .work: return Color(red: 0.20, green: 0.48, blue: 0.96) // ブルー
        case .personal: return Color(red: 0.35, green: 0.78, blue: 0.35) // グリーン
        case .family: return Color(red: 0.98, green: 0.58, blue: 0.20) // オレンジ
        case .health: return Color(red: 0.90, green: 0.26, blue: 0.42) // ピンク
        case .holiday: return Color(red: 0.62, green: 0.40, blue: 0.90) // パープル
        }
    }
}

// MARK: - 1件のイベント

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let location: String?
    let category: CalendarCategory
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    // 開始時刻の表示文字列（例: 9:00）
    var startTimeText: String {
        Self.timeFormatter.string(from: startDate)
    }

    // 終了時刻の表示文字列（例: 10:30）
    var endTimeText: String {
        Self.timeFormatter.string(from: endDate)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()
}

// MARK: - 日付ごとにまとめたイベント群（一覧表示のセクション単位）

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let events: [CalendarEvent]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    // 曜日（例: 金）
    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // 日にち（例: 19）
    var dayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    // 本日かどうか
    var isToday: Bool {
        Self.calendar.isDateInToday(date)
    }

    // 土曜・日曜かどうか（曜日カラー切り替え用）
    var isSaturday: Bool {
        Self.calendar.component(.weekday, from: date) == 7
    }

    var isSunday: Bool {
        Self.calendar.component(.weekday, from: date) == 1
    }
}
