//
//  DefaultPathCacheStoreTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 既定の保存先(Application Support)を使った場合でも保存/取得できることを検証する診断テスト。
// 通常テストはTemporary Directoryを注入するため、この経路は別途確認する。

@testable import AppFeature
import Foundation
import Testing

@Suite("Cache Store: 既定(Application Support)保存先")
struct DefaultPathCacheStoreTests {

    @Test("directoryRoot未指定でも保存して読み戻せる")
    func savesToDefaultApplicationSupport() async {
        let namespace = "diag-\(UUID().uuidString)"
        let store = FileRecipeCacheStore(namespace: namespace)
        let recipe = RecipeCacheMapper.toCached(CacheFixture.recipe("recipe-01"), hasDetail: true)

        await store.saveRecipeDetail(recipe, fetchedAt: CacheFixture.date(2026, 10, 30))
        let record = await store.loadRecipeDetail(id: "recipe-01")

        #expect(record?.payload.id == "recipe-01")
        await store.removeAll()
    }
}
