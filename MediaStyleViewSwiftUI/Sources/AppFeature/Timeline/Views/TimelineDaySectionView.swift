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
    // Zoom遷移用Namespace（遷移先と共有）。各行を遷移元として一意IDでマークする。
    let namespace: Namespace.ID
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
                // この行をZoom遷移の遷移元としてマーク（戻り時にこのカードへ縮小する）
                .matchedTransitionSource(id: RecipeTransitionSourceID.timeline(entry: entry), in: namespace)
            }
        } header: {
            Text(section.title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}
