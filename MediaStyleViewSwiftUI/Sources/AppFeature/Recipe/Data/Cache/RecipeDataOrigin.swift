//
//  RecipeDataOrigin.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 取得したデータの「出所」を表す値型。UIがRemoteの最新データとキャッシュ(保存済み)データを
// 混同せず、保存日時や鮮度(Stale)を利用者へ提示するために使う。
//
// 設計方針:
//  - この情報はRecipe Domain(Recipe/DailyRecipeEntry)自体には持たせない
//    （Domainは出所を知らないべき。永続化/通信の関心を混ぜない）。
//  - 代わりにUseCaseの取得結果(Payload)やViewModelのStateへ添えて、表示層まで運ぶ。
//  - FixtureやキャッシュなしのRemote直取得は .remote（＝権威ある最新）として扱い、
//    追加のバナー等を出さず従来どおりの見た目を保つ。

import Foundation

enum RecipeDataOrigin: Sendable, Equatable {

    // サーバーから今回正常取得した最新データ（またはキャッシュ非対応構成＝Fixture等）
    case remote

    // 保存済みキャッシュから提供したデータ。fetchedAtは最終正常取得日時、isStaleは鮮度ポリシー上の失効。
    case cache(fetchedAt: Date, isStale: Bool)

    // キャッシュ由来か
    var isCache: Bool {
        if case .cache = self { return true }
        return false
    }

    // Stale（鮮度切れのキャッシュ）を表示中か
    var isStale: Bool {
        if case let .cache(_, isStale) = self { return isStale }
        return false
    }

    var fetchedAt: Date? {
        if case let .cache(fetchedAt, _) = self { return fetchedAt }
        return nil
    }

    // 2つの出所を束ねるときの合成（Timelineのように複数取得を1画面へまとめる場合）。
    // どちらかがキャッシュなら全体はキャッシュ扱い（最新と混同しない安全側）。保存日時は古い方、
    // Staleはどちらかが Stale なら Stale とする。
    static func combined(_ lhs: RecipeDataOrigin, _ rhs: RecipeDataOrigin) -> RecipeDataOrigin {
        switch (lhs, rhs) {
        case (.remote, .remote):
            return .remote
        default:
            let lhsDate = lhs.fetchedAt ?? .distantFuture
            let rhsDate = rhs.fetchedAt ?? .distantFuture
            let oldest = min(lhsDate, rhsDate)
            let fetchedAt = oldest == .distantFuture ? Date() : oldest
            return .cache(fetchedAt: fetchedAt, isStale: lhs.isStale || rhs.isStale)
        }
    }
}
