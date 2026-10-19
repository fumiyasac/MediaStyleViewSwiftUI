//
//  CalendarMonthGridView.swift
//  MediaStyleViewSwiftUI
//
//  月表示（無限スクロール）用のグリッド計算ヘルパー
//

import Foundation

// 1ヶ月分のグリッドを組み立てる構造体
struct CalendarMonthGridView {

    // 対象月の1日
    let monthStart: Date
    // 7列グリッド用（先頭・末尾の余白はnil）
    let cells: [Date?]

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 1 // 日曜始まり
        return calendar
    }()

    // 基準月からのオフセット（例: 0=今月, 1=翌月, -1=先月）でグリッドを生成
    init?(baseMonth: Date, offset: Int) {
        let calendar = Self.calendar
        guard
            let monthStart = calendar.date(
                byAdding: .month, value: offset, to: baseMonth
            )
        else { return nil }

        self.monthStart = monthStart

        // 当月の日数と、1日の曜日から先頭余白数を求める
        guard
            let range = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            self.cells = []
            return
        }
        let dayCount = range.count
        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=日曜
        let leadingBlanks = firstWeekday - calendar.firstWeekday

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: day, to: monthStart))
        }
        // 末尾を7の倍数になるまで余白で埋める
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        self.cells = cells
    }

    // 月見出しの本体（例: 9月 / 1月）
    var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
        return formatter.string(from: monthStart)
    }

    // 年をまたぐ1月に付ける小さな年サフィックス（例:  / 2027年）。それ以外はnil
    var yearSuffixText: String? {
        guard isYearStart else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "' / 'yyyy'年'"
        return formatter.string(from: monthStart)
    }

    // 年をまたぐ最初の月（1月）かどうか（見出しの強調用）
    var isYearStart: Bool {
        Self.calendar.component(.month, from: monthStart) == 1
    }

    // 今月の基準日（当月の1日）を返す
    static func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
