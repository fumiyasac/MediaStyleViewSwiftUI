//
//  MealLogEditorReducer.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLog EditorのReducer。State + Action から新Stateとエフェクトを返す純粋同期関数。
// inout/&stateを使わず、Task/SwiftDataにも触れない。requestIDはbeginSavingで外から渡す。
// 二重保存防止・保存失敗時の入力保持・再試行をここで表現する。

import Foundation

struct MealLogEditorReducer: Sendable {

    func reduce(
        state: MealLogEditorState,
        action: MealLogEditorAction
    ) -> MealLogEditorTransition {
        switch action {

        // 入力更新は保存中・保存済みでは無視する。失敗後に編集したらeditingへ戻す（エラー表示を解除）。
        case let .setCookedAt(date):
            guard isEditable(state) else { return noEffect(state) }
            var newState = state
            newState.cookedAt = date
            newState.status = .editing
            return noEffect(newState)

        case let .setRating(rating):
            guard isEditable(state) else { return noEffect(state) }
            var newState = state
            newState.rating = rating
            newState.status = .editing
            return noEffect(newState)

        case let .setMemo(memo):
            guard isEditable(state) else { return noEffect(state) }
            var newState = state
            newState.memo = memo
            newState.status = .editing
            return noEffect(newState)

        // 保存意図はViewModelがrequestIDを採番してbeginSavingへ展開する（Reducerはno-op）
        case .save:
            return noEffect(state)

        // 保存開始。既に保存中なら無視（連打による二重保存を防ぐ）。
        case let .beginSaving(requestID):
            guard !state.isSaving else { return noEffect(state) }
            var newState = state
            newState.status = .saving(requestID: requestID)
            return MealLogEditorTransition(
                state: newState,
                effects: [.save(requestID: requestID, input: state.makeInput())]
            )

        // 保存成功。進行中のrequestIDと一致する時のみ確定する。
        case let .saveSucceeded(requestID, summary):
            guard state.status == .saving(requestID: requestID) else { return noEffect(state) }
            var newState = state
            newState.status = .saved(summary)
            return noEffect(newState)

        // 保存失敗。一致時のみエラーにする。入力内容(cookedAt/rating/memo)は維持する。
        case let .saveFailed(requestID, message):
            guard state.status == .saving(requestID: requestID) else { return noEffect(state) }
            var newState = state
            newState.status = .failed(message: message)
            return noEffect(newState)
        }
    }

    // MARK: - Private Function

    private func isEditable(_ state: MealLogEditorState) -> Bool {
        switch state.status {
        case .editing, .failed: return true
        case .saving, .saved: return false
        }
    }

    private func noEffect(_ state: MealLogEditorState) -> MealLogEditorTransition {
        MealLogEditorTransition(state: state, effects: [])
    }
}
