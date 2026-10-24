//
//  TimelineDaySectionView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Timelineの1日分Section。見出し＋その日の項目（レシピ掲載/調理記録）を並べる。
// 項目タップは親から渡されたクロージャで通知し、行View自体はNavigationやRepositoryを知らない。

import SwiftUI

struct TimelineDaySectionView: View {

    let section: TimelineSectionViewData
    let onTapEntry: (TimelineEntryViewData) -> Void

    var body: some View {
        Section {
            ForEach(section.entries) { entry in
                Button {
                    onTapEntry(entry)
                } label: {
                    switch entry.kind {
                    case .recipe:
                        TimelineRecipeRowView(entry: entry)
                    case .mealLog:
                        TimelineMealLogRowView(entry: entry)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(section.title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}
