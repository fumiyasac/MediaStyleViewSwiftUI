//
//  RecipeCachePolicyTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// 鮮度ポリシーのテスト。固定日時で Fresh / Stale / Expired の境界を検証する（実時刻に依存しない）。

@testable import AppFeature
import Foundation
import Testing

@Suite("Recipe Cache Policy: 鮮度判定")
struct RecipeCachePolicyTests {

    private let policy = RecipeCachePolicy(freshFor: 24 * 60 * 60, maxAge: 30 * 24 * 60 * 60)
    private let base = CacheFixture.date(2026, 10, 30, 12)

    // 11. Freshと判定できる
    @Test("取得直後は Fresh")
    func freshWithinWindow() {
        let fetchedAt = base.addingTimeInterval(-60 * 60) // 1時間前
        #expect(policy.freshness(fetchedAt: fetchedAt, now: base) == .fresh)
    }

    // 12. 境界で安定（ちょうどfreshForはFresh側、超えた瞬間Stale）
    @Test("Fresh境界(24h)で判定が安定する")
    func freshBoundary() {
        let exactly = base.addingTimeInterval(-24 * 60 * 60)
        #expect(policy.freshness(fetchedAt: exactly, now: base) == .fresh)
        let justOver = base.addingTimeInterval(-24 * 60 * 60 - 1)
        #expect(policy.freshness(fetchedAt: justOver, now: base) == .stale)
    }

    // 11/12. Stale
    @Test("Fresh期間を超えると Stale")
    func staleAfterWindow() {
        let fetchedAt = base.addingTimeInterval(-3 * 24 * 60 * 60) // 3日前
        #expect(policy.freshness(fetchedAt: fetchedAt, now: base) == .stale)
    }

    // 13. 保持期限超過は Expired
    @Test("最大保持期間を超えると Expired")
    func expiredBeyondMaxAge() {
        let fetchedAt = base.addingTimeInterval(-31 * 24 * 60 * 60) // 31日前
        #expect(policy.freshness(fetchedAt: fetchedAt, now: base) == .expired)
    }

    @Test("maxAge境界(30日)で判定が安定する")
    func expiredBoundary() {
        let exactly = base.addingTimeInterval(-30 * 24 * 60 * 60)
        #expect(policy.freshness(fetchedAt: exactly, now: base) == .stale)
        let justOver = base.addingTimeInterval(-30 * 24 * 60 * 60 - 1)
        #expect(policy.freshness(fetchedAt: justOver, now: base) == .expired)
    }

    // 14. 不正な取得日時（未来）はFresh扱い（負の経過で誤判定しない）
    @Test("未来の取得日時はFresh扱い(負経過で誤判定しない)")
    func futureFetchedAtIsFresh() {
        let future = base.addingTimeInterval(60 * 60)
        #expect(policy.freshness(fetchedAt: future, now: base) == .fresh)
    }

    // 15. Clock(現在時刻)を固定して判定できる（上記すべてnowを注入）
    @Test("現在時刻を注入して判定できる")
    func injectedNow() {
        let fetchedAt = CacheFixture.date(2026, 1, 1, 12)
        let now = CacheFixture.date(2026, 1, 3, 12) // 48時間後 → Stale
        #expect(policy.freshness(fetchedAt: fetchedAt, now: now) == .stale)
    }
}
