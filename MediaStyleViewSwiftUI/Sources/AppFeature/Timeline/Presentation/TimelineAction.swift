//
//  TimelineAction.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineで起きうる出来事。Actor境界を越えるためSendable。
// requestIDは非決定的なため、Reducer内では生成せずViewModelが採番してbeginLoadingで渡す。

import Foundation

enum TimelineAction: Sendable, Equatable {

    // MARK: - Intents

    // 初回表示。未読込なら読み込む（既読なら再取得しない＝無限読込防止）
    case onAppear
    // 明示的な再取得（MealLog保存/編集/削除後の反映などに使う）
    case reload

    // MARK: - Internal（ViewModelが採番して発行）

    case beginLoading(requestID: UUID)

    // MARK: - Effect completion

    case loadSucceeded(requestID: UUID, entries: [TimelineEntryViewData])
    case loadFailed(requestID: UUID, message: String)
}
