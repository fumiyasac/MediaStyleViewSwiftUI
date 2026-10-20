//
//  CalendarMonthPositionKey.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月セル上端の位置情報を集約する。

import SwiftUI

struct CalendarMonthPositionKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]

    // PreferenceKey準拠に必須のinout。StateMachineのReducerでは使用しない。
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
