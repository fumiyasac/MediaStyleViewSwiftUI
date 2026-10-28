//
//  APIFixtureJSON.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/28.
//

// Contract Test / APIClient Test で使う「実 API から取得した JSON」を固定文字列として保持する。
//
// これらは Go Backend(PR #18, localhost:8080) へ実際に curl して得たレスポンスを貼り付けたもの。
// 実 API を叩かずに「DTO が実レスポンスを取りこぼさず Decode できるか」を再現検証するための基準データ。
// API 仕様が変われば本定数を更新する（契約の破れをテストで検知する）。

import Foundation

enum APIFixtureJSON {

    // GET /api/v1/recipes?limit=2
    static let recipeListLimit2 = """
    {
      "items": [
        {
          "id": "recipe-01",
          "title": "鮭の塩麹焼き",
          "summary": "塩麹でしっとり仕上げる定番の和の主菜。",
          "category": "japanese",
          "cookingMinutes": 25,
          "calories": 320,
          "servings": 2
        },
        {
          "id": "recipe-02",
          "title": "鶏むね肉の香草パン粉焼き",
          "summary": "低カロリーでも満足感のある香ばしい一皿。",
          "category": "western",
          "cookingMinutes": 30,
          "calories": 380,
          "servings": 2
        }
      ],
      "pagination": {
        "limit": 2,
        "offset": 0,
        "total": 24
      }
    }
    """

    // GET /api/v1/recipes/recipe-01
    static let recipeDetail01 = """
    {
      "id": "recipe-01",
      "title": "鮭の塩麹焼き",
      "summary": "塩麹でしっとり仕上げる定番の和の主菜。",
      "category": "japanese",
      "cookingMinutes": 25,
      "calories": 320,
      "servings": 2,
      "imageReference": "recipe-01",
      "ingredients": [
        "生鮭 2切れ",
        "塩麹 大さじ2",
        "大根おろし 適量"
      ],
      "steps": [
        "鮭に塩麹をまぶして30分置く。",
        "魚焼きグリルで両面を焼く。",
        "器に盛り大根おろしを添える。"
      ]
    }
    """

    // GET /api/v1/calendar?from=2026-10-03&to=2026-10-04
    static let calendar = """
    {
      "items": [
        {
          "id": "daily-2026-10-03-recipe-03",
          "publicationDate": "2026-10-03",
          "displayOrder": 0,
          "recipe": {
            "id": "recipe-03",
            "title": "豚肉と野菜の生姜焼き",
            "summary": "ご飯が進むしっかり味の定番おかず。",
            "category": "japanese",
            "cookingMinutes": 20,
            "calories": 450,
            "servings": 2
          }
        },
        {
          "id": "daily-2026-10-04-recipe-04",
          "publicationDate": "2026-10-04",
          "displayOrder": 0,
          "recipe": {
            "id": "recipe-04",
            "title": "トマトソースのペンネ",
            "summary": "完熟トマトの酸味が効いた軽やかなパスタ。",
            "category": "italian",
            "cookingMinutes": 18,
            "calories": 400,
            "servings": 2
          }
        },
        {
          "id": "daily-2026-10-04-recipe-16",
          "publicationDate": "2026-10-04",
          "displayOrder": 1,
          "recipe": {
            "id": "recipe-16",
            "title": "季節のフルーツタルト",
            "summary": "サクサク生地に旬のフルーツをのせて。",
            "category": "dessert",
            "cookingMinutes": 60,
            "calories": 320,
            "servings": 4
          }
        }
      ],
      "range": {
        "from": "2026-10-03",
        "to": "2026-10-04",
        "total": 3
      }
    }
    """

    // 404 (GET /api/v1/recipes/not-exist)
    static let notFoundError = """
    {
      "error": {
        "code": "RECIPE_NOT_FOUND",
        "message": "Recipe was not found."
      }
    }
    """
}
