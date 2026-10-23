//
//  SwiftDataMealLogRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLogRepositoryのSwiftData実装。@ModelActorでModelContext(非Sendable)を隔離し、
// ModelContextの操作とEntity→Domain変換をすべてactorの隔離内で行う。
// 境界の外へ返すのはSendableなMealLogSummaryのみで、MealLogEntityは外へ出さない。
//
// 役割分担:
//  - 検証(rating範囲・recipeID空)はDomainのMealLogInput.validate()へ委譲し、保存前に呼ぶ。
//  - 重複防止: addは常に新しいidを採番、updateはfetch-then-mutate(insertしない)で明示的に扱う。
//  - add/update/delete時はtry modelContext.save()を明示的に呼ぶ。

import Foundation
import SwiftData

@ModelActor
actor SwiftDataMealLogRepository: MealLogRepository {

    // MARK: - MealLogRepository (Command)

    @discardableResult
    func add(_ input: MealLogInput) async throws -> MealLogSummary {
        // 検証はDomainに委譲（不正な入力は永続化しない）
        try input.validate()

        let now = Date()
        let entity = MealLogEntity(
            id: UUID(),
            recipeID: input.recipeID.rawValue,
            dayKey: dayKey(for: input.cookedAt),
            cookedAt: input.cookedAt,
            rating: input.rating,
            memo: input.memo,
            servings: input.servings,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(entity)
        try modelContext.save()
        return summary(from: entity)
    }

    @discardableResult
    func update(id: MealLogID, with input: MealLogInput) async throws -> MealLogSummary {
        try input.validate()

        // 既存レコードを取得して更新する（新規insertしない）
        guard let entity = try fetchEntity(id: id.rawValue) else {
            throw MealLogRepositoryError.notFound(id)
        }
        entity.recipeID = input.recipeID.rawValue
        entity.dayKey = dayKey(for: input.cookedAt)
        entity.cookedAt = input.cookedAt
        entity.rating = input.rating
        entity.memo = input.memo
        entity.servings = input.servings
        entity.updatedAt = Date()
        try modelContext.save()
        return summary(from: entity)
    }

    func delete(id: MealLogID) async throws {
        guard let entity = try fetchEntity(id: id.rawValue) else {
            throw MealLogRepositoryError.notFound(id)
        }
        modelContext.delete(entity)
        try modelContext.save()
    }

    // MARK: - MealLogRepository (Query)

    func summary(for id: MealLogID) async throws -> MealLogSummary? {
        guard let entity = try fetchEntity(id: id.rawValue) else { return nil }
        return summary(from: entity)
    }

    func summaries(for dateKey: DateKey) async throws -> [MealLogSummary] {
        let key = dateKey.value
        let descriptor = FetchDescriptor<MealLogEntity>(
            predicate: #Predicate { $0.dayKey == key },
            sortBy: [SortDescriptor(\.cookedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(summary(from:))
    }

    func summaries(in range: ClosedRange<DateKey>) async throws -> [MealLogSummary] {
        // dayKeyは"yyyy-MM-dd"で辞書順＝日付順のため、文字列範囲で期間を絞れる
        let lower = range.lowerBound.value
        let upper = range.upperBound.value
        let descriptor = FetchDescriptor<MealLogEntity>(
            predicate: #Predicate { $0.dayKey >= lower && $0.dayKey <= upper },
            sortBy: [SortDescriptor(\.cookedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(summary(from:))
    }

    func allSummaries() async throws -> [MealLogSummary] {
        let descriptor = FetchDescriptor<MealLogEntity>(
            sortBy: [SortDescriptor(\.cookedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(summary(from:))
    }

    // MARK: - Private Function（すべてactor隔離内で実行）

    // idで1件取得する
    private func fetchEntity(id: UUID) throws -> MealLogEntity? {
        var descriptor = FetchDescriptor<MealLogEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // cookedAtから暦日キーを導出する（InMemory実装と同じDateKeyCalendarを使いTZ差を避ける）
    private func dayKey(for cookedAt: Date) -> String {
        DateKey(date: cookedAt, calendar: DateKeyCalendar.default).value
    }

    // Entity(参照型/非Sendable)をSummary(値型/Sendable)へ変換する。境界を越えるのは変換後のみ。
    private func summary(from entity: MealLogEntity) -> MealLogSummary {
        MealLogSummary(
            id: MealLogID(entity.id),
            recipeID: RecipeID(entity.recipeID),
            dateKey: DateKey(value: entity.dayKey),
            cookedAt: entity.cookedAt,
            rating: entity.rating,
            memo: entity.memo,
            servings: entity.servings
        )
    }
}
