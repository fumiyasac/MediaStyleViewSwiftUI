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
        Recipe(id: RecipeID("recipe-01"), title: "鮭の塩麹焼き", summary: "塩麹でふっくら仕上げる定番の焼き魚", category: .japanese, cookingMinutes: 25, calories: 320, servings: 2,
               ingredients: ["生鮭 2切れ", "塩麹 大さじ2", "大根おろし 適量", "すだち 1個"],
               steps: ["鮭に塩麹をまぶし30分ほどおく", "グリルを予熱し、中火で両面を焼く", "皮目をパリッとさせて器に盛る", "大根おろしとすだちを添える"]),
        Recipe(id: RecipeID("recipe-02"), title: "肉じゃが", summary: "ほくほくのじゃがいもと牛肉の煮物", category: .japanese, cookingMinutes: 40, calories: 450, servings: 3,
               ingredients: ["牛こま切れ肉 200g", "じゃがいも 3個", "にんじん 1本", "玉ねぎ 1個", "だし汁 300ml", "醤油・みりん 各大さじ3"],
               steps: ["野菜を一口大に切る", "鍋で牛肉を炒める", "野菜を加えてだし汁を注ぐ", "調味料を入れ落とし蓋で15分煮る"]),
        Recipe(id: RecipeID("recipe-03"), title: "ビーフシチュー", summary: "赤ワインでじっくり煮込む洋食の王道", category: .western, cookingMinutes: 90, calories: 620, servings: 4,
               ingredients: ["牛すね肉 500g", "玉ねぎ 2個", "にんじん 1本", "赤ワイン 200ml", "デミグラスソース 1缶", "バター 20g"],
               steps: ["牛肉に焼き色をつける", "野菜を炒める", "赤ワインを加えアルコールを飛ばす", "デミグラスで1時間煮込む"]),
        Recipe(id: RecipeID("recipe-04"), title: "ハンバーグ", summary: "肉汁あふれるジューシーな一皿", category: .western, cookingMinutes: 35, calories: 580, servings: 2,
               ingredients: ["合いびき肉 300g", "玉ねぎ 1/2個", "パン粉 大さじ4", "卵 1個", "ナツメグ 少々"],
               steps: ["玉ねぎをみじん切りにして炒め冷ます", "材料を混ねて成形する", "中火で両面を焼く", "蓋をして蒸し焼きにし火を通す"]),
        Recipe(id: RecipeID("recipe-05"), title: "麻婆豆腐", summary: "花椒がきいた本格四川風", category: .chinese, cookingMinutes: 20, calories: 410, servings: 2,
               ingredients: ["木綿豆腐 1丁", "豚ひき肉 150g", "豆板醤 大さじ1", "花椒 小さじ1", "長ねぎ 1/2本"],
               steps: ["豆腐を角切りにして下茹でする", "ひき肉と豆板醤を炒める", "水と調味料を加え豆腐を入れる", "水溶き片栗粉でとろみをつけ花椒をふる"]),
        Recipe(id: RecipeID("recipe-06"), title: "青椒肉絲", summary: "シャキッとピーマンと牛肉の細切り炒め", category: .chinese, cookingMinutes: 25, calories: 390, servings: 2,
               ingredients: ["牛もも肉 150g", "ピーマン 4個", "たけのこ 100g", "オイスターソース 大さじ1"],
               steps: ["牛肉を細切りにして下味をつける", "野菜を細切りにする", "強火で牛肉を炒める", "野菜を加えオイスターソースで仕上げる"]),
        Recipe(id: RecipeID("recipe-07"), title: "マルゲリータ", summary: "トマトとモッツァレラの王道ピザ", category: .italian, cookingMinutes: 30, calories: 700, servings: 2,
               ingredients: ["ピザ生地 1枚", "トマトソース 80g", "モッツァレラ 100g", "バジル 適量", "オリーブオイル 適量"],
               steps: ["生地にトマトソースを塗る", "チーズをちぎって乗せる", "250度のオーブンで10分焼く", "バジルとオイルを仕上げにかける"]),
        Recipe(id: RecipeID("recipe-08"), title: "カルボナーラ", summary: "卵とチーズの濃厚クリームパスタ", category: .italian, cookingMinutes: 20, calories: 650, servings: 1,
               ingredients: ["スパゲッティ 100g", "卵黄 2個", "パンチェッタ 40g", "粉チーズ 30g", "黒こしょう 適量"],
               steps: ["パスタを茹で始める", "パンチェッタをカリッと焼く", "卵黄とチーズを混ぜる", "茹で汁で温度調整しながら和える"]),
        Recipe(id: RecipeID("recipe-09"), title: "ガトーショコラ", summary: "濃厚でしっとりしたチョコケーキ", category: .dessert, cookingMinutes: 60, calories: 380, servings: 6,
               ingredients: ["チョコレート 150g", "バター 80g", "卵 3個", "砂糖 80g", "薄力粉 30g"],
               steps: ["チョコとバターを湯煎で溶かす", "卵と砂糖を泡立てる", "粉を混ぜて型に流す", "170度で30分焼き冷ます"]),
        Recipe(id: RecipeID("recipe-10"), title: "フルーツゼリー", summary: "見た目も涼しげな季節のゼリー", category: .dessert, cookingMinutes: 15, calories: 150, servings: 4,
               ingredients: ["好みのフルーツ 200g", "ゼラチン 10g", "水 400ml", "砂糖 60g"],
               steps: ["ゼラチンを水でふやかす", "砂糖を溶かした湯で煮溶かす", "フルーツと共に型へ注ぐ", "冷蔵庫で3時間冷やし固める"]),
        Recipe(id: RecipeID("recipe-11"), title: "グリルチキンサラダ", summary: "高たんぱく低カロリーの主役サラダ", category: .healthy, cookingMinutes: 20, calories: 280, servings: 1,
               ingredients: ["鶏むね肉 1枚", "ミックスリーフ 100g", "ミニトマト 5個", "オリーブオイル 大さじ1", "レモン 1/2個"],
               steps: ["鶏むねに塩をして焼く", "そぎ切りにする", "野菜を器に盛る", "ドレッシングをかけて鶏肉を乗せる"]),
        Recipe(id: RecipeID("recipe-12"), title: "具だくさん味噌汁", summary: "野菜をたっぷり摂れる毎日の汁物", category: .healthy, cookingMinutes: 15, calories: 120, servings: 2,
               ingredients: ["大根 100g", "にんじん 50g", "油揚げ 1枚", "だし汁 400ml", "味噌 大さじ2"],
               steps: ["野菜を薄切りにする", "だし汁で野菜を煮る", "柔らかくなったら味噌を溶く", "ひと煮立ちさせて火を止める"]),
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
