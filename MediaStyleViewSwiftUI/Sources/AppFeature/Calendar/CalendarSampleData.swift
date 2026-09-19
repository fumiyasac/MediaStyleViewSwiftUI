//
//  CalendarSampleData.swift
//  MediaStyleViewSwiftUI
//
//  一覧表示画面のプレビュー用ダミーデータ
//

import Foundation

enum CalendarSampleData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    // 指定した日付・時刻のDateを組み立てるヘルパー
    private static func makeDate(
        year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }

    // 一覧表示に流し込むサンプル（2026年9月付近）
    static let days: [CalendarDay] = [
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 19),
            events: [
                CalendarEvent(
                    title: "チーム定例ミーティング",
                    location: "オンライン (Zoom)",
                    category: .work,
                    startDate: makeDate(year: 2026, month: 9, day: 19, hour: 10, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 19, hour: 11, minute: 0),
                    isAllDay: false
                ),
                CalendarEvent(
                    title: "設計レビュー",
                    location: "第2会議室",
                    category: .work,
                    startDate: makeDate(year: 2026, month: 9, day: 19, hour: 14, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 19, hour: 15, minute: 30),
                    isAllDay: false
                ),
                CalendarEvent(
                    title: "ジムでトレーニング",
                    location: "エニタイムフィットネス",
                    category: .health,
                    startDate: makeDate(year: 2026, month: 9, day: 19, hour: 19, minute: 30),
                    endDate: makeDate(year: 2026, month: 9, day: 19, hour: 21, minute: 0),
                    isAllDay: false
                ),
            ]
        ),
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 20),
            events: [
                CalendarEvent(
                    title: "家族で映画鑑賞",
                    location: "TOHOシネマズ",
                    category: .family,
                    startDate: makeDate(year: 2026, month: 9, day: 20, hour: 13, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 20, hour: 15, minute: 30),
                    isAllDay: false
                ),
            ]
        ),
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 21),
            events: [
                CalendarEvent(
                    title: "敬老の日",
                    location: nil,
                    category: .holiday,
                    startDate: makeDate(year: 2026, month: 9, day: 21),
                    endDate: makeDate(year: 2026, month: 9, day: 21),
                    isAllDay: true
                ),
                CalendarEvent(
                    title: "友人とランチ",
                    location: "青山カフェ",
                    category: .personal,
                    startDate: makeDate(year: 2026, month: 9, day: 21, hour: 12, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 21, hour: 13, minute: 30),
                    isAllDay: false
                ),
            ]
        ),
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 22),
            events: [
                CalendarEvent(
                    title: "国民の休日",
                    location: nil,
                    category: .holiday,
                    startDate: makeDate(year: 2026, month: 9, day: 22),
                    endDate: makeDate(year: 2026, month: 9, day: 22),
                    isAllDay: true
                ),
            ]
        ),
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 23),
            events: [
                CalendarEvent(
                    title: "秋分の日",
                    location: nil,
                    category: .holiday,
                    startDate: makeDate(year: 2026, month: 9, day: 23),
                    endDate: makeDate(year: 2026, month: 9, day: 23),
                    isAllDay: true
                ),
                CalendarEvent(
                    title: "歯医者の予約",
                    location: "さくら歯科クリニック",
                    category: .health,
                    startDate: makeDate(year: 2026, month: 9, day: 23, hour: 16, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 23, hour: 16, minute: 45),
                    isAllDay: false
                ),
            ]
        ),
        CalendarDay(
            date: makeDate(year: 2026, month: 9, day: 25),
            events: [
                CalendarEvent(
                    title: "プロジェクト締め切り",
                    location: nil,
                    category: .work,
                    startDate: makeDate(year: 2026, month: 9, day: 25, hour: 18, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 25, hour: 18, minute: 0),
                    isAllDay: false
                ),
                CalendarEvent(
                    title: "誕生日ディナー",
                    location: "銀座イタリアン",
                    category: .personal,
                    startDate: makeDate(year: 2026, month: 9, day: 25, hour: 19, minute: 0),
                    endDate: makeDate(year: 2026, month: 9, day: 25, hour: 21, minute: 30),
                    isAllDay: false
                ),
            ]
        ),
    ]
}
