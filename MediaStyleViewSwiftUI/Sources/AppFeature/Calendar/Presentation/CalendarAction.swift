//
//  CalendarAction.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar Featureで起きうる出来事(Action)。Actor境界を越えるためSendable。
// 「Viewからの意図」「ViewModelが採番して確定させる読込開始」「Effect完了」を1つのenumで表す。
// requestIDは非決定的なUUIDのため、Reducer内では生成せずViewModelが採番してbeginLoadingで渡す。

import Foundation

enum CalendarAction: Sendable, Equatable {

    // MARK: - View intents（Viewが送る意図）

    // 画面表示。ViewModelが現在の表示月の読み込みへ展開する
    case onAppear
    // 日付選択
    case selectDate(Date)
    // 指定月の読み込み要求。ViewModelがrequestIDを採番してbeginLoadingへ展開する
    case loadMonth(Date)

    // MARK: - Internal（ViewModelが採番して発行する）

    // 読み込み開始の確定。requestIDはViewModelが採番済み（Reducerはこれで遷移する）
    case beginLoading(requestID: UUID, month: Date)

    // MARK: - Effect completion（Effect実行後に再送信される）

    // 読み込み成功
    case loadSucceeded(requestID: UUID, entries: [DailyRecipeEntry])
    // 読み込み失敗
    case loadFailed(requestID: UUID, message: String)
}
