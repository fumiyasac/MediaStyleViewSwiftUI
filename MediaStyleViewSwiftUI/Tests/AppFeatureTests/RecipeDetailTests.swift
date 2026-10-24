//
//  RecipeDetailTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Recipe DetailのViewModelと、保存結果のCalendar State反映のテスト。

@testable import AppFeature
import Foundation
import XCTest

private let tokyoCal = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
private func d(_ y: Int, _ m: Int, _ dd: Int) -> Date {
    tokyoCal.date(from: DateComponents(year: y, month: m, day: dd))!
}
private func summary(_ dateKey: String, recipe: String = "recipe-01", id: MealLogID = MealLogID()) -> MealLogSummary {
    MealLogSummary(id: id, recipeID: RecipeID(recipe), dateKey: DateKey(value: dateKey), cookedAt: d(2026, 3, 10), rating: 4, memo: "memo", servings: 1)
}

// MARK: - RecipeDetailViewModel

@MainActor
final class RecipeDetailViewModelTests: XCTestCase {

    private func makeViewModel(recipeID: String) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipeID: RecipeID(recipeID),
            recipeRepository: FixtureRecipeRepository(referenceDate: d(2026, 3, 15), calendar: tokyoCal),
            mealLogRepository: InMemoryMealLogRepository(calendar: tokyoCal)
        )
    }

    // 1 & 5. 正しいIDから詳細を取得でき、材料・手順が表示データへ入る
    func testLoadsRecipeWithIngredientsAndSteps() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-01")
        viewModel.load()
        await viewModel.loadTask?.value

        let recipe = try XCTUnwrap(viewModel.state.recipe)
        XCTAssertEqual(recipe.title, "鮭の塩麹焼き")
        XCTAssertFalse(recipe.ingredients.isEmpty)
        XCTAssertFalse(recipe.steps.isEmpty)
    }

    // 2. 存在しないIDはエラー状態
    func testUnknownRecipeBecomesFailed() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-unknown")
        viewModel.load()
        await viewModel.loadTask?.value

        guard case .failed = viewModel.state else {
            return XCTFail("failedになるべき")
        }
    }

    // 3 & 4. 任意のRecipe IDを開ける（複数日掲載/同日複数のどちらでも、選んだIDで取得できる）
    func testOpensSpecifiedRecipe() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-05")
        viewModel.load()
        await viewModel.loadTask?.value
        XCTAssertEqual(viewModel.state.recipe?.id, RecipeID("recipe-05"))
    }

    // 保存成功を手持ちの調理記録一覧へ反映する（このレシピのもののみ）
    func testDidSaveMealLogReflectsIntoList() async throws {
        let viewModel = makeViewModel(recipeID: "recipe-01")
        viewModel.load()
        await viewModel.loadTask?.value
        XCTAssertTrue(viewModel.state.mealLogs.isEmpty)

        viewModel.didSaveMealLog(summary("2026-03-10", recipe: "recipe-01"))
        XCTAssertEqual(viewModel.state.mealLogs.count, 1)

        // 別レシピの記録は無視する
        viewModel.didSaveMealLog(summary("2026-03-11", recipe: "recipe-02"))
        XCTAssertEqual(viewModel.state.mealLogs.count, 1)
    }
}

// MARK: - Calendar への保存反映（Reducer）

final class CalendarMealLogReflectionTests: XCTestCase {

    private let reducer = CalendarReducer()

    private func initialState() -> CalendarFeatureState {
        .initial(referenceDate: d(2026, 3, 15))
    }

    // 17 & 18. 保存した調理日(=掲載日と異なる)の月へマーカーが反映される
    func testMealLogSavedReflectsOnCookedDayMonth() {
        // 掲載日は3月だが、調理日は4月のケース
        let saved = summary("2026-04-02", recipe: "recipe-01")
        let transition = reducer.reduce(state: initialState(), action: .mealLogSaved(saved))

        let aprilKey = MonthKey(value: "2026-04")
        let logs = transition.state.monthLoad(aprilKey).mealLogs
        XCTAssertEqual(logs.map(\.dateKey), [DateKey(value: "2026-04-02")])
        // 3月には入らない
        XCTAssertTrue(transition.state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
    }

    // 19. 保存反映後に同じ月を再取得(loadSucceeded)しても重複しない（replaceされる）
    func testReloadAfterSaveDoesNotDuplicate() {
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

        XCTAssertEqual(transition.state.monthLoad(marchKey).mealLogs.count, 1)
    }

    // 編集で調理日=月が変わっても、同一idが複数月に残らない
    func testEditMovingDateRemovesFromOldMonth() {
        let id = MealLogID()
        var state = reducer.reduce(state: initialState(), action: .mealLogSaved(summary("2026-03-10", id: id))).state
        // 同一idで4月へ移動
        state = reducer.reduce(state: state, action: .mealLogSaved(summary("2026-04-10", id: id))).state

        XCTAssertTrue(state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
        XCTAssertEqual(state.monthLoad(MonthKey(value: "2026-04")).mealLogs.map(\.id), [id])
    }

    // 削除は全月から除去される
    func testMealLogDeletedRemoves() {
        let id = MealLogID()
        var state = reducer.reduce(state: initialState(), action: .mealLogSaved(summary("2026-03-10", id: id))).state
        state = reducer.reduce(state: state, action: .mealLogDeleted(id)).state
        XCTAssertTrue(state.monthLoad(MonthKey(value: "2026-03")).mealLogs.isEmpty)
    }
}
