//
//  CalendarEventListView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 一覧表示のList本体。日付セクションと区切り線の描画をCalendarListScreenから分離し、
// 画面側のツールバー・検索とList描画の責務を分ける。

import SwiftUI

struct CalendarEventListView: View {

    // MARK: - Property

    let days: [CalendarDay]

    // MARK: - Body

    var body: some View {
        List {
            ForEach(days) { day in
                CalendarDaySectionView(day: day)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)

                // 日付セクション間の区切り線（日付カラム幅を避けてleading16で引く）
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CalendarEventListView(days: CalendarSampleData.days)
}
