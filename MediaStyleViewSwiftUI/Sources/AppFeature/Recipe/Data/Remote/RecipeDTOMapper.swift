//
//  RecipeDTOMapper.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// API DTO から Domain Model への変換を一箇所に集約する。
//
// 分離する理由:
//  - API 契約（英語 category キー・imageReference・displayOrder 等）を Domain に漏らさない。
//  - 変換不能（未知カテゴリ・日付書式不正）を mapping エラーとして明示的に扱い、
//    DTO 層の緩さ（String category 等）が Domain の整合性を壊さないようにする。
//
// 落とす情報（意図的）:
//  - imageReference: Domain の Recipe は画像プロパティを持たない（アセットは ID 由来で解決する方針）。
//  - displayOrder: DailyRecipeEntry に順序フィールドが無い。並び順は配列の順序で表現する。

import Foundation

enum RecipeDTOMapper {

    // MARK: - Category

    // API の英語カテゴリキー → Domain の RecipeCategory。
    // RecipeCategory の rawValue は日本語表示名のため、rawValue イニシャライザは使えない。
    // API 契約（英語キー）と Domain（日本語 rawValue）の対応をここで明示する。
    private static let categoryMap: [String: RecipeCategory] = [
        "japanese": .japanese,
        "western": .western,
        "chinese": .chinese,
        "italian": .italian,
        "dessert": .dessert,
        "healthy": .healthy,
    ]

    static func mapCategory(_ raw: String) throws -> RecipeCategory {
        guard let category = categoryMap[raw] else {
            throw APIClientError.mapping(message: "未知のカテゴリです: \(raw)")
        }
        return category
    }

    // MARK: - Recipe

    // 詳細 DTO → Recipe（材料・手順を含む完全な Recipe）
    static func map(_ dto: RecipeDetailDTO) throws -> Recipe {
        Recipe(
            id: RecipeID(dto.id),
            title: dto.title,
            summary: dto.summary,
            category: try mapCategory(dto.category),
            cookingMinutes: dto.cookingMinutes,
            calories: dto.calories,
            servings: dto.servings,
            ingredients: dto.ingredients,
            steps: dto.steps
            // imageReference は Domain に持たないため破棄する
        )
    }

    // 概要 DTO → Recipe（一覧・カレンダー用。材料/手順は詳細取得でのみ得られるため空）
    static func map(_ dto: RecipeSummaryDTO) throws -> Recipe {
        Recipe(
            id: RecipeID(dto.id),
            title: dto.title,
            summary: dto.summary,
            category: try mapCategory(dto.category),
            cookingMinutes: dto.cookingMinutes,
            calories: dto.calories,
            servings: dto.servings,
            ingredients: [],
            steps: []
        )
    }

    // MARK: - DailyRecipeEntry

    // カレンダー項目 DTO → DailyRecipeEntry。
    // publicationDate は "yyyy-MM-dd" 文字列。TimeZone 付き Date に変換せず、
    // 書式検証のみ行ってそのまま DateKey にする（端末 TZ による日付ズレを避ける）。
    static func map(_ dto: CalendarEntryDTO) throws -> DailyRecipeEntry {
        guard isValidDateKeyString(dto.publicationDate) else {
            throw APIClientError.mapping(message: "日付書式が不正です: \(dto.publicationDate)")
        }
        return DailyRecipeEntry(
            id: DailyRecipeEntryID(dto.id),
            dateKey: DateKey(value: dto.publicationDate),
            recipeID: RecipeID(dto.recipe.id)
            // displayOrder は Domain に持たないため破棄する（並びは配列順で保持）
        )
    }

    // MARK: - Helpers

    // "yyyy-MM-dd"（数字4-2-2）の書式を検証する。暦として妥当かまでは API を信頼する。
    private static func isValidDateKeyString(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2 else {
            return false
        }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}
