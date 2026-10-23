//
//  MealLogRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 調理ログのCRUDを担うRepositoryの境界。
// 書き込みはMealLogInput、読み出しはMealLogSummaryという値型で受け渡し、
// 将来のSwiftData実装でもEntityを外へ出さない設計を保てるようにする。
// Actor境界を越えて注入できるようSendableにし、取得・更新は非同期前提にする。

import Foundation

// MARK: - MealLogRepositoryError

enum MealLogRepositoryError: Error, Equatable, Sendable {
    // 指定IDのログが存在しない（更新・削除時）
    case notFound(MealLogID)
}

// MARK: - MealLogRepository

protocol MealLogRepository: Sendable {

    // 新規作成する。採番済みの要約を返す
    @discardableResult
    func add(_ input: MealLogInput) async throws -> MealLogSummary

    // 既存ログを入力内容で更新する。対象が無ければnotFoundを投げる
    @discardableResult
    func update(id: MealLogID, with input: MealLogInput) async throws -> MealLogSummary

    // 既存ログを削除する。対象が無ければnotFoundを投げる
    func delete(id: MealLogID) async throws

    // IDで1件取得する（無ければnil）
    func summary(for id: MealLogID) async throws -> MealLogSummary?

    // 指定した暦日のログ要約を返す
    func summaries(for dateKey: DateKey) async throws -> [MealLogSummary]

    // 指定した暦日キーの期間(閉区間)のログ要約を返す
    func summaries(in range: ClosedRange<DateKey>) async throws -> [MealLogSummary]

    // 全ログの要約を返す
    func allSummaries() async throws -> [MealLogSummary]
}

// MARK: - Default Implementation

// 既存実装(InMemoryMealLogRepository)を変更せずに済むよう、新規の取得系は
// allSummaries()を使った既定実装を用意する。SwiftData実装では効率的なクエリで上書きする。
extension MealLogRepository {

    func summary(for id: MealLogID) async throws -> MealLogSummary? {
        try await allSummaries().first { $0.id == id }
    }

    func summaries(in range: ClosedRange<DateKey>) async throws -> [MealLogSummary] {
        try await allSummaries().filter { range.contains($0.dateKey) }
    }
}
