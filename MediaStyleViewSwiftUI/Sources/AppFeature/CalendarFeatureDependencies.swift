//
//  CalendarFeatureDependencies.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// Composition Root。App起動時に一度だけ生成し、ContentViewへ渡す。
// AppFeature内部の型(Repository/UseCase/ModelContainer)はinternalのため、App層からは
// この公開型越しに組み立てる。ModelContainerの多重生成を避けるため、Appは本型を1インスタンスだけ保持する。
//
// RecipeRepository/MealLogRepositoryも保持し、Recipe DetailやMealLog Editorへ注入できるようにする。
// 本番はSwiftData永続ストアを使い、生成失敗時はInMemoryへフォールバックしてUI全体が壊れないようにする。

import Foundation

public struct CalendarFeatureDependencies: Sendable {

    // AppFeature内部で使う（外部には公開しない）
    let calendarUseCase: any CalendarUseCase
    let timelineUseCase: any TimelineUseCase
    let recipeRepository: any RecipeRepository
    let mealLogRepository: any MealLogRepository
    let days: [CalendarDay]

    // MARK: - Initializer

    private init(
        recipeRepository: any RecipeRepository,
        mealLogRepository: any MealLogRepository
    ) {
        self.recipeRepository = recipeRepository
        self.mealLogRepository = mealLogRepository
        self.calendarUseCase = DefaultCalendarUseCase(
            recipeRepository: recipeRepository,
            mealLogRepository: mealLogRepository
        )
        self.timelineUseCase = DefaultTimelineUseCase(
            recipeRepository: recipeRepository,
            mealLogRepository: mealLogRepository
        )
        self.days = CalendarSampleData.days
    }

    // 本番構成。Recipe=Fixture、MealLog=SwiftData(永続)。SwiftData生成失敗時はInMemoryへフォールバック。
    public init() {
        let mealLogRepository: any MealLogRepository
        do {
            let container = try MealLogModelContainerFactory.makePersistent()
            mealLogRepository = SwiftDataMealLogRepository(modelContainer: container)
        } catch {
            // 永続ストアを開けない場合でもアプリは起動させる（調理記録は当該起動中のみ保持）
            mealLogRepository = InMemoryMealLogRepository()
        }
        self.init(recipeRepository: FixtureRecipeRepository(), mealLogRepository: mealLogRepository)
    }

    // MARK: - Factory

    // Preview/Test用のin-memory構成（SwiftDataを永続化しない）
    public static func inMemory() -> CalendarFeatureDependencies {
        CalendarFeatureDependencies(
            recipeRepository: FixtureRecipeRepository(),
            mealLogRepository: InMemoryMealLogRepository()
        )
    }
}
