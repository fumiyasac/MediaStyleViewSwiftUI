//
//  CalendarUseCase.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// 月単位でカレンダー表示に必要なデータ（該当月のレシピ掲載と調理記録）を取得するUseCase。
// Presentation(Reducer/ViewModel)はこのProtocol越しに依存し、実装(Fixture+SwiftData)を差し替えられる。
// Actor境界を越えて注入できるようSendable。取得結果はSendable値型(Domain Model)のみを扱い、
// SwiftData Entityは外へ出さない。
//
// 重要: レシピ掲載日(DailyRecipeEntry.dateKey)と調理日(MealLogSummary.dateKey)は意味が異なるため、
//       別々に取得して別フィールドで返す（同一視しない）。

import Foundation

// MARK: - CalendarMonthPayload

// 1ヶ月分の取得結果。掲載レシピと調理記録を分けて保持するSendable値型。
// originは掲載レシピの取得元(最新/キャッシュ)。既定は.remoteで、Fixtureやキャッシュ非対応構成では
// 従来どおり.remote扱いになる（追加表示を出さない）。
struct CalendarMonthPayload: Sendable, Equatable {
    let recipeEntries: [DailyRecipeEntry]
    let mealLogs: [MealLogSummary]
    let origin: RecipeDataOrigin

    init(
        recipeEntries: [DailyRecipeEntry],
        mealLogs: [MealLogSummary],
        origin: RecipeDataOrigin = .remote
    ) {
        self.recipeEntries = recipeEntries
        self.mealLogs = mealLogs
        self.origin = origin
    }

    static let empty = CalendarMonthPayload(recipeEntries: [], mealLogs: [])
}

// MARK: - CalendarUseCase

protocol CalendarUseCase: Sendable {

    // 指定した月(Dateのどの日でも可)の掲載レシピと調理記録をまとめて返す
    func loadMonth(_ month: Date) async throws -> CalendarMonthPayload
}

// MARK: - DefaultCalendarUseCase

// RecipeRepository(掲載レシピ)とMealLogRepository(調理記録)を組み合わせるUseCase実装。
// 月の境界判定はDateKey/MonthKeyの前方一致・範囲で行い、判定に使うCalendar(TimeZone内包)は
// DateKey生成時と揃えてズレを防ぐ。2つの取得はasync letで並行実行する。
struct DefaultCalendarUseCase: CalendarUseCase {

    // MARK: - Property

    private let recipeRepository: any RecipeRepository
    private let mealLogRepository: any MealLogRepository
    private let calendar: Calendar

    // MARK: - Initializer

    init(
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository,
        calendar: Calendar = DateKeyCalendar.default
    ) {
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
        self.calendar = calendar
    }

    // MARK: - CalendarUseCase

    func loadMonth(_ month: Date) async throws -> CalendarMonthPayload {
        let monthKey = MonthKey(date: month, calendar: calendar)
        let range = monthKey.dateKeyRange

        // 掲載レシピ(当月範囲)と調理記録(当月範囲)を並行取得する。
        // 掲載レシピは範囲取得(dailyEntries(in:))で当月の閉区間だけを要求する。
        // Remote実装ではこれがCalendar API(from/to=当月)の1リクエストになり、全期間を取りに行かない。
        // キャッシュ対応Repositoryなら取得元(最新/キャッシュ)も受け取り、Payloadへ添えてUIへ運ぶ。
        async let entriesResult = loadEntries(in: range)
        async let monthLogs = mealLogRepository.summaries(in: range)

        let (entries, origin) = try await entriesResult
        let recipeEntries = entries.sorted { $0.dateKey < $1.dateKey }
        let mealLogs = try await monthLogs

        return CalendarMonthPayload(recipeEntries: recipeEntries, mealLogs: mealLogs, origin: origin)
    }

    // 取得元(origin)付きで掲載割当を取得する。Repositoryがキャッシュ対応(CacheAwareRecipeReading)なら
    // 出所付きで読み、そうでなければ(Fixture/直Remote)最新(.remote)として扱う。
    private func loadEntries(
        in range: ClosedRange<DateKey>
    ) async throws -> (entries: [DailyRecipeEntry], origin: RecipeDataOrigin) {
        if let cacheAware = recipeRepository as? CacheAwareRecipeReading {
            let result = try await cacheAware.loadDailyEntries(in: range)
            return (result.entries, result.origin)
        }
        return (try await recipeRepository.dailyEntries(in: range), .remote)
    }
}
