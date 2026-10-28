//
//  APIClientError.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// API 通信・変換で起こり得る失敗を型で区別する。
//
// HTTP Status と Domain の対応を明確にし、呼び出し側(Repository/UseCase)が原因に応じて扱えるようにする。
// Cancellation は「サーバー障害」ではないため本型に含めず、CancellationError をそのまま伝搬させる
// （既存 ViewModel が CancellationError をエラー表示しない設計と整合させる）。

import Foundation

enum APIClientError: Error, Sendable, Equatable {
    // URL/URLRequest を組み立てられなかった
    case invalidURL
    // 接続失敗など URLSession の通信エラー（キャンセル以外）
    case network(message: String)
    // タイムアウト
    case timeout
    // HTTPURLResponse ではない / ステータスが取得できない等
    case invalidResponse
    // 400
    case badRequest(code: String?, message: String?)
    // 404
    case notFound(code: String?, message: String?)
    // 500 系
    case serverError(status: Int, code: String?, message: String?)
    // 想定外のステータス
    case unexpectedStatus(Int)
    // JSON デコード失敗
    case decoding(message: String)
    // DTO → Domain 変換失敗（不正カテゴリ・必須欠損・不正日付など）
    case mapping(message: String)
}
