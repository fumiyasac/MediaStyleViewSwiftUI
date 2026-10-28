//
//  RemoteRecipeRepository.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Go Backend API を介して Recipe / DailyRecipeEntry を供給する RecipeRepository 実装。
//
// 既存の RecipeRepository Protocol にそのまま準拠する（Protocol は変更しない）。
// Fixture 実装と差し替え可能にしておき、本番採用は次 PR で行う（本 PR では既定は Fixture のまま）。
//
// Protocol と API 形状の差異をここで吸収する:
//  - allRecipes(): API はページング（limit/offset）のため、pagination.total まで全ページ取得する。
//    1 ページ目を「全件」とみなす実装は誤りなので明示的に total まで走査する。
//  - recipe(for:): 詳細エンドポイントが 404(RECIPE_NOT_FOUND) を返したら nil（「存在しない」は正常系）。
//  - dailyEntries(for:): カレンダー API を from=to=当日で呼ぶ。
//  - allDailyEntries(): API に「全期間」エンドポイントは無い（レンジは最大 92 日）。
//    基準日 ±45 日（計 91 日）の有限ウィンドウで取得する。UI の走査要件を満たす範囲に限定する妥協であり、
//    無制限の全期間ではない点を明示しておく（本番採用時に要件へ合わせて調整する）。
//
// 失敗時に Fixture へ暗黙フォールバックしない（エラーは呼び出し側へ伝搬させ、原因を隠さない）。

import Foundation

struct RemoteRecipeRepository: RecipeRepository {

    // MARK: - Property

    private let apiClient: APIClient
    private let calendar: Calendar
    // allDailyEntries のウィンドウ中心となる基準日。テストで固定できるよう注入可能にする。
    private let referenceDate: @Sendable () -> Date

    // 1 ページあたりの取得件数（全件取得時のページサイズ）
    private let pageSize = 100
    // allDailyEntries のウィンドウ半径（日数）。±45 日 = 計 91 日 ≦ API 上限 92 日。
    private let windowRadiusInDays = 45

    // MARK: - Initializer

    init(
        apiClient: APIClient,
        calendar: Calendar = DateKeyCalendar.default,
        referenceDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.apiClient = apiClient
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    // MARK: - RecipeRepository

    // レシピ Master を全件返す（pagination.total に達するまで全ページ取得）。
    func allRecipes() async throws -> [Recipe] {
        var collected: [Recipe] = []
        var offset = 0

        while true {
            try Task.checkCancellation()
            let response = try await apiClient.recipeList(category: nil, limit: pageSize, offset: offset)
            let mapped = try response.items.map { try RecipeDTOMapper.map($0) }
            collected.append(contentsOf: mapped)

            offset += response.items.count
            // これ以上ページが無い（total 到達 or 空ページ）なら終了
            if response.items.isEmpty || collected.count >= response.pagination.total {
                break
            }
        }
        return collected
    }

    // 指定 ID のレシピを返す（404 は nil）。
    func recipe(for id: RecipeID) async throws -> Recipe? {
        do {
            let dto = try await apiClient.recipeDetail(id: id.rawValue)
            return try RecipeDTOMapper.map(dto)
        } catch let error as APIClientError {
            if case .notFound = error {
                return nil // 「存在しない」は正常系として nil を返す
            }
            throw error
        }
    }

    // 指定暦日の掲載割当を返す（from=to=当日）。
    func dailyEntries(for dateKey: DateKey) async throws -> [DailyRecipeEntry] {
        let response = try await apiClient.calendar(from: dateKey.value, to: dateKey.value)
        return try response.items.map { try RecipeDTOMapper.map($0) }
    }

    // 指定範囲の掲載割当を返す。範囲をそのままCalendar API(from/to)へ渡し、必要な範囲だけ取得する。
    // 既定実装(allDailyEntries→フィルタ)をoverrideし、Calendarの月表示・Timelineが
    // 「表示に必要な範囲」だけをAPIから取ってくるようにする（全期間の過剰取得を避ける）。
    // 呼び出し側(Calendar: 1ヶ月, Timeline: 約60日)はいずれもCalendar APIの上限(92日)以内。
    func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry] {
        let response = try await apiClient.calendar(
            from: range.lowerBound.value,
            to: range.upperBound.value
        )
        return try response.items.map { try RecipeDTOMapper.map($0) }
    }

    // 全期間の掲載割当を返す（基準日 ±45 日の有限ウィンドウに限定）。
    func allDailyEntries() async throws -> [DailyRecipeEntry] {
        let base = referenceDate()
        guard
            let fromDate = calendar.date(byAdding: .day, value: -windowRadiusInDays, to: base),
            let toDate = calendar.date(byAdding: .day, value: windowRadiusInDays, to: base)
        else {
            throw APIClientError.mapping(message: "基準日からウィンドウを算出できませんでした")
        }
        let from = DateKey(date: fromDate, calendar: calendar).value
        let to = DateKey(date: toDate, calendar: calendar).value

        let response = try await apiClient.calendar(from: from, to: to)
        return try response.items.map { try RecipeDTOMapper.map($0) }
    }
}
