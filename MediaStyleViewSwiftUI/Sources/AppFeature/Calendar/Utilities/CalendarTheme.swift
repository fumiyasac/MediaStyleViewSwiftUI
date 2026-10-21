//
//  CalendarTheme.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/21.
//

// カレンダー画面の配色を集約する。各Viewに散っていた色リテラルの重複を防ぐ。

import SwiftUI

enum CalendarTheme {

    // MARK: - Color

    // 本日・日曜・各種アクセントに使う赤（Apple純正に近い色）
    static let accent = Color(red: 1.0, green: 0.23, blue: 0.19)
    // 土曜に使う青
    static let saturday = Color(red: 0.20, green: 0.48, blue: 0.96)

    // MARK: - Function

    // 曜日・祝祭日に応じた文字色を返す（日曜/祝日=赤 / 土曜=青 / それ以外=defaultColor）。
    // 祝祭日は日本の慣習・Apple純正と同じく日曜と同じ赤扱いにする。
    // 一覧は平日を.secondary、月セルは平日を.primaryにする差があるため、
    // 既定色を引数で受け取って共通化しつつ違いを保つ。
    // 本日の強調（赤文字や白抜き）は表示側の事情が異なるため呼び出し側に委ねる。
    // isHolidayは曜日ヘッダーなど日付を持たない呼び出しでは既定falseのままにする。
    static func weekdayColor(
        isSunday: Bool, isSaturday: Bool, isHoliday: Bool = false, default defaultColor: Color
    ) -> Color {
        if isSunday || isHoliday {
            return accent
        } else if isSaturday {
            return saturday
        } else {
            return defaultColor
        }
    }
}
