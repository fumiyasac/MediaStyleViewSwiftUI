//
//  TimelineMealLogRowView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineの調理記録(MealLog)項目の行。評価はVoiceOverでも意味が伝わるラベルを付ける。

import SwiftUI

struct TimelineMealLogRowView: View {

    let entry: TimelineEntryViewData

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 種別アイコン（調理記録）
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.20, green: 0.70, blue: 0.35)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("作った記録")
                    .font(.caption2.bold())
                    .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.32))
                Text(entry.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(entry.recipeMissing ? .secondary : .primary)
                if let rating = entry.rating {
                    ratingView(rating)
                }
                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private View

    private func ratingView(_ rating: Int) -> some View {
        let clamped = max(0, min(5, rating))
        return HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < clamped ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundStyle(CalendarTheme.accent)
            }
        }
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        var parts = ["作った記録", entry.title]
        if let rating = entry.rating {
            parts.append("評価\(max(0, min(5, rating)))")
        }
        if let subtitle = entry.subtitle {
            parts.append(subtitle)
        }
        return parts.joined(separator: " ")
    }
}
