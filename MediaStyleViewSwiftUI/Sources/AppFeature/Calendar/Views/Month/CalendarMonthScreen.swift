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
    // StateMachine。Rootが所有し共有する（画面再描画で再生成しない）
    private let viewModel: CalendarViewModel
    // Recipe Detail / MealLog Editor へ渡す依存
    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository
    // 調理ログ保存結果をCalendarへ通知するクロージャ
    private let onMealLogSaved: (MealLogSummary) -> Void

    // 現在最上部に表示中の月オフセット（ヘッダーの年表示用。従来どおり）
    @State private var visibleOffset: Int = 0
    @State private var isTrackingEnabled = false
    // Recipe Detailへの型付きNavigation。タブを跨いでも保持されるようMonthScreenの@Stateで持つ
    @State private var path: [CalendarRoute] = []

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

    init(
        isActive: Bool,
        viewModel: CalendarViewModel,
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository,
        onMealLogSaved: @escaping (MealLogSummary) -> Void
    ) {
        self.isActive = isActive
        self.viewModel = viewModel
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
        self.onMealLogSaved = onMealLogSaved
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
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
                                        state: viewModel.state,
                                        onSelectDate: handleSelectDate
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
            .navigationDestination(for: CalendarRoute.self) { route in
                switch route {
                case let .recipeDetail(recipeID, _):
                    RecipeDetailScreen(
                        recipeID: recipeID,
                        recipeRepository: recipeRepository,
                        mealLogRepository: mealLogRepository,
                        onMealLogSaved: onMealLogSaved
                    )
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
                        // NOTE: 追加アクション用のプレースホルダ（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(CalendarTheme.accent)
        }
    }

    // MARK: - Private Function

    // 日付タップ処理。選択状態を更新し、その日に掲載レシピがあればRecipe Detailへ遷移する。
    // 掲載なしの日は遷移しない（不正遷移を防ぐ）。複数掲載時は先頭のレシピを開く。
    private func handleSelectDate(_ date: Date) {
        viewModel.send(.selectDate(date))

        let dateKey = DateKey(date: date, calendar: Self.dateKeyCalendar)
        let monthKey = MonthKey(date: date, calendar: Self.dateKeyCalendar)
        let entriesOnDay = viewModel.state.monthLoad(monthKey).recipeEntries
            .filter { $0.dateKey == dateKey }
        guard let entry = entriesOnDay.first else { return }
        path.append(.recipeDetail(recipeID: entry.recipeID, publicationDayKey: dateKey))
    }

    // MARK: - Private Function（スクロール機構は従来どおり・変更なし）

    // 日付キー導出用Calendar（データ生成側と揃える）
    private static let dateKeyCalendar = DateKeyCalendar.default

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
