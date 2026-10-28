//
//  URLSessionHTTPClient.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// URLSession による HTTPClient の実装。送受信のみを行う。
//
// エラー方針:
//  - Task キャンセル由来の URLError(.cancelled) は CancellationError へ変換して伝搬する
//    （上位でサーバー障害と区別し、エラー表示にしないため）。
//  - それ以外の URLError/通信失敗はそのまま throw し、APIClient 側で型付きエラーへ変換する（握りつぶさない）。

import Foundation

struct URLSessionHTTPClient: HTTPClient {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)
            // HTTPURLResponse 以外（ステータスを取れない）は不正応答として扱う。
            guard let http = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }
            return HTTPResponse(statusCode: http.statusCode, body: data)
        } catch let urlError as URLError where urlError.code == .cancelled {
            // キャンセルはサーバー障害ではない。CancellationError として上位へ伝える。
            throw CancellationError()
        }
    }
}
