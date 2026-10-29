//
//  CachedRecipeRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// Remote取得と永続キャッシュを調停するRepository。既存のRecipeRepository(Domainのみ)に準拠しつつ、
// 出所付きで読む CacheAwareRecipeReading も提供する（UseCaseは実体がこれなら出所付きで読む）。
//
// 取得戦略（Network-first + Cacheフォールバック）:
//  - 常にRemoteを試みる。成功したらキャッシュを更新し最新(.remote)を返す
//    （サーバー変更が常に反映される＝Scenario E/Retry/再取得を満たす）。
//  - Remoteが「通信障害クラス」(未接続/タイムアウト/5xx/不正応答)で失敗したら、保存済みがあればStale表示で返す。
//  - それ以外(400/404/Decoding/Mapping)は障害フォールバックせず伝搬する
//    （オフライン障害と同一視しない。古い詳細を黙って出し続けない）。
//  - CancellationErrorはフォールバックのトリガーにしない（通常の通信障害として扱わない）。
//  - 期限(maxAge)超過のキャッシュはフォールバックに使わない（古すぎる情報を出さない）。
//
// なぜ早期キャッシュ表示(cache-first)でなくNetwork-firstか:
//  - 既存の単一returnなRepository/UseCase/ViewModel設計を大きく変えずに「オフラインで保存済みを出す」主目的を満たすため。
//    オフライン時は接続失敗が即座に返るため、実用上の待ちは小さい。二段階のcache-then-refreshは次PRの検討事項。

import Foundation

struct CachedRecipeRepository: RecipeRepository, CacheAwareRecipeReading {

    // MARK: - Property

    private let remote: any RecipeRepository
    private let store: any RecipeCacheStore
    private let policy: RecipeCachePolicy
    // 現在時刻（鮮度判定・保存日時）。テストで固定できるよう注入する。
    private let now: @Sendable () -> Date

    // MARK: - Initializer

    init(
        remote: any RecipeRepository,
        store: any RecipeCacheStore,
        policy: RecipeCachePolicy = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.remote = remote
        self.store = store
        self.policy = policy
        self.now = now
    }

    // MARK: - CacheAwareRecipeReading

    func loadAllRecipes() async throws -> RecipeListReadResult {
        do {
            let recipes = try await remote.allRecipes()
            // 一覧は概要(hasDetail=false)として保存。詳細キャッシュとは混同しない。
            await store.saveRecipeList(recipes.map { RecipeCacheMapper.toCached($0, hasDetail: false) }, fetchedAt: now())
            return RecipeListReadResult(recipes: recipes, origin: .remote)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APIClientError where Self.shouldFallBack(on: error) {
            guard let record = await store.loadRecipeList(),
                  let origin = cacheOrigin(for: record.fetchedAt) else {
                throw error
            }
            let recipes = record.payload.compactMap { RecipeCacheMapper.toDomain($0) }
            return RecipeListReadResult(recipes: recipes, origin: origin)
        }
    }

    func loadRecipe(for id: RecipeID) async throws -> RecipeDetailReadResult? {
        do {
            guard let recipe = try await remote.recipe(for: id) else {
                // RemoteRepositoryは404のときnilを返す。これは「見つからない」であり通信障害ではない。
                // 404はフォールバック経路へ入らずnil(=not found)を返すため、古い詳細キャッシュが
                // 表示され続けることはない（オフライン時のみフォールバックで保存済み詳細を使う）。
                return nil
            }
            // 詳細API由来は完全データ(hasDetail=true)として保存する。
            await store.saveRecipeDetail(RecipeCacheMapper.toCached(recipe, hasDetail: true), fetchedAt: now())
            return RecipeDetailReadResult(recipe: recipe, origin: .remote)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APIClientError where Self.shouldFallBack(on: error) {
            // 完全な詳細(hasDetail=true)が保存済みのときだけフォールバック。概要だけを詳細として出さない。
            guard let record = await store.loadRecipeDetail(id: id.rawValue),
                  record.payload.hasDetail,
                  let recipe = RecipeCacheMapper.toDomain(record.payload),
                  let origin = cacheOrigin(for: record.fetchedAt) else {
                throw error
            }
            return RecipeDetailReadResult(recipe: recipe, origin: origin)
        }
    }

    func loadDailyEntries(in range: ClosedRange<DateKey>) async throws -> DailyEntriesReadResult {
        let rangeKey = Self.rangeKey(for: range)
        do {
            let entries = try await remote.dailyEntries(in: range)
            // 空配列も「その範囲が取得済み」として保存する（正常な空結果。古いデータで補完しない）。
            await store.saveDailyEntries(entries.map { RecipeCacheMapper.toCached($0) }, rangeKey: rangeKey, fetchedAt: now())
            return DailyEntriesReadResult(entries: entries, origin: .remote)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APIClientError where Self.shouldFallBack(on: error) {
            // 未取得範囲はキャッシュが無い→エラー伝搬（未取得月を空月扱いしない）。
            guard let record = await store.loadDailyEntries(rangeKey: rangeKey),
                  let origin = cacheOrigin(for: record.fetchedAt) else {
                throw error
            }
            let entries = record.payload.map { RecipeCacheMapper.toDomain($0) }
            return DailyEntriesReadResult(entries: entries, origin: origin)
        }
    }

    // MARK: - RecipeRepository (Domainのみ。出所を落として委譲)

    func allRecipes() async throws -> [Recipe] {
        try await loadAllRecipes().recipes
    }

    func recipe(for id: RecipeID) async throws -> Recipe? {
        try await loadRecipe(for: id)?.recipe
    }

    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] {
        try await loadDailyEntries(in: dateKey...dateKey).entries
    }

    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry] {
        try await loadDailyEntries(in: range).entries
    }

    // allDailyEntries(全期間)はCalendar/Timelineでは使わない（範囲取得を使う）。
    // キャッシュ対象外のためRemoteへ素通しする。
    func allDailyEntries() async throws -> [DailyRecipeEntry] {
        try await remote.allDailyEntries()
    }

    // MARK: - Private

    // fetchedAtから表示用の出所を作る。期限(maxAge)超過はフォールバック不可(nil)。
    private func cacheOrigin(for fetchedAt: Date) -> RecipeDataOrigin? {
        switch policy.freshness(fetchedAt: fetchedAt, now: now()) {
        case .fresh:
            return .cache(fetchedAt: fetchedAt, isStale: false)
        case .stale:
            return .cache(fetchedAt: fetchedAt, isStale: true)
        case .expired:
            return nil
        }
    }

    // 通信障害クラス（＝保存済みキャッシュへのフォールバックを許可）か。
    // 400/404/Decoding/Mapping/invalidURL/想定外ステータスはフォールバックしない。
    private static func shouldFallBack(on error: APIClientError) -> Bool {
        switch error {
        case .network, .timeout, .invalidResponse, .serverError:
            return true
        case .badRequest, .notFound, .decoding, .mapping, .invalidURL, .unexpectedStatus:
            return false
        }
    }

    // 期間キャッシュのキー。from/to両方を含め、別範囲は別キャッシュにする（取得済み範囲の完全性）。
    private static func rangeKey(for range: ClosedRange<DateKey>) -> String {
        "\(range.lowerBound.value)_\(range.upperBound.value)"
    }
}
