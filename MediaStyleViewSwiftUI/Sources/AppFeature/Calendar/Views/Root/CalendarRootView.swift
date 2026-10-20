//
//  CalendarRootView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

import SwiftUI

struct CalendarRootView: View {
    private let days: [CalendarDay]
    @State private var selectedTab: CalendarTab = .month

    init(days: [CalendarDay]) {
        self.days = days
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarMonthScreen(days: days, isActive: selectedTab == .month)
                .tag(CalendarTab.month)
                .tabItem {
                    Label("月", systemImage: "calendar")
                }

            CalendarListScreen()
                .tag(CalendarTab.list)
                .tabItem {
                    Label("一覧", systemImage: "list.bullet")
                }
        }
        .tint(Color(red: 1.0, green: 0.23, blue: 0.19))
    }
}

#Preview {
    CalendarRootView(days: CalendarSampleData.days)
}
