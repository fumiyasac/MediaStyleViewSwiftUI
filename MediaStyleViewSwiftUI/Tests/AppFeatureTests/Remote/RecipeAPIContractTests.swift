//
//  RecipeAPIContractTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Contract Test: 実 API から取得した JSON(APIFixtureJSON)を DTO が取りこぼさず Decode できるか検証する。
// 実ネットワークへは出ない（キャプチャ済み JSON を使う）。API 仕様が変わればここが壊れて契約の破れを検知する。

@testable import AppFeature
import Foundation
import Testing

@Suite("API 契約: 実レスポンス JSON の Decode")
struct RecipeAPIContractTests {

    private let decoder = JSONDecoder()

    // 一覧レスポンス（camelCase キー・pagination）
    @Test("recipes 一覧の実 JSON を DTO へ Decode できる")
    func decodesRecipeList() throws {
        let dto = try decoder.decode(RecipeListResponseDTO.self, from: Data(APIFixtureJSON.recipeListLimit2.utf8))

        #expect(dto.items.count == 2)
        #expect(dto.items[0].id == "recipe-01")
        #expect(dto.items[0].cookingMinutes == 25)
        #expect(dto.items[1].category == "western")
        #expect(dto.pagination.limit == 2)
        #expect(dto.pagination.total == 24)
    }

    // 詳細レスポンス（imageReference / ingredients / steps）
    @Test("recipe 詳細の実 JSON を DTO へ Decode できる")
    func decodesRecipeDetail() throws {
        let dto = try decoder.decode(RecipeDetailDTO.self, from: Data(APIFixtureJSON.recipeDetail01.utf8))

        #expect(dto.id == "recipe-01")
        #expect(dto.imageReference == "recipe-01")
        #expect(dto.ingredients.count == 3)
        #expect(dto.steps.count == 3)

        // 契約通り Domain へ変換できることも確認（カテゴリ対応・材料/手順保持）
        let recipe = try RecipeDTOMapper.map(dto)
        #expect(recipe.category == .japanese)
        #expect(recipe.steps.first == "鮭に塩麹をまぶして30分置く。")
    }

    // カレンダーレスポンス（items/recipe/range・displayOrder）
    @Test("calendar の実 JSON を DTO へ Decode できる")
    func decodesCalendar() throws {
        let dto = try decoder.decode(CalendarResponseDTO.self, from: Data(APIFixtureJSON.calendar.utf8))

        #expect(dto.items.count == 3)
        #expect(dto.items[0].id == "daily-2026-10-03-recipe-03")
        #expect(dto.items[0].recipe.id == "recipe-03")
        #expect(dto.items[2].displayOrder == 1)
        #expect(dto.range.total == 3)

        // 変換後の件数・参照整合
        let entries = try dto.items.map { try RecipeDTOMapper.map($0) }
        #expect(entries.map(\.dateKey.value) == ["2026-10-03", "2026-10-04", "2026-10-04"])
    }

    // エラーレスポンス（{"error":{"code","message"}}）
    @Test("エラー応答の実 JSON を DTO へ Decode できる")
    func decodesErrorBody() throws {
        let dto = try decoder.decode(APIErrorResponseDTO.self, from: Data(APIFixtureJSON.notFoundError.utf8))

        #expect(dto.error.code == "RECIPE_NOT_FOUND")
        #expect(dto.error.message == "Recipe was not found.")
    }
}
