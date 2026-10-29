//
//  CacheLiveIntegrationTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// オプトインの統合テスト。稼働中のGo API(localhost:8080)で「正常取得→キャッシュ保存→オフラインで
// 保存済みを表示」を一気通貫で検証する。オフラインは到達不能ポートで代替し、Dockerを止めずに再現する。
//
// 既定無効。TEST_RUNNER_RUN_REMOTE_INTEGRATION=1 のときだけ実行する（通常のUnit Test実行を失敗させない）。

@testable import AppFeature
import Foundation
import Testing

@Suite("Cache 統合: 実API + オフライン（オプトイン）")
struct CacheLiveIntegrationTests {

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_REMOTE_INTEGRATION"] == "1"
    }

    private let octRange = DateKey(value: "2026-10-01")...DateKey(value: "2026-10-31")

    private func liveRemote() -> RemoteRecipeRepository {
        RemoteRecipeRepository(
            apiClient: APIClient(configuration: .localDevelopment, httpClient: URLSessionHTTPClient())
        )
    }

    // 到達不能な接続先でオフラインを再現する（connection refused → network → フォールバック）。
    private func deadRemote() -> RemoteRecipeRepository {
        RemoteRecipeRepository(
            apiClient: APIClient(
                configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:1")!, timeout: 2),
                httpClient: URLSessionHTTPClient()
            )
        )
    }

    @Test("実API取得→キャッシュ→オフラインで保存済みを表示", .enabled(if: Self.isEnabled))
    func cachesThenServesOffline() async throws {
        let store = CacheFixture.makeStore(namespace: "live")

        // オンライン: 実APIから取得しキャッシュへ保存
        let online = CachedRecipeRepository(remote: liveRemote(), store: store)
        let first = try await online.loadDailyEntries(in: octRange)
        #expect(first.origin == .remote)
        #expect(!first.entries.isEmpty)

        // オフライン: 到達不能 → 保存済みキャッシュを返す
        let offline = CachedRecipeRepository(remote: deadRemote(), store: store)
        let second = try await offline.loadDailyEntries(in: octRange)
        #expect(second.origin.isCache)
        #expect(second.entries.count == first.entries.count)
    }

    @Test("実APIで詳細取得→オフラインで材料・手順を表示", .enabled(if: Self.isEnabled))
    func cachesDetailThenServesOffline() async throws {
        let store = CacheFixture.makeStore(namespace: "live-detail")

        let online = CachedRecipeRepository(remote: liveRemote(), store: store)
        let first = try await online.loadRecipe(for: RecipeID("recipe-01"))
        #expect(first?.origin == .remote)
        #expect(first?.recipe.ingredients.isEmpty == false)

        let offline = CachedRecipeRepository(remote: deadRemote(), store: store)
        let second = try await offline.loadRecipe(for: RecipeID("recipe-01"))
        #expect(second?.origin.isCache == true)
        #expect(second?.recipe.steps == first?.recipe.steps)
    }
}
