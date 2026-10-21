//
//  CalendarMonthGrid.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/19.
//

// 月表示の計算結果。SwiftUI ViewではないのでModelsに置く。

import Foundation

struct CalendarMonthGrid: Sendable {

    // MARK: - Property

    // 対象月の1日
    let monthStart: Date
    // 7列グリッド用。1日の曜日に応じた先頭余白と、末尾を7の倍数に揃える余白はnilで表す
    let cells: [Date?]

    // 共有Calendarを参照する（日曜始まり=firstWeekday=1が余白計算の前提）
    private static let calendar = CalendarFactory.shared

    // 見出し用のDateFormatterはstaticで使い回す（計算プロパティ毎の再生成を避ける）
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let yearSuffixFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "' / 'yyyy'年'"
        return formatter
    }()

    // MARK: - Initializer

    // 基準月からのオフセット（例: 0=今月, 1=翌月, -1=先月）でグリッドを生成する。
    // CalendarMonthScreenが-1200...1200のoffsetを与えて擬似的な無限スクロールを作るため、
    // 1か月分のセル配列をoffset起点で組み立てられるようにしている。
    init?(baseMonth: Date, offset: Int) {
        let calendar = Self.calendar
        guard let monthStart = calendar.date(byAdding: .month, value: offset, to: baseMonth) else {
            return nil
        }
        self.monthStart = monthStart

        // 当月の日数と、1日の曜日から先頭余白数を求める
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            self.cells = []
            return
        }
        // 1日の曜日(weekday)と週の開始曜日(firstWeekday)の差が、月初の前に入る空白セル数になる。
        // 例: 1日が木曜(weekday=5)・日曜始まり(firstWeekday=1)なら先頭に4つのnilを置く。
        let leadingBlanks = calendar.component(.weekday, from: monthStart) - calendar.firstWeekday
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: day, to: monthStart))
        }
        // 7列グリッドとして最終行まで埋めるため、末尾を7の倍数になるまでnilで補う
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        self.cells = cells
    }

    // MARK: - Property（表示用の導出値）

    // 月見出しの本体（例: 9月 / 1月）
    var monthText: String {
        Self.monthFormatter.string(from: monthStart)
    }

    // 年をまたぐ1月に付ける小さな年サフィックス（例:  / 2027年）。それ以外はnil
    var yearSuffixText: String? {
        guard isYearStart else { return nil }
        return Self.yearSuffixFormatter.string(from: monthStart)
    }

    // 年をまたぐ最初の月（1月）かどうか（見出しの強調用）
    var isYearStart: Bool {
        Self.calendar.component(.month, from: monthStart) == 1
    }

    // MARK: - Function

    // 指定日が属する月の1日を返す（基準月の算出に使う）
    static func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
