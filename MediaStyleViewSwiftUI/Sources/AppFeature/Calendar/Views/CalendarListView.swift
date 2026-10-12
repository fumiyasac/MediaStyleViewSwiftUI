//
//  CalendarListView.swift
//  MediaStyleViewSwiftUI
//
//  Apple標準カレンダーアプリの「一覧（リスト）表示」画面の再現
//

import SwiftUI

public struct CalendarListView: View {

    // MARK: - Property

    private let days: [CalendarDay]
    @State private var searchText: String = ""

    // ナビゲーションタイトルに出す「2026年9月」のような文字列
    private var titleText: String {
        guard let first = days.first else { return "カレンダー" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: first.date)
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

    public init() {
        self.days = CalendarSampleData.days
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                ForEach(filteredDays) { day in
                    DaySectionView(day: day)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)

                    // 日付セクション間の区切り線
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "検索")
            .toolbar {
                // 左上: 年表示（Apple純正の戻る導線に相当）
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // NOTE: 年表示への遷移想定
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("2026")
                        }
                        .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.19))
                    }
                }

                // 右上: 受信/追加ボタン（下部はタブバーと競合するため上部へ集約）
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
            .tint(Color(red: 1.0, green: 0.23, blue: 0.19))
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarListView()
}
