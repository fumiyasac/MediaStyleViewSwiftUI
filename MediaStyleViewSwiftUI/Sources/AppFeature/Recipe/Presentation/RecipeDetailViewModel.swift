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
    case loaded(recipe: Recipe, mealLogs: [MealLogSummary], origin: RecipeDataOrigin)
    case failed(message: String)

    var recipe: Recipe? {
        if case let .loaded(recipe, _, _) = self { return recipe }
        return nil
    }

    var mealLogs: [MealLogSummary] {
        if case let .loaded(_, logs, _) = self { return logs }
        return []
    }

    // 詳細の取得元（最新/キャッシュ）。キャッシュ表示中であることの提示に使う。
    var origin: RecipeDataOrigin? {
        if case let .loaded(_, _, origin) = self { return origin }
        return nil
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
                // 取得元(最新/キャッシュ)付きでレシピ詳細を取得する。
                // キャッシュ対応Repositoryなら出所付きで読み、404は「見つからない」(nil)として扱う。
                // そうでなければ(Fixture/直Remote)最新(.remote)扱い。
                async let detailResult = Self.loadDetail(recipeID: recipeID, repository: recipeRepository)
                async let allLogs = mealLogRepository.allSummaries()
                guard let detail = try await detailResult else {
                    try Task.checkCancellation()
                    self?.state = .failed(message: "レシピが見つかりませんでした")
                    return
                }
                let mealLogs = try await allLogs
                    .filter { $0.recipeID == recipeID }
                    .sorted { $0.cookedAt > $1.cookedAt }
                try Task.checkCancellation()
                self?.state = .loaded(recipe: detail.recipe, mealLogs: mealLogs, origin: detail.origin)
            } catch is CancellationError {
                // キャンセルはエラー表示にしない
            } catch {
                if Task.isCancelled { return }
                self?.state = .failed(message: error.localizedDescription)
            }
        }
    }

    // 調理記録の保存成功を手持ちの一覧へ反映する（このレシピのものだけ・同一idは重複させない）。
    // 取得元(origin)は保存操作では変わらないため維持する。
    func didSaveMealLog(_ summary: MealLogSummary) {
        guard case let .loaded(recipe, logs, origin) = state, summary.recipeID == recipeID else { return }
        var newLogs = logs.filter { $0.id != summary.id }
        newLogs.append(summary)
        newLogs.sort { $0.cookedAt > $1.cookedAt }
        state = .loaded(recipe: recipe, mealLogs: newLogs, origin: origin)
    }

    // MARK: - Private

    // 取得元(origin)付きで詳細を読む。nilは「見つからない(404)」。キャッシュ対応でなければ.remote扱い。
    private static func loadDetail(
        recipeID: RecipeID,
        repository: any RecipeRepository
    ) async throws -> (recipe: Recipe, origin: RecipeDataOrigin)? {
        if let cacheAware = repository as? CacheAwareRecipeReading {
            guard let result = try await cacheAware.loadRecipe(for: recipeID) else { return nil }
            return (result.recipe, result.origin)
        }
        guard let recipe = try await repository.recipe(for: recipeID) else { return nil }
        return (recipe, .remote)
    }
}
