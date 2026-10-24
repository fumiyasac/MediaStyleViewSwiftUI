//
//  CalendarRootView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブと一覧タブを束ねるルート。ここがCalendarViewModelの所有者。
// @Stateで保持することで画面の再描画ではViewModelを再生成せず、月タブと一覧タブで同じ状態を共有できる。
// Recipe Detail / MealLog Editor 用にRepositoryも保持し、月タブへ渡す。
// 調理ログ保存の結果は onMealLogSaved でViewModelへ送り、Calendarのマーカーへ反映する。

import SwiftUI

struct CalendarRootView: View {

    // MARK: - Property

    private let days: [CalendarDay]
    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository

    @State private var selectedTab: CalendarTab = .month
    // ViewModelはここで一度だけ生成して保持する（再描画で作り直さない）
    @State private var viewModel: CalendarViewModel

    // MARK: - Initializer

    init(
        days: [CalendarDay],
        calendarUseCase: any CalendarUseCase,
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository,
        referenceDate: Date = Date()
    ) {
        self.days = days
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
        _viewModel = State(
            initialValue: CalendarViewModel(
                useCase: calendarUseCase,
                initialState: .initial(referenceDate: referenceDate)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarMonthScreen(
                days: days,
                isActive: selectedTab == .month,
                viewModel: viewModel,
                recipeRepository: recipeRepository,
                mealLogRepository: mealLogRepository,
                // 保存結果をCalendar Stateへ反映（Design A: 再取得せず直接反映）
                onMealLogSaved: { summary in viewModel.send(.mealLogSaved(summary)) }
            )
            .tag(CalendarTab.month)
            .tabItem {
                Label("月", systemImage: "calendar")
            }

            // 一覧は既存のイベント表示・検索を維持（今回はRecipe/MealLogへ置き換えない）
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
    let dependencies = CalendarFeatureDependencies.inMemory()
    return CalendarRootView(
        days: dependencies.days,
        calendarUseCase: dependencies.calendarUseCase,
        recipeRepository: dependencies.recipeRepository,
        mealLogRepository: dependencies.mealLogRepository
    )
}
