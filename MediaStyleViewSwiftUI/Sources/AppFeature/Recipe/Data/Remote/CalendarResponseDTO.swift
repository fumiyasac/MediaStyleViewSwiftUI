//
//  CalendarResponseDTO.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// GET /api/v1/calendar のレスポンス DTO。
//
// 掲載項目 ID(id) と参照レシピ ID(recipe.id) は別物（混同しない）。
// publicationDate は "YYYY-MM-DD" の文字列で、TimeZone 付き日時へ変換せずそのまま日付キーに使う。
// displayOrder は API 側の安定ソート用で、Swift の DailyRecipeEntry には対応フィールドが無いため
// Mapper では順序保持のためだけに利用する（Domain へは持ち込まない）。

import Foundation

struct CalendarEntryDTO: Decodable, Sendable, Equatable {
    let id: String
    let publicationDate: String
    let displayOrder: Int
    let recipe: RecipeSummaryDTO
}

struct CalendarRangeDTO: Decodable, Sendable, Equatable {
    let from: String
    let to: String
    let total: Int
}

struct CalendarResponseDTO: Decodable, Sendable, Equatable {
    let items: [CalendarEntryDTO]
    let range: CalendarRangeDTO
}

// エラーレスポンス（{"error":{"code","message"}}）
struct APIErrorBodyDTO: Decodable, Sendable, Equatable {
    let code: String
    let message: String
}

struct APIErrorResponseDTO: Decodable, Sendable, Equatable {
    let error: APIErrorBodyDTO
}
