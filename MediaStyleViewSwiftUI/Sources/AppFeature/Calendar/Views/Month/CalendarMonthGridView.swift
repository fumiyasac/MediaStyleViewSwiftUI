//
//  CalendarMonthGridView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 7列の日付グリッドを描画するView。日付計算はCalendarMonthGridに委ね、
// ここはセル配列を並べるだけに責務を限定する。

import SwiftUI

struct CalendarMonthGridView: View {

    // MARK: - Property

    let grid: CalendarMonthGrid
    let days: [CalendarDay]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Body

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, cell in
                if let date = cell {
                    // 注入されたdaysからその日のカテゴリ色を引く（Fixture直参照はしない）
                    CalendarDayCellView(
                        date: date,
                        categories: CalendarDateUtil.categories(on: date, in: days),
                        isToday: CalendarDateUtil.isToday(date),
                        isSunday: CalendarDateUtil.isSunday(date),
                        isSaturday: CalendarDateUtil.isSaturday(date),
                        isHoliday: CalendarDateUtil.isHoliday(date)
                    )
                } else {
                    // 月初前・月末後の余白セル（日セルと同じ高さの空白を置いて桁を揃える）
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
