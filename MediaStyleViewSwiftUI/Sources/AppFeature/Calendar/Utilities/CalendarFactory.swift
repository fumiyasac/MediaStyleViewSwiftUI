//
//  CalendarFactory.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// グレゴリオ暦＋ja_JP＋日曜始まりのCalendarを1か所に集約する。
// 各ファイルで個別生成していた同設定を共有し、生成コストと設定ズレを防ぐ。
// 週計算（月グリッドの先頭余白）に必要なfirstWeekday=1を全体の既定にしておけば、
// 週に依存しない用途（本日判定・加算など）でも安全に使い回せる。

import Foundation

enum CalendarFactory {

    // CalendarはSendableなのでstatic letで安全に共有できる。
    static let shared: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        // 日曜日始まりに固定する（月グリッドの余白セル計算が前提にしている）
        calendar.firstWeekday = 1
        return calendar
    }()
}
