//
//  CalendarViewModel.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// ReducerとEffect実行をつなぐ@MainActor隔離のViewModel。
// 役割:
//  - ViewからのActionを受け、Reducerで純粋にStateを更新する
//  - Reducerが返したEffectを非同期Taskで実行し、完了Actionを再送信する
//  - requestID(UUID)の採番という非決定的処理はここ(非純粋な境界)だけで行う
//  - 進行中Taskのキャンセルを管理し、古い結果が最新Stateを上書きしないようにする
//    （requestID照合はReducer側でも二重に担保）

import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {

    // MARK: - Property

    private(set) var state: CalendarFeatureState

    private let reducer: CalendarReducer
    private let useCase: any CalendarUseCase
    // requestIDを採番するための注入可能なファクトリ（テストで固定でき、Reducerは非決定性に触れない）
    private let requestIDProvider: @Sendable () -> UUID

    // 進行中の読み込みTask。新しい読み込み開始時にキャンセルして1本に保つ。
    // テストから完了待ちできるようinternalにする。
    private(set) var loadTask: Task<Void, Never>?

    // MARK: - Initializer

    init(
        useCase: any CalendarUseCase,
        initialState: CalendarFeatureState,
        reducer: CalendarReducer = CalendarReducer(),
        requestIDProvider: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.useCase = useCase
        self.state = initialState
        self.reducer = reducer
        self.requestIDProvider = requestIDProvider
    }

    // MARK: - Send

    func send(_ action: CalendarAction) {
        switch action {
        // 表示月の読み込みへ展開する
        case .onAppear:
            send(.loadMonth(state.displayedMonth))

        // ここでだけrequestIDを採番し、Reducerが扱えるbeginLoadingへ展開する
        case let .loadMonth(month):
            apply(.beginLoading(requestID: requestIDProvider(), month: month))

        // その他はそのままReducerへ渡す
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
        case let .loadMonth(requestID, month):
            // 直前の読み込みはキャンセルして二重実行・古い結果の反映を防ぐ
            loadTask?.cancel()
            // useCaseはSendableなので値で捕捉。selfは@MainActor(=Sendable)だが循環参照回避のためweak。
            let useCase = self.useCase
            loadTask = Task { [weak self] in
                do {
                    let entries = try await useCase.loadMonth(month)
                    // 待機中にキャンセルされていたら結果を配送しない
                    try Task.checkCancellation()
                    self?.send(.loadSucceeded(requestID: requestID, entries: entries))
                } catch is CancellationError {
                    // キャンセルは通常のエラーとして扱わない（画面エラーにしない）
                } catch {
                    // キャンセル由来の失敗も画面エラーにしない
                    if Task.isCancelled { return }
                    self?.send(.loadFailed(requestID: requestID, message: error.localizedDescription))
                }
            }
        }
    }
}
