//
//  RecipeDetailViewModel.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Recipe Detailの@MainActor ViewModel。
// Recipe(Domain Model)はRecipeRepositoryから取得し、SwiftData Entityへは移行しない。
// このレシピの調理記録(MealLogSummary)も併せて取得して概要表示する。
// 読込状態は loading/loaded/failed の3値で表し、重要な遷移を明示する。
// 保存成功通知(didSaveMealLog)を受けたら、再取得せずに手持ちの記録へ反映する。

import Foundation
import Observation

// MARK: - RecipeDetailState

enum RecipeDetailState: Equatable, Sendable {
    case loading
    case loaded(recipe: Recipe, mealLogs: [MealLogSummary])
    case failed(message: String)

    var recipe: Recipe? {
        if case let .loaded(recipe, _) = self { return recipe }
        return nil
    }

    var mealLogs: [MealLogSummary] {
        if case let .loaded(_, logs) = self { return logs }
        return []
    }
}

// MARK: - RecipeDetailViewModel

@MainActor
@Observable
final class RecipeDetailViewModel {

    // MARK: - Property

    private(set) var state: RecipeDetailState = .loading

    private let recipeID: RecipeID
    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository

    private(set) var loadTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        recipeID: RecipeID,
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository
    ) {
        self.recipeID = recipeID
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
    }

    // MARK: - Function

    // レシピ本体とこのレシピの調理記録を取得する。存在しないIDはエラー状態にする。
    func load() {
        loadTask?.cancel()
        let recipeID = self.recipeID
        let recipeRepository = self.recipeRepository
        let mealLogRepository = self.mealLogRepository
        loadTask = Task { [weak self] in
            do {
                async let recipeResult = recipeRepository.recipe(for: recipeID)
                async let allLogs = mealLogRepository.allSummaries()
                guard let recipe = try await recipeResult else {
                    try Task.checkCancellation()
                    self?.state = .failed(message: "レシピが見つかりませんでした")
                    return
                }
                let mealLogs = try await allLogs
                    .filter { $0.recipeID == recipeID }
                    .sorted { $0.cookedAt > $1.cookedAt }
                try Task.checkCancellation()
                self?.state = .loaded(recipe: recipe, mealLogs: mealLogs)
            } catch is CancellationError {
                // キャンセルはエラー表示にしない
            } catch {
                if Task.isCancelled { return }
                self?.state = .failed(message: error.localizedDescription)
            }
        }
    }

    // 調理記録の保存成功を手持ちの一覧へ反映する（このレシピのものだけ・同一idは重複させない）
    func didSaveMealLog(_ summary: MealLogSummary) {
        guard case let .loaded(recipe, logs) = state, summary.recipeID == recipeID else { return }
        var newLogs = logs.filter { $0.id != summary.id }
        newLogs.append(summary)
        newLogs.sort { $0.cookedAt > $1.cookedAt }
        state = .loaded(recipe: recipe, mealLogs: newLogs)
    }
}
