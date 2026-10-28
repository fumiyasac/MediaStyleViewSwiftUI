//
//  HTTPClient.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// 低レベルの HTTP 送受信だけを担う境界。
//
// なぜ Protocol 化するか:
//  - APIClient / RemoteRepository をテストする際、実ネットワークへ出ずに固定レスポンスを返す Fake へ
//    差し替えられるようにするため（Unit Test で実 API を使わない）。
//  - URLSession を上位から隠し、将来 URLSession 以外へ替えても上位へ影響させないため。
//
// 責務はリクエスト送信とレスポンス受信に限定し、JSON Decode や Domain 変換は行わない。

import Foundation

// HTTP レスポンスの最小表現（ステータスとボディのみ。Domain へは渡さない）。
struct HTTPResponse: Sendable {
    let statusCode: Int
    let body: Data
}

protocol HTTPClient: Sendable {
    // リクエストを送って応答を返す。通信失敗/キャンセルは throw で伝搬する（握りつぶさない）。
    func send(_ request: URLRequest) async throws -> HTTPResponse
}
