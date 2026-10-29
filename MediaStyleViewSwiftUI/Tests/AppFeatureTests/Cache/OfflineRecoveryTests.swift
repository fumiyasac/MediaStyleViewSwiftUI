//
//  OfflineRecoveryTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// Calendar / Timeline / Recipe Detail のオフライン表示とAPI復旧・Retryを、UseCase/ViewModel層で検証する。
// 実APIへは接続しない（Fake Remote + ファイルStore + InMemory MealLog）。

@testable import AppFeature
import Foundation
import Testing

private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

private func cachedRepo(
    remote: FakeRemoteRepository,
    store: FileRecipeCacheStore,
    now: Date
) -> CachedRecipeRepository {
    CachedRecipeRepository(remote: remote, store: store, policy: .standard, now: { now })
}

// MARK: - Calendar / Timeline / Detail offline (24-30)

@Suite("オフライン表示: Calendar / Timeline / Detail")
struct OfflineViewingTests {

    private let t0 = CacheFixture.date(2026, 10, 30, 12)
    private let octRange = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

    // 24. Calendarの取得済み月をオフライン表示できる
    @Test("Calendar: 取得済み月をオフラインで表示できる")
    func calendarMonthOffline() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        let month = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 1))!

        // オンラインで取得（キャッシュ化）
        _ = try await DefaultCalendarUseCase(
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
            calendar: tokyo
        ).loadMonth(month)

        // オフライン
        await remote.setFailure(.network(message: "offline"))
        let payload = try await DefaultCalendarUseCase(
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
            calendar: tokyo
        ).loadMonth(month)

        #expect(payload.recipeEntries.count == 1)
        #expect(payload.origin.isCache)
    }

    // 25. 未取得月を正常な空月として扱わない（エラーにする）
    @Test("Calendar: 未取得月のオフラインは空扱いせずエラー")
    func calendarUnfetchedMonthErrors() async {
        let remote = FakeRemoteRepository(failure: .network(message: "offline"))
        let store = CacheFixture.makeStore()
        let month = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 1))!

        await #expect(throws: APIClientError.self) {
            _ = try await DefaultCalendarUseCase(
                recipeRepository: cachedRepo(remote: remote, store: store, now: t0),
                mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
                calendar: tokyo
            ).loadMonth(month)
        }
    }

    // 26. TimelineでCached RecipeとLocal MealLogを統合できる
    @Test("Timeline: Cached RecipeとLocal MealLogを統合する")
    func timelineCombinesCacheAndMealLog() async throws {
        let remote = FakeRemoteRepository(
            recipes: [CacheFixture.recipe("recipe-01", title: "鮭")],
            entries: [CacheFixture.entry("2026-10-04", recipe: "recipe-01")]
        )
        let store = CacheFixture.makeStore()
        let mealLog = InMemoryMealLogRepository(calendar: tokyo)
        _ = try await mealLog.add(
            MealLogInput(recipeID: RecipeID("recipe-01"), cookedAt: CacheFixture.date(2026, 10, 4, 19), rating: 5, memo: "美味", servings: 2)
        )

        // オンライン取得（キャッシュ化）
        _ = try await DefaultTimelineUseCase(
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0),
            mealLogRepository: mealLog
        ).load(in: octRange)

        // オフライン
        await remote.setFailure(.network(message: "offline"))
        let payload = try await DefaultTimelineUseCase(
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)),
            mealLogRepository: mealLog
        ).load(in: octRange)

        #expect(payload.recipes.contains { $0.id == RecipeID("recipe-01") }) // キャッシュのレシピ
        #expect(payload.dailyEntries.count == 1)                              // キャッシュの掲載
        #expect(payload.mealLogs.count == 1)                                  // ローカルの調理記録
        #expect(payload.origin.isCache)
    }

    // 27. Recipe Detailの保存済み材料・手順をオフライン表示できる
    @MainActor
    @Test("Recipe Detail: 保存済み詳細(材料・手順)をオフライン表示できる")
    func recipeDetailOffline() async throws {
        let recipe = CacheFixture.recipe("recipe-01", ingredients: ["鮭", "塩麹"], steps: ["漬ける", "焼く"])
        let remote = FakeRemoteRepository(recipesByID: ["recipe-01": recipe])
        let store = CacheFixture.makeStore()

        // オンラインで詳細取得（キャッシュ化）
        _ = try await cachedRepo(remote: remote, store: store, now: t0).loadRecipe(for: RecipeID("recipe-01"))

        // オフラインでViewModel経由表示
        await remote.setFailure(.network(message: "offline"))
        let viewModel = RecipeDetailViewModel(
            recipeID: RecipeID("recipe-01"),
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo)
        )
        viewModel.load()
        await viewModel.loadTask?.value

        #expect(viewModel.state.recipe?.ingredients == ["鮭", "塩麹"])
        #expect(viewModel.state.recipe?.steps == ["漬ける", "焼く"])
        #expect(viewModel.state.origin?.isCache == true)
    }

    // 28. API復旧後に最新Recipeへ更新できる
    @Test("復旧: 再取得で最新データへ更新される")
    func recoversToLatest() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()

        _ = try await cachedRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: octRange)
        // サーバー側データが変化
        await remote.setEntries([CacheFixture.entry("2026-10-04"), CacheFixture.entry("2026-10-10")])
        let result = try await cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(3600)).loadDailyEntries(in: octRange)

        #expect(result.entries.count == 2)
        #expect(result.origin == .remote)
    }

    // 29. キャッシュ削除後もMealLogが維持される
    @Test("キャッシュ削除してもMealLogは消えない")
    func cacheClearKeepsMealLog() async throws {
        let store = CacheFixture.makeStore()
        let mealLog = InMemoryMealLogRepository(calendar: tokyo)
        _ = try await mealLog.add(
            MealLogInput(recipeID: RecipeID("recipe-01"), cookedAt: CacheFixture.date(2026, 10, 4), rating: 4, memo: "", servings: 1)
        )
        await store.saveRecipeList([RecipeCacheMapper.toCached(CacheFixture.recipe("recipe-01"), hasDetail: false)], fetchedAt: t0)

        // キャッシュ全消去（ユーザーデータには触れない）
        await store.removeAll()

        #expect(await store.loadRecipeList() == nil)          // キャッシュは消えた
        let logs = try await mealLog.allSummaries()
        #expect(logs.count == 1)                              // MealLogは維持
    }

    // 30. Fixtureモードでは既存動作が変わらない（取得元は常に.remote＝注記なし）
    @Test("Fixture: 取得元は.remoteで従来どおり")
    func fixtureUnchanged() async throws {
        let month = tokyo.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let payload = try await DefaultCalendarUseCase(
            recipeRepository: FixtureRecipeRepository(referenceDate: CacheFixture.date(2026, 3, 15), calendar: tokyo),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo),
            calendar: tokyo
        ).loadMonth(month)
        #expect(payload.origin == .remote)
    }
}

// MARK: - Error Recovery (31-34)

@MainActor
@Suite("Error Recovery: Retry と State")
struct ErrorRecoveryTests {

    private let t0 = CacheFixture.date(2026, 10, 30, 12)

    // 31 & 32. 初回オフライン(キャッシュなし)で失敗 → 復旧後Retryでloadedへ
    @Test("Timeline: 失敗後のRetryでエラーが解消される")
    func timelineRetryResolvesError() async throws {
        let remote = FakeRemoteRepository(failure: .network(message: "offline"))
        let store = CacheFixture.makeStore()
        let useCase = DefaultTimelineUseCase(
            recipeRepository: cachedRepo(remote: remote, store: store, now: t0),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyo)
        )
        let viewModel = TimelineViewModel(useCase: useCase, referenceDate: t0, calendar: tokyo)

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        #expect(viewModel.state.errorMessage != nil) // キャッシュ無し・失敗 → エラー

        // 復旧
        await remote.setFailure(nil)
        await remote.setRecipes([CacheFixture.recipe("recipe-01")])
        viewModel.send(.reload)
        await viewModel.loadTask?.value
        #expect(viewModel.state.errorMessage == nil)
        #expect(viewModel.state.origin == .remote)
    }

    // 33. Retry失敗時に既存キャッシュが失われない
    @Test("Retry失敗を繰り返してもキャッシュは失われない")
    func failedRetriesKeepCache() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")
        _ = try await cachedRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: range)

        await remote.setFailure(.network(message: "offline"))
        // 複数回オフラインでも毎回Staleキャッシュを返す（消えない）
        for i in 1...3 {
            let result = try await cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(Double(i) * 3600)).loadDailyEntries(in: range)
            #expect(result.entries.count == 1)
            #expect(result.origin.isCache)
        }
    }

    // 34. 複数回のRetryでもリクエストが不必要に増えない（1取得=1リモート呼び出し）
    @Test("1回のloadにつきRemote呼び出しは1回")
    func noRequestAmplification() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

        for i in 0..<3 {
            _ = try await cachedRepo(remote: remote, store: store, now: t0.addingTimeInterval(Double(i))).loadDailyEntries(in: range)
        }
        #expect(await remote.dailyEntriesCalls == 3) // 3回のloadで3回だけ
    }
}
