//
//  CalendarSampleData.swift
//  MediaStyleViewSwiftUI
//
//  一覧・月表示画面のプレビュー用ダミーデータ（本日基準で生成）
//

import Foundation

enum CalendarSampleData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    // 本日からのオフセット（日数）と時刻からDateを組み立てるヘルパー。
    // これにより常に「本日」を起点としたサンプルになる
    private static func makeDate(
        dayOffset: Int, hour: Int = 0, minute: Int = 0
    ) -> Date {
        let startOfToday = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) ?? startOfToday
        return calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: day
        ) ?? day
    }

    // その日の0時（セクションの日付）
    private static func dayDate(_ dayOffset: Int) -> Date {
        makeDate(dayOffset: dayOffset)
    }

    // 一覧・月表示に流し込むサンプル（本日=offset:0 を起点に、初回アクセス時に一度だけ生成）
    static let days: [CalendarDay] = buildDays()

    private static func buildDays() -> [CalendarDay] {
        [
            CalendarDay(
                date: dayDate(0),
                events: [
                    CalendarEvent(
                        title: "チーム定例ミーティング",
                        location: "オンライン (Zoom)",
                        category: .work,
                        startDate: makeDate(dayOffset: 0, hour: 10, minute: 0),
                        endDate: makeDate(dayOffset: 0, hour: 11, minute: 0),
                        isAllDay: false
                    ),
                    CalendarEvent(
                        title: "設計レビュー",
                        location: "第2会議室",
                        category: .work,
                        startDate: makeDate(dayOffset: 0, hour: 14, minute: 0),
                        endDate: makeDate(dayOffset: 0, hour: 15, minute: 30),
                        isAllDay: false
                    ),
                    CalendarEvent(
                        title: "ジムでトレーニング",
                        location: "エニタイムフィットネス",
                        category: .health,
                        startDate: makeDate(dayOffset: 0, hour: 19, minute: 30),
                        endDate: makeDate(dayOffset: 0, hour: 21, minute: 0),
                        isAllDay: false
                    ),
                ]
            ),
            CalendarDay(
                date: dayDate(1),
                events: [
                    CalendarEvent(
                        title: "家族で映画鑑賞",
                        location: "TOHOシネマズ",
                        category: .family,
                        startDate: makeDate(dayOffset: 1, hour: 13, minute: 0),
                        endDate: makeDate(dayOffset: 1, hour: 15, minute: 30),
                        isAllDay: false
                    ),
                ]
            ),
            CalendarDay(
                date: dayDate(2),
                events: [
                    CalendarEvent(
                        title: "リフレッシュ休暇",
                        location: nil,
                        category: .holiday,
                        startDate: dayDate(2),
                        endDate: dayDate(2),
                        isAllDay: true
                    ),
                    CalendarEvent(
                        title: "友人とランチ",
                        location: "青山カフェ",
                        category: .personal,
                        startDate: makeDate(dayOffset: 2, hour: 12, minute: 0),
                        endDate: makeDate(dayOffset: 2, hour: 13, minute: 30),
                        isAllDay: false
                    ),
                ]
            ),
            CalendarDay(
                date: dayDate(3),
                events: [
                    CalendarEvent(
                        title: "有給休暇",
                        location: nil,
                        category: .holiday,
                        startDate: dayDate(3),
                        endDate: dayDate(3),
                        isAllDay: true
                    ),
                ]
            ),
            CalendarDay(
                date: dayDate(4),
                events: [
                    CalendarEvent(
                        title: "記念日",
                        location: nil,
                        category: .holiday,
                        startDate: dayDate(4),
                        endDate: dayDate(4),
                        isAllDay: true
                    ),
                    CalendarEvent(
                        title: "歯医者の予約",
                        location: "さくら歯科クリニック",
                        category: .health,
                        startDate: makeDate(dayOffset: 4, hour: 16, minute: 0),
                        endDate: makeDate(dayOffset: 4, hour: 16, minute: 45),
                        isAllDay: false
                    ),
                ]
            ),
            CalendarDay(
                date: dayDate(6),
                events: [
                    CalendarEvent(
                        title: "プロジェクト締め切り",
                        location: nil,
                        category: .work,
                        startDate: makeDate(dayOffset: 6, hour: 18, minute: 0),
                        endDate: makeDate(dayOffset: 6, hour: 18, minute: 0),
                        isAllDay: false
                    ),
                    CalendarEvent(
                        title: "誕生日ディナー",
                        location: "銀座イタリアン",
                        category: .personal,
                        startDate: makeDate(dayOffset: 6, hour: 19, minute: 0),
                        endDate: makeDate(dayOffset: 6, hour: 21, minute: 30),
                        isAllDay: false
                    ),
                ]
            ),
        ]
    }
}
