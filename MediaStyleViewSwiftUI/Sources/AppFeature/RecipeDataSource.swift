//
//  RecipeDataSource.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/29.
//

// レシピ取得元の選択肢。Composition Root(CalendarFeatureDependencies)が「どのRecipeRepository実装を
// 組み立てるか」を1箇所で決めるための設定値。
//
// なぜ enum で表すか:
//  - FixtureとRemoteは同じ RecipeRepository Protocol に準拠しており、呼び出し側(UseCase/ViewModel/View)は
//    取得元を意識しない。切り替えの関心事をこの型に閉じ込め、画面ごとに実装がバラつかないようにする。
//  - 取得元の決定は起動時に1度だけ行い、全画面で同一インスタンスを共有する（多重生成しない）。
//
// 既定値について:
//  - 当面の通常起動は .fixture。Remote統合の動作確認時に明示的に .remote を選ぶ。
//  - 取得元の実行時切替UIは本PRの対象外（Debug設定からの選択で足りる）。

import Foundation

public enum RecipeDataSource: String, Sendable, CaseIterable {

    // 同梱の固定データ（従来どおりの動作。ネットワーク不要）
    case fixture

    // Go Backend API（RemoteRecipeRepository経由でMySQL由来のデータを取得）
    case remote

    // Debug環境変数キー。Scheme等から `RECIPE_DATA_SOURCE=remote` のように指定して切り替える。
    static let environmentKey = "RECIPE_DATA_SOURCE"

    // 通常起動の既定。Remoteは明示選択したときだけ使う。
    static let `default`: RecipeDataSource = .fixture
}
