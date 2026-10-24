//
//  CalendarViewModel.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// ReducerとEffect実行をつなぐ@MainActor隔離のViewModel。
// 役割:
//  - ViewからのActionを受け、Reducerで純粋にStateを更新する
//  - Reducerが返したEffectを「月ごとに」非同期Taskで実行し、完了Actionを再送信する
//  - requestID(UUID)採番・MonthKey/月起点の導出という非純粋処理はここ(境界)だけで行う
//  - 月ごとにTaskを保持し、同月の再読込では前Taskをキャンセル（別月のTaskは止めない）
//  - 古い結果が最新Stateを上書きしないよう、Reducerのrequestid照合と二重に担保する

import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {

    // MARK: - Property

    private(set) var state: CalendarFeatureState

    private let reducer: CalendarReducer
    private let useCase: any CalendarUseCase
    // MonthKey・月起点の導出に使うCalendar（TimeZone内包）
    private let calendar: Calendar
    // requestIDを採番するファクトリ（テストで固定でき、Reducerは非決定性に触れない）
    private let requestIDProvider: @Sendable () -> UUID

    // 月ごとの進行中Task。別月は並行して読み込めるようキーごとに保持する。
    // テストから完了待ちできるようinternalにする。
    private(set) var loadTasks: [MonthKey: Task<Void, Never>] = [:]

    // MARK: - Initializer

    init(
        useCase: any CalendarUseCase,
        initialState: CalendarFeatureState,
        reducer: CalendarReducer = CalendarReducer(),
        calendar: Calendar = DateKeyCalendar.default,
        requestIDProvider: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.useCase = useCase
        self.state = initialState
        self.reducer = reducer
        self.calendar = calendar
        self.requestIDProvider = requestIDProvider
    }

    // MARK: - Send

    func send(_ action: CalendarAction) {
        switch action {
        // 選択中の日付が属する月を読み込む
        case .onAppear:
            send(.loadMonth(state.selectedDate))

        // MonthKey・月起点・requestIDを確定してbeginLoadingへ展開する
        case let .loadMonth(date):
            let monthKey = MonthKey(date: date, calendar: calendar)
            let month = CalendarFeatureState.startOfMonth(for: date, calendar: calendar)
            apply(.beginLoading(requestID: requestIDProvider(), monthKey: monthKey, month: month))

        default:
            apply(action)
        }
    }

    // MARK: - Private Function

    // Reducerで純粋にStateを更新し、返ってきたEffectを実行する
    private func apply(_ action: CalendarAction) {
        let transition = reducer.reduce(state: state, action: action)
        state = transition.state
        for effect in transition.effects {
            run(effect)
        }
    }

    // Effectを実行する。非同期処理・Taskの起動はここだけで行う。
    private func run(_ effect: CalendarEffect) {
        switch effect {
        case let .loadMonth(requestID, monthKey, month):
            // 同月の前リクエストはキャンセル（別月のTaskは止めない）
            loadTasks[monthKey]?.cancel()
            let useCase = self.useCase
            loadTasks[monthKey] = Task { [weak self] in
                do {
                    let payload = try await useCase.loadMonth(month)
                    try Task.checkCancellation()
                    self?.send(.loadSucceeded(requestID: requestID, monthKey: monthKey, payload: payload))
                } catch is CancellationError {
                    // キャンセルは画面エラーにしない
                } catch {
                    if Task.isCancelled { return }
                    self?.send(.loadFailed(requestID: requestID, monthKey: monthKey, message: error.localizedDescription))
                }
            }
        }
    }
}
