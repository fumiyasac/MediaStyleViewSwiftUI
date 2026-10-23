//
//  CalendarUseCase.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 月単位の日別レシピ割当を取得するUseCase。
// Presentation(Reducer/ViewModel)はこのProtocol越しにデータ取得へ依存し、
// 実装(FixtureやBackend)を差し替えられるようにする。Actor境界を越えて注入できるようSendable。
// 新しいDomain Modelは作らず、PR #6のRecipe/DailyRecipeEntryをそのまま再利用する。

import Foundation

// MARK: - CalendarUseCase

protocol CalendarUseCase: Sendable {

    // 指定した月(Dateのどの日でも可)に属する日別割当を、日付順で返す
    func loadMonth(_ month: Date) async throws -> [DailyRecipeEntry]
}

// MARK: - DefaultCalendarUseCase

// RecipeRepositoryを使ったUseCase実装。
// 全割当からその月(yyyy-MM)に属するものを抽出する。月の境界判定はDateKeyの前方一致で行い、
// 判定に使うCalendar(TimeZone内包)はDateKey生成時と揃えてズレを防ぐ。
struct DefaultCalendarUseCase: CalendarUseCase {

    // MARK: - Property

    private let repository: any RecipeRepository
    private let calendar: Calendar

    // MARK: - Initializer

    init(repository: any RecipeRepository, calendar: Calendar = DateKeyCalendar.default) {
        self.repository = repository
        self.calendar = calendar
    }

    // MARK: - CalendarUseCase

    func loadMonth(_ month: Date) async throws -> [DailyRecipeEntry] {
        let prefix = monthPrefix(for: month)
        let all = try await repository.allDailyEntries()
        return all
            .filter { $0.dateKey.value.hasPrefix(prefix) }
            .sorted { $0.dateKey < $1.dateKey }
    }

    // MARK: - Private Function

    // Dateから「yyyy-MM」を組み立てる（DateKeyの先頭と突き合わせるため同じCalendarを使う）
    private func monthPrefix(for month: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }
}
