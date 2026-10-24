//
//  CalendarEffect.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Reducerが宣言する副作用(Effect)。実行自体はしない宣言のみで、実際の非同期処理はViewModelが担う。
// Effectが不要な遷移では空配列を返す。requestID/monthKeyはbeginLoadingのものを載せ、完了Actionと照合する。

import Foundation

enum CalendarEffect: Sendable, Equatable {

    // 指定月の掲載レシピ・調理記録をUseCase経由で読み込む
    case loadMonth(requestID: UUID, monthKey: MonthKey, month: Date)
}
