//
//  TimelineTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineの Factory(グルーピング/ID/検索/フィルタ) と Reducer/ViewModel(StateMachine/DI) のテスト。

@testable import AppFeature
import Foundation
import XCTest

private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
private let utc = DateKeyCalendar.make(timeZone: TimeZone(identifier: "UTC")!)
private func d(_ y: Int, _ m: Int, _ dd: Int, _ h: Int = 12) -> Date {
    tokyo.date(from: DateComponents(year: y, month: m, day: dd, hour: h))!
}
private func recipe(_ id: String, _ title: String, _ summary: String = "概要") -> Recipe {
    Recipe(id: RecipeID(id), title: title, summary: summary, category: .japanese, cookingMinutes: 10, calories: 100, servings: 1, ingredients: ["材料A"], steps: ["手順1"])
}
private func entry(_ dateKey: String, _ recipeID: String) -> DailyRecipeEntry {
    DailyRecipeEntry(id: DailyRecipeEntryID("daily-\(dateKey)-\(recipeID)"), dateKey: DateKey(value: dateKey), recipeID: RecipeID(recipeID))
}
private func log(_ dateKey: String, _ recipeID: String, rating: Int = 4, memo: String = "", id: MealLogID = MealLogID()) -> MealLogSummary {
    MealLogSummary(id: id, recipeID: RecipeID(recipeID), dateKey: DateKey(value: dateKey), cookedAt: d(2026, 3, 1), rating: rating, memo: memo, servings: 1)
}

// MARK: - Factory（グルーピング・ID・検索・フィルタ）

final class TimelineViewDataFactoryTests: XCTestCase {

    private let factory = TimelineViewDataFactory(calendar: tokyo)

    private func sections(_ payload: TimelinePayload, _ filter: TimelineFilter = .all, _ search: String = "") -> [TimelineSectionViewData] {
        factory.makeSections(entries: factory.makeEntries(from: payload), filter: filter, searchText: search)
    }

    // 1 & 2 & 3. 日付別グルーピング・降順・同日のRecipe/MealLog共存
    func testGroupingDescendingAndCoexist() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1"), entry("2026-03-12", "r2")],
            mealLogs: [log("2026-03-10", "r1"), log("2026-03-11", "r2")],
            recipes: [recipe("r1", "鮭"), recipe("r2", "肉じゃが")]
        )
        let result = sections(payload)
        XCTAssertEqual(result.map(\.dayKey.value), ["2026-03-12", "2026-03-11", "2026-03-10"])
        // 3/10は掲載1＋記録1が同Section
        let march10 = result.first { $0.dayKey.value == "2026-03-10" }
        XCTAssertEqual(march10?.entries.count, 2)
        // 同日内はレシピ→記録の順
        XCTAssertEqual(march10?.entries.map(\.kind), [.recipe, .mealLog])
    }

    // 4. 同じRecipeの複数日掲載
    func testSameRecipeMultipleDays() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1"), entry("2026-03-15", "r1")],
            mealLogs: [], recipes: [recipe("r1", "鮭")]
        )
        let result = sections(payload)
        XCTAssertEqual(result.count, 2)
        // 掲載項目IDは日付で異なる（Recipe IDだけに依存しない）
        let ids = result.flatMap { $0.entries.map(\.id) }
        XCTAssertEqual(Set(ids).count, 2)
    }

    // 5 & 6. 同じRecipeの複数回調理・Recipe未掲載日のMealLog表示
    func testMultipleMealLogsAndUnpublishedDay() {
        let payload = TimelinePayload(
            dailyEntries: [],
            mealLogs: [log("2026-03-10", "r1"), log("2026-03-10", "r1"), log("2026-03-20", "r1")],
            recipes: [recipe("r1", "鮭")]
        )
        let result = sections(payload)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first { $0.dayKey.value == "2026-03-10" }?.entries.count, 2)
    }

    // 9. 安定したID（掲載とMealLogで衝突しない）
    func testStableDistinctIDs() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1")],
            mealLogs: [log("2026-03-10", "r1")],
            recipes: [recipe("r1", "鮭")]
        )
        let entries = factory.makeEntries(from: payload)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertTrue(entries.contains { $0.id.hasPrefix("recipe-") })
        XCTAssertTrue(entries.contains { $0.id.hasPrefix("meallog-") })
    }

    // 10. Recipe参照欠損でも安全に表示（代替タイトル）
    func testMissingRecipeIsSafe() {
        let payload = TimelinePayload(
            dailyEntries: [],
            mealLogs: [log("2026-03-10", "unknown")],
            recipes: []
        )
        let entries = factory.makeEntries(from: payload)
        XCTAssertEqual(entries.first?.title, TimelineViewDataFactory.missingRecipeTitle)
        XCTAssertTrue(entries.first?.recipeMissing ?? false)
    }

    // 7 & 8. 年跨ぎ・TimeZone（見出しが崩れない・別Calendarでも成立）
    func testYearCrossingSections() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-12-31", "r1"), entry("2027-01-01", "r1")],
            mealLogs: [], recipes: [recipe("r1", "年越し")]
        )
        let result = sections(payload)
        XCTAssertEqual(result.map(\.dayKey.value), ["2027-01-01", "2026-12-31"])
        XCTAssertFalse(result.allSatisfy { $0.title == $0.dayKey.value }) // 曜日付き見出しに変換されている
    }

    // 11 & 12 & 13. フィルタ
    func testFilters() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1")],
            mealLogs: [log("2026-03-10", "r1")],
            recipes: [recipe("r1", "鮭")]
        )
        XCTAssertEqual(sections(payload, .all).flatMap { $0.entries }.count, 2)
        XCTAssertTrue(sections(payload, .recipe).flatMap { $0.entries }.allSatisfy { $0.kind == .recipe })
        XCTAssertTrue(sections(payload, .mealLog).flatMap { $0.entries }.allSatisfy { $0.kind == .mealLog })
    }

    // 14 & 15 & 16. タイトル検索・メモ検索・フィルタ併用
    func testSearchAndCombination() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1"), entry("2026-03-11", "r2")],
            mealLogs: [log("2026-03-10", "r1", memo: "鮭が美味しかった"), log("2026-03-11", "r2", memo: "普通")],
            recipes: [recipe("r1", "鮭の塩麹焼き"), recipe("r2", "肉じゃが")]
        )
        // タイトル検索「鮭」→ レシピ掲載＋記録の両方（r1関連）
        XCTAssertTrue(sections(payload, .all, "鮭").flatMap { $0.entries }.allSatisfy { $0.recipeID == RecipeID("r1") })
        // メモ検索「美味しかった」→ MealLogのみ
        let memoHit = sections(payload, .all, "美味しかった").flatMap { $0.entries }
        XCTAssertEqual(memoHit.count, 1)
        XCTAssertEqual(memoHit.first?.kind, .mealLog)
        // フィルタ「作った記録」＋検索「鮭」→ r1のMealLogのみ
        let combo = sections(payload, .mealLog, "鮭").flatMap { $0.entries }
        XCTAssertEqual(combo.count, 1)
        XCTAssertEqual(combo.first?.kind, .mealLog)
    }

    // 17. 検索0件（取得0件とは別物＝sectionsが空になる）
    func testSearchNoResults() {
        let payload = TimelinePayload(
            dailyEntries: [entry("2026-03-10", "r1")], mealLogs: [], recipes: [recipe("r1", "鮭")]
        )
        XCTAssertTrue(sections(payload, .all, "存在しない語").isEmpty)
    }
}

// MARK: - Reducer / ViewModel / DI

private actor StubTimelineUseCase: TimelineUseCase {
    enum Behavior: Sendable { case success(TimelinePayload); case failure(String); case cancelled }
    private var queue: [Behavior]
    private(set) var callCount = 0
    init(_ behaviors: [Behavior]) { self.queue = behaviors }
    func load(in range: ClosedRange<DateKey>) async throws -> TimelinePayload {
        callCount += 1
        let behavior = queue.isEmpty ? .success(.empty) : queue.removeFirst()
        switch behavior {
        case let .success(p): return p
        case let .failure(m): throw StubTLError.message(m)
        case .cancelled: throw CancellationError()
        }
    }
}
private enum StubTLError: Error, LocalizedError { case message(String); var errorDescription: String? { switch self { case let .message(m): return m } } }

final class TimelineReducerTests: XCTestCase {
    private let reducer = TimelineReducer()

    // 18. beginLoadingでloadingとEffect
    func testBeginLoading() {
        let id = UUID()
        let t = reducer.reduce(state: .initial, action: .beginLoading(requestID: id))
        XCTAssertEqual(t.state.phase, .loading)
        XCTAssertEqual(t.effects, [.load(requestID: id)])
    }

    // 20. 古いrequestIDの成功は無視
    func testStaleSucceededIgnored() {
        var state = TimelineState.initial
        state.phase = .loading
        state.requestID = UUID()
        let t = reducer.reduce(state: state, action: .loadSucceeded(requestID: UUID(), entries: []))
        XCTAssertEqual(t.state, state)
    }

    // 19. 失敗でエラー・既存entries保持
    func testFailedKeepsEntries() {
        var state = TimelineState.initial
        state.entries = [TimelineEntryViewData(id: "recipe-x", dayKey: DateKey(value: "2026-03-10"), kind: .recipe, recipeID: RecipeID("r1"), title: "鮭", subtitle: nil, rating: nil, recipeMissing: false, searchableText: "鮭")]
        state.phase = .loading
        let id = UUID(); state.requestID = id
        let t = reducer.reduce(state: state, action: .loadFailed(requestID: id, message: "失敗"))
        XCTAssertEqual(t.state.errorMessage, "失敗")
        XCTAssertEqual(t.state.entries.count, 1)
    }
}

@MainActor
final class TimelineViewModelTests: XCTestCase {

    private func makeViewModel(_ useCase: any TimelineUseCase) -> TimelineViewModel {
        TimelineViewModel(useCase: useCase, referenceDate: d(2026, 3, 15), calendar: tokyo)
    }

    // 18 & 24. 初回読み込み成功でStateへ反映（DI差し替え可能）
    func testOnAppearLoads() async throws {
        let payload = TimelinePayload(dailyEntries: [entry("2026-03-10", "r1")], mealLogs: [log("2026-03-10", "r1")], recipes: [recipe("r1", "鮭")])
        let viewModel = makeViewModel(StubTimelineUseCase([.success(payload)]))
        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        XCTAssertEqual(viewModel.state.phase, .loaded)
        XCTAssertEqual(viewModel.state.entries.count, 2)
    }

    // 19. 失敗でエラー状態
    func testLoadFailure() async throws {
        let viewModel = makeViewModel(StubTimelineUseCase([.failure("通信エラー")]))
        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        XCTAssertEqual(viewModel.state.errorMessage, "通信エラー")
    }

    // 21. キャンセルは画面エラーにしない
    func testCancelledNotError() async throws {
        let viewModel = makeViewModel(StubTimelineUseCase([.cancelled]))
        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        XCTAssertNil(viewModel.state.errorMessage)
    }

    // onAppearは既読なら再取得しない（無限読込防止）
    func testOnAppearDoesNotReloadWhenLoaded() async throws {
        let stub = StubTimelineUseCase([.success(.empty), .success(.empty)])
        let viewModel = makeViewModel(stub)
        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        viewModel.send(.onAppear)   // 既読なので何もしない
        await viewModel.loadTask?.value
        let count = await stub.callCount
        XCTAssertEqual(count, 1)
    }

    // 22 & 23. reloadで保存/削除後の最新データが反映される
    func testReloadReflectsLatest() async throws {
        let before = TimelinePayload(dailyEntries: [], mealLogs: [], recipes: [recipe("r1", "鮭")])
        let afterSave = TimelinePayload(dailyEntries: [], mealLogs: [log("2026-03-10", "r1", memo: "作った")], recipes: [recipe("r1", "鮭")])
        let viewModel = makeViewModel(StubTimelineUseCase([.success(before), .success(afterSave)]))

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value
        XCTAssertTrue(viewModel.state.entries.isEmpty)

        viewModel.send(.reload)   // 保存後の反映
        await viewModel.loadTask?.value
        XCTAssertEqual(viewModel.state.entries.count, 1)
        XCTAssertEqual(viewModel.state.entries.first?.kind, .mealLog)
    }
}
