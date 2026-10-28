//
//  RemoteRecipeRepositoryTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// RemoteRecipeRepository の Unit Test（Fake HTTPClient 使用・実 API 非依存）。
// Protocol 準拠の挙動（全ページ取得・404→nil・レンジ組み立て・エラー伝搬・キャンセル）を検証する。

@testable import AppFeature
import Foundation
import Testing

@Suite("RemoteRecipeRepository: Protocol 準拠の挙動")
struct RemoteRecipeRepositoryTests {

    private let configuration = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)

    private func makeRepository(
        recorder: RequestRecorder = RequestRecorder(),
        referenceDate: @escaping @Sendable () -> Date = { Date() },
        handler: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) -> RemoteRecipeRepository {
        RemoteRecipeRepository(
            apiClient: APIClient(
                configuration: configuration,
                httpClient: FakeHTTPClient(recorder: recorder, handler: handler)
            ),
            calendar: DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!),
            referenceDate: referenceDate
        )
    }

    // 指定件数のレシピ一覧 JSON を生成する（offset から連番 id を振る）。
    private func listPageJSON(offset: Int, count: Int, total: Int) -> String {
        let items = (0..<count).map { index -> String in
            let number = offset + index + 1
            return """
            {"id":"recipe-\(number)","title":"料理\(number)","summary":"説明","category":"japanese","cookingMinutes":20,"calories":300,"servings":2}
            """
        }.joined(separator: ",")
        return """
        {"items":[\(items)],"pagination":{"limit":100,"offset":\(offset),"total":\(total)}}
        """
    }

    // 21. allRecipes は 1 ページで収まる場合そのまま全件返す
    @Test("allRecipes: 単一ページを全件返す")
    func allRecipesSinglePage() async throws {
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 200, body: Data(self.listPageJSON(offset: 0, count: 3, total: 3).utf8))
        }

        let recipes = try await repository.allRecipes()
        #expect(recipes.count == 3)
        #expect(recipes.map(\.id.rawValue) == ["recipe-1", "recipe-2", "recipe-3"])
    }

    // 22. allRecipes は total に達するまで全ページを取得して連結する
    @Test("allRecipes: 複数ページを total まで取得して連結する")
    func allRecipesPaginates() async throws {
        let recorder = RequestRecorder()
        // total=250 を 100/100/50 の 3 ページで返す
        let repository = makeRepository(recorder: recorder) { request in
            let offset = Self.offsetQuery(of: request) ?? 0
            let remaining = max(0, 250 - offset)
            let count = min(100, remaining)
            return HTTPResponse(statusCode: 200, body: Data(self.listPageJSON(offset: offset, count: count, total: 250).utf8))
        }

        let recipes = try await repository.allRecipes()
        #expect(recipes.count == 250)
        #expect(await recorder.count == 3) // 100,100,50 の 3 回
        // 重複なく連番であること（先頭/末尾を確認）
        #expect(recipes.first?.id == RecipeID("recipe-1"))
        #expect(recipes.last?.id == RecipeID("recipe-250"))
    }

    // 23. allRecipes はサーバーエラーをそのまま伝搬する（Fixture へフォールバックしない）
    @Test("allRecipes: サーバーエラーを伝搬する（フォールバックしない）")
    func allRecipesPropagatesError() async {
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 500, body: Data("err".utf8))
        }

        await #expect(throws: APIClientError.self) {
            _ = try await repository.allRecipes()
        }
    }

    // 24. recipe(for:) は 200 で Recipe を返す
    @Test("recipe(for:): 存在する ID で Recipe を返す")
    func recipeFound() async throws {
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.recipeDetail01.utf8))
        }

        let recipe = try await repository.recipe(for: RecipeID("recipe-01"))
        #expect(recipe?.id == RecipeID("recipe-01"))
        #expect(recipe?.ingredients.isEmpty == false)
    }

    // 25. recipe(for:) は 404 を nil へ変換する（存在しないは正常系）
    @Test("recipe(for:): 404 は nil を返す")
    func recipeNotFoundReturnsNil() async throws {
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 404, body: Data(APIFixtureJSON.notFoundError.utf8))
        }

        let recipe = try await repository.recipe(for: RecipeID("not-exist"))
        #expect(recipe == nil)
    }

    // 26. recipe(for:) は 500 を伝搬する（404 以外はエラー）
    @Test("recipe(for:): 500 はエラーを伝搬する")
    func recipeServerErrorPropagates() async {
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 500, body: Data("err".utf8))
        }

        await #expect(throws: APIClientError.self) {
            _ = try await repository.recipe(for: RecipeID("recipe-01"))
        }
    }

    // 27. dailyEntries(for:) は from=to=当日で calendar を呼び、項目を変換する
    @Test("dailyEntries(for:): from=to=当日で取得して変換する")
    func dailyEntriesForDay() async throws {
        let recorder = RequestRecorder()
        let repository = makeRepository(recorder: recorder) { _ in
            HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.calendar.utf8))
        }

        let entries = try await repository.dailyEntries(for: DateKey(value: "2026-10-04"))

        // 送信 Query の from/to が当日一致であること
        let url = try #require(await recorder.last?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "from", value: "2026-10-04")))
        #expect(items.contains(URLQueryItem(name: "to", value: "2026-10-04")))
        // Fixture の 3 件が DailyRecipeEntry へ変換される
        #expect(entries.count == 3)
        #expect(entries.first?.recipeID == RecipeID("recipe-03"))
    }

    // 28. allDailyEntries は基準日 ±45 日(計 91 日)のレンジで calendar を呼ぶ
    @Test("allDailyEntries: 基準日 ±45 日のレンジで取得する")
    func allDailyEntriesWindow() async throws {
        let recorder = RequestRecorder()
        let tokyo = DateKeyCalendar.make(timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let base = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 15))!
        let repository = makeRepository(recorder: recorder, referenceDate: { base }) { _ in
            HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.calendar.utf8))
        }

        _ = try await repository.allDailyEntries()

        let url = try #require(await recorder.last?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        // 10/15 の ±45 日 = 08/31 〜 11/29
        #expect(items.contains(URLQueryItem(name: "from", value: "2026-08-31")))
        #expect(items.contains(URLQueryItem(name: "to", value: "2026-11-29")))
    }

    // 29. 変換不能(未知カテゴリ)のときは mapping エラーを伝搬する
    @Test("未知カテゴリを含む応答は mapping エラーを伝搬する")
    func mappingErrorPropagates() async {
        let json = #"{"items":[{"id":"r","title":"t","summary":"s","category":"UNKNOWN","cookingMinutes":1,"calories":1,"servings":1}],"pagination":{"limit":100,"offset":0,"total":1}}"#
        let repository = makeRepository { _ in
            HTTPResponse(statusCode: 200, body: Data(json.utf8))
        }

        await #expect {
            _ = try await repository.allRecipes()
        } throws: { error in
            if case APIClientError.mapping = error { return true }
            return false
        }
    }

    // 30. キャンセルは CancellationError として伝搬する（サーバー障害扱いにしない）
    @Test("キャンセルは CancellationError を伝搬する")
    func cancellationPropagates() async {
        let repository = makeRepository { _ in
            throw CancellationError()
        }

        await #expect(throws: CancellationError.self) {
            _ = try await repository.recipe(for: RecipeID("recipe-01"))
        }
    }

    // MARK: - Helpers

    private static func offsetQuery(of request: URLRequest) -> Int? {
        guard let url = request.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "offset" })?.value else {
            return nil
        }
        return Int(value)
    }
}
