//
//  CalendarMonthScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月タブの画面入口。元コードの無限スクロール/位置検出/復元を維持。

import SwiftUI

public struct CalendarMonthScreen: View {

    // MARK: - Property

    // 基準となる今月の1日。全オフセットはこの月を起点に計算する
    private let baseMonth = CalendarMonthGrid.startOfMonth(for: Date())

    // 前後100年分（±1200ヶ月）の月を並べ、LazyVStackで可視分だけ描画することで
    // 実質「無限スクロール」の体験を作る。真の無限リストにせずとも、この範囲なら
    // ユーザー操作では端に到達せず、offset=0を今月として扱えるため実装が単純になる。
    private let monthOffsets = Array(-1200...1200)

    private let isActive: Bool
    private let days: [CalendarDay]

    // 現在最上部に表示中の月オフセット。ヘッダーの年表示に使う
    @State private var visibleOffset: Int = 0
    // 位置検出を受け付けるかのフラグ。復元スクロール中に途中経過の位置で
    // visibleOffsetが誤更新されるのを防ぐためにfalseにする（詳細はrestore参照）
    @State private var isTrackingEnabled = false

    // 共有Calendarを参照する（個別生成しない）
    private static let calendar = CalendarFactory.shared

    // ヘッダーの年表示用DateFormatterはstaticで使い回す
    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年"
        return formatter
    }()

    // 表示中オフセットの月から「yyyy年」を導出する
    private var yearText: String {
        let date = Self.calendar.date(byAdding: .month, value: visibleOffset, to: baseMonth) ?? baseMonth
        return Self.yearFormatter.string(from: date)
    }

    // MARK: - Initializer

    // 以前のpublic APIを壊さない互換用。画面内からのSampleData参照は旧API互換のみ
    public init(isActive: Bool = true) {
        self.isActive = isActive
        self.days = CalendarSampleData.days
    }

    // Rootから同じイベント配列を注入する
    init(days: [CalendarDay], isActive: Bool) {
        self.days = days
        self.isActive = isActive
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarWeekdayHeaderView()
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(monthOffsets, id: \.self) { offset in
                                if let grid = CalendarMonthGrid(baseMonth: baseMonth, offset: offset) {
                                    CalendarMonthView(grid: grid, days: days)
                                        .id(offset)
                                        // 各月の上端位置(minY)をmonthScroll座標系で収集し、
                                        // onPreferenceChangeで最上部の月を判定する材料にする
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: CalendarMonthPositionKey.self,
                                                    value: [offset: geo.frame(in: .named("monthScroll")).minY]
                                                )
                                            }
                                        )
                                }
                            }
                        }
                    }
                    .coordinateSpace(name: "monthScroll")
                    .onPreferenceChange(CalendarMonthPositionKey.self) { positions in
                        updateVisibleOffset(from: positions)
                    }
                    .onAppear {
                        // 初回表示時に現在のoffset（=今月0）へ復元して今月を先頭に出す
                        restore(to: visibleOffset, using: proxy)
                    }
                    .onChange(of: isActive) { _, nowActive in
                        // タブ復帰時は元の位置へ戻す。離脱時は追跡を止めて誤更新を防ぐ
                        if nowActive {
                            restore(to: visibleOffset, using: proxy)
                        } else {
                            isTrackingEnabled = false
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                        // 「今日」ボタンはツールバー（別の階層）にあり、ここのproxyへ直接触れない。
                        // そのためNotificationCenter経由で今月(offset=0)への復元を依頼する
                        visibleOffset = 0
                        restore(to: 0, using: proxy)
                    }
                }
            }
            .navigationTitle(yearText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("今日") {
                        NotificationCenter.default.post(name: .scrollToToday, object: nil)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // NOTE: 受信ボックス想定（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "tray")
                    }
                    Button {
                        // NOTE: イベント追加想定（現状の非動作ボタンを維持）
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(CalendarTheme.accent)
        }
    }

    // MARK: - Private Function

    // 指定オフセットの月を最上部へ復元する。
    // LazyVStackは生成タイミングでレイアウトが確定しないことがあり、1回のscrollToでは
    // ずれる場合がある。そのため0/0.15/0.3秒の3回scrollToして確実に目的の月へ寄せ、
    // レイアウトが落ち着く0.45秒後に追跡を再開する。復元中(isTrackingEnabled=false)は
    // 途中位置でvisibleOffsetが書き換わらないようにしている。
    private func restore(to offset: Int, using proxy: ScrollViewProxy) {
        isTrackingEnabled = false
        for delay in [0.0, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                proxy.scrollTo(offset, anchor: .top)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTrackingEnabled = true
        }
    }

    // 収集した各月の上端位置から、最上部に表示中の月オフセットを決めてヘッダーに反映する。
    // thresholdはヘッダー直下の境界線(y≒0)。上端がそこを過ぎた(minY<=threshold)月のうち
    // 最も下にある=最も境界に近い月を「今まさに最上部の月」とみなす。
    // どの月もまだ境界を過ぎていない場合は、最も上にある月を採用する。
    private func updateVisibleOffset(from positions: [Int: CGFloat]) {
        guard isTrackingEnabled, !positions.isEmpty else { return }

        let threshold: CGFloat = 1
        let chosen: Int
        if let top = positions.filter({ $0.value <= threshold }).max(by: { $0.value < $1.value }) {
            chosen = top.key
        } else if let first = positions.min(by: { $0.value < $1.value }) {
            chosen = first.key
        } else {
            return
        }
        if chosen != visibleOffset {
            visibleOffset = chosen
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarMonthScreen()
}
