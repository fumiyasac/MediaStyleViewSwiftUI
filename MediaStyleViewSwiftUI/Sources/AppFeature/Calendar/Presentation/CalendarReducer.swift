//
//  CalendarReducer.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// State + Action から「次のState」と「実行すべきEffect」を返す純粋な同期関数。
// 以下を厳守する:
//  - inout / &state を使わず、新しいStateを組み立てて返す
//  - Taskを起動せず、URLSession/SwiftDataにも触れない
//  - Date() / UUID() など非決定的な値をReducer内で生成しない
//    （requestIDはbeginLoadingで外から渡されたものだけを使う）
//  - 完了ActionのrequestIDが進行中IDと一致する時だけ反映し、古い結果で上書きしない

import Foundation

// MARK: - CalendarTransition

// Reducerの戻り値。次のStateと、ViewModelが実行すべきEffect列。
struct CalendarTransition: Sendable, Equatable {
    let state: CalendarFeatureState
    let effects: [CalendarEffect]
}

// MARK: - CalendarReducer

struct CalendarReducer: Sendable {

    func reduce(
        state: CalendarFeatureState,
        action: CalendarAction
    ) -> CalendarTransition {
        switch action {

        // onAppear / loadMonth は「読み込みたい」という意図のみ。
        // requestIDの採番(UUID)はReducerでは行えないため、ViewModelがbeginLoadingへ展開する。
        // Reducer単体ではStateを変えないno-opにして、関数全体を純粋・決定的に保つ。
        case .onAppear, .loadMonth:
            return CalendarTransition(state: state, effects: [])

        // 日付選択はselectedDateの更新のみ（この時点では再読込しない）
        case let .selectDate(date):
            var newState = state
            newState.selectedDate = date
            return CalendarTransition(state: newState, effects: [])

        // 読み込み開始の確定。表示月を更新し、進行中IDを差し替え、
        // 直前データを保持したままloadingにして、読み込みEffectを返す。
        case let .beginLoading(requestID, month):
            var newState = state
            newState.displayedMonth = month
            newState.currentRequestID = requestID
            newState.entriesState = .loading(previous: state.entriesState.entries)
            return CalendarTransition(
                state: newState,
                effects: [.loadMonth(requestID: requestID, month: month)]
            )

        // 読み込み成功。進行中IDと一致する時のみ反映（古い結果は破棄）。
        case let .loadSucceeded(requestID, entries):
            guard requestID == state.currentRequestID else {
                return CalendarTransition(state: state, effects: [])
            }
            var newState = state
            newState.entriesState = .loaded(entries)
            newState.currentRequestID = nil
            return CalendarTransition(state: newState, effects: [])

        // 読み込み失敗。進行中IDと一致する時のみ反映（古い結果は破棄）。
        // 直前データは保持してエラー表示と併存させる。
        case let .loadFailed(requestID, message):
            guard requestID == state.currentRequestID else {
                return CalendarTransition(state: state, effects: [])
            }
            var newState = state
            newState.entriesState = .failed(message: message, previous: state.entriesState.entries)
            newState.currentRequestID = nil
            return CalendarTransition(state: newState, effects: [])
        }
    }
}
