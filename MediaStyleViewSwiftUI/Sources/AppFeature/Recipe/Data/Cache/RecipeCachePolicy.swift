//
//  RecipeCachePolicy.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// キャッシュの鮮度ポリシー。取得日時(fetchedAt)と現在時刻から Fresh / Stale / Expired を判定する。
//
// 設計方針:
//  - 閾値(Fresh期間・最大保持期間)は設定値として分離し、運用で調整できるようにする。
//  - 現在時刻は注入可能にし、テストが実日時に依存しない（固定Clockで境界を検証できる）。
//  - 判定境界は「freshFor を超えたら Stale」「maxAge を超えたら Expired」。
//    ちょうど境界値のときは Fresh/有効側に倒す（<= で判定）ことで境界近傍の揺れを避ける。

import Foundation

// MARK: - CacheFreshness

enum CacheFreshness: Sendable, Equatable {
    // 新鮮（そのまま最新相当として表示可）
    case fresh
    // 鮮度切れ（表示は許容するが「保存済み/要更新」であることを示す）
    case stale
    // 保持期限超過（既定では利用しない）
    case expired
}

// MARK: - RecipeCachePolicy

struct RecipeCachePolicy: Sendable {

    // Freshとみなす最大経過時間（既定24時間）
    let freshFor: TimeInterval
    // キャッシュとして保持する最大経過時間（既定30日）。超過は expired。
    let maxAge: TimeInterval

    init(
        freshFor: TimeInterval = 24 * 60 * 60,
        maxAge: TimeInterval = 30 * 24 * 60 * 60
    ) {
        self.freshFor = freshFor
        self.maxAge = maxAge
    }

    // 取得日時と現在時刻から鮮度を判定する。
    // fetchedAtが未来（端末時計のズレ等の不正値）の場合は、経過時間を0とみなしFresh扱いにする
    // （負の経過で誤ってExpired/Stale判定しないための安全側）。
    func freshness(fetchedAt: Date, now: Date) -> CacheFreshness {
        let age = now.timeIntervalSince(fetchedAt)
        if age <= freshFor {
            return .fresh
        } else if age <= maxAge {
            return .stale
        } else {
            return .expired
        }
    }

    var `default`: RecipeCachePolicy { self }

    static let standard = RecipeCachePolicy()
}
