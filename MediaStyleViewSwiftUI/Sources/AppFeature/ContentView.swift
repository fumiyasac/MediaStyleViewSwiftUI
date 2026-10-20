//
//  ContentView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2021/10/01.
//

import SwiftUI

public struct ContentView: View {
    public init() {}

    public var body: some View {
        CalendarRootView(days: CalendarSampleData.days)
    }
}

#Preview {
    ContentView()
}
