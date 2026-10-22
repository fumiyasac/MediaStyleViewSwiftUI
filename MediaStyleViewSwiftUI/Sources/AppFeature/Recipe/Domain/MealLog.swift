//
//  MealLog.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 調理ログの入力(Write)と要約(Read)のDomain Model。
// 将来SwiftDataで永続化するが、SwiftData EntityはViewやStateに渡さない方針のため、
// 書き込みはMealLogInput、読み出しはMealLogSummaryという値型プロジェクションで受け渡す。
// どちらもSendableな値型にする。

import Foundation

// MARK: - MealLogID

// 調理ログの識別子。新規作成時にRepositoryが払い出し、更新・削除で参照する。
struct MealLogID: Hashable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

// MARK: - MealLogInput

// 調理ログの書き込み用ペイロード。idはRepositoryが採番するため持たない。
// cookedAtは絶対時刻で受け取り、どの暦日(DateKey)に属するかの判定はRepository側の
// Calendar/TimeZoneに委ねる（入力側でTZを決め打ちしない）。
struct MealLogInput: Hashable, Sendable {

    // MARK: - Property

    // 作ったレシピ
    let recipeID: RecipeID
    // 調理した日時（絶対時刻）
    let cookedAt: Date
    // 5段階評価（1...5想定）
    let rating: Int
    // メモ・感想
    let memo: String
    // 実際に作った人数
    let servings: Int

    // MARK: - Initializer

    init(recipeID: RecipeID, cookedAt: Date, rating: Int, memo: String, servings: Int) {
        self.recipeID = recipeID
        self.cookedAt = cookedAt
        self.rating = rating
        self.memo = memo
        self.servings = servings
    }
}

// MARK: - MealLogSummary

// 調理ログの読み出し用プロジェクション。保存済みログをUI/Stateへ渡すための値型。
// cookedAtから導出した暦日dateKeyを持たせ、日別の集計・表示をしやすくする。
struct MealLogSummary: Identifiable, Hashable, Sendable {

    // MARK: - Property

    let id: MealLogID
    let recipeID: RecipeID
    // cookedAtをRepositoryのCalendarで暦日に落とした結果
    let dateKey: DateKey
    let cookedAt: Date
    let rating: Int
    let memo: String
    let servings: Int

    // MARK: - Initializer

    init(
        id: MealLogID,
        recipeID: RecipeID,
        dateKey: DateKey,
        cookedAt: Date,
        rating: Int,
        memo: String,
        servings: Int
    ) {
        self.id = id
        self.recipeID = recipeID
        self.dateKey = dateKey
        self.cookedAt = cookedAt
        self.rating = rating
        self.memo = memo
        self.servings = servings
    }
}
