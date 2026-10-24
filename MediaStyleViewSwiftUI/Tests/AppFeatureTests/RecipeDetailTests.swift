//
//  RecipeDetailTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Recipe DetailのViewModelと、保存結果のCalendar State反映のテスト。
// Swift Testing へ移行済み。

@testable import AppFeature
import Foundation
import Testing

private let tokyoCal = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
private func d(_ y: Int, _ m: Int, _ dd: Int) -> Date {
    tokyoCal.date(from: DateComponents(year: y, month: m, day: dd))!
}
private func summary(_ dateKey: String, recipe: String = "recipe-01", id: MealLogID = MealLogID()) -> MealLogSummary {
    MealLogSummary(id: id, recipeID: RecipeID(recipe), dateKey: DateKey(value: dateKey), cookedAt: d(2026, 3, 10), rating: 4, memo: "memo", servings: 1)
}

// MARK: - RecipeDetailViewModel

@MainActor
@Suite("Recipe Detailの読み込み")
struct RecipeDetailViewModelTests {

    private func makeViewModel(recipeID: String) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipeID: RecipeID(recipeID),
            recipeRepository: FixtureRecipeRepository(referenceDate: d(2026, 3, 15), calendar: tokyoCal),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyoCal)
        )
    }

    // 1 & 5. 正しいIDから詳細を取得でき、材料・手順が表示データへ入る
    @Test("正しいIDから詳細を取得でき材料・手順が表示データへ入る")
    func loadsRecipeWithIngredientsAndSteps() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-01")
        viewModel.load()
        await viewModel.loadTask?.value

        let recipe = try #require(viewModel.state.recipe)
        #expect(recipe.title == "鮭の塩麹焼き")
        #expect(!recipe.ingredients.isEmpty)
        #expect(!recipe.steps.isEmpty)
    }

    // 2. 存在しないIDはエラー状態
    @Test("存在しないIDはエラー状態になる")
    func unknownRecipeBecomesFailed() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-unknown")
        viewModel.load()
        await viewModel.loadTask?.value

        guard case .failed = viewModel.state else {
            Issue.record("failedになるべき")
            return
        }
    }

    // 3 & 4. 任意のRecipe IDを開ける（複数日掲載/同日複数のどちらでも、選んだIDで取得できる）
    @Test("任意のRecipe IDを開ける")
    func opensSpecifiedRecipe() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-05")
        viewModel.load()
        await viewModel.loadTask?.value
        #expect(viewModel.state.recipe?.id == RecipeID("recipe-05"))
    }

    // 保存成功を手持ちの調理記録一覧へ反映する（このレシピのもののみ）
    @Test("保存成功をこのレシピの調理記録一覧へ反映する")
    func didSaveMealLogReflectsIntoList() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-01")
        viewModel.load()
        await viewModel.loadTask?.value
        #expect(viewModel.state.mealLogs.isEmpty)

        viewModel.didSaveMealLog(summary("2026-03-10", recipe: "recipe-01"))
        #expect(viewModel.state.mealLogs.count == 1)

        // 別レシピの記録は無視する
        viewModel.didSaveMealLog(summary("2026-03-11", recipe: "recipe-02"))
        #expect(viewModel.state.mealLogs.count == 1)
    }
}

// MARK: - Calendar への保存反映（Reducer）

@Suite("保存結果のCalendar State反映")
struct CalendarMealLogReflectionTests {

    private let reducer = CalendarReducer()

    private func initialState() -> CalendarFeatureState {
        .initial(referenceDate: d(2026, 3, 15))
    }

    // 17 & 18. 保存した調理日(=掲載日と異なる)の月へマーカーが反映される
    @Test("保存した調理日(掲載日と異なる)の月へマーカーが反映される")
    func mealLogSavedReflectsOnCookedDayMonth() {
        // 掲載日は3月だが、調理日は4月のケース
        let saved = summary("2026-04-02", recipe: "recipe-01")
        let transition = reducer.reduce(state: initialState(), action: .mealLogSaved(saved))

        let aprilKey = MonthKey(value: "2026-04")
        let logs = transition.state.monthLoad(aprilKey).mealLogs
        #expect(logs.map(\.dateKey) == [DateKey(value: "2026-04-02")])
        // 3月には入らない
        #expect(transition.state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
    }

    // 19. 保存反映後に同じ月を再取得(loadSucceeded)しても重複しない（replaceされる）
    @Test("保存反映後に同じ月を再取得しても重複しない")
    func reloadAfterSaveDoesNotDuplicate() {
        let id = MealLogID()
        let saved = summary("2026-03-10", id: id)
        var state = reducer.reduce(state: initialState(), action: .mealLogSaved(saved)).state

        // 同月をloading→loadSucceeded（repositoryは同じログを1件含む）
        let marchKey = MonthKey(value: "2026-03")
        state.months[marchKey]?.phase = .loading
        let reqID = UUID()
        state.months[marchKey]?.requestID = reqID
        let payload = CalendarMonthPayload(recipeEntries: [], mealLogs: [saved])
        let transition = reducer.reduce(state: state, action: .loadSucceeded(requestID: reqID, monthKey: marchKey, payload: payload))

        #expect(transition.state.monthLoad(marchKey).mealLogs.count == 1)
    }

    // 編集で調理日=月が変わっても、同一idが複数月に残らない
    @Test("編集で調理日=月が変わっても同一idが複数月に残らない")
    func editMovingDateRemovesFromOldMonth() {
        let id = MealLogID()
        var state = reducer.reduce(state: initialState(), action: .mealLogSaved(summary("2026-03-10", id: id))).state
        // 同一idで4月へ移動
        state = reducer.reduce(state: state, action: .mealLogSaved(summary("2026-04-10", id: id))).state

        #expect(state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
        #expect(state.monthLoad(MonthKey(value: "2026-04")).mealLogs.map(\.id) == [id])
    }

    // 削除は全月から除去される
    @Test("削除は全月から除去される")
    func mealLogDeletedRemoves() {
        let id = MealLogID()
        var state = reducer.reduce(state: initialState(), action: .mealLogSaved(summary("2026-03-10", id: id))).state
        state = reducer.reduce(state: state, action: .mealLogDeleted(id)).state
        #expect(state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
    }
}
