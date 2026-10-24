//
//  RecipeDetailScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// レシピ詳細画面。RecipeDetailViewModel経由でRecipe(Domain Model)とこのレシピの調理記録を表示する。
// 画像は未提供のため、カテゴリ色＋SF Symbolのプレースホルダーを主役に置く。
// 「作った記録を追加」からMealLog EditorのSheetを開き、保存成功時にDetailとCalendarへ反映する。

import SwiftUI

struct RecipeDetailScreen: View {

    // MARK: - Property

    @State private var viewModel: RecipeDetailViewModel
    @State private var showEditor = false

    private let recipeID: RecipeID
    private let mealLogRepository: any MealLogRepository
    // 保存成功をCalendar側へ通知するクロージャ（CalendarViewModel.send(.mealLogSaved)相当）
    private let onMealLogSaved: (MealLogSummary) -> Void

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    // MARK: - Initializer

    init(
        recipeID: RecipeID,
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository,
        onMealLogSaved: @escaping (MealLogSummary) -> Void
    ) {
        self.recipeID = recipeID
        self.mealLogRepository = mealLogRepository
        self.onMealLogSaved = onMealLogSaved
        _viewModel = State(
            initialValue: RecipeDetailViewModel(
                recipeID: recipeID,
                recipeRepository: recipeRepository,
                mealLogRepository: mealLogRepository
            )
        )
    }

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle("レシピ")
            .navigationBarTitleDisplayMode(.inline)
            .task { viewModel.load() }
    }

    // MARK: - Private View

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .failed(message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)

        case let .loaded(recipe, mealLogs):
            loadedBody(recipe: recipe, mealLogs: mealLogs)
        }
    }

    private func loadedBody(recipe: Recipe, mealLogs: [MealLogSummary]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage(for: recipe)

                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.category.displayName)
                        .font(.caption.bold())
                        .foregroundStyle(CalendarTheme.accent)
                    Text(recipe.title)
                        .font(.title.bold())
                    Text(recipe.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                metaRow(for: recipe)

                Divider()
                RecipeIngredientSectionView(ingredients: recipe.ingredients, servings: recipe.servings)

                Divider()
                RecipeInstructionSectionView(steps: recipe.steps)

                Divider()
                mealLogSection(mealLogs: mealLogs)

                addMealLogButton(recipe: recipe)
            }
            .padding(16)
        }
        .sheet(isPresented: $showEditor) {
            MealLogEditorSheet(
                recipeID: recipe.id,
                recipeTitle: recipe.title,
                // 調理日の初期値はユーザーの現在日付（掲載日ではない）
                defaultCookedAt: Date(),
                repository: mealLogRepository,
                onSaved: { summary in
                    viewModel.didSaveMealLog(summary)
                    onMealLogSaved(summary)
                }
            )
        }
    }

    // 画像プレースホルダー（カテゴリ色のグラデーション＋シンボル）
    private func heroImage(for recipe: Recipe) -> some View {
        let base = heroColor(for: recipe.category)
        return ZStack {
            LinearGradient(
                colors: [base.opacity(0.85), base.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: recipe.category.symbolName)
                .font(.system(size: 56))
                .foregroundStyle(.white)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("\(recipe.title)の写真プレースホルダー")
    }

    // カテゴリ別のプレースホルダー色（DomainをSwiftUIに結合させないためView側でマップ）
    private func heroColor(for category: RecipeCategory) -> Color {
        switch category {
        case .japanese: return Color(red: 0.90, green: 0.45, blue: 0.35)
        case .western: return Color(red: 0.85, green: 0.55, blue: 0.25)
        case .chinese: return Color(red: 0.80, green: 0.30, blue: 0.30)
        case .italian: return Color(red: 0.40, green: 0.65, blue: 0.45)
        case .dessert: return Color(red: 0.85, green: 0.45, blue: 0.65)
        case .healthy: return Color(red: 0.40, green: 0.70, blue: 0.55)
        }
    }

    private func metaRow(for recipe: Recipe) -> some View {
        HStack(spacing: 20) {
            metaItem(icon: "clock", text: "\(recipe.cookingMinutes)分")
            metaItem(icon: "person.2", text: "\(recipe.servings)人分")
            metaItem(icon: "flame", text: "\(recipe.calories)kcal")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func metaItem(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
    }

    @ViewBuilder
    private func mealLogSection(mealLogs: [MealLogSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("あなたの調理記録")
                .font(.headline)

            if mealLogs.isEmpty {
                Text("まだ調理記録はありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mealLogs) { log in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(Self.logDateFormatter.string(from: log.cookedAt))
                                .font(.subheadline.bold())
                            Spacer()
                            Text(String(repeating: "★", count: max(0, min(5, log.rating))))
                                .foregroundStyle(CalendarTheme.accent)
                        }
                        if !log.memo.isEmpty {
                            Text(log.memo)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func addMealLogButton(recipe: Recipe) -> some View {
        Button {
            showEditor = true
        } label: {
            Label("作った記録を追加", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(CalendarTheme.accent)
        .padding(.top, 4)
    }
}
