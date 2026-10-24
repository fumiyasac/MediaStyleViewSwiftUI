//
//  TimelineScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 一覧タブのTimeline画面。日付別にレシピ掲載と調理記録を新しい順で表示する。
// 種別フィルタ・検索はView側(@State)でローカルに適用し、Repositoryへは都度アクセスしない。
// レシピ項目タップで既存のRecipe Detailへ遷移する（NavigationStackはこの画面が1つだけ持つ）。

import SwiftUI

struct TimelineScreen: View {

    // MARK: - Property

    private let viewModel: TimelineViewModel
    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository
    private let onMealLogSaved: (MealLogSummary) -> Void

    @State private var filter: TimelineFilter = .all
    @State private var searchText: String = ""
    @State private var path: [CalendarRoute] = []

    private let factory = TimelineViewDataFactory()

    // MARK: - Initializer

    init(
        viewModel: TimelineViewModel,
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository,
        onMealLogSaved: @escaping (MealLogSummary) -> Void
    ) {
        self.viewModel = viewModel
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
        self.onMealLogSaved = onMealLogSaved
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("表示", selection: $filter) {
                    ForEach(TimelineFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                content
            }
            .navigationTitle("タイムライン")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "レシピ・メモを検索")
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
            .tint(CalendarTheme.accent)
            .onAppear { viewModel.send(.onAppear) }
        }
    }

    // MARK: - Private View

    @ViewBuilder
    private var content: some View {
        let sections = factory.makeSections(
            entries: viewModel.state.entries,
            filter: filter,
            searchText: searchText
        )

        if viewModel.state.entries.isEmpty, viewModel.state.isLoading {
            // 初回読み込み中
            ProgressView("読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.state.entries.isEmpty, let message = viewModel.state.errorMessage {
            // 取得失敗かつ表示データ無し → エラー＋再試行
            errorView(message: message)
        } else if viewModel.state.isEmptyData {
            // 取得データ自体が0件
            emptyView(
                title: "まだ記録がありません",
                message: "レシピを選んで「作った記録」を追加するとここに表示されます"
            )
        } else if sections.isEmpty {
            // 検索・フィルタ結果が0件（取得0件とは区別）
            emptyView(
                title: "該当する項目がありません",
                message: "検索条件やフィルタを変えてみてください"
            )
        } else {
            timelineList(sections: sections)
        }
    }

    private func timelineList(sections: [TimelineSectionViewData]) -> some View {
        List {
            ForEach(sections) { section in
                TimelineDaySectionView(section: section, onTapEntry: handleTapEntry)
            }
        }
        .listStyle(.plain)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("再読み込み") { viewModel.send(.reload) }
                .buttonStyle(.borderedProminent)
                .tint(CalendarTheme.accent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyView(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Private Function

    // レシピ参照が解決できる項目のみ詳細へ遷移する（欠損項目は遷移しない）
    private func handleTapEntry(_ entry: TimelineEntryViewData) {
        guard !entry.recipeMissing else { return }
        let publicationDayKey: DateKey? = entry.kind == .recipe ? entry.dayKey : nil
        path.append(.recipeDetail(recipeID: entry.recipeID, publicationDayKey: publicationDayKey))
    }
}
