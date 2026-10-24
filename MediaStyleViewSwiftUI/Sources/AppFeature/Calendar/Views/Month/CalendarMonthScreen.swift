//
//  CalendarMonthScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブの画面入口。無限スクロール/位置検出/復元の仕組みは一切変更しない。
// 今回の追加:
//  - CalendarViewModelを受け取り、各月の表示時にその月のRecipe/MealLogを読み込む（月ごとに重複抑制）
//  - 各日セルへViewData(掲載レシピ/調理記録/選択)を反映し、タップでselectDateをViewModelへ通知する

import SwiftUI

struct CalendarMonthScreen: View {

    // MARK: - Property

    // 基準となる今月の1日。全オフセットはこの月を起点に計算する
    private let baseMonth = CalendarMonthGrid.startOfMonth(for: Date())

    // 前後100年分（±1200ヶ月）。LazyVStackで可視分だけ描画し実質無限スクロールにする（従来どおり）
    private let monthOffsets = Array(-1200...1200)

    private let isActive: Bool
    private let days: [CalendarDay]
    // StateMachine。Rootが所有し共有する（画面再描画で再生成しない）
    private let viewModel: CalendarViewModel

    // 現在最上部に表示中の月オフセット（ヘッダーの年表示用。従来どおり）
    @State private var visibleOffset: Int = 0
    @State private var isTrackingEnabled = false

    private static let calendar = CalendarFactory.shared

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年"
        return formatter
    }()

    private var yearText: String {
        let date = Self.calendar.date(byAdding: .month, value: visibleOffset, to: baseMonth) ?? baseMonth
        return Self.yearFormatter.string(from: date)
    }

    // MARK: - Initializer

    init(days: [CalendarDay], isActive: Bool, viewModel: CalendarViewModel) {
        self.days = days
        self.isActive = isActive
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarWeekdayHeaderView()
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(monthOffsets, id: \.self) { offset in
                                if let grid = CalendarMonthGrid(baseMonth: baseMonth, offset: offset) {
                                    CalendarMonthView(
                                        grid: grid,
                                        days: days,
                                        state: viewModel.state,
                                        onSelectDate: { viewModel.send(.selectDate($0)) }
                                    )
                                    .id(offset)
                                    // 各月が表示されたらその月のRecipe/MealLogを読み込む（重複はReducerが抑制）
                                    .onAppear {
                                        viewModel.send(.loadMonth(grid.monthStart))
                                    }
                                    // 各月の上端位置をmonthScroll座標系で収集（従来どおり）
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
                        // NOTE: イベント追加想定（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(CalendarTheme.accent)
        }
    }

    // MARK: - Private Function（スクロール機構は従来どおり・変更なし）

    private func restore(to offset: Int, using proxy: ScrollViewProxy) {
        isTrackingEnabled = false
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
