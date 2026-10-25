//
//  RecipeTransitionSourceID.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/26.
//

// Zoom Navigation Transitionの遷移元を一意に識別する値型。
// Recipe Master ID（どの献立か）と、画面上の遷移元View（どのカードか）は意味が異なる。
// 同じRecipeが複数の掲載日・複数の場所(Calendar/Timeline)に現れるため、
// 遷移元Viewごとに一意なIDを持たせ、戻り時に正しいカードへ縮小できるようにする。
//
// 設計ルール:
//  - matchedTransitionSource と navigationTransition(.zoom) で同じ値を使う。
//  - View再描画ごとにUUIDを生成しない（既存の安定IDから決定的に作る）。
//  - 同一画面内でSource IDが重複しない。
//  - 同じRecipeの複数掲載を区別する（entryKeyで分離）。
//  - SwiftData EntityやNamespaceを保持しない（純粋なHashable値）。

import Foundation

struct RecipeTransitionSourceID: Hashable, Sendable {

    // 遷移元の場所。Calendar/Timelineで同一Recipe・同一日でも衝突しないよう区別する。
    enum Origin: String, Hashable, Sendable {
        case calendar
        case timeline
    }

    let origin: Origin
    // 遷移先のRecipe（意味の確認用。IDの等価性にも寄与する）
    let recipeID: RecipeID
    // 画面内で遷移元Viewを一意に識別するキー（掲載割当ID/調理記録ID/掲載日など、既存の安定ID）
    let entryKey: String

    // MARK: - Factory

    // Timeline項目から生成。entry.idは掲載割当ID/MealLog IDベースで一意（Recipe Master IDとは別物）。
    static func timeline(entry: TimelineEntryViewData) -> RecipeTransitionSourceID {
        RecipeTransitionSourceID(origin: .timeline, recipeID: entry.recipeID, entryKey: entry.id)
    }

    // Calendarの掲載日から生成（将来のPreview Card遷移用。掲載日で一意化する）。
    static func calendar(recipeID: RecipeID, dayKey: DateKey) -> RecipeTransitionSourceID {
        RecipeTransitionSourceID(origin: .calendar, recipeID: recipeID, entryKey: dayKey.value)
    }
}
