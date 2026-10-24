//
//  ContentView.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2021/10/01.
//

import SwiftUI

public struct ContentView: View {

    // MARK: - Property

    // Composition Rootで組み立てた依存（UseCase/イベント配列）
    private let dependencies: CalendarFeatureDependencies

    // MARK: - Initializer

    // App起動時に一度だけ生成した依存を受け取る（ModelContainerの多重生成を避ける）。
    // 既定はin-memory構成にして、ContentViewが再生成されても永続ストアを多重に開かないようにする
    // （本番はApp側で生成した依存を明示的に渡す）。
    public init(dependencies: CalendarFeatureDependencies = .inMemory()) {
        self.dependencies = dependencies
    }

    // MARK: - Body

    public var body: some View {
        CalendarRootView(
            days: dependencies.days,
            calendarUseCase: dependencies.calendarUseCase,
            recipeRepository: dependencies.recipeRepository,
            mealLogRepository: dependencies.mealLogRepository
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView(dependencies: .inMemory())
}
