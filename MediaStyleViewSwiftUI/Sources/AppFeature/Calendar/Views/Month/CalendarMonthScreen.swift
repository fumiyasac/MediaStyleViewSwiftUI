//
//  CalendarMonthScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブの画面入口。元コードの無限スクロール/位置検出/復元を維持。

import SwiftUI

public struct CalendarMonthScreen: View {
    private let baseMonth = CalendarMonthGrid.startOfMonth(for: Date())
    private let monthOffsets = Array(-1200...1200)
    private let isActive: Bool
    private let days: [CalendarDay]
    private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    @State private var visibleOffset: Int = 0
    @State private var isTrackingEnabled = false

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    private var yearText: String {
        let date = Self.calendar.date(byAdding: .month, value: visibleOffset, to: baseMonth) ?? baseMonth
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年"
        return formatter.string(from: date)
    }

    // 以前のpublic APIを壊さない。画面内からのSampleData参照は旧API互換用のみ。
    public init(isActive: Bool = true) {
        self.isActive = isActive
        self.days = CalendarSampleData.days
    }

    // Rootから同じイベント配列を注入する。
    init(days: [CalendarDay], isActive: Bool) {
        self.days = days
        self.isActive = isActive
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarWeekdayHeaderView()
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(monthOffsets, id: \.self) { offset in
                                if let grid = CalendarMonthGrid(baseMonth: baseMonth, offset: offset) {
                                    CalendarMonthView(grid: grid, days: days)
                                        .id(offset)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: CalendarMonthPositionKey.self,
                                                    value: [offset: geo.frame(in: .named("monthScroll")).minY]
                                                )
                                            }
                                        )
                                }
                            }
                        }
                    }
                    .coordinateSpace(name: "monthScroll")
                    .onPreferenceChange(CalendarMonthPositionKey.self) { positions in
                        updateVisibleOffset(from: positions)
                    }
                    .onAppear {
                        restore(to: visibleOffset, using: proxy)
                    }
                    .onChange(of: isActive) { _, nowActive in
                        if nowActive {
                            restore(to: visibleOffset, using: proxy)
                        } else {
                            isTrackingEnabled = false
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                        visibleOffset = 0
                        restore(to: 0, using: proxy)
                    }
                }
            }
            .navigationTitle(yearText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("今日") {
                        NotificationCenter.default.post(name: .scrollToToday, object: nil)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // NOTE: 受信ボックス想定（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "tray")
                    }
                    Button {
                        // NOTE: イベント追加想定（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(accentRed)
        }
    }

    private func restore(to offset: Int, using proxy: ScrollViewProxy) {
        isTrackingEnabled = false
        // 元コードと同じ時刻・順序・非アニメーションで位置復元する。
        for delay in [0.0, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                proxy.scrollTo(offset, anchor: .top)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTrackingEnabled = true
        }
    }

    private func updateVisibleOffset(from positions: [Int: CGFloat]) {
        guard isTrackingEnabled, !positions.isEmpty else { return }

        let threshold: CGFloat = 1
        let chosen: Int
        if let top = positions.filter({ $0.value <= threshold }).max(by: { $0.value < $1.value }) {
            chosen = top.key
        } else if let first = positions.min(by: { $0.value < $1.value }) {
            chosen = first.key
        } else {
            return
        }
        if chosen != visibleOffset {
            visibleOffset = chosen
        }
    }
}

#Preview {
    CalendarMonthScreen()
}
