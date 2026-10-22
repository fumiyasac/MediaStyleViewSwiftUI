//
//  FixtureRecipeRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// RecipeRepositoryのFixture実装。レシピMasterと日別割当を固定データから返す。
// 生成時に基準日(referenceDate)とCalendarを受け取り、日別割当を決定的に組み立てて保持する。
// 不変な値(配列・辞書)しか持たないためstructのままSendableになる。

import Foundation

struct FixtureRecipeRepository: RecipeRepository {

    // MARK: - Property

    private let recipesByID: [RecipeID: Recipe]
    private let orderedRecipes: [Recipe]
    private let entries: [DailyRecipeEntry]
    // dateKeyでの引き当てを高速化するための索引
    private let entriesByDateKey: [DateKey: [DailyRecipeEntry]]

    // MARK: - Initializer

    // referenceDateを中心に±15日の割当を生成する。既定は現在時刻＝アプリ起動時の「今日」。
    // CalendarはDateKey生成に使うものを注入でき、テストではTZ・基準日を固定して決定的にする。
    init(
        referenceDate: Date = Date(),
        calendar: Calendar = DateKeyCalendar.default
    ) {
        let recipes = RecipeFixtureData.recipes
        self.orderedRecipes = recipes
        self.recipesByID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })

        let entries = RecipeFixtureData.dailyEntries(referenceDate: referenceDate, calendar: calendar)
        self.entries = entries
        self.entriesByDateKey = Dictionary(grouping: entries, by: \.dateKey)
    }

    // MARK: - RecipeRepository

    func allRecipes() async throws -> [Recipe] {
        orderedRecipes
    }

    func recipe(for id: RecipeID) async throws -> Recipe? {
        recipesByID[id]
    }

    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] {
        entriesByDateKey[dateKey] ?? []
    }

    func allDailyEntries() async throws -> [DailyRecipeEntry] {
        entries
    }
}
