//
//  RecipeTransitionSourceIDTests.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/26.
//

// Zoom遷移の遷移元識別子(RecipeTransitionSourceID)とNavigation Route構築の純粋ロジックを検証する。
// アニメーション描画は保証できないためSimulator手動確認と併用する（本テストは値の一意性/安定性/Route構築のみ）。

@testable import AppFeature
import Foundation
import Testing

@Suite("Recipe Zoom遷移のSource IdentityとRoute構築")
struct RecipeTransitionSourceIDTests {

    private func entry(
        id: String,
        recipe: String,
        kind: TimelineEntryKind = .recipe,
        dayKey: String = "2026-03-10"
    ) -> TimelineEntryViewData {
        TimelineEntryViewData(
            id: id,
            dayKey: DateKey(value: dayKey),
            kind: kind,
            recipeID: RecipeID(recipe),
            title: "タイトル",
            subtitle: nil,
            rating: nil,
            recipeMissing: false,
            searchableText: "たいとる"
        )
    }

    // MARK: - Source ID

    // 1. 同じ掲載項目から生成するSource IDは同じになる
    @Test("同じ掲載項目から生成するSource IDは同じ")
    func sameEntrySameID() {
        let e = entry(id: "recipe-daily-2026-03-10-r1", recipe: "recipe-01")
        #expect(RecipeTransitionSourceID.timeline(entry: e) == RecipeTransitionSourceID.timeline(entry: e))
    }

    // 2. 同じRecipeでも異なる掲載項目ならSource IDが異なる（複数日掲載の区別）
    @Test("同じRecipeでも異なる掲載項目ならSource IDが異なる")
    func sameRecipeDifferentEntriesDiffer() {
        let a = entry(id: "recipe-daily-2026-03-10-r1", recipe: "recipe-01", dayKey: "2026-03-10")
        let b = entry(id: "recipe-daily-2026-03-20-r1", recipe: "recipe-01", dayKey: "2026-03-20")
        #expect(RecipeTransitionSourceID.timeline(entry: a) != RecipeTransitionSourceID.timeline(entry: b))
    }

    // 3. CalendarとTimelineではSource IDを区別できる
    @Test("CalendarとTimelineでSource IDを区別できる")
    func calendarAndTimelineDiffer() {
        let e = entry(id: "recipe-daily-2026-03-10-r1", recipe: "recipe-01", dayKey: "2026-03-10")
        let timeline = RecipeTransitionSourceID.timeline(entry: e)
        let calendar = RecipeTransitionSourceID.calendar(recipeID: RecipeID("recipe-01"), dayKey: DateKey(value: "2026-03-10"))
        #expect(timeline != calendar)
        #expect(timeline.origin == .timeline)
        #expect(calendar.origin == .calendar)
    }

    // 4. Source IDはView再描画（同一入力の再生成）で変化しない＝決定的
    @Test("Source IDは再生成で変化しない（決定的）")
    func deterministicAcrossRecreation() {
        let id1 = RecipeTransitionSourceID.calendar(recipeID: RecipeID("recipe-05"), dayKey: DateKey(value: "2026-04-02"))
        let id2 = RecipeTransitionSourceID.calendar(recipeID: RecipeID("recipe-05"), dayKey: DateKey(value: "2026-04-02"))
        #expect(id1 == id2)
        #expect(id1.hashValue == id2.hashValue)
    }

    // 5. 異なるRecipeが同じSource IDにならない
    @Test("異なるRecipeが同じSource IDにならない")
    func differentRecipesDiffer() {
        let a = RecipeTransitionSourceID.calendar(recipeID: RecipeID("recipe-01"), dayKey: DateKey(value: "2026-03-10"))
        let b = RecipeTransitionSourceID.calendar(recipeID: RecipeID("recipe-02"), dayKey: DateKey(value: "2026-03-10"))
        #expect(a != b)
    }

    // MARK: - Navigation Route

    // 6. 正しいRecipe IDでRouteを構築できる
    @Test("正しいRecipe IDでRouteを構築できる")
    func buildRouteWithRecipeID() {
        let route = CalendarRoute.recipeDetail(recipeID: RecipeID("recipe-03"), publicationDayKey: nil, sourceID: nil)
        guard case let .recipeDetail(recipeID, _, _) = route else {
            Issue.record("recipeDetailであるべき")
            return
        }
        #expect(recipeID == RecipeID("recipe-03"))
    }

    // 7. 掲載日のContextを必要に応じて保持できる
    @Test("掲載日のContextを保持できる")
    func routeKeepsPublicationDayKey() {
        let dayKey = DateKey(value: "2026-03-10")
        let route = CalendarRoute.recipeDetail(recipeID: RecipeID("recipe-03"), publicationDayKey: dayKey, sourceID: nil)
        guard case let .recipeDetail(_, publicationDayKey, _) = route else {
            Issue.record("recipeDetailであるべき")
            return
        }
        #expect(publicationDayKey == dayKey)
    }

    // 8. Sourceがない場合（Deep Link/Calendar直接遷移）でもRecipe DetailのRouteを構築できる
    @Test("Sourceが無くてもRouteを構築できる（フォールバック）")
    func routeBuildableWithoutSource() {
        let route = CalendarRoute.recipeDetail(recipeID: RecipeID("recipe-07"), publicationDayKey: nil, sourceID: nil)
        guard case let .recipeDetail(_, _, sourceID) = route else {
            Issue.record("recipeDetailであるべき")
            return
        }
        #expect(sourceID == nil)
    }

    // 9. 同じRecipeの複数掲載に対応できる（異なるsourceIDのRouteは別物）
    @Test("同じRecipeの複数掲載で別Routeになる")
    func multiplePublicationsDistinctRoutes() {
        let a = entry(id: "recipe-daily-2026-03-10-r1", recipe: "recipe-01", dayKey: "2026-03-10")
        let b = entry(id: "recipe-daily-2026-03-20-r1", recipe: "recipe-01", dayKey: "2026-03-20")
        let routeA = CalendarRoute.recipeDetail(recipeID: a.recipeID, publicationDayKey: a.dayKey, sourceID: .timeline(entry: a))
        let routeB = CalendarRoute.recipeDetail(recipeID: b.recipeID, publicationDayKey: b.dayKey, sourceID: .timeline(entry: b))
        #expect(routeA != routeB)
    }

    // 10. 深いNavigation階層でもRouteの識別が安定する（Hashableで集合に入れても衝突しない）
    @Test("深い階層でもRouteの識別が安定する")
    func routeIdentityStableInHierarchy() {
        let routes: [CalendarRoute] = [
            .recipeDetail(recipeID: RecipeID("recipe-01"), publicationDayKey: DateKey(value: "2026-03-10"), sourceID: .calendar(recipeID: RecipeID("recipe-01"), dayKey: DateKey(value: "2026-03-10"))),
            .recipeDetail(recipeID: RecipeID("recipe-02"), publicationDayKey: nil, sourceID: nil),
            .recipeDetail(recipeID: RecipeID("recipe-01"), publicationDayKey: DateKey(value: "2026-03-20"), sourceID: .calendar(recipeID: RecipeID("recipe-01"), dayKey: DateKey(value: "2026-03-20"))),
        ]
        #expect(Set(routes).count == 3)
    }
}
