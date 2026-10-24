//
//  CalendarRootView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブと一覧タブを束ねるルート。ここがCalendarViewModelの所有者。
// @Stateで保持することで画面の再描画ではViewModelを再生成せず、月タブと一覧タブで同じ状態を共有できる。
// UseCase(Repositoryを内包)は外から注入し、Preview/TestではInMemory実装へ差し替えられる。

import SwiftUI

struct CalendarRootView: View {

    // MARK: - Property

    private let days: [CalendarDay]
    @State private var selectedTab: CalendarTab = .month
    // ViewModelはここで一度だけ生成して保持する（再描画で作り直さない）
    @State private var viewModel: CalendarViewModel

    // MARK: - Initializer

    init(days: [CalendarDay], useCase: any CalendarUseCase, referenceDate: Date = Date()) {
        self.days = days
        _viewModel = State(
            initialValue: CalendarViewModel(
                useCase: useCase,
                initialState: .initial(referenceDate: referenceDate)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // isActiveで月タブが選択中かを渡し、タブ復帰時の位置復元に使う（従来どおり）
            CalendarMonthScreen(
                days: days,
                isActive: selectedTab == .month,
                viewModel: viewModel
            )
            .tag(CalendarTab.month)
            .tabItem {
                Label("月", systemImage: "calendar")
            }

            // 一覧は既存のイベント表示・検索を維持（今回はRecipe/MealLogへ置き換えない）。
            // 同じViewModelをRootが所有しているため、後続PRで一覧も同じ状態を利用できる。
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
    CalendarRootView(
        days: CalendarSampleData.days,
        useCase: DefaultCalendarUseCase(
            recipeRepository: FixtureRecipeRepository(),
            mealLogRepository: InMemoryMealLogRepository()
        )
    )
}
