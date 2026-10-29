//
//  RecipeCacheStoreTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// FileRecipeCacheStore の永続化テスト。Temporary Directoryへ書き込み、別インスタンスから読み戻す。

@testable import AppFeature
import Foundation
import Testing

@Suite("Recipe Cache Store: 永続化")
struct RecipeCacheStoreTests {

    private func cached(_ id: String, hasDetail: Bool = true) -> CachedRecipe {
        RecipeCacheMapper.toCached(CacheFixture.recipe(id), hasDetail: hasDetail)
    }

    // 1 & 2. 保存して取得できる
    @Test("詳細を保存して取得できる")
    func saveAndLoadDetail() async {
        let store = CacheFixture.makeStore()
        let at = CacheFixture.date(2026, 10, 30)
        await store.saveRecipeDetail(cached("recipe-01"), fetchedAt: at)

        let record = await store.loadRecipeDetail(id: "recipe-01")
        #expect(record?.payload.id == "recipe-01")
        #expect(record?.payload.hasDetail == true)
    }

    // 3. 更新できる（後勝ち：新しいfetchedAtで上書き）
    @Test("保存済み詳細を新しい取得日時で更新できる")
    func updateDetail() async {
        let store = CacheFixture.makeStore()
        await store.saveRecipeDetail(cached("recipe-01", hasDetail: false), fetchedAt: CacheFixture.date(2026, 10, 29))
        await store.saveRecipeDetail(cached("recipe-01", hasDetail: true), fetchedAt: CacheFixture.date(2026, 10, 30))

        let record = await store.loadRecipeDetail(id: "recipe-01")
        #expect(record?.payload.hasDetail == true)
    }

    // 4. 削除できる（名前空間ごと）
    @Test("removeAll でキャッシュを削除できる")
    func removeAll() async {
        let store = CacheFixture.makeStore()
        await store.saveRecipeList([cached("recipe-01")], fetchedAt: CacheFixture.date(2026, 10, 30))
        await store.removeAll()
        let record = await store.loadRecipeList()
        #expect(record == nil)
    }

    // 5. 別インスタンスから読み込める（ファイル永続）
    @Test("別のStoreインスタンスから読み込める")
    func persistsAcrossInstances() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let writer = FileRecipeCacheStore(namespace: "shared", directoryRoot: root)
        await writer.saveRecipeList([cached("recipe-01"), cached("recipe-02")], fetchedAt: CacheFixture.date(2026, 10, 30))

        let reader = FileRecipeCacheStore(namespace: "shared", directoryRoot: root)
        let record = await reader.loadRecipeList()
        #expect(record?.payload.count == 2)
    }

    // 6. Schema Versionが異なるファイルは無視する
    @Test("未知のSchema Versionは無視される")
    func schemaMismatchIgnored() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("RecipeCache/sv"), withIntermediateDirectories: true)
        // 現行+1 の未知Schemaを直接書き込む
        let bogus = """
        {"schemaVersion": \(RecipeCacheSchema.current + 1), "fetchedAt": "2026-10-30T00:00:00Z", "payload": []}
        """
        let url = root.appendingPathComponent("RecipeCache/sv/recipe-list.json")
        try Data(bogus.utf8).write(to: url)

        let store = FileRecipeCacheStore(namespace: "sv", directoryRoot: root)
        let record = await store.loadRecipeList()
        #expect(record == nil)
    }

    // 7. 破損JSONを安全に扱える（nil）
    @Test("破損JSONは安全にnilを返す")
    func corruptedJSONIsSafe() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("RecipeCache/broken"), withIntermediateDirectories: true)
        let url = root.appendingPathComponent("RecipeCache/broken/recipe-list.json")
        try Data("{ not valid json".utf8).write(to: url)

        let store = FileRecipeCacheStore(namespace: "broken", directoryRoot: root)
        let record = await store.loadRecipeList()
        #expect(record == nil)
    }

    // 8. 保存日時が保持される
    @Test("保存日時(fetchedAt)が保持される")
    func keepsFetchedAt() async {
        let store = CacheFixture.makeStore()
        let at = CacheFixture.date(2026, 10, 15, 9)
        await store.saveDailyEntries([], rangeKey: "2026-10-01_2026-10-31", fetchedAt: at)
        let record = await store.loadDailyEntries(rangeKey: "2026-10-01_2026-10-31")
        #expect(record?.fetchedAt == at)
        #expect(record?.payload.isEmpty == true) // 空配列も保持できる
    }

    // 9. Recipe IDごとに混同しない
    @Test("Recipe IDごとのキャッシュが混同されない")
    func idsAreIsolated() async {
        let store = CacheFixture.makeStore()
        await store.saveRecipeDetail(cached("recipe-01"), fetchedAt: CacheFixture.date(2026, 10, 30))
        await store.saveRecipeDetail(cached("recipe-02"), fetchedAt: CacheFixture.date(2026, 10, 30))

        let r1 = await store.loadRecipeDetail(id: "recipe-01")
        let r2 = await store.loadRecipeDetail(id: "recipe-02")
        #expect(r1?.payload.id == "recipe-01")
        #expect(r2?.payload.id == "recipe-02")
        #expect(await store.loadRecipeDetail(id: "recipe-99") == nil)
    }

    // 10. 複数Taskから同時に操作しても破綻しない（actorで直列化）
    @Test("複数Taskからの並行保存で破綻しない")
    func concurrentWritesAreSafe() async {
        let store = CacheFixture.makeStore()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<20 {
                group.addTask {
                    await store.saveRecipeDetail(
                        self.cached("recipe-\(index)"),
                        fetchedAt: CacheFixture.date(2026, 10, 30)
                    )
                }
            }
        }
        // 代表して数件が読み出せること（クラッシュ・破損が起きない）
        #expect(await store.loadRecipeDetail(id: "recipe-0") != nil)
        #expect(await store.loadRecipeDetail(id: "recipe-19") != nil)
    }

    // 補足. 新しい保存を古い取得結果で上書きしない
    @Test("古い取得日時では新しいキャッシュを上書きしない")
    func olderFetchDoesNotOverwrite() async {
        let store = CacheFixture.makeStore()
        await store.saveRecipeList([cached("new")], fetchedAt: CacheFixture.date(2026, 10, 30))
        await store.saveRecipeList([cached("old")], fetchedAt: CacheFixture.date(2026, 10, 20)) // 古い→無視

        let record = await store.loadRecipeList()
        #expect(record?.payload.first?.id == "new")
    }
}
