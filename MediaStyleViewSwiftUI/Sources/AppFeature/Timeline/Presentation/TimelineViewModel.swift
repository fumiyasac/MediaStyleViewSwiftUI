//
//  TimelineViewModel.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineの@MainActor ViewModel。ReducerでStateを更新し、取得Effectを非同期実行する。
// 全期間は取らず、基準日から一定範囲(既定: 45日前〜15日後=Fixtureの掲載分布を含む約60日)だけ取得する。
// UseCaseが返すPayloadはFactoryでフラットなViewDataへ変換してからStateへ入れる。
// MealLogの保存/編集/削除後はreloadで再取得して最新化する（requestID照合で古い結果を弾く）。

import Foundation
import Observation

@MainActor
@Observable
final class TimelineViewModel {

    // MARK: - Property

    private(set) var state: TimelineState

    private let reducer: TimelineReducer
    private let useCase: any TimelineUseCase
    private let factory: TimelineViewDataFactory
    // 取得対象の期間（初期化時に基準日から確定）
    private let range: ClosedRange<DateKey>
    private let requestIDProvider: @Sendable () -> UUID

    // 進行中の取得Task。新しい取得開始時にキャンセルして1本に保つ。
    private(set) var loadTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        useCase: any TimelineUseCase,
        referenceDate: Date = Date(),
        calendar: Calendar = DateKeyCalendar.default,
        pastDays: Int = 45,
        futureDays: Int = 15,
        reducer: TimelineReducer = TimelineReducer(),
        requestIDProvider: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.useCase = useCase
        self.reducer = reducer
        self.factory = TimelineViewDataFactory(calendar: calendar)
        self.requestIDProvider = requestIDProvider
        self.state = .initial

        let startOfReference = calendar.startOfDay(for: referenceDate)
        let lower = calendar.date(byAdding: .day, value: -pastDays, to: startOfReference) ?? startOfReference
        let upper = calendar.date(byAdding: .day, value: futureDays, to: startOfReference) ?? startOfReference
        self.range = DateKey(date: lower, calendar: calendar)...DateKey(date: upper, calendar: calendar)
    }

    // MARK: - Send

    func send(_ action: TimelineAction) {
        switch action {
        // 初回表示：未読込の時だけ読み込む（既読なら再取得しない）
        case .onAppear:
            if case .idle = state.phase {
                apply(.beginLoading(requestID: requestIDProvider()))
            }
        // 明示的な再取得（保存/編集/削除後の反映）
        case .reload:
            apply(.beginLoading(requestID: requestIDProvider()))
        default:
            apply(action)
        }
    }

    // MARK: - Private Function

    private func apply(_ action: TimelineAction) {
        let transition = reducer.reduce(state: state, action: action)
        state = transition.state
        for effect in transition.effects {
            run(effect)
        }
    }

    private func run(_ effect: TimelineEffect) {
        switch effect {
        case let .load(requestID):
            loadTask?.cancel()
            let useCase = self.useCase
            let factory = self.factory
            let range = self.range
            loadTask = Task { [weak self] in
                do {
                    let payload = try await useCase.load(in: range)
                    let entries = factory.makeEntries(from: payload)
                    try Task.checkCancellation()
                    self?.send(.loadSucceeded(requestID: requestID, entries: entries, origin: payload.origin))
                } catch is CancellationError {
                    // キャンセルは画面エラーにしない
                } catch {
                    if Task.isCancelled { return }
                    self?.send(.loadFailed(requestID: requestID, message: error.localizedDescription))
                }
            }
        }
    }
}
