//
//  CacheTestSupport.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// キャッシュ系テストの共通ヘルパー。実Go APIへは接続せず、挙動を注入できるFake Remoteを使う。
// 保存先はテストごとに独立したTemporary Directory。固定日時を使い実時刻へ依存しない。

@testable import AppFeature
import Foundation

// MARK: - Builders

enum CacheFixture {

    static func recipe(
        _ id: String,
        title: String = "タイトル",
        category: RecipeCategory = .japanese,
        ingredients: [String] = ["材料A"],
        steps: [String] = ["手順1"]
    ) -> Recipe {
        Recipe(
            id: RecipeID(id),
            title: title,
            summary: "概要",
            category: category,
            cookingMinutes: 20,
            calories: 300,
            servings: 2,
            ingredients: ingredients,
            steps: steps
        )
    }

    static func entry(_ dateKey: String, recipe: String = "recipe-01") -> DailyRecipeEntry {
        DailyRecipeEntry(
            id: DailyRecipeEntryID("daily-\(dateKey)-\(recipe)"),
            dateKey: DateKey(value: dateKey),
            recipeID: RecipeID(recipe)
        )
    }

    // テストごとに独立したキャッシュ保存先を返す
    static func makeStore(namespace: String = "test") -> FileRecipeCacheStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipe-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return FileRecipeCacheStore(namespace: namespace, directoryRoot: root)
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d; components.hour = h
        let calendar = Calendar(identifier: .gregorian)
        var utc = calendar
        utc.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return utc.date(from: components)!
    }
}

// MARK: - Fake Remote

// 挙動を注入できるRecipeRepository。失敗(APIClientError)・キャンセル・成功値・呼び出し回数を制御する。
// RemoteRecipeRepositoryに倣い、recipe(for:)は「見つからない(404)」をnilで表す。
actor FakeRemoteRepository: RecipeRepository {

    private var recipes: [Recipe]
    private var entries: [DailyRecipeEntry]
    private var recipesByID: [String: Recipe]
    private var failure: APIClientError?
    private var throwsCancellation: Bool

    private(set) var allRecipesCalls = 0
    private(set) var dailyEntriesCalls = 0
    private(set) var recipeCalls = 0

    init(
        recipes: [Recipe] = [],
        entries: [DailyRecipeEntry] = [],
        recipesByID: [String: Recipe] = [:],
        failure: APIClientError? = nil,
        throwsCancellation: Bool = false
    ) {
        self.recipes = recipes
        self.entries = entries
        self.recipesByID = recipesByID
        self.failure = failure
        self.throwsCancellation = throwsCancellation
    }

    // MARK: - Control

    func setRecipes(_ value: [Recipe]) { recipes = value }
    func setEntries(_ value: [DailyRecipeEntry]) { entries = value }
    func setRecipe(_ recipe: Recipe?, for id: String) { recipesByID[id] = recipe }
    func setFailure(_ value: APIClientError?) { failure = value }
    func setCancellation(_ value: Bool) { throwsCancellation = value }

    // MARK: - RecipeRepository

    func allRecipes() async throws -> [Recipe] {
        allRecipesCalls += 1
        try failIfNeeded()
        return recipes
    }

    func recipe(for id: RecipeID) async throws -> Recipe? {
        recipeCalls += 1
        try failIfNeeded()
        return recipesByID[id.rawValue] // nil = 404 相当
    }

    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] {
        try failIfNeeded()
        return entries.filter { $0.dateKey == dateKey }
    }

    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry] {
        dailyEntriesCalls += 1
        try failIfNeeded()
        return entries.filter { range.contains($0.dateKey) }
    }

    func allDailyEntries() async throws -> [DailyRecipeEntry] {
        try failIfNeeded()
        return entries
    }

    // MARK: - Private

    private func failIfNeeded() throws {
        if throwsCancellation { throw CancellationError() }
        if let failure { throw failure }
    }
}
