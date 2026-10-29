//
//  CacheAwareRecipeReading.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 取得元(RecipeDataOrigin)付きでレシピを読むための境界。
//
// なぜ既存のRecipeRepository(Domainのみ返す)と別に用意するか:
//  - RecipeRepository Protocolは「Domainだけ返す」契約のまま保ちたい（Fixture等の実装・既存テストを壊さない）。
//  - 一方でキャッシュ対応では「最新かキャッシュか/保存日時/Stale」をUIへ伝える必要がある。
//  - そこでDomainへ出所を混ぜず、取得結果に出所を添える専用の読み込み情報(Result)をこの境界で返す。
//
// UseCaseは RecipeRepository を保持しつつ、実体がこの境界に対応していれば出所付きで読む（対応しなければ.remote扱い）。

import Foundation

// MARK: - Read Results

struct RecipeListReadResult: Sendable, Equatable {
    let recipes: [Recipe]
    let origin: RecipeDataOrigin
}

struct DailyEntriesReadResult: Sendable, Equatable {
    let entries: [DailyRecipeEntry]
    let origin: RecipeDataOrigin
}

struct RecipeDetailReadResult: Sendable, Equatable {
    let recipe: Recipe
    let origin: RecipeDataOrigin
}

// MARK: - CacheAwareRecipeReading

protocol CacheAwareRecipeReading: Sendable {

    // レシピ一覧（概要）。成功=最新、Remote障害時は保存済みをStale表示で返し得る。
    func loadAllRecipes() async throws -> RecipeListReadResult

    // レシピ詳細。nilは「見つからない(404)」を表す（オフライン障害とは区別する）。
    func loadRecipe(for id: RecipeID) async throws -> RecipeDetailReadResult?

    // 指定期間の掲載割当。未取得範囲はキャッシュが無いため、Remote障害時はエラー（空月扱いにしない）。
    func loadDailyEntries(in range: ClosedRange<DateKey>) async throws -> DailyEntriesReadResult
}
