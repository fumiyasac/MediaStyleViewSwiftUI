//
//  CalendarEventListView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// 元CalendarListScreenのList描画をそのまま分離する。

import SwiftUI

struct CalendarEventListView: View {
    let days: [CalendarDay]

    var body: some View {
        List {
            ForEach(days) { day in
                CalendarDaySectionView(day: day)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowSeparator(.hidden)

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

#Preview {
    CalendarEventListView(days: CalendarSampleData.days)
}
