//
//  CalendarScrollNotification.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// CalendarScrollNotification.swift
// 元の通知名をそのまま維持し、今日ボタンのスクロール動作を保存する。

import Foundation

extension Notification.Name {
    static let scrollToToday = Notification.Name("MonthCalendarView.scrollToToday")
}
