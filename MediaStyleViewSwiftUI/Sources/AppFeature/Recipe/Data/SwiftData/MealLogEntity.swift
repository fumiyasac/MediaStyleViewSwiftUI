//
//  MealLogEntity.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLogの永続化専用モデル(@Model)。参照型であり、Sendableではない。
// このEntityはModelActorの隔離内でのみ扱い、ViewModel/Reducer/Stateへは渡さず、
// 必ずMealLogSummary(値型)へ変換してから境界の外へ出す。
//
// 設計上の注意:
//  - idはDomainのMealLogID(UUID)をそのまま主キーにする（.uniqueで一意性を担保）。
//    ただし重複防止はid採番(add)とfetch-then-update(更新)で明示的に扱い、.uniqueだけに依存しない。
//  - 同一レシピの複数回調理を履歴として残すため、recipeID+dayKeyは一意キーにしない
//    （一意なのはidのみ）。
//  - dayKeyは「ユーザーが実際に調理した日」(cookedAtから導出した暦日)であり、
//    レシピの掲載日(DailyRecipeEntry.dateKey)とは別物。混同しないよう別モデルに分離している。

import Foundation
import SwiftData

@Model
final class MealLogEntity {

    // MARK: - Property

    // 調理ログの一意ID（DomainのMealLogID.rawValue）
    @Attribute(.unique) var id: UUID
    // 作ったレシピ（RecipeID.rawValue）
    var recipeID: String
    // 調理した暦日キー（cookedAtからCalendarで導出した"yyyy-MM-dd"）
    var dayKey: String
    // 調理した日時（絶対時刻）
    var cookedAt: Date
    // 5段階評価（1...5。検証はDomain側のvalidate()で担保）
    var rating: Int
    // メモ・感想（空文字可）
    var memo: String
    // 作った人数
    var servings: Int
    // レコード作成日時（永続化メタデータ）
    var createdAt: Date
    // レコード更新日時（永続化メタデータ）
    var updatedAt: Date

    // MARK: - Initializer

    init(
        id: UUID,
        recipeID: String,
        dayKey: String,
        cookedAt: Date,
        rating: Int,
        memo: String,
        servings: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.recipeID = recipeID
        self.dayKey = dayKey
        self.cookedAt = cookedAt
        self.rating = rating
        self.memo = memo
        self.servings = servings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
