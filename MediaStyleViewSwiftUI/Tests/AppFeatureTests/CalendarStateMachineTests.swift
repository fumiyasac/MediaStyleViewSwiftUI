//
//  CalendarStateMachineTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar FeatureのStateMachine（Reducer純粋遷移 / ViewModelの非同期ロード）のテスト。

@testable import AppFeature
import Foundation
import XCTest

// MARK: - Test Doubles

// 挙動を差し込める調理ログ取得のStub。可変状態を持つためactorでSendableにする
// （@unchecked Sendableは使わない）。
private actor StubCalendarUseCase: CalendarUseCase {

    enum Behavior: Sendable {
        case success([DailyRecipeEntry])
        case failure(message: String)
        case cancelled
    }

    private var queue: [Behavior]
    private let fallback: Behavior
    private(set) var receivedMonths: [Date] = []

    init(_ behaviors: [Behavior], fallback: Behavior = .success([])) {
        self.queue = behaviors
        self.fallback = fallback
    }

    func loadMonth(_ month: Date) async throws -> [DailyRecipeEntry] {
        receivedMonths.append(month)
        let behavior = queue.isEmpty ? fallback : queue.removeFirst()
        switch behavior {
        case let .success(entries):
            return entries
        case let .failure(message):
            throw StubUseCaseError.message(message)
        case .cancelled:
            throw CancellationError()
        }
    }
}

private enum StubUseCaseError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case let .message(message): return message
        }
    }
}

// MARK: - Fixture Helpers（テスト全体で使う決定的なデータ）

private let tokyoCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    tokyoCalendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func makeEntry(_ dateKey: String, _ recipe: String) -> DailyRecipeEntry {
    DailyRecipeEntry(
        id: DailyRecipeEntryID("daily-\(dateKey)"),
        dateKey: DateKey(value: dateKey),
        recipeID: RecipeID(recipe)
    )
}

// MARK: - CalendarReducerTests

final class CalendarReducerTests: XCTestCase {

    private let reducer = CalendarReducer()

    private func initialState() -> CalendarFeatureState {
        CalendarFeatureState.initial(referenceDate: makeDate(2026, 3, 15), calendar: tokyoCalendar)
    }

    // 1. 読み込み開始Actionで、loading化＋進行中ID設定＋読み込みEffectが返る
    func testBeginLoadingReturnsLoadEffect() {
        let id = UUID()
        let month = makeDate(2026, 3, 1)
        let transition = reducer.reduce(state: initialState(), action: .beginLoading(requestID: id, month: month))

        XCTAssertEqual(transition.state.currentRequestID, id)
        XCTAssertTrue(transition.state.isLoading)
        XCTAssertEqual(transition.state.displayedMonth, month)
        XCTAssertEqual(transition.effects, [.loadMonth(requestID: id, month: month)])
    }

    // onAppear / loadMonth はReducerではno-op（ViewModelがbeginLoadingへ展開する）
    func testIntentActionsAreNoOpInReducer() {
        let state = initialState()
        XCTAssertEqual(reducer.reduce(state: state, action: .onAppear), CalendarTransition(state: state, effects: []))
        XCTAssertEqual(
            reducer.reduce(state: state, action: .loadMonth(makeDate(2026, 4, 1))),
            CalendarTransition(state: state, effects: [])
        )
    }

    // 2. 日付選択でselectedDateが更新され、Effectは無い
    func testSelectDateUpdatesSelectedDate() {
        let selected = makeDate(2026, 3, 20)
        let transition = reducer.reduce(state: initialState(), action: .selectDate(selected))
        XCTAssertEqual(transition.state.selectedDate, selected)
        XCTAssertTrue(transition.effects.isEmpty)
    }

    // 3. 読み込み成功でentriesがloadedとして反映され、進行中IDがクリアされる
    func testLoadSucceededReflectsEntries() {
        let id = UUID()
        var loading = initialState()
        loading.currentRequestID = id
        loading.entriesState = .loading(previous: [])
        let entries = [makeEntry("2026-03-01", "recipe-01"), makeEntry("2026-03-02", "recipe-02")]

        let transition = reducer.reduce(state: loading, action: .loadSucceeded(requestID: id, entries: entries))

        XCTAssertEqual(transition.state.entriesState, .loaded(entries))
        XCTAssertEqual(transition.state.entries, entries)
        XCTAssertNil(transition.state.currentRequestID)
        XCTAssertTrue(transition.effects.isEmpty)
    }

    // 4. 読み込み失敗でfailedになり、直前データは保持される
    func testLoadFailedSetsErrorAndKeepsPrevious() {
        let id = UUID()
        let previous = [makeEntry("2026-03-01", "recipe-01")]
        var loading = initialState()
        loading.currentRequestID = id
        loading.entriesState = .loading(previous: previous)

        let transition = reducer.reduce(state: loading, action: .loadFailed(requestID: id, message: "読み込み失敗"))

        XCTAssertEqual(transition.state.errorMessage, "読み込み失敗")
        XCTAssertEqual(transition.state.entries, previous)
        XCTAssertNil(transition.state.currentRequestID)
    }

    // 5. 古いrequestIDの成功結果は無視される
    func testStaleSucceededIsIgnored() {
        let current = UUID()
        let stale = UUID()
        var loading = initialState()
        loading.currentRequestID = current
        loading.entriesState = .loading(previous: [])

        let transition = reducer.reduce(
            state: loading,
            action: .loadSucceeded(requestID: stale, entries: [makeEntry("2026-03-01", "recipe-01")])
        )
        XCTAssertEqual(transition.state, loading)
        XCTAssertTrue(transition.effects.isEmpty)
    }

    // 6. 古いrequestIDの失敗結果は無視される
    func testStaleFailedIsIgnored() {
        let current = UUID()
        let stale = UUID()
        var loading = initialState()
        loading.currentRequestID = current
        loading.entriesState = .loading(previous: [])

        let transition = reducer.reduce(state: loading, action: .loadFailed(requestID: stale, message: "x"))
        XCTAssertEqual(transition.state, loading)
    }

    // 8. 複数回の読み込みで、古い結果が新しい結果を上書きしない
    func testNewerResultIsNotOverwrittenByOlder() {
        let idA = UUID()
        let idB = UUID()
        let entriesA = [makeEntry("2026-03-01", "recipe-01")]
        let entriesB = [makeEntry("2026-04-01", "recipe-02")]

        // A開始→A成功（loaded A）
        var state = initialState()
        state = reducer.reduce(state: state, action: .beginLoading(requestID: idA, month: makeDate(2026, 3, 1))).state
        state = reducer.reduce(state: state, action: .loadSucceeded(requestID: idA, entries: entriesA)).state
        XCTAssertEqual(state.entries, entriesA)

        // B開始（進行中IDがBになる）
        state = reducer.reduce(state: state, action: .beginLoading(requestID: idB, month: makeDate(2026, 4, 1))).state

        // 遅れて届いたAの成功は無視される
        state = reducer.reduce(state: state, action: .loadSucceeded(requestID: idA, entries: entriesA)).state
        XCTAssertEqual(state.currentRequestID, idB)

        // Bの成功で最新化される
        state = reducer.reduce(state: state, action: .loadSucceeded(requestID: idB, entries: entriesB)).state
        XCTAssertEqual(state.entries, entriesB)
    }

    // 9. 同一State・Actionに対してReducerは常に同じ結果を返す
    func testReducerIsDeterministic() {
        let id = UUID()
        let state = initialState()
        let actions: [CalendarAction] = [
            .selectDate(makeDate(2026, 3, 9)),
            .beginLoading(requestID: id, month: makeDate(2026, 3, 1)),
            .onAppear,
        ]
        for action in actions {
            XCTAssertEqual(reducer.reduce(state: state, action: action), reducer.reduce(state: state, action: action))
        }
    }
}

// MARK: - CalendarViewModelTests

@MainActor
final class CalendarViewModelTests: XCTestCase {

    private func initialState() -> CalendarFeatureState {
        CalendarFeatureState.initial(referenceDate: makeDate(2026, 3, 15), calendar: tokyoCalendar)
    }

    // 読み込み成功でViewModelのStateへentriesが反映される
    func testViewModelLoadSuccess() async throws {
        let entries = [makeEntry("2026-03-01", "recipe-01"), makeEntry("2026-03-02", "recipe-02")]
        let viewModel = CalendarViewModel(
            useCase: StubCalendarUseCase([.success(entries)]),
            initialState: initialState()
        )

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value

        XCTAssertEqual(viewModel.state.entries, entries)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.errorMessage)
    }

    // 4(ViewModel側). 読み込み失敗でエラー状態になる
    func testViewModelLoadFailure() async throws {
        let viewModel = CalendarViewModel(
            useCase: StubCalendarUseCase([.failure(message: "通信エラー")]),
            initialState: initialState()
        )

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value

        XCTAssertEqual(viewModel.state.errorMessage, "通信エラー")
    }

    // 7. キャンセルされた読み込みは画面エラーにならない
    func testViewModelCancelledLoadDoesNotBecomeError() async throws {
        let viewModel = CalendarViewModel(
            useCase: StubCalendarUseCase([.cancelled]),
            initialState: initialState()
        )

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value

        XCTAssertNil(viewModel.state.errorMessage)
        // 完了Actionが来ないためloadingのまま（エラー表示にはしない）
        XCTAssertTrue(viewModel.state.isLoading)
    }

    // selectDateでViewModelのselectedDateが更新される
    func testViewModelSelectDate() {
        let viewModel = CalendarViewModel(
            useCase: StubCalendarUseCase([]),
            initialState: initialState()
        )
        let selected = makeDate(2026, 3, 25)
        viewModel.send(.selectDate(selected))
        XCTAssertEqual(viewModel.state.selectedDate, selected)
    }

    // 10. Fixture Repositoryを使って月のロードを検証する
    func testViewModelLoadsViaFixtureRepository() async throws {
        let reference = makeDate(2026, 3, 15)
        let repository = FixtureRecipeRepository(referenceDate: reference, calendar: tokyoCalendar)
        let useCase = DefaultCalendarUseCase(repository: repository, calendar: tokyoCalendar)
        let viewModel = CalendarViewModel(
            useCase: useCase,
            initialState: .initial(referenceDate: reference, calendar: tokyoCalendar)
        )

        viewModel.send(.onAppear)
        await viewModel.loadTask?.value

        let entries = viewModel.state.entries
        // 基準日±15日のうち3月分（30件）が読み込まれる
        XCTAssertEqual(entries.count, 30)
        XCTAssertTrue(entries.allSatisfy { $0.dateKey.value.hasPrefix("2026-03") })
        XCTAssertFalse(viewModel.state.isLoading)
    }
}
