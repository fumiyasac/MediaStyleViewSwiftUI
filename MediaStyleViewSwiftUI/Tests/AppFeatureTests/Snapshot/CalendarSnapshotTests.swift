//
//  CalendarSnapshotTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// Calendar月表示のVisual Regression。週ヘッダ＋1ヶ月グリッド（掲載レシピ/調理記録マーカー）を
// 固定Fixtureで描画し、基準画像との差分を検出する。アニメーションや無限スクロールは対象外。

@testable import AppFeature
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite("Calendar月表示のSnapshot")
struct CalendarSnapshotTests {

    // 週ヘッダ＋月グリッド（CalendarMonthScreenの構成を踏襲した安定表示）
    private func monthView() -> some View {
        VStack(spacing: 0) {
            CalendarWeekdayHeaderView()
            Divider()
            CalendarMonthView(
                grid: SnapshotFixture.octoberGrid(),
                state: SnapshotFixture.calendarState(),
                onSelectDate: { _ in }
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }

    @Test("月表示（掲載レシピ・調理記録マーカーあり / Light）")
    func monthWithMarkersLight() {
        assertSnapshot(
            of: monthView(),
            as: .image(
                precision: SnapshotConfig.precision,
                perceptualPrecision: SnapshotConfig.perceptualPrecision,
                layout: .device(config: SnapshotConfig.device),
                traits: SnapshotConfig.light
            )
        )
    }
}
