//
//  CalendarAction.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar Featureで起きうる出来事(Action)。Actor境界を越えるためSendable。
// 月単位のロードに対応するため、読込開始・完了Actionは対象月(MonthKey)を持つ。
// requestID(UUID)は非決定的なため、Reducer内では生成せずViewModelが採番してbeginLoadingで渡す。

import Foundation

enum CalendarAction: Sendable, Equatable {

    // MARK: - View intents（Viewが送る意図）

    // 画面表示。ViewModelが選択中の月の読み込みへ展開する
    case onAppear
    // 日付選択
    case selectDate(Date)
    // 指定月の読み込み要求。ViewModelがMonthKeyとrequestIDを確定してbeginLoadingへ展開する
    case loadMonth(Date)

    // MARK: - Internal（ViewModelが採番して発行する）

    // 読み込み開始の確定。requestID/monthKeyはViewModelが確定済み（Reducerはこれで遷移する）
    case beginLoading(requestID: UUID, monthKey: MonthKey, month: Date)

    // MARK: - Effect completion（Effect実行後に再送信される）

    // 読み込み成功（対象月のpayloadを反映）
    case loadSucceeded(requestID: UUID, monthKey: MonthKey, payload: CalendarMonthPayload)
    // 読み込み失敗
    case loadFailed(requestID: UUID, monthKey: MonthKey, message: String)
}
