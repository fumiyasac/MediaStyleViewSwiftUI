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
    // Remote由来の2取得(一覧・掲載)を合成した取得元。既定は.remote。
    let origin: RecipeDataOrigin

    init(
        dailyEntries: [DailyRecipeEntry],
        mealLogs: [MealLogSummary],
        recipes: [Recipe],
        origin: RecipeDataOrigin = .remote
    ) {
        self.dailyEntries = dailyEntries
        self.mealLogs = mealLogs
        self.recipes = recipes
        self.origin = origin
    }

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
        // レシピMaster(名称解決用)・期間内の掲載割当・期間内の調理記録を並行取得する。
        // 掲載割当は範囲取得(dailyEntries(in:))で期間限定して取得する。
        // Remote実装ではこれがCalendar API(from/to=期間)の1リクエストになり、全期間を取りに行かない。
        // recipesはTimeline行のタイトル解決に使う名称辞書(Recipe概要)。Remoteでも一覧APIの
        // ページング1系統で取得でき、掲載件数ぶんの詳細取得(N+1)は発生させない。
        // 取得元(最新/キャッシュ)は一覧・掲載の2取得を合成し、どちらかがキャッシュなら全体をキャッシュ扱いにする。
        async let recipesResult = loadRecipes()
        async let entriesResult = loadEntries(in: range)
        async let logsResult = mealLogRepository.summaries(in: range)

        let (recipes, recipesOrigin) = try await recipesResult
        let (dailyEntries, entriesOrigin) = try await entriesResult
        let mealLogs = try await logsResult
        let origin = RecipeDataOrigin.combined(recipesOrigin, entriesOrigin)

        return TimelinePayload(dailyEntries: dailyEntries, mealLogs: mealLogs, recipes: recipes, origin: origin)
    }

    // 取得元(origin)付きでレシピ一覧を取得する（キャッシュ対応なら出所付き、そうでなければ.remote）。
    private func loadRecipes() async throws -> (recipes: [Recipe], origin: RecipeDataOrigin) {
        if let cacheAware = recipeRepository as? CacheAwareRecipeReading {
            let result = try await cacheAware.loadAllRecipes()
            return (result.recipes, result.origin)
        }
        return (try await recipeRepository.allRecipes(), .remote)
    }

    // 取得元(origin)付きで期間内の掲載割当を取得する。
    private func loadEntries(
        in range: ClosedRange<DateKey>
    ) async throws -> (entries: [DailyRecipeEntry], origin: RecipeDataOrigin) {
        if let cacheAware = recipeRepository as? CacheAwareRecipeReading {
            let result = try await cacheAware.loadDailyEntries(in: range)
            return (result.entries, result.origin)
        }
        return (try await recipeRepository.dailyEntries(in: range), .remote)
    }
}
