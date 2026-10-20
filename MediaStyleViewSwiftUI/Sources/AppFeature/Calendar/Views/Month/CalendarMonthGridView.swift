//
//  CalendarMonthGridView.swift
//  MediaStyleViewSwiftUI
//
//  月表示（無限スクロール）用のグリッド計算ヘルパー
//

// 純粋な7列の描画View。月の日付計算はCalendarMonthGridを使う。

import SwiftUI

struct CalendarMonthGridView: View {
    let grid: CalendarMonthGrid
    let days: [CalendarDay]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, cell in
                if let date = cell {
                    CalendarDayCellView(
                        date: date,
                        categories: CalendarDateUtil.categories(on: date),
                        isToday: CalendarDateUtil.isToday(date),
                        isSunday: CalendarDateUtil.isSunday(date),
                        isSaturday: CalendarDateUtil.isSaturday(date)
                    )
                } else {
                    Color.clear
                        .frame(height: 58)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        if let grid = CalendarMonthGrid(baseMonth: CalendarMonthGrid.startOfMonth(for: Date()), offset: 0) {
            CalendarMonthGridView(grid: grid, days: CalendarSampleData.days)
        }
    }
}
