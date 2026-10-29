//
//  RecipeCacheMapper.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// Domain ↔ キャッシュDTO の変換を集約する。API DTO↔Domainと同様に、永続化フォーマットの関心を
// Domainへ漏らさないための境界。カテゴリはRecipeCategoryのrawValue(表示名)で保存・復元する。
// 復元時に未知カテゴリ等で変換できないレコードは nil（＝キャッシュ無効）として扱い、壊れた表示を避ける。

import Foundation

enum RecipeCacheMapper {

    // MARK: - Recipe → Cached

    // hasDetail: 詳細API由来(材料・手順あり)ならtrue。一覧/カレンダー由来の概要ならfalse。
    static func toCached(_ recipe: Recipe, hasDetail: Bool) -> CachedRecipe {
        CachedRecipe(
            id: recipe.id.rawValue,
            title: recipe.title,
            summary: recipe.summary,
            categoryRawValue: recipe.category.rawValue,
            cookingMinutes: recipe.cookingMinutes,
            calories: recipe.calories,
            servings: recipe.servings,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            hasDetail: hasDetail
        )
    }

    // MARK: - Cached → Domain

    // 変換不能(未知カテゴリ)は nil。呼び出し側はキャッシュ無効として扱う。
    static func toDomain(_ cached: CachedRecipe) -> Recipe? {
        guard let category = RecipeCategory(rawValue: cached.categoryRawValue) else {
            return nil
        }
        return Recipe(
            id: RecipeID(cached.id),
            title: cached.title,
            summary: cached.summary,
            category: category,
            cookingMinutes: cached.cookingMinutes,
            calories: cached.calories,
            servings: cached.servings,
            ingredients: cached.ingredients,
            steps: cached.steps
        )
    }

    // MARK: - DailyEntry

    static func toCached(_ entry: DailyRecipeEntry) -> CachedDailyEntry {
        CachedDailyEntry(
            id: entry.id.rawValue,
            dateKey: entry.dateKey.value,
            recipeID: entry.recipeID.rawValue
        )
    }

    static func toDomain(_ cached: CachedDailyEntry) -> DailyRecipeEntry {
        DailyRecipeEntry(
            id: DailyRecipeEntryID(cached.id),
            dateKey: DateKey(value: cached.dateKey),
            recipeID: RecipeID(cached.recipeID)
        )
    }
}
