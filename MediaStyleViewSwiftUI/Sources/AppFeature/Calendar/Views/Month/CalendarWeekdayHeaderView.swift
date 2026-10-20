//
//  CalendarWeekdayHeaderView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブ上部の固定曜日行

import SwiftUI

struct CalendarWeekdayHeaderView: View {
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(weekdayColor(index: index))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private func weekdayColor(index: Int) -> Color {
        switch index {
        case 0: return accentRed
        case 6: return Color(red: 0.20, green: 0.48, blue: 0.96)
        default: return .secondary
        }
    }
}

#Preview {
    CalendarWeekdayHeaderView()
}
