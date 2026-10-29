//
//  OfflineCacheBanner.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 保存済み(キャッシュ)データを表示中であることを利用者へ伝える共通バナー。
//
// なぜUIへ取得元を出すか:
//  - キャッシュ(保存済み)とサーバーの最新データを混同させないため。保存日時と「要更新(Stale)」を提示し、
//    利用者が鮮度を判断できるようにする。
//  - 取得元が .remote（最新 or Fixture/キャッシュ非対応構成）のときは何も描画しない。
//    これにより従来画面・Snapshotの見た目を変えない（オフライン時だけ現れる付加情報）。

import SwiftUI

struct OfflineCacheBanner: View {

    let origin: RecipeDataOrigin?

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    var body: some View {
        if let origin, case let .cache(fetchedAt, isStale) = origin {
            HStack(spacing: 8) {
                Image(systemName: isStale ? "clock.badge.exclamationmark" : "wifi.slash")
                    .font(.footnote)
                Text(messageText(fetchedAt: fetchedAt, isStale: isStale))
                    .font(.footnote)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .accessibilityElement(children: .combine)
        }
    }

    private func messageText(fetchedAt: Date, isStale: Bool) -> String {
        let saved = Self.formatter.string(from: fetchedAt)
        if isStale {
            return "保存済みデータを表示中（\(saved)取得・要更新）"
        }
        return "保存済みデータを表示中（\(saved)取得）"
    }
}
