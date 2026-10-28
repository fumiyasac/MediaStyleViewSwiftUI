//
//  MediaStyleViewSwiftUIApp.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2021/10/01.
//

import AppFeature
import SwiftUI

// TODO: BackendはGo言語で作成する

@main
struct MediaStyleViewSwiftUIApp: App {

    // Composition Root。起動時に一度だけ依存(ModelContainer/Repository/UseCase)を組み立てて保持する。
    // ここで1インスタンスだけ持つことでSwiftData ModelContainerの多重生成を避ける。
    // 取得元(Fixture/Remote)はCalendarFeatureDependencies()がDebug環境変数RECIPE_DATA_SOURCEから解決する。
    private let dependencies = CalendarFeatureDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}
