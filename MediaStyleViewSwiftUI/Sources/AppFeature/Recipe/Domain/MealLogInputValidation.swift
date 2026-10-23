//
//  MealLogInputValidation.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// MealLogInputの入力検証をDomain側に置く。検証ルールはこの1か所に集約し、
// Repositoryには永続化の責務だけを残す（Repositoryは保存前にvalidate()を呼ぶだけ）。
// 将来MealLog用UseCaseを追加した際も、同じvalidate()を前段で再利用できる。

import Foundation

// MARK: - MealLogValidationError

enum MealLogValidationError: Error, Equatable, Sendable {
    // 評価が1...5の範囲外
    case ratingOutOfRange(Int)
    // recipeIDが空（空白のみ含む）
    case emptyRecipeID
}

// MARK: - MealLogInput + Validation

extension MealLogInput {

    // 許容する評価の範囲
    static let ratingRange = 1...5

    // 入力の妥当性を検証する。
    // - rating: 1...5の範囲
    // - recipeID: 空文字（空白のみ）不可
    // - memo: 空文字でも可（方針どおり検証しない）
    // - 日付キー: cookedAtがDate型のため形式は常に妥当。保存時にCalendarで暦日へ導出する
    func validate() throws {
        guard Self.ratingRange.contains(rating) else {
            throw MealLogValidationError.ratingOutOfRange(rating)
        }
        let trimmedRecipeID = recipeID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRecipeID.isEmpty else {
            throw MealLogValidationError.emptyRecipeID
        }
    }
}
