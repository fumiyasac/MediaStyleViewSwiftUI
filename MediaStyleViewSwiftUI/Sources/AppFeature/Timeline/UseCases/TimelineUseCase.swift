//
//  TimelineUseCase.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 指定期間のレシピ掲載と調理記録をまとめて取得するUseCase。
// Timeline専用Repositoryは作らず、既存のRecipeRepository/MealLogRepositoryを組み合わせる。
// SwiftData EntityではなくSendableなDomain Model(DailyRecipeEntry/MealLogSummary/Recipe)だけを扱い、
// 取得はasync letで並行実行する。掲載日と調理日は別物のまま保持し、表示層で区別する。

import Foundation

// MARK: - TimelinePayload

// 期間内の生データ。表示用への変換(ViewData化・グルーピング)はPresentation層のFactoryが行う。
struct TimelinePayload: Sendable, Equatable {
    let dailyEntries: [DailyRecipeEntry]
    let mealLogs: [MealLogSummary]
    let recipes: [Recipe]

    static let empty = TimelinePayload(dailyEntries: [], mealLogs: [], recipes: [])
}

// MARK: - TimelineUseCase

protocol TimelineUseCase: Sendable {

    // 指定した暦日キーの期間(閉区間)に含まれる掲載レシピ・調理記録と、名称解決用のレシピMasterをまとめPayloadで返す
    func load(in range: ClosedRange<DateKey>) async throws -> TimelinePayload
}

// MARK: - DefaultTimelineUseCase

struct DefaultTimelineUseCase: TimelineUseCase {

    // MARK: - Property

    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository

    // MARK: - Initializer

    init(recipeRepository: any RecipeRepository, mealLogRepository: any MealLogRepository) {
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
    }

    // MARK: - TimelineUseCase

    func load(in range: ClosedRange<DateKey>) async throws -> TimelinePayload {
        // レシピMaster・全掲載割当・期間内の調理記録を並行取得する
        async let recipesResult = recipeRepository.allRecipes()
        async let entriesResult = recipeRepository.allDailyEntries()
        async let logsResult = mealLogRepository.summaries(in: range)

        let recipes = try await recipesResult
        let dailyEntries = try await entriesResult.filter { range.contains($0.dateKey) }
        let mealLogs = try await logsResult

        return TimelinePayload(dailyEntries: dailyEntries, mealLogs: mealLogs, recipes: recipes)
    }
}
