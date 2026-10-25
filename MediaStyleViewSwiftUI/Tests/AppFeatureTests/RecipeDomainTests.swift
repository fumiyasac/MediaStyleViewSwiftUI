//
//  RecipeDomainTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Recipe Domain + Fixture Repository（PR1）のテスト。
// 日付キーのTimeZone影響、Fixtureの件数・複数日掲載、調理ログのCRUDを検証する。
// Swift Testing へ移行済み。Repositoryはテストごとに生成し共有状態を持たない。

@testable import AppFeature
import Foundation
import Testing

// テスト用のTimeZone固定Calendar（決定的に検証するため）。immutableなSendable値。
private let tokyoCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
private let utcCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "UTC")!)

// MARK: - DateKey

@Suite("DateKey（暦日キー）")
struct DateKeyTests {

    @Test("日付成分をゼロ埋めしたyyyy-MM-ddで生成される")
    func dateKeyFormat() throws {
        let date = try #require(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 5)))
        #expect(DateKey(date: date, calendar: tokyoCalendar).value == "2026-03-05")
    }

    @Test("同じ絶対時刻でもTimeZoneが違えば属する暦日キーが変わる")
    func dateKeyDependsOnTimeZone() throws {
        // UTCで 2026-01-01 15:00 の瞬間（JSTでは 2026-01-02 00:00）
        let instant = try #require(
            utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15))
        )
        #expect(DateKey(date: instant, calendar: utcCalendar).value == "2026-01-01")
        #expect(DateKey(date: instant, calendar: tokyoCalendar).value == "2026-01-02")
    }

    @Test("文字列の辞書順と日付順が一致する")
    func dateKeyComparable() {
        #expect(DateKey(value: "2026-01-01") < DateKey(value: "2026-01-02"))
        #expect(DateKey(value: "2025-12-31") < DateKey(value: "2026-01-01"))
    }
}

// MARK: - FixtureRecipeRepository

@Suite("FixtureRecipeRepository")
struct FixtureRecipeRepositoryTests {

    @Test("レシピMasterは24件返る")
    func fixtureHasTwentyFourRecipes() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipes = try await repository.allRecipes()
        #expect(recipes.count == 24)
    }

    @Test("IDでMasterを引ける。存在しないIDはnil")
    func fixtureRecipeLookupByID() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipe = try await repository.recipe(for: RecipeID("recipe-01"))
        #expect(recipe?.title == "鮭の塩麹焼き")
        let missing = try await repository.recipe(for: RecipeID("recipe-xx"))
        #expect(missing == nil)
    }

    @Test("日別割当は基準日±15日の31件。基準日のキーには1件割り当たる")
    func fixtureDailyEntriesCountAndReferenceDay() async throws {
        let reference = try #require(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15)))
        let repository = FixtureRecipeRepository(referenceDate: reference, calendar: tokyoCalendar)

        let all = try await repository.allDailyEntries()
        #expect(all.count == 31)

        let todays = try await repository.dailyEntries(for: DateKey(value: "2026-03-15"))
        #expect(todays.count == 1)

        // 割当の無い日は空配列
        let empty = try await repository.dailyEntries(for: DateKey(value: "1999-01-01"))
        #expect(empty.isEmpty)
    }

    @Test("同じレシピが複数日に掲載される（12件を31日に循環割り当て）")
    func fixtureAllowsSameRecipeOnMultipleDays() async throws {
        let reference = try #require(tokyoCalendar.date(from: DateComponents(year: 2026, month: 3, day: 15)))
        let repository = FixtureRecipeRepository(referenceDate: reference, calendar: tokyoCalendar)

        let all = try await repository.allDailyEntries()
        let countByRecipe = Dictionary(grouping: all, by: \.recipeID).mapValues(\.count)
        let maxCount = countByRecipe.values.max() ?? 0
        #expect(maxCount >= 2)
    }

    @Test("日別割当が参照するレシピIDはすべてMasterに存在する（参照整合性）")
    func fixtureEntriesReferenceExistingRecipes() async throws {
        let repository = FixtureRecipeRepository(referenceDate: Date(), calendar: tokyoCalendar)
        let recipeIDs = Set(try await repository.allRecipes().map(\.id))
        let entries = try await repository.allDailyEntries()
        for entry in entries {
            #expect(recipeIDs.contains(entry.recipeID))
        }
    }
}

// MARK: - InMemoryMealLogRepository

@Suite("InMemoryMealLogRepository")
struct InMemoryMealLogRepositoryTests {

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

    // DateComponentsに時刻を足すヘルパー
    private func merge(_ components: DateComponents, hour: Int) -> DateComponents {
        var result = components
        result.hour = hour
        return result
    }

    // 追加するとidが採番され、cookedAtから注入Calendarで暦日キーが導出される
    @Test("追加でidが採番されcookedAtから暦日キーが導出される")
    func mealLogAddDerivesDateKeyFromCalendar() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        // UTC 2026-01-01 15:00 → JSTでは 2026-01-02
        let cookedAt = try #require(
            utcCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 15))
        )
        let created = try await repository.add(makeInput(cookedAt: cookedAt, rating: 4))

        #expect(created.dateKey.value == "2026-01-02")
        #expect(created.recipeID == RecipeID("recipe-01"))
        #expect(created.rating == 4)

        let listed = try await repository.summaries(for: DateKey(value: "2026-01-02"))
        #expect(listed.map(\.id) == [created.id])
    }

    // 更新はidを維持しつつ内容を差し替える
    @Test("更新はidを維持しつつ内容を差し替える")
    func mealLogUpdateKeepsID() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let cookedAt = try #require(tokyoCalendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 19)))
        let created = try await repository.add(makeInput(cookedAt: cookedAt, rating: 3))

        let updated = try await repository.update(
            id: created.id,
            with: makeInput(recipeID: "recipe-02", cookedAt: cookedAt, rating: 5, memo: "最高", servings: 3)
        )
        #expect(updated.id == created.id)
        #expect(updated.recipeID == RecipeID("recipe-02"))
        #expect(updated.rating == 5)
        #expect(updated.memo == "最高")

        let all = try await repository.allSummaries()
        #expect(all.count == 1)
    }

    // 削除するとその日の一覧から消える
    @Test("削除するとその日の一覧から消える")
    func mealLogDelete() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let cookedAt = try #require(tokyoCalendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 19)))
        let created = try await repository.add(makeInput(cookedAt: cookedAt))

        try await repository.delete(id: created.id)

        let listed = try await repository.summaries(for: DateKey(value: "2026-05-03"))
        #expect(listed.isEmpty)
        let all = try await repository.allSummaries()
        #expect(all.isEmpty)
    }

    // 存在しないidの更新・削除はnotFoundを投げる
    @Test("存在しないidの更新・削除はnotFoundを投げる")
    func mealLogUpdateAndDeleteMissingThrows() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let missingID = MealLogID()
        let cookedAt = Date()

        await #expect(throws: MealLogRepositoryError.notFound(missingID)) {
            _ = try await repository.update(id: missingID, with: makeInput(cookedAt: cookedAt))
        }
        await #expect(throws: MealLogRepositoryError.notFound(missingID)) {
            try await repository.delete(id: missingID)
        }
    }

    // 複数ログはcookedAt昇順で安定して返る
    @Test("複数ログはcookedAt昇順で安定して返る")
    func mealLogSummariesSortedByCookedAt() async throws {
        let repository = InMemoryMealLogRepository(calendar: tokyoCalendar)
        let day = DateComponents(year: 2026, month: 6, day: 2)
        let morning = try #require(tokyoCalendar.date(from: merge(day, hour: 8)))
        let night = try #require(tokyoCalendar.date(from: merge(day, hour: 20)))

        // あえて夜→朝の順で追加する
        _ = try await repository.add(makeInput(cookedAt: night, memo: "夜ごはん"))
        _ = try await repository.add(makeInput(cookedAt: morning, memo: "朝ごはん"))

        let listed = try await repository.summaries(for: DateKey(value: "2026-06-02"))
        #expect(listed.map(\.memo) == ["朝ごはん", "夜ごはん"])
    }
}
