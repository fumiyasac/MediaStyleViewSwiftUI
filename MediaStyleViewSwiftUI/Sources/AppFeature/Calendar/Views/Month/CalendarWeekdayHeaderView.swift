//
//  CalendarWeekdayHeaderView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブ上部の固定曜日行

import SwiftUI

struct CalendarWeekdayHeaderView: View {

    // MARK: - Property

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    // MARK: - Body

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

    // MARK: - Private Function

    // 曜日ラベルの色。平日は.secondaryを既定にして日曜=赤/土曜=青を共通ロジックで解決する
    private func weekdayColor(index: Int) -> Color {
        CalendarTheme.weekdayColor(
            isSunday: index == 0, isSaturday: index == 6, default: .secondary
        )
    }
}

// MARK: - Preview

#Preview {
    CalendarWeekdayHeaderView()
}
