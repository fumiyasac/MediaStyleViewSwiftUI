//
//  RecipeRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// レシピMasterと日別割当を供給する読み取り用Repositoryの境界。
// 実装(Fixture / 将来のAPI・SwiftData)を差し替えられるようProtocolで抽象化する。
// Actor境界を越えて保持・注入できるよう、Protocol自体をSendableにする。
// 取得は非同期前提(async throws)にして、将来のI/O実装でもシグネチャを変えずに済むようにする。

import Foundation

// MARK: - RecipeRepository

protocol RecipeRepository: Sendable {

    // レシピMasterを全件返す
    func allRecipes() async throws -> [Recipe]

    // 指定IDのレシピを返す（無ければnil）
    func recipe(for id: RecipeID) async throws -> Recipe?

    // 指定した暦日の掲載割当を返す（0件もあり得る）
    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry]

    // 全期間の掲載割当を返す（カレンダー全体の走査用）
    func allDailyEntries() async throws -> [DailyRecipeEntry]
}
