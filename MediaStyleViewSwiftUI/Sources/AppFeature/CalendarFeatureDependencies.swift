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

    // Remote(API)構成の組み立て口。Recipe=RemoteRecipeRepository、MealLog=SwiftData(永続)。
    // 本PRでは本番init()はFixtureのままにし、本Factoryは次PRでの本番切替に備えて用意しておく
    // （ここを呼ぶまで実アプリの取得元はFixtureから変わらない）。
    // 公開シグネチャに internal な APIConfiguration を露出させないため internal とする。
    // AppFeature 内部および @testable import から到達できれば本 PR の要件(構成口の用意)は満たす。
    static func remote(
        configuration: APIConfiguration = .localDevelopment
    ) -> CalendarFeatureDependencies {
        let apiClient = APIClient(
            configuration: configuration,
            httpClient: URLSessionHTTPClient()
        )
        let mealLogRepository: any MealLogRepository
        do {
            let container = try MealLogModelContainerFactory.makePersistent()
            mealLogRepository = SwiftDataMealLogRepository(modelContainer: container)
        } catch {
            mealLogRepository = InMemoryMealLogRepository()
        }
        return CalendarFeatureDependencies(
            recipeRepository: RemoteRecipeRepository(apiClient: apiClient),
            mealLogRepository: mealLogRepository
        )
    }
}
