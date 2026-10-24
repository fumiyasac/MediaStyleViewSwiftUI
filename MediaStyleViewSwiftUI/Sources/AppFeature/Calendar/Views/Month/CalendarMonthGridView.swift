//
//  CalendarMonthGridView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 7列の日付グリッドを描画するView。日付計算はCalendarMonthGridに委ね、各セルの表示データは
// CalendarDayViewDataFactoryがStateから組み立てる。タップは親から渡されたクロージャで通知し、
// 子View(セル)がViewModelやRepositoryに触れないようにする。

import SwiftUI

struct CalendarMonthGridView: View {

    // MARK: - Property

    let grid: CalendarMonthGrid
    // Recipe/MealLogの読込状態と選択中日付
    let state: CalendarFeatureState
    // 日付タップの通知（親経由でViewModelへ）
    let onSelectDate: (Date) -> Void

    // 表示データ組み立てのFactory（日付キーの導出Calendarを一元化）
    private let factory = CalendarDayViewDataFactory()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    // MARK: - Body

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, cell in
                if let date = cell {
                    CalendarDayCellView(
                        viewData: factory.make(date: date, state: state)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectDate(date)
                    }
                } else {
                    // 月初前・月末後の余白セル（日セルと同じ高さの空白を置いて桁を揃える）
                    Color.clear
                        .frame(height: 58)
                }
            }
        }
    }
}
