//
//  CalendarMonthView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 1ヶ月分の見出しとグリッド配置。MonthViewから責務単位で分割。

import SwiftUI

struct CalendarMonthView: View {
    let grid: CalendarMonthGrid
    let days: [CalendarDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthTitle
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 2)

            CalendarMonthGridView(grid: grid, days: days)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }

    private var monthTitle: Text {
        let month = Text(grid.monthText)
            .font(.system(size: 22, weight: .bold))
        if let suffix = grid.yearSuffixText {
            return month
                + Text(suffix)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
        }
        return month
    }
}

#Preview {
    ScrollView {
        if let grid = CalendarMonthGrid(baseMonth: CalendarMonthGrid.startOfMonth(for: Date()), offset: 0) {
            CalendarMonthView(grid: grid, days: CalendarSampleData.days)
        }
    }
}
