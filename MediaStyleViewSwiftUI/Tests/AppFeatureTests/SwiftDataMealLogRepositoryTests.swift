//
//  SwiftDataMealLogRepositoryTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// SwiftDataMealLogRepositoryの永続化テスト。
// in-memoryストアでのCRUD/整合性と、一時ファイルを再オープンする永続化テストを明確に分ける。
// 本番データ(makePersistent)は使わない。

@testable import AppFeature
import Foundation
import SwiftData
import XCTest

final class SwiftDataMealLogRepositoryTests: XCTestCase {

    // 決定的に検証するためTimeZone固定Calendar
    private let tokyoCalendar = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)

    // MARK: - Helpers

    private func makeInMemoryRepository() throws -> SwiftDataMealLogRepository {
        let container = try MealLogModelContainerFactory.makeInMemory()
        return SwiftDataMealLogRepository(modelContainer: container)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        tokyoCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func input(
        recipe: String = "recipe-01",
        cookedAt: Date,
        rating: Int = 4,
        memo: String = "おいしい",
        servings: Int = 2
    ) -> MealLogInput {
        MealLogInput(
            recipeID: RecipeID(recipe),
            cookedAt: cookedAt,
            rating: rating,
            memo: memo,
            servings: servings
        )
    }

    // MARK: - CRUD

    // 1 & 11. 保存でき、Domain Model(MealLogSummary)へ正しく変換される
    func testAddSavesAndConvertsToSummary() async throws {
        let repository = try makeInMemoryRepository()
        // JSTで 2026-01-02 の日時
        let cookedAt = date(2026, 1, 2, 10)
        let created = try await repository.add(input(recipe: "recipe-03", cookedAt: cookedAt, rating: 5, memo: "最高", servings: 3))

        XCTAssertEqual(created.recipeID, RecipeID("recipe-03"))
        XCTAssertEqual(created.dateKey, DateKey(value: "2026-01-02"))
        XCTAssertEqual(created.cookedAt, cookedAt)
        XCTAssertEqual(created.rating, 5)
        XCTAssertEqual(created.memo, "最高")
        XCTAssertEqual(created.servings, 3)
    }

    // 2. 保存したMealLogを取得できる
    func testFetchSavedByID() async throws {
        let repository = try makeInMemoryRepository()
        let created = try await repository.add(input(cookedAt: date(2026, 3, 1)))

        let fetched = try await repository.summary(for: created.id)
        XCTAssertEqual(fetched, created)
    }

    // 3. 同一IDで更新しても重複レコードが作られない
    func testUpdateDoesNotCreateDuplicate() async throws {
        let repository = try makeInMemoryRepository()
        let created = try await repository.add(input(cookedAt: date(2026, 3, 1)))

        _ = try await repository.update(id: created.id, with: input(cookedAt: date(2026, 3, 1), rating: 2, memo: "普通"))

        let all = try await repository.allSummaries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, created.id)
    }

    // 4. 調理日・評価・メモを更新できる
    func testUpdateChangesFields() async throws {
        let repository = try makeInMemoryRepository()
        let created = try await repository.add(input(cookedAt: date(2026, 3, 1), rating: 3, memo: "初回"))

        let newCookedAt = date(2026, 3, 5, 20)
        let updated = try await repository.update(
            id: created.id,
            with: input(cookedAt: newCookedAt, rating: 5, memo: "改良した")
        )

        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(updated.cookedAt, newCookedAt)
        XCTAssertEqual(updated.dateKey, DateKey(value: "2026-03-05"))
        XCTAssertEqual(updated.rating, 5)
        XCTAssertEqual(updated.memo, "改良した")
    }

    // 5 & 6. 削除でき、削除後は取得できない
    func testDeleteRemovesRecord() async throws {
        let repository = try makeInMemoryRepository()
        let created = try await repository.add(input(cookedAt: date(2026, 3, 1)))

        try await repository.delete(id: created.id)

        let fetched = try await repository.summary(for: created.id)
        XCTAssertNil(fetched)
        let all = try await repository.allSummaries()
        XCTAssertTrue(all.isEmpty)
    }

    // 存在しないIDの更新・削除はnotFound
    func testUpdateAndDeleteMissingThrows() async throws {
        let repository = try makeInMemoryRepository()
        let missing = MealLogID()

        do {
            _ = try await repository.update(id: missing, with: input(cookedAt: date(2026, 3, 1)))
            XCTFail("notFoundが投げられるべき")
        } catch let error as MealLogRepositoryError {
            XCTAssertEqual(error, .notFound(missing))
        }
        do {
            try await repository.delete(id: missing)
            XCTFail("notFoundが投げられるべき")
        } catch let error as MealLogRepositoryError {
            XCTAssertEqual(error, .notFound(missing))
        }
    }

    // MARK: - データ整合性

    // 7. 同一レシピを異なる日に複数回保存できる
    func testSameRecipeOnDifferentDays() async throws {
        let repository = try makeInMemoryRepository()
        _ = try await repository.add(input(recipe: "recipe-01", cookedAt: date(2026, 3, 1)))
        _ = try await repository.add(input(recipe: "recipe-01", cookedAt: date(2026, 3, 8)))

        let all = try await repository.allSummaries()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.recipeID)), [RecipeID("recipe-01")])
        XCTAssertEqual(Set(all.map(\.dateKey)), [DateKey(value: "2026-03-01"), DateKey(value: "2026-03-08")])
    }

    // 8. 同一日に複数の調理ログを保存できる
    func testMultipleLogsOnSameDay() async throws {
        let repository = try makeInMemoryRepository()
        _ = try await repository.add(input(recipe: "recipe-01", cookedAt: date(2026, 3, 1, 8), memo: "朝"))
        _ = try await repository.add(input(recipe: "recipe-05", cookedAt: date(2026, 3, 1, 20), memo: "夜"))

        let sameDay = try await repository.summaries(for: DateKey(value: "2026-03-01"))
        XCTAssertEqual(sameDay.count, 2)
        // cookedAt昇順で返る
        XCTAssertEqual(sameDay.map(\.memo), ["朝", "夜"])
    }

    // 9. 指定期間内のデータだけ取得できる
    func testSummariesInRange() async throws {
        let repository = try makeInMemoryRepository()
        _ = try await repository.add(input(cookedAt: date(2026, 2, 28)))
        _ = try await repository.add(input(cookedAt: date(2026, 3, 1)))
        _ = try await repository.add(input(cookedAt: date(2026, 3, 15)))
        _ = try await repository.add(input(cookedAt: date(2026, 4, 1)))

        let range = DateKey(value: "2026-03-01")...DateKey(value: "2026-03-31")
        let inMarch = try await repository.summaries(in: range)

        XCTAssertEqual(inMarch.map(\.dateKey), [DateKey(value: "2026-03-01"), DateKey(value: "2026-03-15")])
    }

    // 10. 不正なrating(範囲外)は保存できない
    func testInvalidRatingIsRejected() async throws {
        let repository = try makeInMemoryRepository()

        for invalid in [0, 6, -1] {
            do {
                _ = try await repository.add(input(cookedAt: date(2026, 3, 1), rating: invalid))
                XCTFail("rating=\(invalid) は拒否されるべき")
            } catch let error as MealLogValidationError {
                XCTAssertEqual(error, .ratingOutOfRange(invalid))
            }
        }
        // 何も保存されていない
        let all = try await repository.allSummaries()
        XCTAssertTrue(all.isEmpty)
    }

    // 空のrecipeIDも拒否される
    func testEmptyRecipeIDIsRejected() async throws {
        let repository = try makeInMemoryRepository()
        do {
            _ = try await repository.add(input(recipe: "   ", cookedAt: date(2026, 3, 1)))
            XCTFail("空のrecipeIDは拒否されるべき")
        } catch let error as MealLogValidationError {
            XCTAssertEqual(error, .emptyRecipeID)
        }
    }

    // MARK: - 永続化・Actor Isolation

    // 12. in-memory ModelContainerでCRUDが動作する（代表の往復を確認）
    func testInMemoryContainerCRUD() async throws {
        let repository = try makeInMemoryRepository()
        let created = try await repository.add(input(cookedAt: date(2026, 3, 1)))
        let afterAdd = try await repository.summary(for: created.id)
        XCTAssertNotNil(afterAdd)
        try await repository.delete(id: created.id)
        let afterDelete = try await repository.summary(for: created.id)
        XCTAssertNil(afterDelete)
    }

    // 13. 同じModelContainerから新しいRepositoryを作成しても保存内容を取得できる
    func testNewRepositoryOnSameContainerSeesData() async throws {
        let container = try MealLogModelContainerFactory.makeInMemory()
        let repository1 = SwiftDataMealLogRepository(modelContainer: container)
        let created = try await repository1.add(input(cookedAt: date(2026, 3, 1)))

        let repository2 = SwiftDataMealLogRepository(modelContainer: container)
        let fetched = try await repository2.summary(for: created.id)
        XCTAssertEqual(fetched?.id, created.id)
    }

    // 14. 一時ファイルの永続ストアを再オープンしても保存内容が残っている
    func testPersistAcrossReopenWithFileStore() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mealLog-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }

        let savedID: MealLogID
        do {
            // 1つ目のContainerで保存してからスコープを抜けて解放する
            let container1 = try MealLogModelContainerFactory.make(url: url)
            let repository1 = SwiftDataMealLogRepository(modelContainer: container1)
            savedID = try await repository1.add(input(cookedAt: date(2026, 3, 1))).id
        }

        // 同じURLで再オープンした別Containerから取得できる
        let container2 = try MealLogModelContainerFactory.make(url: url)
        let repository2 = SwiftDataMealLogRepository(modelContainer: container2)
        let fetched = try await repository2.summary(for: savedID)
        XCTAssertEqual(fetched?.id, savedID)
    }

    // 15. 複数の非同期処理から同時に使っても不正なデータ競合が起きない（actor隔離で直列化）
    func testConcurrentAddsAreSerialized() async throws {
        let repository = try makeInMemoryRepository()
        let count = 50
        // self(非Sendable)を並行クロージャへ捕捉しないよう、入力は事前に生成しておく
        let inputs = (0..<count).map { index in
            input(cookedAt: date(2026, 3, 1, 0), rating: (index % 5) + 1)
        }

        await withTaskGroup(of: Void.self) { group in
            for log in inputs {
                group.addTask {
                    // Sendableなrepository(actor)とlog(値型)だけを捕捉する
                    _ = try? await repository.add(log)
                }
            }
        }

        let all = try await repository.allSummaries()
        XCTAssertEqual(all.count, count)
    }
}
