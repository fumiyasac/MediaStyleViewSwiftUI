//
//  RecipeDomainTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Recipe Domain + Fixture Repository（PR1）のテスト。
// 日付キーのTimeZone影響、Fixtureの件数・複数日掲載、調理ログのCRUDを検証する。

@testable import AppFeature
import Foundation
import XCTest

final class RecipeDomainTests: XCTestCase {

    // テスト用のTimeZone固定Calendar（決定的に検証するため）
    private let tokyoCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
    private let utcCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "UTC")!)

    // MARK: - DateKey

    // 日付成分をゼロ埋めした「yyyy-MM-dd」で生成される
    func testDateKeyFormat() throws {
        let date = try XCTUnwrap(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 5)))
        XCTAssertEqual(DateKey(date: date, calendar: tokyoCalendar).value, "2026-03-05")
    }

    // 同じ絶対時刻でも、CalendarのTimeZoneが違えば属する暦日(キー)が変わる
    func testDateKeyDependsOnTimeZone() throws {
        // UTCで 2026-01-01 15:00 の瞬間（JSTでは 2026-01-02 00:00）
        let instant = try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15))
        )
        XCTAssertEqual(DateKey(date: instant, calendar: utcCalendar).value, "2026-01-01")
        XCTAssertEqual(DateKey(date: instant, calendar: tokyoCalendar).value, "2026-01-02")
    }

    // 文字列の辞書順と日付順が一致する
    func testDateKeyComparable() {
        XCTAssertLessThan(DateKey(value: "2026-01-01"), DateKey(value: "2026-01-02"))
        XCTAssertLessThan(DateKey(value: "2025-12-31"), DateKey(value: "2026-01-01"))
    }

    // MARK: - FixtureRecipeRepository

    // レシピMasterは12件返る
    func testFixtureHasTwelveRecipes() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipes = try await repository.allRecipes()
        XCTAssertEqual(recipes.count, 12)
    }

    // IDでMasterを引ける。存在しないIDはnil
    func testFixtureRecipeLookupByID() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipe = try await repository.recipe(for: RecipeID("recipe-01"))
        XCTAssertEqual(recipe?.title, "鮭の塩麹焼き")
        let missing = try await repository.recipe(for: RecipeID("recipe-xx"))
        XCTAssertNil(missing)
    }

    // 日別割当は基準日±15日の31件。基準日のキーには1件割り当たる
    func testFixtureDailyEntriesCountAndReferenceDay() async throws {
        let reference = try XCTUnwrap(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15)))
        let repository = FixtureRecipeRepository(referenceDate: reference, calendar: tokyoCalendar)

        let all = try await repository.allDailyEntries()
        XCTAssertEqual(all.count, 31)

        let todays = try await repository.dailyEntries(for: DateKey(value: "2026-03-15"))
        XCTAssertEqual(todays.count, 1)

        // 割当の無い日は空配列
        let empty = try await repository.dailyEntries(for: DateKey(value: "1999-01-01"))
        XCTAssertTrue(empty.isEmpty)
    }

    // 同じレシピが複数日に掲載される（12件を31日に循環割り当て）
    func testFixtureAllowsSameRecipeOnMultipleDays() async throws {
        let reference = try XCTUnwrap(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15)))
        let repository = FixtureRecipeRepository(referenceDate: reference, calendar: tokyoCalendar)

        let all = try await repository.allDailyEntries()
        let countByRecipe = Dictionary(grouping: all, by: \.recipeID).mapValues(\.count)
        let maxCount = countByRecipe.values.max() ?? 0
        XCTAssertGreaterThanOrEqual(maxCount, 2)
    }

    // 日別割当が参照するレシピIDはすべてMasterに存在する（参照整合性）
    func testFixtureEntriesReferenceExistingRecipes() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipeIDs = Set(try await repository.allRecipes().map(\.id))
        let entries = try await repository.allDailyEntries()
        for entry in entries {
            XCTAssertTrue(recipeIDs.contains(entry.recipeID))
        }
    }

    // MARK: - InMemoryMealLogRepository

    private func makeInput(
        recipeID: String = "recipe-01",
        cookedAt: Date,
        rating: Int = 4,
        memo: String = "おいしい",
        servings: Int = 2
    ) -> MealLogInput {
        MealLogInput(
            recipeID: RecipeID(recipeID),
            cookedAt: cookedAt,
            rating: rating,
            memo: memo,
            servings: servings
        )
    }

    // 追加するとidが採番され、cookedAtから注入Calendarで暦日キーが導出される
    func testMealLogAddDerivesDateKeyFromCalendar() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        // UTC 2026-01-01 15:00 → JSTでは 2026-01-02
        let cookedAt = try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15))
        )
        let created = try await repository.add(makeInput(cookedAt: cookedAt, rating: 4))

        XCTAssertEqual(created.dateKey.value, "2026-01-02")
        XCTAssertEqual(created.recipeID, RecipeID("recipe-01"))
        XCTAssertEqual(created.rating, 4)

        let listed = try await repository.summaries(for: DateKey(value: "2026-01-02"))
        XCTAssertEqual(listed.map(\.id), [created.id])
    }

    // 更新はidを維持しつつ内容を差し替える
    func testMealLogUpdateKeepsID() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let cookedAt = try XCTUnwrap(tokyoCalendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 19)))
        let created = try await repository.add(makeInput(cookedAt: cookedAt, rating: 3))

        let updated = try await repository.update(
            id: created.id,
            with: makeInput(recipeID: "recipe-02", cookedAt: cookedAt, rating: 5, memo: "最高", servings: 3)
        )
        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(updated.recipeID, RecipeID("recipe-02"))
        XCTAssertEqual(updated.rating, 5)
        XCTAssertEqual(updated.memo, "最高")

        let all = try await repository.allSummaries()
        XCTAssertEqual(all.count, 1)
    }

    // 削除するとその日の一覧から消える
    func testMealLogDelete() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let cookedAt = try XCTUnwrap(tokyoCalendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 19)))
        let created = try await repository.add(makeInput(cookedAt: cookedAt))

        try await repository.delete(id: created.id)

        let listed = try await repository.summaries(for: DateKey(value: "2026-05-03"))
        XCTAssertTrue(listed.isEmpty)
        let all = try await repository.allSummaries()
        XCTAssertTrue(all.isEmpty)
    }

    // 存在しないidの更新・削除はnotFoundを投げる
    func testMealLogUpdateAndDeleteMissingThrows() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let missingID = MealLogID()
        let cookedAt = Date()

        do {
            _ = try await repository.update(id: missingID, with: makeInput(cookedAt: cookedAt))
            XCTFail("notFoundが投げられるべき")
        } catch let error as MealLogRepositoryError {
            XCTAssertEqual(error, .notFound(missingID))
        }

        do {
            try await repository.delete(id: missingID)
            XCTFail("notFoundが投げられるべき")
        } catch let error as MealLogRepositoryError {
            XCTAssertEqual(error, .notFound(missingID))
        }
    }

    // 複数ログはcookedAt昇順で安定して返る
    func testMealLogSummariesSortedByCookedAt() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let day = DateComponents(year: 2026, month: 6, day: 2)
        let morning = try XCTUnwrap(tokyoCalendar.date(from: merge(day, hour: 8)))
        let night = try XCTUnwrap(tokyoCalendar.date(from: merge(day, hour: 20)))

        // あえて夜→朝の順で追加する
        _ = try await repository.add(makeInput(cookedAt: night, memo: "夜ごはん"))
        _ = try await repository.add(makeInput(cookedAt: morning, memo: "朝ごはん"))

        let listed = try await repository.summaries(for: DateKey(value: "2026-06-02"))
        XCTAssertEqual(listed.map(\.memo), ["朝ごはん", "夜ごはん"])
    }

    // DateComponentsに時刻を足すヘルパー
    private func merge(_ components: DateComponents, hour: Int) -> DateComponents {
        var result = components
        result.hour = hour
        return result
    }
}
