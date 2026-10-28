//
//  RecipeListResponseDTO.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// GET /api/v1/recipes のレスポンス DTO。
// pagination.total を保持し、Remote 側で全ページ取得（allRecipes）を行う際の終了判定に使う。

import Foundation

struct PaginationDTO: Decodable, Sendable, Equatable {
    let limit: Int
    let offset: Int
    let total: Int
}

struct RecipeListResponseDTO: Decodable, Sendable, Equatable {
    let items: [RecipeSummaryDTO]
    let pagination: PaginationDTO
}
