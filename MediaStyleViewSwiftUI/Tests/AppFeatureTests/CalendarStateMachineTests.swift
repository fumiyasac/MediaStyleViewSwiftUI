//
//  CalendarStateMachineTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar FeatureのStateMachine（月単位Reducer遷移 / ViewModelの非同期ロード / DI）のテスト。
// Swift Testing へ移行済み。UseCase Stubはactorで並列安全、同期待ちはloadTasksのawaitで行う（Task.sleep非依存）。

@testable import AppFeature
import Foundation
import Testing

// MARK: - Test Doubles

// 挙動を差し込めるUseCase Stub。可変状態を持つためactorでSendableにする（@unchecked不使用）。
private actor StubCalendarUseCase: CalendarUseCase {

    enum Behavior: Sendable {
        case success(CalendarMonthPayload)
        case failure(message: String)
        case cancelled
    }

    private var queue: [Behavior]
    private let fallback: Behavior
    private(set) var loadedMonths: [Date] = []

    init(_ behaviors: [Behavior], fallback: Behavior = .success(.empty)) {
        self.queue = behaviors
        self.fallback = fallback
    }

    func loadMonth(_ month: Date) async throws -> CalendarMonthPayload {
        loadedMonths.append(month)
        let behavior = queue.isEmpty ? fallback : queue.removeFirst()
        switch behavior {
        case let .success(payload): return payload
        case let .failure(message): throw StubError.message(message)
        case .cancelled: throw CancellationError()
        }
    }
}

private enum StubError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case let .message(message): return message }
    }
}

// MARK: - Fixture Helpers

private let tokyoCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    tokyoCalendar.date(from: DateComponents(year: year, month: month, day: day))!
}

private func makeEntry(_ dateKey: String, _ recipe: String = "recipe-01") -> DailyRecipeEntry {
    DailyRecipeEntry(
        id: DailyRecipeEntryID("daily-\(dateKey)"),
        dateKey: DateKey(value: dateKey),
        recipeID: RecipeID(recipe)
    )
}

private func makeMealLog(_ dateKey: String, _ recipe: String = "recipe-01") -> MealLogSummary {
    MealLogSummary(
        id: MealLogID(),
        recipeID: RecipeID(recipe),
        dateKey: DateKey(value: dateKey),
        cookedAt: makeDate(2026, 3, 1),
        rating: 4,
        memo: "memo",
        servings: 2
    )
}

// MARK: - CalendarReducerTests

@Suite("Calendarの状態遷移")
struct CalendarReducerTests {

    private let reducer = CalendarReducer()

    private func initialState() -> CalendarFeatureState {
        .initial(referenceDate: makeDate(2026, 3, 15))
    }

    // 1. 読み込み開始で、その月がloading化し読み込みEffectが返る
    @Test("読み込み開始でその月がloading化し読み込みEffectが返る")
    func beginLoadingReturnsLoadEffect() {
        let id = UUID()
        let monthKey = MonthKey(value: "2026-03")
        let month = makeDate(2026, 3, 1)

        let transition = reducer.reduce(
            state: initialState(),
            action: .beginLoading(requestID: id, monthKey: monthKey, month: month)
        )
        #expect(transition.state.monthLoad(monthKey).phase == .loading)
        #expect(transition.state.monthLoad(monthKey).requestID == id)
        #expect(transition.effects == [.loadMonth(requestID: id, monthKey: monthKey, month: month)])
    }

    // 4. 日付選択でselectedDateが更新され、Effectは無い
    @Test("日付選択でselectedDateが更新されEffectは無い")
    func selectDateUpdatesSelectedDate() {
        let selected = makeDate(2026, 3, 20)
        let transition = reducer.reduce(state: initialState(), action: .selectDate(selected))
        #expect(transition.state.selectedDate == selected)
        #expect(transition.effects.isEmpty)
    }

    // 2 & 3. 読み込み成功でRecipeとMealLogがStateへ反映される
    @Test("読み込み成功でRecipeとMealLogがStateへ反映される")
    func loadSucceededReflectsRecipeAndMealLog() {
        let id = UUID()
        let monthKey = MonthKey(value: "2026-03")
        var state = initialState()
        state = reducer.reduce(
            state: state,
            action: .beginLoading(requestID: id, monthKey: monthKey, month: makeDate(2026, 3, 1))
        ).state

        let entries = [makeEntry("2026-03-01"), makeEntry("2026-03-02")]
        let logs = [makeMealLog("2026-03-01")]
        let transition = reducer.reduce(
            state: state,
            action: .loadSucceeded(
                requestID: id,
                monthKey: monthKey,
                payload: CalendarMonthPayload(recipeEntries: entries, mealLogs: logs)
            )
        )
        #expect(transition.state.monthLoad(monthKey).recipeEntries == entries)
        #expect(transition.state.monthLoad(monthKey).mealLogs == logs)
        #expect(transition.state.monthLoad(monthKey).phase == .loaded)
        #expect(transition.state.monthLoad(monthKey).requestID == nil)
    }

    // 5. 読み込み失敗で既存データが必要以上に消えない（直前のRecipe/MealLogを保持）
    @Test("読み込み失敗で直前のRecipe/MealLogを保持する")
    func loadFailedKeepsPreviousData() {
        let id = UUID()
        let monthKey = MonthKey(value: "2026-03")
        var state = initialState()
        // データ付きで読み込み中の状態を直接作る
        state.months[monthKey] = CalendarMonthLoad(
            recipeEntries: [makeEntry("2026-03-01")],
            mealLogs: [makeMealLog("2026-03-01")],
            phase: .loading,
            requestID: id
        )

        let transition = reducer.reduce(
            state: state,
            action: .loadFailed(requestID: id, monthKey: monthKey, message: "読み込み失敗")
        )
        #expect(transition.state.monthLoad(monthKey).phase == .failed(message: "読み込み失敗"))
        #expect(transition.state.monthLoad(monthKey).recipeEntries == [makeEntry("2026-03-01")])
        #expect(transition.state.monthLoad(monthKey).mealLogs.count == 1)
    }

    // 6. 古いrequestIDの成功結果は無視される
    @Test("古いrequestIDの成功結果は無視される")
    func staleSucceededIsIgnored() {
        let monthKey = MonthKey(value: "2026-03")
        var state = initialState()
        state.months[monthKey] = CalendarMonthLoad(
            recipeEntries: [], mealLogs: [], phase: .loading, requestID: UUID()
        )
        let transition = reducer.reduce(
            state: state,
            action: .loadSucceeded(
                requestID: UUID(),   // 進行中IDと別物
                monthKey: monthKey,
                payload: CalendarMonthPayload(recipeEntries: [makeEntry("2026-03-01")], mealLogs: [])
            )
        )
        #expect(transition.state == state)
    }

    // 7. 古いrequestIDの失敗結果は無視される
    @Test("古いrequestIDの失敗結果は無視される")
    func staleFailedIsIgnored() {
        let monthKey = MonthKey(value: "2026-03")
        var state = initialState()
        state.months[monthKey] = CalendarMonthLoad(
            recipeEntries: [], mealLogs: [], phase: .loading, requestID: UUID()
        )
        let transition = reducer.reduce(
            state: state,
            action: .loadFailed(requestID: UUID(), monthKey: monthKey, message: "x")
        )
        #expect(transition.state == state)
    }

    // 8. 別月の読み込み完了で、他月のデータが消えない
    @Test("別月の読み込み完了で他月のデータが消えない")
    func otherMonthDataIsPreserved() {
        let marchKey = MonthKey(value: "2026-03")
        let aprilKey = MonthKey(value: "2026-04")
        let aprilID = UUID()

        var state = initialState()
        // 3月は読み込み済み
        state.months[marchKey] = CalendarMonthLoad(
            recipeEntries: [makeEntry("2026-03-01")], mealLogs: [], phase: .loaded, requestID: nil
        )
        // 4月は読み込み中
        state.months[aprilKey] = CalendarMonthLoad(
            recipeEntries: [], mealLogs: [], phase: .loading, requestID: aprilID
        )

        let transition = reducer.reduce(
            state: state,
            action: .loadSucceeded(
                requestID: aprilID,
                monthKey: aprilKey,
                payload: CalendarMonthPayload(recipeEntries: [makeEntry("2026-04-01")], mealLogs: [])
            )
        )
        // 4月は更新、3月はそのまま
        #expect(transition.state.monthLoad(aprilKey).recipeEntries == [makeEntry("2026-04-01")])
        #expect(transition.state.monthLoad(marchKey).recipeEntries == [makeEntry("2026-03-01")])
        #expect(transition.state.monthLoad(marchKey).phase == .loaded)
    }

    // 9. 同じ月の重複読み込みは抑制される（loading/loaded中は新規Effectを出さない）
    @Test("同じ月の重複読み込みは抑制される")
    func duplicateLoadIsSuppressed() {
        let monthKey = MonthKey(value: "2026-03")
        var state = initialState()
        state.months[monthKey] = CalendarMonthLoad(
            recipeEntries: [], mealLogs: [], phase: .loading, requestID: UUID()
        )
        let transition = reducer.reduce(
            state: state,
            action: .beginLoading(requestID: UUID(), monthKey: monthKey, month: makeDate(2026, 3, 1))
        )
        #expect(transition.effects.isEmpty)
        #expect(transition.state == state)
    }

    // Reducerの決定性
    @Test("同じ条件なら同じ結果になる（決定性）")
    func reducerIsDeterministic() {
        let id = UUID()
        let monthKey = MonthKey(value: "2026-03")
        let state = initialState()
        let actions: [CalendarAction] = [
            .selectDate(makeDate(2026, 3, 9)),
            .beginLoading(requestID: id, monthKey: monthKey, month: makeDate(2026, 3, 1)),
            .onAppear,
        ]
        for action in actions {
            #expect(
                reducer.reduce(state: state, action: action) == reducer.reduce(state: state, action: action)
            )
        }
    }
}

// MARK: - CalendarViewModelTests

@MainActor
@Suite("Calendar ViewModelの非同期ロード")
struct CalendarViewModelTests {

    private let referenceDate = makeDate(2026, 3, 15)
    private var marchKey: MonthKey { MonthKey(date: referenceDate, calendar: tokyoCalendar) }

    private func makeViewModel(useCase: any CalendarUseCase) -> CalendarViewModel {
        CalendarViewModel(
            useCase: useCase,
            initialState: .initial(referenceDate: referenceDate),
            calendar: tokyoCalendar
        )
    }

    // 19 & 2 & 3. Fixture+InMemoryを注入し、onAppearでRecipe/MealLogがStateへ反映される
    @Test("onAppearでFixture+InMemoryからRecipe/MealLogがStateへ反映される")
    func viewModelOnAppearLoadsViaFixtureAndInMemory() async throws {
        let mealLogRepository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        // 20. InMemoryに当月の調理ログを事前投入
        _ = try await mealLogRepository.add(
            MealLogInput(recipeID: RecipeID("recipe-01"), cookedAt: makeDate(2026, 3, 10), rating: 5, memo: "作った", servings: 2)
        )
        let useCase = DefaultCalendarUseCase(
            recipeRepository: FixtureRecipeRepository(referenceDate: referenceDate, calendar: tokyoCalendar),
            mealLogRepository: mealLogRepository,
            calendar: tokyoCalendar
        )
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.send(.onAppear)
        await viewModel.loadTasks[marchKey]?.value

        let load = viewModel.state.monthLoad(marchKey)
        #expect(load.phase == .loaded)
        #expect(!load.recipeEntries.isEmpty)
        #expect(load.recipeEntries.allSatisfy { $0.dateKey.value.hasPrefix("2026-03") })
        #expect(load.mealLogs.map(\.dateKey) == [DateKey(value: "2026-03-10")])
    }

    // 4. selectDateでselectedDateが更新される
    @Test("selectDateでselectedDateが更新される")
    func viewModelSelectDate() {
        let viewModel = makeViewModel(useCase: StubCalendarUseCase([]))
        let selected = makeDate(2026, 3, 25)
        viewModel.send(.selectDate(selected))
        #expect(viewModel.state.selectedDate == selected)
    }

    // 10. キャンセルされた読み込みは画面エラーにならない
    @Test("キャンセルされた読み込みは画面エラーにならない")
    func viewModelCancelledLoadDoesNotBecomeError() async throws {
        let viewModel = makeViewModel(useCase: StubCalendarUseCase([.cancelled]))
        viewModel.send(.onAppear)
        await viewModel.loadTasks[marchKey]?.value

        #expect(viewModel.state.monthLoad(marchKey).errorMessage == nil)
        #expect(viewModel.state.monthLoad(marchKey).phase == .loading)
    }

    // 失敗時はerrorMessageが入る
    @Test("失敗時はerrorMessageが入る")
    func viewModelLoadFailure() async throws {
        let viewModel = makeViewModel(useCase: StubCalendarUseCase([.failure(message: "通信エラー")]))
        viewModel.send(.onAppear)
        await viewModel.loadTasks[marchKey]?.value

        #expect(viewModel.state.monthLoad(marchKey).errorMessage == "通信エラー")
    }

    // 9(ViewModel). 同じ月を2回loadしても重複Taskにならない（2回目は抑制）
    @Test("同じ月を2回loadしても重複Taskにならない")
    func viewModelDuplicateMonthSuppressed() async throws {
        let stub = StubCalendarUseCase([.success(CalendarMonthPayload(recipeEntries: [makeEntry("2026-03-01")], mealLogs: []))])
        let viewModel = makeViewModel(useCase: stub)

        viewModel.send(.loadMonth(referenceDate))
        viewModel.send(.loadMonth(referenceDate))  // 2回目（loading中なので抑制される）
        await viewModel.loadTasks[marchKey]?.value

        let loadedCount = await stub.loadedMonths.count
        #expect(loadedCount == 1)
    }

    // 22. ViewModelを再生成せずに複数月を切り替えて読み込める
    @Test("ViewModelを再生成せずに複数月を切り替えて読み込める")
    func viewModelLoadsMultipleMonthsWithoutRecreation() async throws {
        let useCase = DefaultCalendarUseCase(
            recipeRepository: FixtureRecipeRepository(referenceDate: referenceDate, calendar: tokyoCalendar),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyoCalendar),
            calendar: tokyoCalendar
        )
        let viewModel = makeViewModel(useCase: useCase)

        let aprilDate = makeDate(2026, 4, 1)
        let aprilKey = MonthKey(date: aprilDate, calendar: tokyoCalendar)

        viewModel.send(.loadMonth(referenceDate))
        viewModel.send(.loadMonth(aprilDate))
        await viewModel.loadTasks[marchKey]?.value
        await viewModel.loadTasks[aprilKey]?.value

        #expect(viewModel.state.monthLoad(marchKey).phase == .loaded)
        #expect(viewModel.state.monthLoad(aprilKey).phase == .loaded)
    }

    // 21. SwiftData Repositoryを使った取得結果がStateへ反映される
    @Test("SwiftData Repositoryを使った取得結果がStateへ反映される")
    func viewModelWithSwiftDataRepository() async throws {
        let container = try MealLogModelContainerFactory.makeInMemory()
        let mealLogRepository = SwiftDataMealLogRepository(modelContainer: container)
        _ = try await mealLogRepository.add(
            MealLogInput(recipeID: RecipeID("recipe-02"), cookedAt: makeDate(2026, 3, 12), rating: 4, memo: "swiftdata", servings: 1)
        )
        let useCase = DefaultCalendarUseCase(
            recipeRepository: FixtureRecipeRepository(referenceDate: referenceDate, calendar: tokyoCalendar),
            mealLogRepository: mealLogRepository,
            calendar: tokyoCalendar
        )
        let viewModel = makeViewModel(useCase: useCase)

        viewModel.send(.onAppear)
        await viewModel.loadTasks[marchKey]?.value

        let load = viewModel.state.monthLoad(marchKey)
        #expect(load.phase == .loaded)
        #expect(load.mealLogs.map(\.dateKey) == [DateKey(value: "2026-03-12")])
    }
}
