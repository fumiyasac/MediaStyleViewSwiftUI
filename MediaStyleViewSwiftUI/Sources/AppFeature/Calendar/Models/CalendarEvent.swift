//
//  CalendarEvent.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/19.
//

// Apple標準カレンダーアプリの「一覧（リスト）表示」再現用モデル

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

    // MARK: - Property

    let id = UUID()
    let title: String
    let location: String?
    let category: CalendarCategory
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool

    // DateFormatterは生成コストが高いのでstaticで使い回す（計算プロパティ毎の再生成を避ける）
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    // 開始時刻の表示文字列（例: 9:00）
    var startTimeText: String {
        Self.timeFormatter.string(from: startDate)
    }

    // 終了時刻の表示文字列（例: 10:30）
    var endTimeText: String {
        Self.timeFormatter.string(from: endDate)
    }
}

// MARK: - 日付ごとにまとめたイベント群（一覧表示のセクション単位）

struct CalendarDay: Identifiable {

    // MARK: - Property

    let id = UUID()
    let date: Date
    let events: [CalendarEvent]

    // 共有Calendarを参照する（個別生成しない）
    private static let calendar = CalendarFactory.shared

    // 曜日・日にち表示のDateFormatterも使い回す（詳細はtimeFormatterと同じ理由）
    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "d"
        return formatter
    }()

    // 曜日（例: 金）
    var weekdayText: String {
        Self.weekdayFormatter.string(from: date)
    }

    // 日にち（例: 19）
    var dayText: String {
        Self.dayFormatter.string(from: date)
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
