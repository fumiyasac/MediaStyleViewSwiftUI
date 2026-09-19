//
//  MonthView.swift
//  MediaStyleViewSwiftUI
//
//  月表示の1ヶ月分（見出し + 日付グリッド）
//

import SwiftUI

struct MonthView: View {

    let grid: MonthGrid

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0), count: 7
    )
    private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // 月の見出し（1月は「2027年/」を小さく前置。色は常に黒表示）
            monthTitle
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 2)

            // 日付グリッド
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(grid.cells.enumerated()), id: \.offset) { _, cell in
                    if let date = cell {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 58)
                    }
                }
            }
        }
        // 月ごとの上部区切り線
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
    }

    // 月見出し（年またぎの1月は「 / 2027年」を細字グレーで小さく後置して連結）
    private var monthTitle: Text {
        let month = Text(grid.monthText)
            .font(.system(size: 22, weight: .bold))
        if let suffix = grid.yearSuffixText {
            return month
                + Text(suffix)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.secondary)
        }
        return month
    }

    // 1日分のセル（日にち + イベントドット）
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isToday = CalendarDateUtil.isToday(date)
        let categories = CalendarDateUtil.categories(on: date)

        VStack(spacing: 3) {
            Text("\(CalendarDateUtil.dayNumber(of: date))")
                .font(.system(size: 18, weight: isToday ? .bold : .regular))
                .foregroundStyle(dayColor(for: date, isToday: isToday))
                .frame(width: 30, height: 30)
                .background {
                    if isToday {
                        Circle().fill(accentRed)
                    }
                }

            // イベントのカテゴリ色ドット（最大4件まで表示）
            HStack(spacing: 3) {
                ForEach(Array(categories.prefix(4).enumerated()), id: \.offset) { _, category in
                    Circle()
                        .fill(category.color)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }

    // 日にちの文字色（本日=白 / 日曜=赤 / 土曜=青 / 平日=黒）
    private func dayColor(for date: Date, isToday: Bool) -> Color {
        if isToday {
            return .white
        } else if CalendarDateUtil.isSunday(date) {
            return accentRed
        } else if CalendarDateUtil.isSaturday(date) {
            return Color(red: 0.20, green: 0.48, blue: 0.96)
        } else {
            return .primary
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        if let grid = MonthGrid(baseMonth: MonthGrid.startOfMonth(for: Date()), offset: 0) {
            MonthView(grid: grid)
        }
    }
}
