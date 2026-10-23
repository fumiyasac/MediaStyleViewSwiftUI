//
//  CalendarFeatureState.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar FeatureのState。View表示に必要な値だけを持つSendableな値型。
// 「読み込み中でも表示中の既存データを失わない」ために、データ本体ではなく読込フェーズを
// enumで表し、loading/failedには直前のデータ(previous)を持たせる。
// これにより「loadedなのにデータが無い」等の不正な組み合わせを表現しづらくする。

import Foundation

// MARK: - CalendarEntriesState

// 日別割当の読込フェーズ。各フェーズが必要なデータだけを内包する。
enum CalendarEntriesState: Sendable, Equatable {
    // 初期状態（未読込）
    case idle
    // 読み込み中（再読込時は直前のデータを保持して表示を維持する）
    case loading(previous: [DailyRecipeEntry])
    // 読み込み成功
    case loaded([DailyRecipeEntry])
    // 読み込み失敗（直前のデータは保持し、エラー表示と併存できる）
    case failed(message: String, previous: [DailyRecipeEntry])

    // いまUIに出すべきデータ（loading/failedでは直前データ、idleでは空）
    var entries: [DailyRecipeEntry] {
        switch self {
        case .idle:
            return []
        case let .loading(previous):
            return previous
        case let .loaded(entries):
            return entries
        case let .failed(_, previous):
            return previous
        }
    }
}

// MARK: - CalendarFeatureState

struct CalendarFeatureState: Sendable, Equatable {

    // MARK: - Property

    // 選択中の日付
    var selectedDate: Date
    // 表示対象の月（当月の起点日に正規化して保持）
    var displayedMonth: Date
    // 読み込み済みデータと読込フェーズ
    var entriesState: CalendarEntriesState
    // 進行中リクエストの識別子（完了Actionの照合に使う）
    var currentRequestID: UUID?

    // MARK: - Derived

    // 現在表示すべき日別割当
    var entries: [DailyRecipeEntry] { entriesState.entries }

    // 読み込み中かどうか
    var isLoading: Bool {
        if case .loading = entriesState { return true }
        return false
    }

    // エラー表示用メッセージ（失敗時のみ）
    var errorMessage: String? {
        if case let .failed(message, _) = entriesState { return message }
        return nil
    }

    // MARK: - Factory

    // 初期State。displayedMonthは基準日の当月起点に正規化する。
    // referenceDateは非決定的なDate()を外から渡すための引数（既定はテストで固定できる）。
    static func initial(
        referenceDate: Date,
        calendar: Calendar = DateKeyCalendar.default
    ) -> CalendarFeatureState {
        CalendarFeatureState(
            selectedDate: referenceDate,
            displayedMonth: startOfMonth(for: referenceDate, calendar: calendar),
            entriesState: .idle,
            currentRequestID: nil
        )
    }

    // 指定日が属する月の起点日(1日 0時)を返す
    static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
