//
//  FakeHTTPClient.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Unit Test 用の HTTPClient 差し替え。実ネットワークへ出ずに固定レスポンス/任意の失敗を返す。
//
// Swift 6 の並行性に適合させる:
//  - 送信されたリクエストの記録は actor(RequestRecorder)に閉じ、共有可変状態を安全に扱う
//    （@unchecked Sendable や nonisolated(unsafe) は使わない）。
//  - レスポンス決定は @Sendable クロージャで行い、呼び出しごとの分岐(ページング等)を表現する。

@testable import AppFeature
import Foundation

// 送信されたリクエストを順に記録する（検証用）。
actor RequestRecorder {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }

    var count: Int { requests.count }
    var last: URLRequest? { requests.last }
}

struct FakeHTTPClient: HTTPClient {

    let recorder: RequestRecorder
    private let handler: @Sendable (URLRequest) async throws -> HTTPResponse

    init(
        recorder: RequestRecorder = RequestRecorder(),
        handler: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) {
        self.recorder = recorder
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        await recorder.record(request)
        return try await handler(request)
    }

    // MARK: - Convenience

    // 常に同じステータス/ボディを返す。
    static func responding(status: Int, json: String) -> FakeHTTPClient {
        FakeHTTPClient { _ in
            HTTPResponse(statusCode: status, body: Data(json.utf8))
        }
    }

    // 常に指定エラーで失敗する。
    static func failing(with error: Error) -> FakeHTTPClient {
        FakeHTTPClient { _ in throw error }
    }
}
