//
//  APIClient.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// 型付き API クライアント。Endpoint からの URL 生成・送信・Status 検証・JSON Decode・エラー変換を担う。
//
//  - HTTPClient(Protocol)越しに送受信する（テストで Fake 差し替え可能）。
//  - HTTP Status を APIClientError へ変換する（Status と失敗種別の対応を 1 箇所に集約）。
//  - Cancellation は CancellationError のまま伝搬し、サーバー障害と混同しない。
//  - JSON は camelCase のため keyDecodingStrategy は既定のまま（プロパティ名一致）。

import Foundation

struct APIClient: Sendable {

    private let configuration: APIConfiguration
    private let httpClient: any HTTPClient
    private let decoder: JSONDecoder

    init(configuration: APIConfiguration, httpClient: any HTTPClient) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.decoder = JSONDecoder() // Go 側 JSON は camelCase のため変換不要
    }

    // MARK: - Endpoints

    func recipeList(category: String?, limit: Int, offset: Int) async throws -> RecipeListResponseDTO {
        try await get(.recipeList(category: category, limit: limit, offset: offset), as: RecipeListResponseDTO.self)
    }

    func recipeDetail(id: String) async throws -> RecipeDetailDTO {
        try await get(.recipeDetail(id: id), as: RecipeDetailDTO.self)
    }

    func calendar(from: String, to: String) async throws -> CalendarResponseDTO {
        try await get(.calendar(from: from, to: to), as: CalendarResponseDTO.self)
    }

    // MARK: - Core

    private func get<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T {
        let request = try endpoint.makeRequest(configuration: configuration)

        let response: HTTPResponse
        do {
            response = try await httpClient.send(request)
        } catch is CancellationError {
            throw CancellationError() // キャンセルはそのまま伝搬（エラー表示にしない）
        } catch let apiError as APIClientError {
            throw apiError
        } catch let urlError as URLError {
            if urlError.code == .timedOut {
                throw APIClientError.timeout
            }
            throw APIClientError.network(message: urlError.localizedDescription)
        } catch {
            throw APIClientError.network(message: error.localizedDescription)
        }

        try validate(response)

        do {
            return try decoder.decode(T.self, from: response.body)
        } catch {
            throw APIClientError.decoding(message: String(describing: error))
        }
    }

    // HTTP Status を型付きエラーへ変換する。
    private func validate(_ response: HTTPResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 400:
            let body = parseError(response.body)
            throw APIClientError.badRequest(code: body?.code, message: body?.message)
        case 404:
            let body = parseError(response.body)
            throw APIClientError.notFound(code: body?.code, message: body?.message)
        case 500...599:
            let body = parseError(response.body)
            throw APIClientError.serverError(status: response.statusCode, code: body?.code, message: body?.message)
        default:
            throw APIClientError.unexpectedStatus(response.statusCode)
        }
    }

    // {"error":{"code","message"}} 形式を解釈（解釈不能なら nil）。
    private func parseError(_ data: Data) -> APIErrorBodyDTO? {
        try? decoder.decode(APIErrorResponseDTO.self, from: data).error
    }
}
