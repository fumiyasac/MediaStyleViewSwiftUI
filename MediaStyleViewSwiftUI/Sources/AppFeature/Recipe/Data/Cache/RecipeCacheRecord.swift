//
//  RecipeCacheRecord.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 永続キャッシュのファイル表現。Domainとは分離したCodableなDTOで保存する。
//
// なぜDomainを直接Codableにしないか:
//  - 永続化フォーマット(保存時の表現)とDomainの関心を分離するため（API DTO↔Domainと同じ思想）。
//  - Schema Versionを明示し、将来フィールドが変わっても古いファイルを安全に無視/移行できるようにするため。
//
// RecipeCacheRecordは「何を(payload)」「いつ取得したか(fetchedAt)」「どの形式か(schemaVersion)」を束ねる封筒。
// fetchedAtは鮮度(Fresh/Stale)と「保存日時」の表示に使う。

import Foundation

// MARK: - Schema Version

// 保存フォーマットのバージョン。フィールド構造を変えたら増やす。
// 読み込み時に一致しないレコードは「無い物」として安全に無視する（壊れた移行での事故を防ぐ）。
enum RecipeCacheSchema {
    static let current = 1
}

// MARK: - Envelope

struct RecipeCacheRecord<Payload: Codable & Sendable>: Codable, Sendable {
    // 保存フォーマットのバージョン
    let schemaVersion: Int
    // 最終正常取得日時（鮮度判定・保存日時表示に使う）
    let fetchedAt: Date
    // 保存本体
    let payload: Payload

    init(payload: Payload, fetchedAt: Date, schemaVersion: Int = RecipeCacheSchema.current) {
        self.schemaVersion = schemaVersion
        self.fetchedAt = fetchedAt
        self.payload = payload
    }
}

// payloadを読まずにメタ情報だけ覗くためのヘッダ。保存前に既存レコードのfetchedAtを比較し、
// 「新しい保存結果を古い通信結果で上書きしない」ための判断に使う（JSONDecoderは未知のpayloadキーを無視する）。
struct RecipeCacheHeader: Codable, Sendable {
    let schemaVersion: Int
    let fetchedAt: Date
}

// MARK: - Cached DTOs

// レシピのキャッシュ表現。
// hasDetail: 詳細API由来(材料・手順あり)か、一覧/カレンダー由来の概要のみかを区別する。
// 概要だけを「詳細取得済み」として扱わないための完全性フラグ（Recipe Detailのキャッシュ判定に使う）。
struct CachedRecipe: Codable, Sendable, Equatable {
    let id: String
    let title: String
    let summary: String
    // RecipeCategoryのrawValue(表示名)をそのまま保存し、読み込み時に復元する
    let categoryRawValue: String
    let cookingMinutes: Int
    let calories: Int
    let servings: Int
    let ingredients: [String]
    let steps: [String]
    let hasDetail: Bool
}

// カレンダー掲載割当のキャッシュ表現。displayOrderはDomainが保持しないため配列順で表現する。
struct CachedDailyEntry: Codable, Sendable, Equatable {
    let id: String
    let dateKey: String
    let recipeID: String
}
