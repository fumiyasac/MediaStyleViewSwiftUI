//
//  CalendarListScreen.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/09/19.
//

// Apple標準カレンダーアプリの「一覧（リスト）表示」画面の再現

import SwiftUI

public struct CalendarListScreen: View {

    // MARK: - Property

    private let days: [CalendarDay]
    @State private var searchText: String = ""

    // タイトル・戻るボタン表示用のDateFormatterはstaticで使い回す
    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    // ナビゲーションタイトルに出す「2026年9月」のような文字列
    private var titleText: String {
        guard let first = days.first else { return "カレンダー" }
        return Self.titleFormatter.string(from: first.date)
    }


    // 検索文字列でイベントを絞り込んだ結果
    private var filteredDays: [CalendarDay] {
        guard !searchText.isEmpty else { return days }
        return days.compactMap { day in
            let matched = day.events.filter { event in
                event.title.localizedCaseInsensitiveContains(searchText)
                    || (event.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            return matched.isEmpty ? nil : CalendarDay(date: day.date, events: matched)
        }
    }

    // MARK: - Initializer

    // Rootから月表示と同じイベント配列を注入する
    init(days: [CalendarDay]) {
        self.days = days
    }

    // 以前のpublic APIを壊さないための互換用。内部ではinit(days:)へ委譲する
    public init() {
        self.init(days: CalendarSampleData.days)
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            // List描画はCalendarEventListViewへ委譲し、重複を排除する
            CalendarEventListView(days: filteredDays)
                .navigationTitle(titleText)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "検索")
                .toolbar {

                    // 右上: 受信/追加ボタン（下部はタブバーと競合するため上部へ集約）
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            // NOTE: イベント追加想定
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .tint(CalendarTheme.accent)
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarListScreen()
}
