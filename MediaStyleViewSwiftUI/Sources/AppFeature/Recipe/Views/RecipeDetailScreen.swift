//
//  RecipeDetailScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// レシピ詳細画面。RecipeDetailViewModel経由でRecipe(Domain Model)とこのレシピの調理記録を表示する。
// 写真メディア風の閲覧体験のため、背面に固定したHero(RecipeHeroView)の上を不透明な本文がスクロールする。
// スクロール量はonScrollGeometryChange(iOS 18+)で必要な値だけ取得し、Heroの描画と
// Compact Titleの表示判定にのみ使う（StateMachine/ViewModelへは毎フレーム送らない）。
// 「作った記録を追加」からMealLog EditorのSheetを開き、保存成功時にDetailとCalendarへ反映する。

import SwiftUI

struct RecipeDetailScreen: View {

    // MARK: - Property

    @State private var viewModel: RecipeDetailViewModel
    @State private var showEditor = false
    // スクロール連動の一時的な描画状態（StateMachineではなくViewが所有する）
    @State private var scrollOffset: CGFloat = 0
    @State private var isCompact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let recipeID: RecipeID
    private let mealLogRepository: any MealLogRepository
    // 保存成功をCalendar側へ通知するクロージャ（CalendarViewModel.send(.mealLogSaved)相当）
    private let onMealLogSaved: (MealLogSummary) -> Void

    // Hero展開時の高さ（描画パラメータ計算の基準）
    private static let heroHeight: CGFloat = 320
    // 本文上端をHeroへ少し重ねる量（角丸を被せるメディア風の見た目）
    private static let contentOverlap: CGFloat = 24

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
                .navigationTitle("レシピ")

        case let .failed(message):
            // 取得失敗。Remote取得ではネットワーク失敗やタイムアウトが現実に起こるため、
            // 利用者が明示的に再試行できるようにする（再試行はこのレシピ取得だけを再実行する）。
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("再読み込み") { viewModel.load() }
                    .buttonStyle(.borderedProminent)
                    .tint(CalendarTheme.accent)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .navigationTitle("レシピ")

        case let .loaded(recipe, mealLogs):
            loadedBody(recipe: recipe, mealLogs: mealLogs)
        }
    }

    private func loadedBody(recipe: Recipe, mealLogs: [MealLogSummary]) -> some View {
        ZStack(alignment: .top) {
            // 背面に固定するHero（本文がこの上をスクロールして覆う）
            RecipeHeroView(
                recipe: recipe,
                scrollOffset: scrollOffset,
                expandedHeight: Self.heroHeight,
                reduceMotion: reduceMotion
            )
            .frame(height: Self.heroHeight)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    // Hero分の余白（透明なのでHeroが見える）。本文を少しだけHeroへ重ねる。
                    Color.clear.frame(height: Self.heroHeight - Self.contentOverlap)

                    RecipeDetailContent(
                        recipe: recipe,
                        mealLogs: mealLogs,
                        onAddTap: { showEditor = true }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
                }
            }
            // 必要な値（先頭からのスクロール量）だけを抽出して受け取る
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                scrollOffset = newOffset
                updateCompactState(for: newOffset)
            }
            // Heroと原点を揃えてフルブリード表示にする（本文はSafe Area内に収まる）
            .ignoresSafeArea(edges: .top)
        }
        .navigationTitle(isCompact ? recipe.title : "")
        .toolbarBackground(isCompact ? .visible : .hidden, for: .navigationBar)
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

    // MARK: - Private Function

    // Compact Title表示をヒステリシス付きで更新（閾値付近の点滅を避ける）。
    // Reduce Motion時はアニメーションを付けない。
    private func updateCompactState(for offset: CGFloat) {
        let progress = RecipeHeroMetrics.make(
            scrollOffset: offset,
            expandedHeight: Self.heroHeight
        ).collapseProgress
        let next = RecipeHeroMetrics.compactTitleVisible(
            collapseProgress: progress,
            isCurrentlyCompact: isCompact
        )
        guard next != isCompact else { return }
        if reduceMotion {
            isCompact = next
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { isCompact = next }
        }
    }
}

// MARK: - RecipeDetailContent

// 本文（スクロール量に依存しない）。別Viewに切り出すことで、スクロール中に
// scrollOffsetが変化しても本文のbodyが再評価されないようにする（材料・手順の再描画を避ける）。
// Snapshotテストから同期的に検証できるようinternalにしている（挙動は不変）。
struct RecipeDetailContent: View {

    let recipe: Recipe
    let mealLogs: [MealLogSummary]
    let onAddTap: () -> Void

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            metaRow

            Divider()
            RecipeIngredientSectionView(ingredients: recipe.ingredients, servings: recipe.servings)

            Divider()
            RecipeInstructionSectionView(steps: recipe.steps)

            Divider()
            mealLogSection

            addMealLogButton
        }
        .padding(16)
    }

    private var metaRow: some View {
        HStack(spacing: 20) {
            Label("\(recipe.cookingMinutes)分", systemImage: "clock")
            Label("\(recipe.servings)人分", systemImage: "person.2")
            Label("\(recipe.calories)kcal", systemImage: "flame")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var mealLogSection: some View {
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

    private var addMealLogButton: some View {
        Button(action: onAddTap) {
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
