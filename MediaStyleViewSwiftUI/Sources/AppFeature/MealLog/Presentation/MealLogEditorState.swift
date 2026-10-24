//
//  MealLogEditorState.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLog Editor（調理記録の入力Sheet）のStateMachine定義。
// フォーム入力値(cookedAt/rating/memo)もStateで保持しつつ、重要な非同期状態
// (editing/saving/saved/failed)を明示する。requestIDで二重保存・古い結果を弾く。
// 調理日の初期値はユーザーの現在日付。掲載日を自動で調理日にしない（呼び出し側がcookedAtを渡す）。

import Foundation

// MARK: - MealLogEditorStatus

enum MealLogEditorStatus: Equatable, Sendable {
    // 入力可能
    case editing
    // 保存中（requestIDで完了Actionを照合）
    case saving(requestID: UUID)
    // 保存成功（確定したSummaryを保持。Sheetはこれを見て閉じる）
    case saved(MealLogSummary)
    // 保存失敗（入力内容は維持し、再試行できる）
    case failed(message: String)
}

// MARK: - MealLogEditorState

struct MealLogEditorState: Equatable, Sendable {

    // MARK: - Property

    let recipeID: RecipeID
    var cookedAt: Date
    var rating: Int
    var memo: String
    // Editorでは人数を収集しないため固定値を保持する
    let servings: Int
    var status: MealLogEditorStatus

    // MARK: - Derived

    var isSaving: Bool {
        if case .saving = status { return true }
        return false
    }

    var savedSummary: MealLogSummary? {
        if case let .saved(summary) = status { return summary }
        return nil
    }

    var errorMessage: String? {
        if case let .failed(message) = status { return message }
        return nil
    }

    // 現在の入力からMealLogInputを組み立てる（検証はInput.validate()/Repositoryに委譲）
    func makeInput() -> MealLogInput {
        MealLogInput(
            recipeID: recipeID,
            cookedAt: cookedAt,
            rating: rating,
            memo: memo,
            servings: servings
        )
    }

    // MARK: - Factory

    // 初期State。cookedAtは呼び出し側（原則ユーザーの現在日付）から受け取る。
    static func initial(
        recipeID: RecipeID,
        cookedAt: Date,
        rating: Int = 3,
        memo: String = "",
        servings: Int = 1
    ) -> MealLogEditorState {
        MealLogEditorState(
            recipeID: recipeID,
            cookedAt: cookedAt,
            rating: rating,
            memo: memo,
            servings: servings,
            status: .editing
        )
    }
}

// MARK: - MealLogEditorAction

enum MealLogEditorAction: Sendable, Equatable {
    // フォーム入力
    case setCookedAt(Date)
    case setRating(Int)
    case setMemo(String)
    // 保存意図（ViewModelがrequestIDを採番してbeginSavingへ展開）
    case save
    // 保存開始の確定
    case beginSaving(requestID: UUID)
    // 保存完了
    case saveSucceeded(requestID: UUID, summary: MealLogSummary)
    case saveFailed(requestID: UUID, message: String)
}

// MARK: - MealLogEditorEffect

enum MealLogEditorEffect: Sendable, Equatable {
    // 入力を永続化する（実行はViewModel、保存はRepository）
    case save(requestID: UUID, input: MealLogInput)
}

// MARK: - MealLogEditorTransition

struct MealLogEditorTransition: Sendable, Equatable {
    let state: MealLogEditorState
    let effects: [MealLogEditorEffect]
}
