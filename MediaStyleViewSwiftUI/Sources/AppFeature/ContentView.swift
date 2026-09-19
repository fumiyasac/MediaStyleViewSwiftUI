//
//  ContentView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2021/10/01.
//

import SwiftUI

public struct ContentView: View {

    // 選択中タブ（0:月 / 1:一覧）。タブ切り替えを月表示側へ伝えて位置を復元する
    @State private var selectedTab = 0

    // MARK: - Initializer

    public init() {}

    // MARK: - Body

    public var body: some View {
        TabView(selection: $selectedTab) {
            MonthCalendarView(isActive: selectedTab == 0)
                .tag(0)
                .tabItem {
                    Label("月", systemImage: "calendar")
                }

            CalendarListView()
                .tag(1)
                .tabItem {
                    Label("一覧", systemImage: "list.bullet")
                }
        }
        .tint(Color(red: 1.0, green: 0.23, blue: 0.19))
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
