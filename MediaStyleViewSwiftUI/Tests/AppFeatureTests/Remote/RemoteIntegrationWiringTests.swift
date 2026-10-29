//
//  RemoteIntegrationWiringTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/29.
//

// Phase 14: Remote統合の配線に関するテスト。
//  - Composition Rootの取得元選択(Fixture/Remote)
//  - Calendar/Timeline UseCaseが「必要な範囲だけ」をRepositoryへ要求する（範囲取得の配線）
//  - RemoteRecipeRepository.dailyEntries(in:)がCalendar APIへ範囲(from/to)で問い合わせる
//  - RecipeRepository.dailyEntries(in:)の既定実装（全件→範囲フィルタ）
//  - Recipe Detailの再試行（失敗→再読み込みで成功）
// 実APIには接続せず、Fake HTTPClient / 記録用Fake Repositoryで検証する。

@testable import AppFeature
import Foundation
import Testing

// MARK: - Recording Fake

// dailyEntries(in:)へ渡された範囲を記録するFake。Swift6並行性のためactorで可変状態を隔離する。
private actor RecordingRecipeRepository: RecipeRepository {

    private(set) var rangeCalls: [ClosedRange<DateKey>] = []
    private let entries: [DailyRecipeEntry]
    private let recipes: [Recipe]

    init(entries: [DailyRecipeEntry], recipes: [Recipe] = []) {
        self.entries = entries
        self.recipes = recipes
    }

    func allRecipes() async throws -> [Recipe] { recipes }
    func recipe(for id: RecipeID) async throws -> Recipe? { recipes.first { $0.id == id } }
    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] {
        entries.filter { $0.dateKey == dateKey }
    }
    func allDailyEntries() async throws -> [DailyRecipeEntry] { entries }

    // 範囲取得をoverrideして呼び出し範囲を記録する（UseCaseが範囲指定で呼ぶことの検証用）
    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry] {
        rangeCalls.append(range)
        return entries.filter { range.contains($0.dateKey) }
    }
}

private func entry(_ dateKey: String, recipe: String = "recipe-01") -> DailyRecipeEntry {
    DailyRecipeEntry(
        id: DailyRecipeEntryID("daily-\(dateKey)-\(recipe)"),
        dateKey: DateKey(value: dateKey),
        recipeID: RecipeID(recipe)
    )
}

// MARK: - Composition Root: 取得元選択

@Suite("Composition Root: 取得元の選択")
struct RecipeDataSourceWiringTests {

    // 1. 既定の取得元はFixture
    @Test("既定の取得元は fixture")
    func defaultIsFixture() {
        #expect(RecipeDataSource.default == .fixture)
    }

    // 2. fixture選択でFixtureRecipeRepositoryが組み立てられる
    @Test("fixture選択で FixtureRecipeRepository を使う")
    func fixtureBuildsFixtureRepository() {
        let repository = CalendarFeatureDependencies.makeRecipeRepository(for: .fixture)
        #expect(repository is FixtureRecipeRepository)
    }

    // 3. remote選択では、永続キャッシュで包んだCachedRecipeRepositoryが組み立てられる
    //    （Remoteを直接返さず、オフライン時に保存済みデータを使えるようにする）。
    @Test("remote選択で CachedRecipeRepository(Remoteをキャッシュで内包) を使う")
    func remoteBuildsCachedRepository() {
        let repository = CalendarFeatureDependencies.makeRecipeRepository(for: .remote)
        #expect(repository is CachedRecipeRepository)
    }

    // 4. inMemory()はFixture構成（Preview/Test既定）
    @Test("inMemory 構成は Fixture を使う")
    func inMemoryUsesFixture() {
        let dependencies = CalendarFeatureDependencies.inMemory()
        #expect(dependencies.recipeRepository is FixtureRecipeRepository)
    }

    // 5. 文字列からRecipeDataSourceへ復元できる（Scheme環境変数の解釈）
    @Test("環境変数文字列から RecipeDataSource を解釈できる")
    func parsesFromRawValue() {
        #expect(RecipeDataSource(rawValue: "fixture") == .fixture)
        #expect(RecipeDataSource(rawValue: "remote") == .remote)
        #expect(RecipeDataSource(rawValue: "unknown") == nil)
    }

    // 6. 環境変数が無ければ既定(.fixture)へ解決する
    @Test("環境変数なしでは fixture に解決する")
    func resolvesDefaultWithoutEnv() {
        let resolved = CalendarFeatureDependencies.resolvedDataSource(environment: [:])
        #expect(resolved == .fixture)
    }

    // 7. Debugでは RECIPE_DATA_SOURCE=remote で remote に解決する
    //    （テストはDebugビルドで走るため #if DEBUG 経路が有効）
    @Test("RECIPE_DATA_SOURCE=remote で remote に解決する(Debug)")
    func resolvesRemoteFromEnv() {
        let resolved = CalendarFeatureDependencies.resolvedDataSource(
            environment: ["RECIPE_DATA_SOURCE": "remote"]
        )
        #expect(resolved == .remote)
    }

    // 8. 不正な値は既定(.fixture)へフォールバックする
    @Test("不正な RECIPE_DATA_SOURCE は fixture に解決する")
    func resolvesDefaultForInvalidEnv() {
        let resolved = CalendarFeatureDependencies.resolvedDataSource(
            environment: ["RECIPE_DATA_SOURCE": "nope"]
        )
        #expect(resolved == .fixture)
    }
}

// MARK: - UseCaseの範囲取得配線

@Suite("UseCase: 必要な範囲だけを要求する")
struct RangeScopedFetchTests {

    private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

    // 6. CalendarUseCase.loadMonthは当月の閉区間でdailyEntries(in:)を呼ぶ（全期間を取りに行かない）
    @Test("Calendar: loadMonth は当月範囲で掲載割当を要求する")
    func calendarRequestsMonthRange() async throws {
        let repository = RecordingRecipeRepository(entries: [
            entry("2026-10-04"), entry("2026-09-30"), entry("2026-11-01"),
        ])
        let useCase = DefaultCalendarUseCase(
            recipeRepository: repository,
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
            calendar: tokyo
        )
        let month = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 15))!

        let payload = try await useCase.loadMonth(month)

        let calls = await repository.rangeCalls
        #expect(calls.count == 1)
        #expect(calls.first?.lowerBound == DateKey(value: "2026-10-01"))
        #expect(calls.first?.upperBound == DateKey(value: "2026-10-31"))
        // 当月(10月)の1件だけが返る（9月末・11月頭は範囲外）
        #expect(payload.recipeEntries.map(\.dateKey.value) == ["2026-10-04"])
    }

    // 7. TimelineUseCase.loadは与えられた範囲でdailyEntries(in:)を呼ぶ
    @Test("Timeline: load は指定範囲で掲載割当を要求する")
    func timelineRequestsGivenRange() async throws {
        let repository = RecordingRecipeRepository(
            entries: [entry("2026-10-04"), entry("2026-12-31")],
            recipes: [Recipe(id: RecipeID("recipe-01"), title: "t", summary: "s", category: .japanese, cookingMinutes: 1, calories: 1, servings: 1)]
        )
        let useCase = DefaultTimelineUseCase(
            recipeRepository: repository,
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo)
        )
        let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

        let payload = try await useCase.load(in: range)

        let calls = await repository.rangeCalls
        #expect(calls == [range])
        #expect(payload.dailyEntries.map(\.dateKey.value) == ["2026-10-04"])
    }
}

// MARK: - RemoteRecipeRepositoryの範囲取得

@Suite("Remote: dailyEntries(in:) は Calendar API を範囲で呼ぶ")
struct RemoteRangeFetchTests {

    private let configuration = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)

    // 8. dailyEntries(in:)は from=範囲下限 / to=範囲上限 で /calendar を1回呼ぶ
    @Test("範囲の下限/上限を from/to に載せて calendar を1回呼ぶ")
    func callsCalendarWithRange() async throws {
        let recorder = RequestRecorder()
        let repository = RemoteRecipeRepository(
            apiClient: APIClient(
                configuration: configuration,
                httpClient: FakeHTTPClient(recorder: recorder) { _ in
                    HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.calendar.utf8))
                }
            )
        )
        let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

        _ = try await repository.dailyEntries(in: range)

        #expect(await recorder.count == 1)
        let url = try #require(await recorder.last?.url)
        #expect(url.path == "/api/v1/calendar")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "from", value: "2026-10-01")))
        #expect(items.contains(URLQueryItem(name: "to", value: "2026-10-31")))
    }
}

// MARK: - 既定実装（全件→範囲フィルタ）

@Suite("RecipeRepository: dailyEntries(in:) の既定実装")
struct DefaultRangeFilterTests {

    private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

    // 9. Fixtureは既定実装を使い、範囲外の掲載を除外して返す
    @Test("Fixture は全件を範囲で絞り込む（既定実装）")
    func fixtureFiltersByRange() async throws {
        let reference = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let fixture = FixtureRecipeRepository(referenceDate: reference, calendar: tokyo)

        let all = try await fixture.allDailyEntries()
        let narrow = DateKey(value: "2026-10-15")...DateKey(value: "2026-10-15")
        let filtered = try await fixture.dailyEntries(in: narrow)

        // 結果はすべて範囲内で、全件以下
        #expect(filtered.allSatisfy { narrow.contains($0.dateKey) })
        #expect(filtered.count <= all.count)
    }
}

// MARK: - Recipe Detail 再試行

// 1回目の取得は失敗し、2回目以降は成功するFake（再試行の検証用）。
private actor FlakyRecipeRepository: RecipeRepository {
    private var attempts = 0
    private let recipe: Recipe

    init(recipe: Recipe) { self.recipe = recipe }

    func allRecipes() async throws -> [Recipe] { [recipe] }
    func allDailyEntries() async throws -> [DailyRecipeEntry] { [] }
    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] { [] }

    func recipe(for id: RecipeID) async throws -> Recipe? {
        attempts += 1
        if attempts == 1 {
            throw APIClientError.timeout // 初回は通信失敗
        }
        return recipe
    }
}

@MainActor
@Suite("Recipe Detail: 失敗後の再試行")
struct RecipeDetailRetryTests {

    // 10. 初回失敗→再度load()で成功する（保存済み状態や他取得をやり直す必要はない）
    @Test("失敗後に再読み込みで成功状態へ遷移する")
    func retrySucceedsAfterFailure() async throws {
        let recipe = Recipe(
            id: RecipeID("recipe-01"), title: "鮭の塩麹焼き", summary: "s",
            category: .japanese, cookingMinutes: 25, calories: 320, servings: 2,
            ingredients: ["塩麹"], steps: ["焼く"]
        )
        let viewModel = RecipeDetailViewModel(
            recipeID: RecipeID("recipe-01"),
            recipeRepository: FlakyRecipeRepository(recipe: recipe),
            mealLogRepository: InMemoryMealLogRepository()
        )

        viewModel.load()
        await viewModel.loadTask?.value
        guard case .failed = viewModel.state else {
            Issue.record("初回は失敗状態になるべき")
            return
        }

        // 再試行
        viewModel.load()
        await viewModel.loadTask?.value
        #expect(viewModel.state.recipe?.id == RecipeID("recipe-01"))
    }
}
