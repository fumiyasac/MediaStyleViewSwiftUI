//
//  CachedRecipeRepositoryTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// CachedRecipeRepository の調停ロジック（Network-first + Cacheフォールバック）を検証する。
// 実APIへは接続せず、Fake Remote + ファイルStore + 固定Clockを使う。

@testable import AppFeature
import Foundation
import Testing

@Suite("Cached Recipe Repository: Remote/Cache 調停")
struct CachedRecipeRepositoryTests {

    private let t0 = CacheFixture.date(2026, 10, 30, 12)
    private var t0Plus25h: Date { t0.addingTimeInterval(25 * 60 * 60) }   // Stale
    private var t0Plus40d: Date { t0.addingTimeInterval(40 * 24 * 60 * 60) } // Expired

    private func makeRepo(
        remote: FakeRemoteRepository,
        store: FileRecipeCacheStore,
        now: Date
    ) -> CachedRecipeRepository {
        CachedRecipeRepository(remote: remote, store: store, policy: .standard, now: { now })
    }

    private let range = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

    // 16. Remote成功でキャッシュが更新される
    @Test("Remote成功で最新を返しキャッシュへ保存する")
    func remoteSuccessUpdatesCache() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        let repo = makeRepo(remote: remote, store: store, now: t0)

        let result = try await repo.loadDailyEntries(in: range)
        #expect(result.origin == .remote)
        #expect(result.entries.count == 1)
        // キャッシュへ保存されている
        let record = await store.loadDailyEntries(rangeKey: "2026-10-01_2026-10-31")
        #expect(record?.payload.count == 1)
    }

    // 17. キャッシュあり・Remote失敗 → Stale表示
    @Test("キャッシュあり・Remote失敗でStaleキャッシュを返す")
    func cacheServedOnNetworkFailure() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        // 1回目: 成功してキャッシュ
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: range)
        // 2回目: 通信障害 + 25時間後（Stale）
        await remote.setFailure(.network(message: "offline"))
        let result = try await makeRepo(remote: remote, store: store, now: t0Plus25h).loadDailyEntries(in: range)

        #expect(result.entries.count == 1)
        if case let .cache(_, isStale) = result.origin {
            #expect(isStale == true)
        } else {
            Issue.record("cache origin であるべき")
        }
    }

    // 18. キャッシュなし・Remote失敗 → エラー
    @Test("キャッシュなし・Remote失敗はエラーを伝搬する")
    func errorWhenNoCache() async {
        let remote = FakeRemoteRepository(failure: .timeout)
        let store = CacheFixture.makeStore()
        let repo = makeRepo(remote: remote, store: store, now: t0)

        await #expect(throws: APIClientError.timeout) {
            _ = try await repo.loadDailyEntries(in: range)
        }
    }

    // 19. 正常な空配列をキャッシュできる（空月を後で補完しない）
    @Test("正常な空結果をキャッシュし、オフラインでも空として返す")
    func cachesEmptyResult() async throws {
        let remote = FakeRemoteRepository(entries: []) // この範囲は掲載0件
        let store = CacheFixture.makeStore()
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: range)

        await remote.setFailure(.network(message: "offline"))
        let result = try await makeRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)).loadDailyEntries(in: range)
        #expect(result.entries.isEmpty)
        #expect(result.origin.isCache)
    }

    // 20. HTTP 404 をオフライン障害と混同しない（詳細はnil=not found、Staleを出さない）
    @Test("404はオフライン障害と混同せずnil(not found)を返す")
    func notFoundIsNotOffline() async throws {
        let recipe = CacheFixture.recipe("recipe-01")
        let remote = FakeRemoteRepository(recipesByID: ["recipe-01": recipe])
        let store = CacheFixture.makeStore()
        // 1回目: 詳細を取得してキャッシュ
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadRecipe(for: RecipeID("recipe-01"))
        // サーバーから消えた(404=nil)。オフラインではないので古い詳細を出さずnilを返す。
        await remote.setRecipe(nil, for: "recipe-01")
        let result = try await makeRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)).loadRecipe(for: RecipeID("recipe-01"))
        #expect(result == nil)
    }

    // 21. Decoding Errorをキャッシュで黙って隠さない
    @Test("Decoding Errorはキャッシュで隠さず伝搬する")
    func decodingErrorNotHidden() async throws {
        let remote = FakeRemoteRepository(recipes: [CacheFixture.recipe("recipe-01")])
        let store = CacheFixture.makeStore()
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadAllRecipes() // キャッシュ作成
        await remote.setFailure(.decoding(message: "broken"))

        await #expect {
            _ = try await makeRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)).loadAllRecipes()
        } throws: { error in
            if case APIClientError.decoding = error { return true }
            return false
        }
    }

    // 22. Cancellationはフォールバックを起こさない
    @Test("CancellationはCacheフォールバックを起こさず伝搬する")
    func cancellationDoesNotFallBack() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: range) // キャッシュあり
        await remote.setCancellation(true)

        await #expect(throws: CancellationError.self) {
            _ = try await makeRepo(remote: remote, store: store, now: t0.addingTimeInterval(60)).loadDailyEntries(in: range)
        }
    }

    // 23. 古い通信結果が新しいキャッシュを上書きしない
    @Test("古い取得結果が新しいキャッシュを上書きしない")
    func olderResultDoesNotOverwrite() async throws {
        let store = CacheFixture.makeStore()
        // 新: entries=[10-04] を t0+1時間 で保存
        let newer = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        _ = try await makeRepo(remote: newer, store: store, now: t0.addingTimeInterval(3600)).loadDailyEntries(in: range)
        // 旧: entries=[10-20] を t0(より古い) で保存しようとする → Storeが拒否
        let older = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-20")])
        _ = try await makeRepo(remote: older, store: store, now: t0).loadDailyEntries(in: range)

        // オフラインで確認 → 新しい方(10-04)が残っている
        let offline = FakeRemoteRepository(failure: .network(message: "offline"))
        let result = try await makeRepo(remote: offline, store: store, now: t0.addingTimeInterval(7200)).loadDailyEntries(in: range)
        #expect(result.entries.map(\.dateKey.value) == ["2026-10-04"])
    }

    // 補足. Expired(期限超過)キャッシュはフォールバックに使わない
    @Test("期限超過キャッシュはフォールバックに使わずエラーにする")
    func expiredCacheNotUsed() async throws {
        let remote = FakeRemoteRepository(entries: [CacheFixture.entry("2026-10-04")])
        let store = CacheFixture.makeStore()
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadDailyEntries(in: range)
        await remote.setFailure(.network(message: "offline"))

        await #expect(throws: APIClientError.self) {
            _ = try await makeRepo(remote: remote, store: store, now: t0Plus40d).loadDailyEntries(in: range)
        }
    }

    // 補足. 概要のみ保存の詳細はDetailフォールバックに使わない（完全性）
    @Test("概要のみのキャッシュは詳細フォールバックに使わない")
    func summaryNotServedAsDetail() async throws {
        // 一覧取得で概要(hasDetail=false)を保存
        let remote = FakeRemoteRepository(recipes: [CacheFixture.recipe("recipe-01")])
        let store = CacheFixture.makeStore()
        _ = try await makeRepo(remote: remote, store: store, now: t0).loadAllRecipes()
        // 詳細取得がオフライン → 概要は詳細として使えずエラー
        let offline = FakeRemoteRepository(failure: .network(message: "offline"))
        await #expect(throws: APIClientError.self) {
            _ = try await makeRepo(remote: offline, store: store, now: t0.addingTimeInterval(60)).loadRecipe(for: RecipeID("recipe-01"))
        }
    }
}
