//
//  InMemoryMealLogRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// MealLogRepositoryのインメモリ実装。SwiftData導入前の暫定ストアとして使う。
// 可変状態(保存済みログ)を持つため、データ競合を型レベルで防げるactorにする
// （@unchecked Sendableやロックを使わず、actor隔離で安全性を担保する）。
// cookedAtからDateKeyへの変換に使うCalendarは注入でき、テストでTZ・基準を固定できる。

import Foundation

actor InMemoryMealLogRepository: MealLogRepository {

    // MARK: - Property

    // id採番とdateKey導出に使うCalendar（TimeZoneを内包）
    private let calendar: Calendar
    // 保存済みログ。要約(MealLogSummary)そのものを保持して読み出しをそのまま返す
    private var storage: [MealLogID: MealLogSummary] = [:]

    // MARK: - Initializer

    init(calendar: Calendar = DateKeyCalendar.default) {
        self.calendar = calendar
    }

    // MARK: - MealLogRepository

    @discardableResult
    func add(_ input: MealLogInput) async throws -> MealLogSummary {
        let summary = makeSummary(id: MealLogID(), from: input)
        storage[summary.id] = summary
        return summary
    }

    @discardableResult
    func update(id: MealLogID, with input: MealLogInput) async throws -> MealLogSummary {
        guard storage[id] != nil else {
            throw MealLogRepositoryError.notFound(id)
        }
        // idは維持したまま、入力内容で作り直す
        let summary = makeSummary(id: id, from: input)
        storage[id] = summary
        return summary
    }

    func delete(id: MealLogID) async throws {
        guard storage[id] != nil else {
            throw MealLogRepositoryError.notFound(id)
        }
        storage[id] = nil
    }

    func summaries(for dateKey: DateKey) async throws -> [MealLogSummary] {
        sortedByCookedAt(storage.values.filter { $0.dateKey == dateKey })
    }

    func allSummaries() async throws -> [MealLogSummary] {
        sortedByCookedAt(Array(storage.values))
    }

    // MARK: - Private Function

    // 入力からdateKeyを導出して要約を組み立てる（cookedAt→暦日の変換はこのCalendarに一元化）
    private func makeSummary(id: MealLogID, from input: MealLogInput) -> MealLogSummary {
        MealLogSummary(
            id: id,
            recipeID: input.recipeID,
            dateKey: DateKey(date: input.cookedAt, calendar: calendar),
            cookedAt: input.cookedAt,
            rating: input.rating,
            memo: input.memo,
            servings: input.servings
        )
    }

    // 調理時刻の昇順で安定した並びにする（Dictionaryの非決定的な順序を避ける）
    private func sortedByCookedAt(_ summaries: [MealLogSummary]) -> [MealLogSummary] {
        summaries.sorted { lhs, rhs in
            if lhs.cookedAt != rhs.cookedAt {
                return lhs.cookedAt < rhs.cookedAt
            }
            // 同時刻はid文字列で決定的に並べる
            return lhs.id.description < rhs.id.description
        }
    }
}
