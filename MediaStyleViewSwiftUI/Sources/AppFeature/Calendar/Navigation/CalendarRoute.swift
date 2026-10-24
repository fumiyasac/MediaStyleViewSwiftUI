//
//  CalendarRoute.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// カレンダーからの型付きNavigation Route。NavigationStackのpathに積む値。
// SwiftData EntityではなくSendableな値(RecipeID/DateKey)だけを渡す。
// 掲載日(publicationDayKey)は「どの掲載日からレシピを開いたか」の文脈として任意で渡す
// （調理日とは別物。Detail側で調理日の初期値に流用しない）。

import Foundation

enum CalendarRoute: Hashable, Sendable {
    case recipeDetail(recipeID: RecipeID, publicationDayKey: DateKey?)
}
