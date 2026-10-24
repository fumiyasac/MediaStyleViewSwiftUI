//
//  TimelineRecipeRowView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineのレシピ掲載項目の行。画像が無くてもレイアウトが崩れないアイコン＋テキスト構成。

import SwiftUI

struct TimelineRecipeRowView: View {

    let entry: TimelineEntryViewData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 種別アイコン（レシピ掲載）
            Image(systemName: "book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(CalendarTheme.accent))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("掲載レシピ")
                    .font(.caption2.bold())
                    .foregroundStyle(CalendarTheme.accent)
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("掲載レシピ \(entry.title)")
    }
}
