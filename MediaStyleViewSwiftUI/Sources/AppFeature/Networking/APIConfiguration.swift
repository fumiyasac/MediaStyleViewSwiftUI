//
//  APIConfiguration.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// API 接続先の設定。Base URL をコードへ直接埋め込まず、値型として注入可能にする。
//
// なぜ分離するか:
//  - Debug(ローカルDocker) / Test(Fake) / 将来の Release で接続先を切り替えられるようにするため。
//  - Simulator は Mac の localhost へ到達できるが、実機は Mac の LAN アドレスが必要になるなど、
//    接続先は実行環境で変わる。Release 構成へローカル用 URL を混入させないよう、生成責務を 1 箇所に集約する。
//
// 本 PR ではアプリの標準取得元を Remote へ切り替えないため、この設定は「選択されたときのみ」使われる。

import Foundation

struct APIConfiguration: Sendable {

    // API のベース URL（例: http://localhost:8080）
    let baseURL: URL
    // リクエストのタイムアウト秒
    let timeout: TimeInterval

    init(baseURL: URL, timeout: TimeInterval = 15) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    // ローカル開発(Docker Compose)向けの既定。Simulator から Mac の localhost:8080 へ到達する想定。
    // 実機や Release では別途適切な接続先を注入すること（ここに本番 URL を書かない）。
    static let localDevelopment = APIConfiguration(
        baseURL: URL(string: "http://localhost:8080")!
    )
}
