//
//  TimelineSectionViewData.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// 日付別Sectionの表示専用値型と、PayloadからViewData/Sectionを組み立てるFactory。
// Payload→フラットなViewData変換(makeEntries)はレシピ名の結合が必要なためFactoryが担い、
// グルーピング・フィルタ・検索(makeSections)はローカルに（Repositoryへ再アクセスせず）行う。

import Foundation

// MARK: - TimelineSectionViewData

struct TimelineSectionViewData: Sendable, Hashable, Identifiable {
    // 暦日キー文字列をIDにする
    let id: String
    let dayKey: DateKey
    // 見出し（例: 2026年10月22日(木)）
    let title: String
    let entries: [TimelineEntryViewData]
}

// MARK: - TimelineViewDataFactory

struct TimelineViewDataFactory {

    // レシピ情報欠損時の代替タイトル
    static let missingRecipeTitle = "レシピ情報を取得できませんでした"

    // 日付見出し用のFormatter（Section見出しで使う）
    private static let sectionTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日(E)"
        return formatter
    }()

    // 日付キー→Date復元用のCalendar（データ生成側と揃える）
    private let calendar: Calendar

    init(calendar: Calendar = DateKeyCalendar.default) {
        self.calendar = calendar
    }

    // MARK: - Payload → フラットなViewData

    // 掲載レシピとMealLogを1種類の配列へ変換する。レシピ名はMasterから解決し、欠損も安全に扱う。
    func makeEntries(from payload: TimelinePayload) -> [TimelineEntryViewData] {
        let recipeByID = Dictionary(payload.recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let recipeEntries = payload.dailyEntries.map { entry -> TimelineEntryViewData in
            let recipe = recipeByID[entry.recipeID]
            let title = recipe?.title ?? Self.missingRecipeTitle
            let subtitle = recipe?.summary
            return TimelineEntryViewData(
                id: "recipe-\(entry.id.rawValue)",
                dayKey: entry.dateKey,
                kind: .recipe,
                recipeID: entry.recipeID,
                title: title,
                subtitle: subtitle,
                rating: nil,
                recipeMissing: recipe == nil,
                searchableText: [title, subtitle ?? ""].joined(separator: " ").lowercased()
            )
        }

        let mealLogEntries = payload.mealLogs.map { log -> TimelineEntryViewData in
            let recipe = recipeByID[log.recipeID]
            let title = recipe?.title ?? Self.missingRecipeTitle
            let subtitle = log.memo.isEmpty ? nil : log.memo
            return TimelineEntryViewData(
                id: "meallog-\(log.id.rawValue.uuidString)",
                dayKey: log.dateKey,
                kind: .mealLog,
                recipeID: log.recipeID,
                title: title,
                subtitle: subtitle,
                rating: log.rating,
                recipeMissing: recipe == nil,
                searchableText: [title, log.memo].joined(separator: " ").lowercased()
            )
        }

        return recipeEntries + mealLogEntries
    }

    // MARK: - フィルタ・検索・グルーピング（ローカル）

    // フィルタと検索を適用し、日付降順のSection配列にまとめる。空の日はSectionを作らない。
    func makeSections(
        entries: [TimelineEntryViewData],
        filter: TimelineFilter,
        searchText: String
    ) -> [TimelineSectionViewData] {
        let normalizedQuery = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filtered = entries.filter { entry in
            matchesFilter(entry, filter) && matchesQuery(entry, normalizedQuery)
        }

        // 日付降順。同日内はレシピ→MealLogの順、さらにidで安定化（決定的順序）
        let grouped = Dictionary(grouping: filtered, by: \.dayKey)
        return grouped.keys
            .sorted(by: >)
            .map { dayKey in
                let sorted = (grouped[dayKey] ?? []).sorted { lhs, rhs in
                    if lhs.kind != rhs.kind {
                        return kindOrder(lhs.kind) < kindOrder(rhs.kind)
                    }
                    return lhs.id < rhs.id
                }
                return TimelineSectionViewData(
                    id: dayKey.value,
                    dayKey: dayKey,
                    title: sectionTitle(for: dayKey),
                    entries: sorted
                )
            }
    }

    // MARK: - Private Function

    private func matchesFilter(_ entry: TimelineEntryViewData, _ filter: TimelineFilter) -> Bool {
        switch filter {
        case .all: return true
        case .recipe: return entry.kind == .recipe
        case .mealLog: return entry.kind == .mealLog
        }
    }

    private func matchesQuery(_ entry: TimelineEntryViewData, _ query: String) -> Bool {
        query.isEmpty || entry.searchableText.contains(query)
    }

    private func kindOrder(_ kind: TimelineEntryKind) -> Int {
        switch kind {
        case .recipe: return 0
        case .mealLog: return 1
        }
    }

    // 日付キー("yyyy-MM-dd")から曜日付きの見出しを作る（同じCalendarで解釈）
    private func sectionTitle(for dayKey: DateKey) -> String {
        let parts = dayKey.value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else {
            return dayKey.value
        }
        return Self.sectionTitleFormatter.string(from: date)
    }
}
