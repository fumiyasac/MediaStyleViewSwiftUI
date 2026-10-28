//
//  RecipeResponseDTO.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Go API の JSON レスポンスに対応する DTO 群。
//
// Domain Model とは分離する:
//  - API 契約（フィールド名・任意/必須）を Domain に漏らさず、API 変更の影響を Mapper に閉じるため。
//  - JSON キーは camelCase（Go 側 DTO の json タグが cookingMinutes 等）なので、
//    JSONDecoder の keyDecodingStrategy は既定(.useDefaultKeys)のままプロパティ名を一致させる。
//
// DTO は Decodable かつ Sendable（Actor 境界を越えても安全に扱う）。

import Foundation

// レシピ概要（一覧・カレンダーの recipe フィールド）
struct RecipeSummaryDTO: Decodable, Sendable, Equatable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let cookingMinutes: Int
    let calories: Int
    let servings: Int
}

// レシピ詳細（材料・手順・画像参照を含む）
struct RecipeDetailDTO: Decodable, Sendable, Equatable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let cookingMinutes: Int
    let calories: Int
    let servings: Int
    // 画像参照（存在しない場合 null）。現状は Recipe ID と同値のローカルアセットキー。
    let imageReference: String?
    let ingredients: [String]
    let steps: [String]
}
