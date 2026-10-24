//
//  CalendarDayCellView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// 月グリッド内の1日。表示専用のCalendarDayViewDataだけを受け取り、Domain/State/Repositoryは知らない。
// 見た目(今日の赤丸・曜日色・セル高さ58)は維持する。意味を持つマーカーはRecipeとMealLogのみ:
//  - 選択中の日付を示すリング（今日の赤丸を隠さない）
//  - レシピ掲載日マーカー（右上）・調理記録マーカー（左上）。形状・配置で区別する
// 旧イベント（work/health等）のカテゴリドットは廃止した。
// セル全体を1つのアクセシビリティ要素にまとめ、日付と掲載/調理の有無を読み上げる。

import SwiftUI

struct CalendarDayCellView: View {

    // MARK: - Property

    let viewData: CalendarDayViewData

    // MARK: - Body

    var body: some View {
        VStack(spacing: 3) {
            Text("\(viewData.dayNumber)")
                .font(.system(size: 18, weight: viewData.isToday ? .bold : .regular))
                .foregroundStyle(dayColor)
                .frame(width: 30, height: 30)
                .background {
                    // 本日は赤丸で強調（Apple純正と同じ表現）
                    if viewData.isToday {
                        Circle().fill(CalendarTheme.accent)
                    }
                }
                .overlay {
                    // 選択中はリングで示す。今日(赤丸)の上でも見えるよう色を出し分ける
                    if viewData.isSelected {
                        Circle().strokeBorder(selectionColor, lineWidth: 2)
                    }
                }

            // マーカー用の高さ（旧イベントドット廃止後も日付の縦位置を揃えるため確保）
            Color.clear.frame(height: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        // レシピ掲載マーカー（右上・調理記録とは形状/配置で区別）
        .overlay(alignment: .topTrailing) {
            if viewData.hasRecipe {
                Image(systemName: "fork.knife")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color(red: 0.98, green: 0.58, blue: 0.20))
                    .padding(2)
            }
        }
        // 調理記録マーカー（左上）
        .overlay(alignment: .topLeading) {
            if viewData.hasMealLog {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.20, green: 0.70, blue: 0.35))
                    .padding(2)
            }
        }
        // セル全体を1要素にまとめ、日付と状態（今日/選択/掲載/調理）を読み上げる
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Private Property

    // 日にちの文字色。本日だけは赤丸に重ねる白抜きにし、それ以外は祝日/日曜=赤・土曜=青・平日.primary
    private var dayColor: Color {
        if viewData.isToday {
            return .white
        }
        return CalendarTheme.weekdayColor(
            isSunday: viewData.isSunday,
            isSaturday: viewData.isSaturday,
            isHoliday: viewData.isHoliday,
            default: .primary
        )
    }

    // 選択リングの色。今日(赤丸)の上では白、それ以外はアクセント赤で示す
    private var selectionColor: Color {
        viewData.isToday ? .white : CalendarTheme.accent
    }

    // 日付表示用のフォーマッタ（例: 10月24日）。生成コストが高いので使い回す
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    // VoiceOver読み上げ文言。例:「10月24日、今日、選択中、レシピ掲載あり、調理記録あり」
    private var accessibilityText: String {
        var parts = [Self.dateFormatter.string(from: viewData.date)]
        if viewData.isToday { parts.append("今日") }
        if viewData.isSelected { parts.append("選択中") }
        if viewData.hasRecipe { parts.append("レシピ掲載あり") }
        if viewData.hasMealLog { parts.append("調理記録あり") }
        return parts.joined(separator: "、")
    }
}
