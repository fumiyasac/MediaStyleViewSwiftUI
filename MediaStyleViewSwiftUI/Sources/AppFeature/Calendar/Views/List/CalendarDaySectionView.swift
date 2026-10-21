//
//  CalendarDaySectionView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/09/19.
//

// 一覧表示の日付ごとのセクション（左に日付・右にイベント群）

import SwiftUI

struct CalendarDaySectionView: View {

    // MARK: - Property

    let day: CalendarDay

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // 左側の日付カラム
            VStack(spacing: 2) {
                Text(day.weekdayText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(weekdayColor)

                if day.isToday {
                    // 本日は赤丸で強調（Apple純正と同じ表現）
                    Text(day.dayText)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(CalendarTheme.accent)
                        )
                } else {
                    Text(day.dayText)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                }
            }
            .frame(width: 44)

            // 右側のイベント一覧
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                    CalendarEventRowView(event: event)

                    if index < day.events.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Private Function

    // 曜日ラベルの色。本日は日曜と同じ赤扱いにし、以降は祝日/日曜=赤・土曜=青・平日.secondaryを
    // 共通ロジックで解決する（本日の日にち自体は上の赤丸＋白抜きで表現するため、ここでは色のみ）
    private var weekdayColor: Color {
        if day.isToday {
            return CalendarTheme.accent
        }
        return CalendarTheme.weekdayColor(
            isSunday: day.isSunday,
            isSaturday: day.isSaturday,
            isHoliday: CalendarDateUtil.isHoliday(day.date),
            default: .secondary
        )
    }
}

// MARK: - Preview

#Preview {
    List {
        CalendarDaySectionView(day: CalendarSampleData.days[0])
        CalendarDaySectionView(day: CalendarSampleData.days[2])
    }
    .listStyle(.plain)
}
