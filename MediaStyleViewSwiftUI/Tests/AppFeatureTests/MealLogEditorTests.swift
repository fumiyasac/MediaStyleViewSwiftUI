//
//  MealLogEditorTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLog EditorのReducer遷移とViewModelの保存フロー（成功/失敗/再試行/二重保存抑制/キャンセル）のテスト。
// Swift Testing へ移行済み。Repository Stubはactorで並列安全、同期待ちはsaveTaskのawaitで行う。

@testable import AppFeature
import Foundation
import Testing

// 保存挙動を差し込めるMealLogRepository Stub（actorでSendable）。
private actor StubMealLogRepository: MealLogRepository {

    enum Behavior: Sendable {
        case success
        case failure(message: String)
        case cancelled
    }

    private var queue: [Behavior]
    private let fallback: Behavior
    private(set) var addCallCount = 0
    private let calendar = DateKeyCalendar.default

    init(_ behaviors: [Behavior], fallback: Behavior = .success) {
        self.queue = behaviors
        self.fallback = fallback
    }

    func add(_ input: MealLogInput) async throws -> MealLogSummary {
        addCallCount += 1
        // 入力検証はDomainに委譲（範囲外ratingはここで弾かれる）
        try input.validate()
        let behavior = queue.isEmpty ? fallback : queue.removeFirst()
        switch behavior {
        case .success:
            return MealLogSummary(
                id: MealLogID(),
                recipeID: input.recipeID,
                dateKey: DateKey(date: input.cookedAt, calendar: calendar),
                cookedAt: input.cookedAt,
                rating: input.rating,
                memo: input.memo,
                servings: input.servings
            )
        case let .failure(message):
            throw StubRepoError.message(message)
        case .cancelled:
            throw CancellationError()
        }
    }

    func update(id: MealLogID, with input: MealLogInput) async throws -> MealLogSummary { throw StubRepoError.message("unused") }
    func delete(id: MealLogID) async throws {}
    func summaries(for dateKey: DateKey) async throws -> [MealLogSummary] { [] }
    func allSummaries() async throws -> [MealLogSummary] { [] }
}

private enum StubRepoError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case let .message(m): return m } }
}

private let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
    tokyo.date(from: DateComponents(year: y, month: m, day: d))!
}

// MARK: - Reducer

@Suite("MealLog Editorの状態遷移")
struct MealLogEditorReducerTests {

    private let reducer = MealLogEditorReducer()

    private func editing() -> MealLogEditorState {
        .initial(recipeID: RecipeID("recipe-01"), cookedAt: day(2026, 3, 10), rating: 3, memo: "")
    }

    // 6. 正常入力で保存Effectが生成される
    @Test("正常入力で保存Effectが生成される")
    func beginSavingProducesSaveEffect() {
        let id = UUID()
        let transition = reducer.reduce(state: editing(), action: .beginSaving(requestID: id))
        #expect(transition.state.status == .saving(requestID: id))
        #expect(transition.effects.count == 1)
    }

    // 9. 保存中の連続タップで二重保存されない（2回目のbeginSavingはEffectを出さない）
    @Test("保存中の連続タップで二重保存されない")
    func doubleBeginSavingSuppressed() {
        let first = reducer.reduce(state: editing(), action: .beginSaving(requestID: UUID()))
        let second = reducer.reduce(state: first.state, action: .beginSaving(requestID: UUID()))
        #expect(second.effects.isEmpty)
        #expect(second.state == first.state)
    }

    // 10. 保存成功で成功状態へ遷移する
    @Test("保存成功で成功状態へ遷移する")
    func saveSucceeded() {
        let id = UUID()
        let saving = reducer.reduce(state: editing(), action: .beginSaving(requestID: id)).state
        let summary = MealLogSummary(id: MealLogID(), recipeID: RecipeID("recipe-01"), dateKey: DateKey(value: "2026-03-10"), cookedAt: day(2026, 3, 10), rating: 3, memo: "", servings: 1)
        let transition = reducer.reduce(state: saving, action: .saveSucceeded(requestID: id, summary: summary))
        #expect(transition.state.savedSummary == summary)
    }

    // 11. 保存失敗でエラー状態となり入力内容が維持される
    @Test("保存失敗でエラー状態となり入力内容が維持される")
    func saveFailedKeepsInput() {
        let id = UUID()
        var state = editing()
        state = reducer.reduce(state: state, action: .setMemo("作った")).state
        state = reducer.reduce(state: state, action: .beginSaving(requestID: id)).state
        let failed = reducer.reduce(state: state, action: .saveFailed(requestID: id, message: "失敗")).state
        #expect(failed.errorMessage == "失敗")
        #expect(failed.memo == "作った")
    }

    // 12. 保存失敗後に再試行できる（failedからbeginSavingでsavingへ）
    @Test("保存失敗後に再試行できる")
    func retryAfterFailure() {
        let id1 = UUID()
        let saving = reducer.reduce(state: editing(), action: .beginSaving(requestID: id1)).state
        let failed = reducer.reduce(state: saving, action: .saveFailed(requestID: id1, message: "失敗")).state
        let id2 = UUID()
        let retry = reducer.reduce(state: failed, action: .beginSaving(requestID: id2))
        #expect(retry.state.status == .saving(requestID: id2))
        #expect(retry.effects.count == 1)
    }

    // 古いrequestIDの完了は無視される
    @Test("古いrequestIDの完了は無視される")
    func staleCompletionIgnored() {
        let id = UUID()
        let saving = reducer.reduce(state: editing(), action: .beginSaving(requestID: id)).state
        let stale = reducer.reduce(state: saving, action: .saveFailed(requestID: UUID(), message: "x"))
        #expect(stale.state == saving)
    }
}

// MARK: - ViewModel

@MainActor
@Suite("MealLog Editorの保存フロー")
struct MealLogEditorViewModelTests {

    private func makeViewModel(_ repository: any MealLogRepository, rating: Int = 4, memo: String = "") -> MealLogEditorViewModel {
        MealLogEditorViewModel(
            repository: repository,
            initialState: .initial(recipeID: RecipeID("recipe-01"), cookedAt: day(2026, 3, 10), rating: rating, memo: memo)
        )
    }

    // 8. メモが空でも保存できる
    @Test("メモが空でも保存できる")
    func saveWithEmptyMemo() async throws {
        let viewModel = makeViewModel(StubMealLogRepository([.success]), memo: "")
        viewModel.send(.save)
        await viewModel.saveTask?.value
        #expect(viewModel.state.savedSummary != nil)
    }

    // 7. 評価が範囲外なら保存できない（Repository検証で失敗になる）
    @Test("評価が範囲外なら保存できない")
    func invalidRatingCannotSave() async throws {
        let viewModel = makeViewModel(StubMealLogRepository([.success]), rating: 7)
        viewModel.send(.save)
        await viewModel.saveTask?.value
        #expect(viewModel.state.savedSummary == nil)
        #expect(viewModel.state.errorMessage != nil)
    }

    // 11. 失敗でエラー状態・入力維持、12. 再試行で成功
    @Test("失敗でエラー状態・入力維持し、再試行で成功する")
    func failureThenRetrySucceeds() async throws {
        let repository = StubMealLogRepository([.failure(message: "通信失敗"), .success])
        let viewModel = makeViewModel(repository)

        viewModel.send(.save)
        await viewModel.saveTask?.value
        #expect(viewModel.state.errorMessage == "通信失敗")

        viewModel.send(.save)   // 再試行
        await viewModel.saveTask?.value
        #expect(viewModel.state.savedSummary != nil)
    }

    // 13. キャンセルされた処理を保存エラーとして誤表示しない
    @Test("キャンセルを保存エラーとして誤表示しない")
    func cancelledNotShownAsError() async throws {
        let viewModel = makeViewModel(StubMealLogRepository([.cancelled]))
        viewModel.send(.save)
        await viewModel.saveTask?.value
        #expect(viewModel.state.errorMessage == nil)
        #expect(viewModel.state.savedSummary == nil)
    }

    // 9. 連続タップで二重保存されない（addは1回だけ）
    @Test("連続タップで二重保存されない")
    func doubleTapDoesNotDoubleSave() async throws {
        let repository = StubMealLogRepository([.success])
        let viewModel = makeViewModel(repository)
        viewModel.send(.save)
        viewModel.send(.save)   // 保存中の2回目は抑制される
        await viewModel.saveTask?.value
        let count = await repository.addCallCount
        #expect(count == 1)
    }
}
