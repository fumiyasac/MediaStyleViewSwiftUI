//
//  RecipeDTOMapperTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// RecipeDTOMapper の Unit Test。DTO→Domain 変換の正しさ・情報の破棄・変換失敗を検証する。

@testable import AppFeature
import Foundation
import Testing

@Suite("RecipeDTOMapper: DTO→Domain 変換")
struct RecipeDTOMapperTests {

    private func summaryDTO(category: String = "japanese") -> RecipeSummaryDTO {
        RecipeSummaryDTO(
            id: "recipe-01",
            title: "鮭の塩麹焼き",
            summary: "塩麹でしっとり。",
            category: category,
            cookingMinutes: 25,
            calories: 320,
            servings: 2
        )
    }

    private func detailDTO(category: String = "italian") -> RecipeDetailDTO {
        RecipeDetailDTO(
            id: "recipe-04",
            title: "トマトソースのペンネ",
            summary: "軽やかなパスタ。",
            category: category,
            cookingMinutes: 18,
            calories: 400,
            servings: 2,
            imageReference: "recipe-04",
            ingredients: ["ペンネ 160g", "トマト缶 1缶"],
            steps: ["茹でる", "和える"]
        )
    }

    // 11. 詳細 DTO を材料・手順込みで Recipe へ変換する
    @Test("RecipeDetailDTO を材料/手順込みで Recipe に変換する")
    func mapsDetail() throws {
        let recipe = try RecipeDTOMapper.map(detailDTO())

        #expect(recipe.id == RecipeID("recipe-04"))
        #expect(recipe.title == "トマトソースのペンネ")
        #expect(recipe.category == .italian)
        #expect(recipe.cookingMinutes == 18)
        #expect(recipe.ingredients == ["ペンネ 160g", "トマト缶 1缶"])
        #expect(recipe.steps == ["茹でる", "和える"])
    }

    // 12. 概要 DTO は材料・手順を空にして変換する
    @Test("RecipeSummaryDTO は ingredients/steps を空で変換する")
    func mapsSummaryWithEmptyDetails() throws {
        let recipe = try RecipeDTOMapper.map(summaryDTO())

        #expect(recipe.id == RecipeID("recipe-01"))
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.steps.isEmpty)
    }

    // 13-18. 英語カテゴリキーを Domain の RecipeCategory へ正しく対応付ける
    @Test("カテゴリ英語キーを RecipeCategory へ対応付ける", arguments: [
        ("japanese", RecipeCategory.japanese),
        ("western", .western),
        ("chinese", .chinese),
        ("italian", .italian),
        ("dessert", .dessert),
        ("healthy", .healthy),
    ])
    func mapsCategory(raw: String, expected: RecipeCategory) throws {
        let recipe = try RecipeDTOMapper.map(summaryDTO(category: raw))
        #expect(recipe.category == expected)
    }

    // 19. 未知カテゴリは mapping エラー（rawValue イニシャライザに頼らない）
    @Test("未知カテゴリは mapping エラーになる")
    func unknownCategoryThrows() {
        #expect(throws: APIClientError.self) {
            _ = try RecipeDTOMapper.map(summaryDTO(category: "unknown"))
        }
    }

    // 20. カレンダー項目 DTO を DailyRecipeEntry へ変換する（日付文字列はそのまま・順序情報は破棄）
    @Test("CalendarEntryDTO を DailyRecipeEntry に変換する")
    func mapsCalendarEntry() throws {
        let dto = CalendarEntryDTO(
            id: "daily-2026-10-04-recipe-04",
            publicationDate: "2026-10-04",
            displayOrder: 1,
            recipe: summaryDTO()
        )

        let entry = try RecipeDTOMapper.map(dto)

        #expect(entry.id == DailyRecipeEntryID("daily-2026-10-04-recipe-04"))
        #expect(entry.dateKey == DateKey(value: "2026-10-04"))
        #expect(entry.recipeID == RecipeID("recipe-01")) // recipe.id を参照（項目 id ではない）
    }

    // 補足. 不正な日付書式は mapping エラー（TZ 変換せず書式のみ検証）
    @Test("不正な publicationDate は mapping エラーになる")
    func invalidDateThrows() {
        let dto = CalendarEntryDTO(
            id: "daily-x",
            publicationDate: "2026/10/04",
            displayOrder: 0,
            recipe: summaryDTO()
        )
        #expect(throws: APIClientError.self) {
            _ = try RecipeDTOMapper.map(dto)
        }
    }
}
