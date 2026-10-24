//
//  TimelineEntryViewData.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineの1項目の表示専用値型。Domain Model/Repositoryの内部構造をViewに持ち込まない。
// レシピ掲載項目とMealLog項目を同じ型で扱い、kindで区別する。

import Foundation

// MARK: - TimelineEntryKind

enum TimelineEntryKind: Sendable, Hashable {
    case recipe
    case mealLog
}

// MARK: - TimelineFilter

// 種別フィルタ。検索文字列と組み合わせて使う。
enum TimelineFilter: Sendable, Hashable, CaseIterable {
    case all
    case recipe
    case mealLog

    var title: String {
        switch self {
        case .all: return "すべて"
        case .recipe: return "レシピ"
        case .mealLog: return "作った記録"
        }
    }
}

// MARK: - TimelineEntryViewData

struct TimelineEntryViewData: Sendable, Hashable, Identifiable {

    // MARK: - Property

    // Timeline項目の安定ID。掲載項目は掲載割当ID、MealLog項目はMealLog IDを基にkind別プレフィックスを付ける。
    // （同一Recipeの複数日掲載でも衝突せず、Recipe Master IDとも別物）
    let id: String
    // 所属する暦日（掲載項目=掲載日 / MealLog項目=調理日）
    let dayKey: DateKey
    let kind: TimelineEntryKind
    // 遷移先のレシピ
    let recipeID: RecipeID
    let title: String
    let subtitle: String?
    // MealLog項目のみ（1...5）。レシピ項目はnil
    let rating: Int?
    // 参照先レシピが見つからないMealLog項目か（欠損時の代替表示に使う）
    let recipeMissing: Bool
    // ローカル検索用に正規化（小文字化）したテキスト
    let searchableText: String
}
