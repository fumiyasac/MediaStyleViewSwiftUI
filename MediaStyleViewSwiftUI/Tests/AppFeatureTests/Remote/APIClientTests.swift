//
//  APIClientTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// APIClient の Unit Test（Fake HTTPClient 使用・実 API 非依存）。
// URL 組み立て / ステータス→型付きエラー変換 / Decode / キャンセル伝搬を検証する。

@testable import AppFeature
import Foundation
import Testing

@Suite("APIClient: リクエスト生成とレスポンス変換")
struct APIClientTests {

    private let configuration = APIConfiguration(baseURL: URL(string: "http://localhost:8080")!)

    // 1. recipeList が /api/v1/recipes へ limit/offset 付き GET を組み立てる
    @Test("recipeList は limit/offset を Query に付与した GET を送る")
    func recipeListBuildsRequest() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient(recorder: recorder) { _ in
                HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.recipeListLimit2.utf8))
            }
        )

        _ = try await client.recipeList(category: nil, limit: 2, offset: 0)

        let request = try #require(await recorder.last)
        #expect(request.httpMethod == "GET")
        let url = try #require(request.url)
        #expect(url.path == "/api/v1/recipes")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "limit", value: "2")))
        #expect(items.contains(URLQueryItem(name: "offset", value: "0")))
        // category=nil のときは付与しない
        #expect(!items.contains { $0.name == "category" })
    }

    // 2. category 指定時は Query に category が付く
    @Test("recipeList は category 指定時に Query へ含める")
    func recipeListIncludesCategory() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient(recorder: recorder) { _ in
                HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.recipeListLimit2.utf8))
            }
        )

        _ = try await client.recipeList(category: "japanese", limit: 10, offset: 5)

        let url = try #require(await recorder.last?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "category", value: "japanese")))
        #expect(items.contains(URLQueryItem(name: "offset", value: "5")))
    }

    // 3. recipeDetail は /api/v1/recipes/{id} を組み立てる
    @Test("recipeDetail は id を Path に含む GET を送る")
    func recipeDetailBuildsRequest() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient(recorder: recorder) { _ in
                HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.recipeDetail01.utf8))
            }
        )

        _ = try await client.recipeDetail(id: "recipe-01")

        let url = try #require(await recorder.last?.url)
        #expect(url.path == "/api/v1/recipes/recipe-01")
    }

    // 4. calendar は from/to を Query に付与する
    @Test("calendar は from/to を Query に付与した GET を送る")
    func calendarBuildsRequest() async throws {
        let recorder = RequestRecorder()
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient(recorder: recorder) { _ in
                HTTPResponse(statusCode: 200, body: Data(APIFixtureJSON.calendar.utf8))
            }
        )

        _ = try await client.calendar(from: "2026-10-03", to: "2026-10-04")

        let url = try #require(await recorder.last?.url)
        #expect(url.path == "/api/v1/calendar")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "from", value: "2026-10-03")))
        #expect(items.contains(URLQueryItem(name: "to", value: "2026-10-04")))
    }

    // 5. 200 の一覧レスポンスを DTO へ Decode できる
    @Test("200 応答を RecipeListResponseDTO へ Decode する")
    func decodesRecipeList() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.responding(status: 200, json: APIFixtureJSON.recipeListLimit2)
        )

        let dto = try await client.recipeList(category: nil, limit: 2, offset: 0)

        #expect(dto.items.count == 2)
        #expect(dto.items.first?.id == "recipe-01")
        #expect(dto.pagination.total == 24)
    }

    // 6. 400 は badRequest（error ボディの code/message を取り出す）
    @Test("400 応答は badRequest に変換する")
    func mapsBadRequest() async throws {
        let body = #"{"error":{"code":"INVALID_RANGE","message":"range too wide"}}"#
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.responding(status: 400, json: body)
        )

        await #expect(throws: APIClientError.badRequest(code: "INVALID_RANGE", message: "range too wide")) {
            _ = try await client.calendar(from: "2000-01-01", to: "2030-01-01")
        }
    }

    // 7. 404 は notFound に変換する
    @Test("404 応答は notFound に変換する")
    func mapsNotFound() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.responding(status: 404, json: APIFixtureJSON.notFoundError)
        )

        await #expect(throws: APIClientError.notFound(code: "RECIPE_NOT_FOUND", message: "Recipe was not found.")) {
            _ = try await client.recipeDetail(id: "not-exist")
        }
    }

    // 8. 500 は serverError に変換する（ボディが解釈不能でも status を保持）
    @Test("500 応答は serverError に変換する")
    func mapsServerError() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.responding(status: 500, json: "internal error")
        )

        await #expect(throws: APIClientError.serverError(status: 500, code: nil, message: nil)) {
            _ = try await client.recipeDetail(id: "recipe-01")
        }
    }

    // 9. 壊れた JSON は decoding エラーになる
    @Test("不正 JSON は decoding エラーに変換する")
    func mapsDecodingError() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.responding(status: 200, json: "{ not json")
        )

        await #expect {
            _ = try await client.recipeList(category: nil, limit: 2, offset: 0)
        } throws: { error in
            if case APIClientError.decoding = error { return true }
            return false
        }
    }

    // 10. HTTPClient が CancellationError を投げたら APIClient も CancellationError を伝搬する
    @Test("キャンセルは CancellationError のまま伝搬する")
    func propagatesCancellation() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.failing(with: CancellationError())
        )

        await #expect(throws: CancellationError.self) {
            _ = try await client.recipeDetail(id: "recipe-01")
        }
    }

    // 補足. タイムアウト(URLError.timedOut)は timeout に変換する
    @Test("URLError.timedOut は timeout に変換する")
    func mapsTimeout() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.failing(with: URLError(.timedOut))
        )

        await #expect(throws: APIClientError.timeout) {
            _ = try await client.recipeList(category: nil, limit: 2, offset: 0)
        }
    }

    // 補足. 一般的な URLError は network に変換する
    @Test("接続不能(URLError)は network に変換する")
    func mapsNetworkError() async throws {
        let client = APIClient(
            configuration: configuration,
            httpClient: FakeHTTPClient.failing(with: URLError(.cannotConnectToHost))
        )

        await #expect {
            _ = try await client.recipeList(category: nil, limit: 2, offset: 0)
        } throws: { error in
            if case APIClientError.network = error { return true }
            return false
        }
    }
}
