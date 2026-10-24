//
//  MealLogEditorViewModel.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLog Editorの@MainActor ViewModel。ReducerでStateを更新し、保存Effectを非同期実行する。
// 保存はMealLogRepository(既存CRUD)を再利用。requestID採番はここだけで行う。
// 保存処理は画面離脱で中断させないため[weak self]で保持し、明示的なcancelはしない
// （Sheet側は保存中の対話的dismissを抑止する）。

import Foundation
import Observation

@MainActor
@Observable
final class MealLogEditorViewModel {

    // MARK: - Property

    private(set) var state: MealLogEditorState

    private let reducer: MealLogEditorReducer
    private let repository: any MealLogRepository
    private let requestIDProvider: @Sendable () -> UUID

    // 進行中の保存Task。テストから完了待ちできるようinternalにする。
    private(set) var saveTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        repository: any MealLogRepository,
        initialState: MealLogEditorState,
        reducer: MealLogEditorReducer = MealLogEditorReducer(),
        requestIDProvider: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.state = initialState
        self.reducer = reducer
        self.requestIDProvider = requestIDProvider
    }

    // MARK: - Send

    func send(_ action: MealLogEditorAction) {
        switch action {
        // ここでだけrequestIDを採番してbeginSavingへ展開する
        case .save:
            apply(.beginSaving(requestID: requestIDProvider()))
        default:
            apply(action)
        }
    }

    // MARK: - Private Function

    private func apply(_ action: MealLogEditorAction) {
        let transition = reducer.reduce(state: state, action: action)
        state = transition.state
        for effect in transition.effects {
            run(effect)
        }
    }

    private func run(_ effect: MealLogEditorEffect) {
        switch effect {
        case let .save(requestID, input):
            let repository = self.repository
            saveTask = Task { [weak self] in
                do {
                    let summary = try await repository.add(input)
                    try Task.checkCancellation()
                    self?.send(.saveSucceeded(requestID: requestID, summary: summary))
                } catch is CancellationError {
                    // キャンセルは通常の保存エラーにしない
                } catch {
                    if Task.isCancelled { return }
                    self?.send(.saveFailed(requestID: requestID, message: error.localizedDescription))
                }
            }
        }
    }
}
