//
//  Recipe.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// レシピMaster（献立そのもの）のDomain Model。Actorやレイヤーを越えて渡すため、
// Sendableな値型にする。SwiftData Entityとは分離し、将来的にもViewやStateには
// この値型を渡す（Entityは渡さない）。

import Foundation

// MARK: - RecipeID

// レシピの識別子。生のStringを直接使うと取り違えが起きるため、型で包んで安全性を上げる。
struct RecipeID: Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

// MARK: - RecipeCategory

// レシピの大まかな分類。表示名とSF Symbol名を持たせ、後続のUIでそのまま使えるようにする。
enum RecipeCategory: String, CaseIterable, Sendable {
    case japanese = "和食"
    case western = "洋食"
    case chinese = "中華"
    case italian = "イタリアン"
    case dessert = "デザート"
    case healthy = "ヘルシー"

    // 表示名（rawValueをそのまま使う）
    var displayName: String { rawValue }

    // 後続UIのアイコン用（SF Symbol名）
    var symbolName: String {
        switch self {
        case .japanese: return "fish"
        case .western: return "fork.knife"
        case .chinese: return "takeoutbag.and.cup.and.straw"
        case .italian: return "circle.grid.cross"
        case .dessert: return "birthday.cake"
        case .healthy: return "leaf"
        }
    }
}

// MARK: - Recipe

struct Recipe: Identifiable, Hashable, Sendable {

    // MARK: - Property

    let id: RecipeID
    // 料理名
    let title: String
    // 一言説明（一覧やDetailの要約に使う想定）
    let summary: String
    // 分類
    let category: RecipeCategory
    // 調理時間（分）
    let cookingMinutes: Int
    // 想定カロリー（kcal）
    let calories: Int
    // 標準の盛り付け人数
    let servings: Int
    // 材料（Detail表示用。各要素は「材料名 分量」程度の自由文）
    let ingredients: [String]
    // 調理手順（Detail表示用。順序は配列の並び）
    let steps: [String]

    // MARK: - Initializer

    // ingredients/stepsは既定を空配列にして、既存の生成箇所を壊さない
    init(
        id: RecipeID,
        title: String,
        summary: String,
        category: RecipeCategory,
        cookingMinutes: Int,
        calories: Int,
        servings: Int,
        ingredients: [String] = [],
        steps: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.cookingMinutes = cookingMinutes
        self.calories = calories
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
    }
}
