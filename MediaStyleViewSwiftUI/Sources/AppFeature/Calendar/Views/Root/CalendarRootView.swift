//
//  CalendarRootView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブとTimeline(一覧)タブを束ねるルート。CalendarViewModelとTimelineViewModelの所有者。
// 両ViewModelを@Stateで一度だけ生成して保持し、画面の再描画で作り直さない。
// 調理ログ保存の結果は onMealLogSaved で両ViewModelへ通知する:
//  - Calendar: mealLogSavedで該当月へ直接反映（Design A）
//  - Timeline: reloadで再取得して最新化（Design B）
// どちらも同じRepositoryを通すためデータ整合性は保たれる。

import SwiftUI

struct CalendarRootView: View {

    // MARK: - Property

    private let days: [CalendarDay]
    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository

    @State private var selectedTab: CalendarTab = .month
    @State private var viewModel: CalendarViewModel
    @State private var timelineViewModel: TimelineViewModel

    // MARK: - Initializer

    init(
        days: [CalendarDay],
        calendarUseCase: any CalendarUseCase,
        timelineUseCase: any TimelineUseCase,
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
        _timelineViewModel = State(
            initialValue: TimelineViewModel(useCase: timelineUseCase, referenceDate: referenceDate)
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
                onMealLogSaved: handleMealLogSaved
            )
            .tag(CalendarTab.month)
            .tabItem {
                Label("月", systemImage: "calendar")
            }

            // 一覧タブはTimeline（レシピ掲載＋調理記録の統合表示）へ移行
            TimelineScreen(
                viewModel: timelineViewModel,
                recipeRepository: recipeRepository,
                mealLogRepository: mealLogRepository,
                onMealLogSaved: handleMealLogSaved
            )
            .tag(CalendarTab.list)
            .tabItem {
                Label("一覧", systemImage: "list.bullet")
            }
        }
        .tint(CalendarTheme.accent)
    }

    // MARK: - Private Function

    // 保存結果を両ViewModelへ通知（Calendarは直接反映、Timelineは再取得）
    private func handleMealLogSaved(_ summary: MealLogSummary) {
        viewModel.send(.mealLogSaved(summary))
        timelineViewModel.send(.reload)
    }
}

// MARK: - Preview

#Preview {
    let dependencies = CalendarFeatureDependencies.inMemory()
    return CalendarRootView(
        days: dependencies.days,
        calendarUseCase: dependencies.calendarUseCase,
        timelineUseCase: dependencies.timelineUseCase,
        recipeRepository: dependencies.recipeRepository,
        mealLogRepository: dependencies.mealLogRepository
    )
}
