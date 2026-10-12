//
//  MonthCalendarView.swift
//  MediaStyleViewSwiftUI
//
//  Apple標準カレンダーの様に、月が縦に途切れなく続く無限スクロール画面
//

import SwiftUI

public struct MonthCalendarView: View {

    // MARK: - Property

    // 基準となる今月の1日
    private let baseMonth = MonthGrid.startOfMonth(for: Date())

    // 前後100年分（±1200ヶ月）を用意し、LazyVStackで遅延描画することで
    // 実質「無限スクロール」の体験を実現する
    private let monthOffsets = Array(-1200...1200)

    // このタブ（月表示）が選択中か。タブ切替時の位置復元トリガに使う
    private let isActive: Bool

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    // 現在最上部に見えている月のオフセット（スクロールに応じて更新）
    // 初期値0 = 本日の月。最後に見ていた月として保持し、タブ再表示時に復元する
    @State private var visibleOffset: Int = 0
    // 位置追跡の有効フラグ。プログラム的なスクロール／タブ遷移中は無効化して誤検出を防ぐ
    @State private var isTrackingEnabled = false

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    // ナビゲーションタイトル用（表示中の月の年）
    private var yearText: String {
        let date = Self.calendar.date(byAdding: .month, value: visibleOffset, to: baseMonth)
            ?? baseMonth
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年"
        return formatter.string(from: date)
    }

    // MARK: - Initializer

    public init(isActive: Bool = true) {
        self.isActive = isActive
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // 固定の曜日ヘッダー
                weekdayHeader

                Divider()

                // 月の無限スクロール本体
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(monthOffsets, id: \.self) { offset in
                                if let grid = MonthGrid(baseMonth: baseMonth, offset: offset) {
                                    MonthView(grid: grid)
                                        .id(offset)
                                        // 各月の位置をスクロール座標系で報告
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear.preference(
                                                    key: MonthPositionKey.self,
                                                    value: [offset: geo.frame(in: .named("monthScroll")).minY]
                                                )
                                            }
                                        )
                                }
                            }
                        }
                    }
                    .coordinateSpace(name: "monthScroll")
                    // 最上部に見えている月を検出してヘッダーの年を更新
                    .onPreferenceChange(MonthPositionKey.self) { positions in
                        updateVisibleOffset(from: positions)
                    }
                    .onAppear {
                        // 初回表示時に本日の月（offset:0）を最上部へ復元
                        restore(to: visibleOffset, using: proxy)
                    }
                    // タブ切替（onAppear/onDisappearが発火しないため選択状態を監視）
                    .onChange(of: isActive) { _, nowActive in
                        if nowActive {
                            // 月タブに戻ったら、最後に見ていた月を最上部へ復元
                            restore(to: visibleOffset, using: proxy)
                        } else {
                            // 一覧タブへ移る間は追跡を止め、リセット位置で年が書き換わるのを防ぐ
                            isTrackingEnabled = false
                        }
                    }
                    // 「今日」ボタンから本日の月へ戻す通知
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToToday)) { _ in
                        // アニメーション付きだと遅延リストの長距離スクロールで到達に失敗するため、
                        // 復元と同じ確実な方式で本日の月（offset:0）へ戻す
                        visibleOffset = 0
                        restore(to: 0, using: proxy)
                    }
                }
            }
            .navigationTitle(yearText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 「今日」は左上（TabViewのタブバーと重なる下部だとタップを奪われるため上部へ）
                ToolbarItem(placement: .topBarLeading) {
                    Button("今日") {
                        NotificationCenter.default.post(name: .scrollToToday, object: nil)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // NOTE: 受信ボックス想定
                    } label: {
                        Image(systemName: "tray")
                    }
                    Button {
                        // NOTE: イベント追加想定
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(accentRed)
        }
    }

    // 曜日ヘッダー（日曜=赤 / 土曜=青）
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(weekdayColor(index: index))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    private func weekdayColor(index: Int) -> Color {
        switch index {
        case 0: return accentRed                                  // 日曜
        case 6: return Color(red: 0.20, green: 0.48, blue: 0.96)  // 土曜
        default: return .secondary
        }
    }

    // 各月の上端位置から「今まさに最上部に見えている月」を求める
    // 指定オフセットの月を最上部へ復元する（起動時・タブ再表示時に使用）
    private func restore(to offset: Int, using proxy: ScrollViewProxy) {
        // 復元中は位置追跡を止め、リセット位置でヘッダー年が書き換わるのを防ぐ
        isTrackingEnabled = false
        // タブ再表示時のリセットと競合しないよう、複数回スクロールして確実に復元
        for delay in [0.0, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                proxy.scrollTo(offset, anchor: .top)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isTrackingEnabled = true
        }
    }

    private func updateVisibleOffset(from positions: [Int: CGFloat]) {
        // 復元スクロール中／タブ遷移中は、途中経過の位置で年を書き換えない
        guard isTrackingEnabled, !positions.isEmpty else { return }

        // 上端がヘッダーラインより上（minY <= 0）に達している月のうち、
        // 最も下にある（minYが最大の）ものが最上部に表示中の月
        let threshold: CGFloat = 1
        let chosen: Int
        if let top = positions.filter({ $0.value <= threshold }).max(by: { $0.value < $1.value }) {
            chosen = top.key
        } else if let first = positions.min(by: { $0.value < $1.value }) {
            // まだどの月も上端に達していない場合は最も上にある月
            chosen = first.key
        } else {
            return
        }

        if chosen != visibleOffset {
            visibleOffset = chosen
        }
    }
}

// 月ごとの上端位置（オフセット→minY）を集約するPreferenceKey
private struct MonthPositionKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// 「今日」ボタン → 今月へスクロールするための通知名
extension Notification.Name {
    static let scrollToToday = Notification.Name("MonthCalendarView.scrollToToday")
}

// MARK: - Preview

#Preview {
    MonthCalendarView()
}
