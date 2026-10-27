//
//  TimelineSnapshotTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// TimelineのVisual Regression。固定Payloadから生成した日付別Section（掲載レシピ/調理記録の混在）を
// 描画して基準画像と比較する。検索/フィルタ/非同期ロードは対象外（Factoryで生成済みの固定データを使う）。

@testable import AppFeature
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("TimelineのSnapshot")
struct TimelineSnapshotTests {

    // TimelineScreen.timelineListと同じ構成（List + TimelineDaySectionView）のラッパー。
    // @Namespace（Zoom遷移用）はUI固有情報のためViewで保持する。
    private struct TimelineListWrapper: View {
        let sections: [TimelineSectionViewData]
        @Namespace private var namespace
        var body: some View {
            List {
                ForEach(sections) { section in
                    TimelineDaySectionView(section: section, namespace: namespace, onTapEntry: { _ in })
                }
            }
            .listStyle(.plain)
        }
    }

    private func sections() -> [TimelineSectionViewData] {
        let factory = TimelineViewDataFactory(calendar: SnapshotFixture.calendar)
        let entries = factory.makeEntries(from: SnapshotFixture.timelinePayload())
        return factory.makeSections(entries: entries, filter: .all, searchText: "")
    }

    @Test("掲載レシピと調理記録の混在表示（Light）")
    func mixedEntriesLight() {
        assertSnapshot(
            of: TimelineListWrapper(sections: sections()),
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .device(config: SnapshotConfig.device),
                traits: SnapshotConfig.light
            )
        )
    }
}
