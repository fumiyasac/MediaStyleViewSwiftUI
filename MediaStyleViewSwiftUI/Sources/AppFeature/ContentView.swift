//
//  ContentView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2021/10/01.
//

import SwiftUI

public struct ContentView: View {

    // MARK: - Initializer

    public init() {}

    // MARK: - Body

    public var body: some View {
        // サンプルデータを一度だけ生成し、Root経由で月・一覧タブへ同じ配列を渡す
        CalendarRootView(days: CalendarSampleData.days)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
