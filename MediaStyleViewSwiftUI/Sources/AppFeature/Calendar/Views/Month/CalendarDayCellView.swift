//
//  CalendarDayCellView.swift.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月グリッド内の1日。元MonthView.dayCellの見た目をそのまま移植。

import SwiftUI

struct CalendarDayCellView: View {
    let date: Date
    let categories: [CalendarCategory]
    let isToday: Bool
    let isSunday: Bool
    let isSaturday: Bool

    private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    var body: some View {
        VStack(spacing: 3) {
            Text("\(CalendarDateUtil.dayNumber(of: date))")
                .font(.system(size: 18, weight: isToday ? .bold : .regular))
                .foregroundStyle(dayColor)
                .frame(width: 30, height: 30)
                .background {
                    if isToday {
                        Circle().fill(accentRed)
                    }
                }

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

    private var dayColor: Color {
        if isToday {
            return .white
        } else if isSunday {
            return accentRed
        } else if isSaturday {
            return Color(red: 0.20, green: 0.48, blue: 0.96)
        } else {
            return .primary
        }
    }
}
