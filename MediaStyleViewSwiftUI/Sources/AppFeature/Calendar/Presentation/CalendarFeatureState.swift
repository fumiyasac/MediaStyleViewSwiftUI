//
//  CalendarFeatureState.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Calendar FeatureのState。View表示に必要な値だけを持つSendableな値型。
//
// 連続スクロールでは複数月が同時に見えるため、単一の読込状態では月Bの読込が月Aを上書きしてしまう。
// そこでStateは「月キーごとの読込状態 months: [MonthKey: CalendarMonthLoad]」を持ち、
// 各月が自前のデータ・phase・requestIDを持つことで、別月の読込で他月のデータが消えないようにする。
// 読込中/失敗でも各月のデータ(recipeEntries/mealLogs)は保持し、表示を失わない。

import Foundation

// MARK: - CalendarLoadPhase

// 月単位の読込フェーズ。
enum CalendarLoadPhase: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(message: String)
}

// MARK: - CalendarMonthLoad

// 1ヶ月分の読込状態。データ(recipeEntries/mealLogs)はphaseと分離して保持し、
// 再読込中も直前のデータを失わない。requestIDはその月の進行中リクエストの照合に使う。
struct CalendarMonthLoad: Sendable, Equatable {

    var recipeEntries: [DailyRecipeEntry]
    var mealLogs: [MealLogSummary]
    var phase: CalendarLoadPhase
    var requestID: UUID?
    // 掲載レシピの取得元（最新/キャッシュ）。キャッシュ表示中であることをUIへ示すために持つ。
    // 既定は.remote（Fixture/キャッシュ非対応構成では常に最新扱い＝注記を出さない）。
    var origin: RecipeDataOrigin = .remote

    static let empty = CalendarMonthLoad(
        recipeEntries: [], mealLogs: [], phase: .idle, requestID: nil, origin: .remote
    )

    var isLoading: Bool { phase == .loading }

    var errorMessage: String? {
        if case let .failed(message) = phase { return message }
        return nil
    }

    // 既に読込済み or 読込中なら、新規の読込要求は不要（重複読込・無限読込の抑制に使う）
    var isActiveOrLoaded: Bool {
        switch phase {
        case .loading, .loaded: return true
        case .idle, .failed: return false
        }
    }
}

// MARK: - CalendarFeatureState

struct CalendarFeatureState: Sendable, Equatable {

    // MARK: - Property

    // 選択中の日付
    var selectedDate: Date
    // 月キーごとの読込状態（キャッシュ）
    var months: [MonthKey: CalendarMonthLoad]

    // MARK: - Derived

    // 指定月の読込状態（未登録ならempty）
    func monthLoad(_ key: MonthKey) -> CalendarMonthLoad {
        months[key] ?? .empty
    }

    // MARK: - Factory

    // 初期State。monthsは空（各月はスクロール/表示で順次読み込む）。
    // referenceDateは非決定的なDate()を外から渡すための引数。
    static func initial(referenceDate: Date) -> CalendarFeatureState {
        CalendarFeatureState(selectedDate: referenceDate, months: [:])
    }

    // 指定日が属する月の起点日(1日 0時)を返す（表示月やmonth引数の正規化に使う）
    static func startOfMonth(for date: Date, calendar: Calendar = DateKeyCalendar.default) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
