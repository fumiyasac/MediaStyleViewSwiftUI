//
//  CalendarTab.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/20.
//

// TabViewだけのUI選択状態。将来のStateMachineに無理に含めない。

enum CalendarTab: Hashable, Sendable {
    case month
    case list
}
