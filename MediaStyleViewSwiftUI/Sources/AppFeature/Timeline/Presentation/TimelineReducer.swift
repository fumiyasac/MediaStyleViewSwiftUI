//
//  TimelineReducer.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// TimelineのReducerとEffect/Transition。State + Action から新Stateとエフェクトを返す純粋同期関数。
// inout/&stateやTask/SwiftDataに触れず、requestID照合で古い結果を弾く。
// 読込失敗でも既存entriesは保持して表示を維持する。

import Foundation

// MARK: - TimelineEffect

enum TimelineEffect: Sendable, Equatable {
    // 期間内データを読み込む（期間はViewModelが保持する。requestIDで完了を照合）
    case load(requestID: UUID)
}

// MARK: - TimelineTransition

struct TimelineTransition: Sendable, Equatable {
    let state: TimelineState
    let effects: [TimelineEffect]
}

// MARK: - TimelineReducer

struct TimelineReducer: Sendable {

    func reduce(state: TimelineState, action: TimelineAction) -> TimelineTransition {
        switch action {

        // onAppear/reloadは意図のみ。読み込むか否か・requestID採番はViewModelが行いbeginLoadingへ展開する。
        case .onAppear, .reload:
            return TimelineTransition(state: state, effects: [])

        // 読み込み開始。既存entriesは保持したままloadingにして読み込みEffectを返す。
        case let .beginLoading(requestID):
            var newState = state
            newState.phase = .loading
            newState.requestID = requestID
            return TimelineTransition(state: newState, effects: [.load(requestID: requestID)])

        // 読み込み成功。進行中IDと一致する時のみ反映（古い結果は破棄）。
        case let .loadSucceeded(requestID, entries, origin):
            guard state.requestID == requestID else {
                return TimelineTransition(state: state, effects: [])
            }
            var newState = state
            newState.entries = entries
            newState.phase = .loaded
            newState.requestID = nil
            // 取得元(最新/キャッシュ)を保持し、キャッシュ表示中であることをUIが示せるようにする
            newState.origin = origin
            return TimelineTransition(state: newState, effects: [])

        // 読み込み失敗。一致時のみエラーにする。既存entriesは保持する。
        case let .loadFailed(requestID, message):
            guard state.requestID == requestID else {
                return TimelineTransition(state: state, effects: [])
            }
            var newState = state
            newState.phase = .failed(message: message)
            newState.requestID = nil
            return TimelineTransition(state: newState, effects: [])
        }
    }
}
