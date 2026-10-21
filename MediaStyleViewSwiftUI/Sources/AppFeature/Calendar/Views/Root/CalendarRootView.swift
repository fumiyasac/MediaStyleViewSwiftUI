//
//  CalendarRootView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブと一覧タブを束ねるルート。両タブに同じイベント配列を注入する。

import SwiftUI

struct CalendarRootView: View {

    // MARK: - Property

    private let days: [CalendarDay]
    @State private var selectedTab: CalendarTab = .month

    // MARK: - Initializer

    init(days: [CalendarDay]) {
        self.days = days
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // isActiveで月タブが選択中かを渡し、タブ復帰時の位置復元に使う
            CalendarMonthScreen(days: days, isActive: selectedTab == .month)
                .tag(CalendarTab.month)
                .tabItem {
                    Label("月", systemImage: "calendar")
                }

            // 月表示と同じdaysを注入して表示内容を揃える
            CalendarListScreen(days: days)
                .tag(CalendarTab.list)
                .tabItem {
                    Label("一覧", systemImage: "list.bullet")
                }
        }
        .tint(CalendarTheme.accent)
    }
}

// MARK: - Preview

#Preview {
    CalendarRootView(days: CalendarSampleData.days)
}
