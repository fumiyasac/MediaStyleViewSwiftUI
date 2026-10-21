//
//  CalendarDayCellView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月グリッド内の1日。元MonthView.dayCellの見た目をそのまま移植。

import SwiftUI

struct CalendarDayCellView: View {

    // MARK: - Property

    let date: Date
    let categories: [CalendarCategory]
    let isToday: Bool
    let isSunday: Bool
    let isSaturday: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 3) {
            Text("\(CalendarDateUtil.dayNumber(of: date))")
                .font(.system(size: 18, weight: isToday ? .bold : .regular))
                .foregroundStyle(dayColor)
                .frame(width: 30, height: 30)
                .background {
                    // 本日は赤丸で強調（Apple純正と同じ表現）
                    if isToday {
                        Circle().fill(CalendarTheme.accent)
                    }
                }

            // その日のイベントのカテゴリ色ドット（最大4件）
            HStack(spacing: 3) {
                ForEach(Array(categories.prefix(4).enumerated()), id: \.offset) { _, category in
                    Circle()
                        .fill(category.color)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }

    // MARK: - Private Function

    // 日にちの文字色。本日だけは赤丸に重ねる白抜きにし、それ以外は平日.primary基準で共通解決する
    private var dayColor: Color {
        if isToday {
            return .white
        }
        return CalendarTheme.weekdayColor(
            isSunday: isSunday, isSaturday: isSaturday, default: .primary
        )
    }
}
