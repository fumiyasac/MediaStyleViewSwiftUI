//
//  RemoteRecipeIntegrationTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// 明示オプトインの Integration Test。実際に稼働中の Go Backend(localhost:8080)へ接続して検証する。
//
// 既定では無効（.enabled(if:)）。環境変数 RUN_REMOTE_INTEGRATION=1 のときだけ実行する。
// これにより、API が起動していない通常の Unit Test 実行を失敗させない
// （API 未起動＝「未検証」として扱い、落とさない）。
//
// 実行方法（xcodebuild は TEST_RUNNER_ 接頭辞付き変数を接頭辞を外して Simulator のテストプロセスへ渡す）:
//   TEST_RUNNER_RUN_REMOTE_INTEGRATION=1 xcodebuild test -scheme AppFeature \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//     -only-testing:AppFeatureTests/RemoteRecipeIntegrationTests

@testable import AppFeature
import Foundation
import Testing

@Suite("Remote 統合: 実 API 接続（オプトイン）")
struct RemoteRecipeIntegrationTests {

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_REMOTE_INTEGRATION"] == "1"
    }

    private func makeRepository() -> RemoteRecipeRepository {
        RemoteRecipeRepository(
            apiClient: APIClient(
                configuration: .localDevelopment,
                httpClient: URLSessionHTTPClient()
            )
        )
    }

    @Test("実 API から一覧を取得できる", .enabled(if: Self.isEnabled))
    func fetchesAllRecipes() async throws {
        let recipes = try await makeRepository().allRecipes()
        #expect(!recipes.isEmpty)
    }

    @Test("実 API から詳細を取得できる", .enabled(if: Self.isEnabled))
    func fetchesRecipeDetail() async throws {
        let recipe = try await makeRepository().recipe(for: RecipeID("recipe-01"))
        #expect(recipe != nil)
        #expect(recipe?.ingredients.isEmpty == false)
    }

    @Test("実 API で存在しない ID は nil", .enabled(if: Self.isEnabled))
    func missingRecipeIsNil() async throws {
        let recipe = try await makeRepository().recipe(for: RecipeID("recipe-does-not-exist"))
        #expect(recipe == nil)
    }

    @Test("実 API からカレンダー割当を取得できる", .enabled(if: Self.isEnabled))
    func fetchesDailyEntries() async throws {
        let entries = try await makeRepository().dailyEntries(for: DateKey(value: "2026-10-04"))
        #expect(entries.allSatisfy { $0.dateKey == DateKey(value: "2026-10-04") })
    }

    // MARK: - UseCase 経由の E2E（ViewModelが実際に呼ぶ経路）

    // Calendar: loadMonth が Remote→Calendar API で当月の掲載データを返す（MealLogはInMemory）。
    @Test("実 API から Calendar UseCase が当月の掲載を取得できる", .enabled(if: Self.isEnabled))
    func calendarUseCaseLoadsMonth() async throws {
        let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let useCase = DefaultCalendarUseCase(
            recipeRepository: makeRepository(),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
            calendar: tokyo
        )
        let month = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 1))!

        let payload = try await useCase.loadMonth(month)

        // Seed期間(2026-10)の掲載が返り、すべて当月に収まる
        #expect(!payload.recipeEntries.isEmpty)
        #expect(payload.recipeEntries.allSatisfy { $0.dateKey.value.hasPrefix("2026-10") })
    }

    // Timeline: load が Remote Recipe(一覧)＋掲載(範囲)を統合して返す。
    @Test("実 API から Timeline UseCase が掲載とレシピを取得できる", .enabled(if: Self.isEnabled))
    func timelineUseCaseLoadsRange() async throws {
        let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let useCase = DefaultTimelineUseCase(
            recipeRepository: makeRepository(),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo)
        )
        let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

        let payload = try await useCase.load(in: range)

        #expect(!payload.recipes.isEmpty) // 名称解決用のレシピMaster
        #expect(!payload.dailyEntries.isEmpty) // 範囲内の掲載
        #expect(payload.dailyEntries.allSatisfy { range.contains($0.dateKey) })
    }
}
