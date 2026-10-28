//
//  APIEndpoint.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Go API の各エンドポイント定義と URLRequest 生成。
//
// URL 組み立ては URLComponents を使う（Query の％エンコードを正しく行い、文字列連結の事故を防ぐため）。
// パス・Query 名は PR #18 の実装/Swagger に一致させる:
//   GET /api/v1/recipes?category&limit&offset
//   GET /api/v1/recipes/{id}
//   GET /api/v1/calendar?from&to

import Foundation

enum APIEndpoint: Sendable {
    case recipeList(category: String?, limit: Int, offset: Int)
    case recipeDetail(id: String)
    case calendar(from: String, to: String)

    // 共通プレフィックス
    private static let apiPrefix = "/api/v1"

    // baseURL と設定から URLRequest を組み立てる。組み立て失敗は APIClientError.invalidURL。
    func makeRequest(configuration: APIConfiguration) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURL
        }

        switch self {
        case let .recipeList(category, limit, offset):
            components.path += "\(Self.apiPrefix)/recipes"
            var queries = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
            ]
            if let category {
                queries.append(URLQueryItem(name: "category", value: category))
            }
            components.queryItems = queries

        case let .recipeDetail(id):
            // パス成分として安全に連結（id は Query ではなく Path）。
            components.path += "\(Self.apiPrefix)/recipes/\(id)"

        case let .calendar(from, to):
            components.path += "\(Self.apiPrefix)/calendar"
            components.queryItems = [
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to),
            ]
        }

        guard let url = components.url else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
