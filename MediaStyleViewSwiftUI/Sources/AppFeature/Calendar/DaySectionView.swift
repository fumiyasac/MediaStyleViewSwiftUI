//
//  DaySectionView.swift
//  MediaStyleViewSwiftUI
//
//  一覧表示の日付ごとのセクション（左に日付・右にイベント群）
//

import SwiftUI

struct DaySectionView: View {

    let day: CalendarDay

    // 曜日ラベルの色（本日=赤 / 日曜=赤 / 土曜=青 / 平日=グレー）
    private var weekdayColor: Color {
        if day.isToday || day.isSunday {
            return Color(red: 1.0, green: 0.23, blue: 0.19)
        } else if day.isSaturday {
            return Color(red: 0.20, green: 0.48, blue: 0.96)
        } else {
            return .secondary
        }
    }

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
                            Circle().fill(Color(red: 1.0, green: 0.23, blue: 0.19))
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
                    EventRowView(event: event)

                    if index < day.events.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    List {
        DaySectionView(day: CalendarSampleData.days[0])
        DaySectionView(day: CalendarSampleData.days[2])
    }
    .listStyle(.plain)
}
