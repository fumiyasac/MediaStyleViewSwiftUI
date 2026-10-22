//
//  DailyRecipeEntry.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 「ある暦日にどのレシピを掲載するか」の割当を表すDomain Model。
// Recipe本体ではなくRecipeIDを参照で持つことで、同じレシピを複数日に掲載できる
// （正規化：レシピMasterは1件、割当は日付ごとに複数持てる）。Sendableな値型にする。

import Foundation

// MARK: - DailyRecipeEntryID

// 日別割当の識別子。日付×レシピで一意になるようFixture側で決定的に払い出す。
struct DailyRecipeEntryID: Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

// MARK: - DailyRecipeEntry

struct DailyRecipeEntry: Identifiable, Hashable, Sendable {

    // MARK: - Property

    let id: DailyRecipeEntryID
    // 掲載する暦日
    let dateKey: DateKey
    // 掲載するレシピ（Master参照）
    let recipeID: RecipeID

    // MARK: - Initializer

    init(id: DailyRecipeEntryID, dateKey: DateKey, recipeID: RecipeID) {
        self.id = id
        self.dateKey = dateKey
        self.recipeID = recipeID
    }
}
