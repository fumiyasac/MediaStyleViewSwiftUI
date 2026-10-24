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
//  - Date() / UUID() など非決定的な値をReducer内で生成しない（requestID/monthKeyは外から渡す）
//  - 完了ActionのrequestIDが「その月の」進行中IDと一致する時だけ反映し、古い結果で上書きしない
//  - 既読/読込中の月への読込要求は抑制する（重複読込・画面再表示での無限読込を防ぐ）

import Foundation

// MARK: - CalendarTransition

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

        // onAppear / loadMonth は意図のみ。requestID/MonthKeyの確定はViewModelが行い
        // beginLoadingへ展開する。Reducer単体ではno-opにして純粋・決定的に保つ。
        case .onAppear, .loadMonth:
            return CalendarTransition(state: state, effects: [])

        // 日付選択はselectedDateの更新のみ（再読込しない＝不要なAPIアクセスを発生させない）
        case let .selectDate(date):
            var newState = state
            newState.selectedDate = date
            return CalendarTransition(state: newState, effects: [])

        // その月の読み込み開始。既読/読込中なら抑制（重複読込・無限読込を防ぐ）。
        // idle/failedの時だけ、直前データを保持したままloadingにして読み込みEffectを返す。
        case let .beginLoading(requestID, monthKey, month):
            let current = state.monthLoad(monthKey)
            guard !current.isActiveOrLoaded else {
                return CalendarTransition(state: state, effects: [])
            }
            var load = current
            load.phase = .loading
            load.requestID = requestID
            var newState = state
            newState.months[monthKey] = load
            return CalendarTransition(
                state: newState,
                effects: [.loadMonth(requestID: requestID, monthKey: monthKey, month: month)]
            )

        // 読み込み成功。その月の進行中IDと一致する時のみ反映（古い結果は破棄＝他月も壊さない）。
        case let .loadSucceeded(requestID, monthKey, payload):
            guard state.monthLoad(monthKey).requestID == requestID else {
                return CalendarTransition(state: state, effects: [])
            }
            var load = state.monthLoad(monthKey)
            load.recipeEntries = payload.recipeEntries
            load.mealLogs = payload.mealLogs
            load.phase = .loaded
            load.requestID = nil
            var newState = state
            newState.months[monthKey] = load
            return CalendarTransition(state: newState, effects: [])

        // 読み込み失敗。その月の進行中IDと一致する時のみ反映。直前データは保持する。
        case let .loadFailed(requestID, monthKey, message):
            guard state.monthLoad(monthKey).requestID == requestID else {
                return CalendarTransition(state: state, effects: [])
            }
            var load = state.monthLoad(monthKey)
            load.phase = .failed(message: message)
            load.requestID = nil
            var newState = state
            newState.months[monthKey] = load
            return CalendarTransition(state: newState, effects: [])

        // 他画面での調理ログ保存/更新をmealLogsへ直接反映する（Design A）。
        // 月キーはdateKey("yyyy-MM-dd")の先頭7文字から純粋に導出（Date/Calendar非依存）。
        // 編集で調理日=月が変わるケースに備え、同一idを全月から除いてから対象月へ入れ直す。
        // 保存結果は確定値なので非同期の再取得を挟まず、古い読込が上書きする余地を作らない。
        case let .mealLogSaved(summary):
            var newState = state
            newState.months = monthsRemovingMealLog(id: summary.id, from: state.months)
            let monthKey = MonthKey(value: String(summary.dateKey.value.prefix(7)))
            var load = newState.monthLoad(monthKey)
            load.mealLogs.append(summary)
            newState.months[monthKey] = load
            return CalendarTransition(state: newState, effects: [])

        // 調理ログ削除を全月から反映する
        case let .mealLogDeleted(id):
            var newState = state
            newState.months = monthsRemovingMealLog(id: id, from: state.months)
            return CalendarTransition(state: newState, effects: [])
        }
    }

    // MARK: - Private Function

    // 指定idの調理ログを全月のmealLogsから除いた新しいmonthsを返す（純粋関数。&stateは使わない）
    private func monthsRemovingMealLog(
        id: MealLogID,
        from months: [MonthKey: CalendarMonthLoad]
    ) -> [MonthKey: CalendarMonthLoad] {
        var result = months
        for key in result.keys {
            result[key]?.mealLogs.removeAll { $0.id == id }
        }
        return result
    }
}
