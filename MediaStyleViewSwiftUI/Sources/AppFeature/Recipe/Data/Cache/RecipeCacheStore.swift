//
//  RecipeCacheStore.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// レシピ永続キャッシュの保存/取得境界。実装(ファイル)を差し替え可能にし、CachedRecipeRepositoryは
// この抽象にだけ依存する（CacheStoreはSwiftUIもGin/MySQLも知らない）。
//
// キャッシュキーの設計:
//  - レシピ一覧: 固定キー（全件概要）。初回ページだけを全件として扱わないよう、保存は全件取得時のみ行う。
//  - レシピ詳細: Recipe ID単位（詳細取得済みのみ保存。概要と混同しない）。
//  - カレンダー掲載: 取得期間(from/to)をそのままキー(rangeKey)にする。取得済み範囲の完全性を保つため、
//    一部期間を全体の結果として扱わない（別範囲は別キャッシュ）。
//
// 読み込みは失敗時に nil(=キャッシュ無し) を返す（破損/未知Schemaでも画面を壊さない）。
// 書き込みはベストエフォート（失敗しても正常取得データの表示を妨げない）。

import Foundation

protocol RecipeCacheStore: Sendable {

    // レシピ一覧（概要）
    func loadRecipeList() async -> RecipeCacheRecord<[CachedRecipe]>?
    func saveRecipeList(_ recipes: [CachedRecipe], fetchedAt: Date) async

    // レシピ詳細（Recipe ID単位・材料/手順を含む完全データ）
    func loadRecipeDetail(id: String) async -> RecipeCacheRecord<CachedRecipe>?
    func saveRecipeDetail(_ recipe: CachedRecipe, fetchedAt: Date) async

    // カレンダー掲載（取得期間キー単位）
    func loadDailyEntries(rangeKey: String) async -> RecipeCacheRecord<[CachedDailyEntry]>?
    func saveDailyEntries(_ entries: [CachedDailyEntry], rangeKey: String, fetchedAt: Date) async

    // このキャッシュ名前空間を全消去（MealLog等のユーザーデータには一切触れない）
    func removeAll() async
}
