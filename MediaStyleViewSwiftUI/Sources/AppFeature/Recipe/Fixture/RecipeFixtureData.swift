//
//  RecipeFixtureData.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/23.
//

// Fixture（ダミーデータ）の素。レシピMaster12件と、基準日を中心にした31日分の日別割当を提供する。
// 日別割当は12件のMasterを循環参照するため、同じレシピが複数日に掲載される（複数日掲載を許可）。
// 割当の暦日は基準日(referenceDate)とCalendarから決定的に生成し、端末TZに依存させない。

import Foundation

enum RecipeFixtureData {

    // MARK: - Recipe Master（12件）

    static let recipes: [Recipe] = [
        Recipe(id: RecipeID("recipe-01"), title: "鮭の塩麹焼き", summary: "塩麹でふっくら仕上げる定番の焼き魚", category: .japanese, cookingMinutes: 25, calories: 320, servings: 2),
        Recipe(id: RecipeID("recipe-02"), title: "肉じゃが", summary: "ほくほくのじゃがいもと牛肉の煮物", category: .japanese, cookingMinutes: 40, calories: 450, servings: 3),
        Recipe(id: RecipeID("recipe-03"), title: "ビーフシチュー", summary: "赤ワインでじっくり煮込む洋食の王道", category: .western, cookingMinutes: 90, calories: 620, servings: 4),
        Recipe(id: RecipeID("recipe-04"), title: "ハンバーグ", summary: "肉汁あふれるジューシーな一皿", category: .western, cookingMinutes: 35, calories: 580, servings: 2),
        Recipe(id: RecipeID("recipe-05"), title: "麻婆豆腐", summary: "花椒がきいた本格四川風", category: .chinese, cookingMinutes: 20, calories: 410, servings: 2),
        Recipe(id: RecipeID("recipe-06"), title: "青椒肉絲", summary: "シャキッとピーマンと牛肉の細切り炒め", category: .chinese, cookingMinutes: 25, calories: 390, servings: 2),
        Recipe(id: RecipeID("recipe-07"), title: "マルゲリータ", summary: "トマトとモッツァレラの王道ピザ", category: .italian, cookingMinutes: 30, calories: 700, servings: 2),
        Recipe(id: RecipeID("recipe-08"), title: "カルボナーラ", summary: "卵とチーズの濃厚クリームパスタ", category: .italian, cookingMinutes: 20, calories: 650, servings: 1),
        Recipe(id: RecipeID("recipe-09"), title: "ガトーショコラ", summary: "濃厚でしっとりしたチョコケーキ", category: .dessert, cookingMinutes: 60, calories: 380, servings: 6),
        Recipe(id: RecipeID("recipe-10"), title: "フルーツゼリー", summary: "見た目も涼しげな季節のゼリー", category: .dessert, cookingMinutes: 15, calories: 150, servings: 4),
        Recipe(id: RecipeID("recipe-11"), title: "グリルチキンサラダ", summary: "高たんぱく低カロリーの主役サラダ", category: .healthy, cookingMinutes: 20, calories: 280, servings: 1),
        Recipe(id: RecipeID("recipe-12"), title: "具だくさん味噌汁", summary: "野菜をたっぷり摂れる毎日の汁物", category: .healthy, cookingMinutes: 15, calories: 120, servings: 2),
    ]

    // MARK: - Daily Entry（基準日±15日の31件）

    // 日別割当の生成日数（基準日を中心に前後へ広げる）
    static let dailyEntrySpan = 15

    // 基準日(referenceDate)を中心に、前後dailyEntrySpan日の計31件を生成する。
    // レシピは12件を循環で割り当て、複数日に同じレシピが載るようにする。
    static func dailyEntries(
        referenceDate: Date,
        calendar: Calendar = DateKeyCalendar.default
    ) -> [DailyRecipeEntry] {
        let startOfReference = calendar.startOfDay(for: referenceDate)
        return (-dailyEntrySpan...dailyEntrySpan).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfReference) else {
                return nil
            }
            let dateKey = DateKey(date: date, calendar: calendar)
            // 連番offsetからインデックスを決めて循環割り当てする（決定的）
            let recipeIndex = (offset + dailyEntrySpan) % recipes.count
            let recipe = recipes[recipeIndex]
            return DailyRecipeEntry(
                id: DailyRecipeEntryID("daily-\(dateKey.value)"),
                dateKey: dateKey,
                recipeID: recipe.id
            )
        }
    }
}
