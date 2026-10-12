//
//  EventRowView.swift
//  MediaStyleViewSwiftUI
//
//  一覧表示内のイベント1件分の行
//

import SwiftUI

struct EventRowView: View {

    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {

            // カテゴリカラーの縦バー（Apple純正の一覧表示に近い表現）
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.color)
                .frame(width: 4)

            // タイトルと場所
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let location = event.location {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            // 時刻表示（終日は「終日」、それ以外は開始〜終了を上下に）
            if event.isAllDay {
                Text("終日")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.startTimeText)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Text(event.endTimeText)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
    }
}

// MARK: - Preview

#Preview {
    List {
        EventRowView(event: CalendarSampleData.days[0].events[0])
        EventRowView(event: CalendarSampleData.days[2].events[0])
    }
}
