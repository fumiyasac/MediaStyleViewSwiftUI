//
//  TimelineState.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// TimelineのState。非同期取得の状態(初期/読込中/表示中/失敗)と、取得済みのフラットなViewDataを持つ。
// 「データなし」は loaded かつ entries が空、「更新中」は loading かつ既存entriesありで導出する。
// 検索文字列と種別フィルタはView側(@State)で保持し、ここでは非同期状態に責務を限定する。

import Foundation

// MARK: - TimelineLoadPhase

enum TimelineLoadPhase: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)
}

// MARK: - TimelineState

struct TimelineState: Sendable, Equatable {

    // MARK: - Property

    // 取得済みのフラットなViewData（グルーピング・フィルタ・検索はView側でローカルに適用）
    var entries: [TimelineEntryViewData]
    var phase: TimelineLoadPhase
    // 進行中リクエストの識別子（完了Actionの照合に使う）
    var requestID: UUID?
    // 直近成功時の取得元（最新/キャッシュ）。nilは未取得。キャッシュ表示中の提示に使う。
    var origin: RecipeDataOrigin? = nil

    // MARK: - Derived

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    // 更新中（既存表示を保ったままの再取得）
    var isRefreshing: Bool { isLoading && !entries.isEmpty }

    // 取得データ自体が0件（検索0件とは区別する。検索0件はView側で判定）
    var isEmptyData: Bool {
        if case .loaded = phase { return entries.isEmpty }
        return false
    }

    var errorMessage: String? {
        if case let .failed(message) = phase { return message }
        return nil
    }

    // MARK: - Factory

    static let initial = TimelineState(entries: [], phase: .idle, requestID: nil, origin: nil)
}
