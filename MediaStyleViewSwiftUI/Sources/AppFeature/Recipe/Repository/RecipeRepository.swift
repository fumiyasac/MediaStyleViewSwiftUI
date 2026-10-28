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

    // 指定した暦日キーの閉区間に含まれる掲載割当を返す（月表示・Timelineの範囲取得用）。
    // Remote実装ではこの範囲をそのままCalendar API(from/to)へ渡し、「必要な範囲だけ」取得する
    // （全期間を毎回取得しないための境界）。Fixtureは既定実装で全件を範囲フィルタすれば十分。
    //
    // 重要: Protocolの「要件」として宣言する（既定実装はextensionに置く）。
    // UseCaseは `any RecipeRepository` 越しに呼ぶため、要件にしないとextensionの既定実装が
    // 静的ディスパッチされ、RemoteのAPI呼び出しへ切り替わらない（動的ディスパッチのために必須）。
    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry]
}

// MARK: - Default Implementation

extension RecipeRepository {

    // 既定実装: 全件取得してから範囲で絞り込む。
    // Fixture等「全件を安価に返せる」実装向け。I/Oを範囲限定したいRemoteはこれをoverrideする。
    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry] {
        try await allDailyEntries().filter { range.contains($0.dateKey) }
    }
}
