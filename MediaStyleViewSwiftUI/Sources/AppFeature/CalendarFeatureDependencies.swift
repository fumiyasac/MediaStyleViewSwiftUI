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

    // 本番構成。取得元(Recipe=Fixture/Remote)はComposition Rootで1度だけ決め、全画面で同一の
    // Repositoryインスタンスを共有する（ViewからRepositoryを生成しない・画面ごとに不一致にしない）。
    // MealLogは取得元に関わらず常にSwiftData(永続)。生成失敗時のみInMemoryへフォールバックして起動は守る。
    //
    // 取得元の決定:
    //  - Debugでは環境変数 RECIPE_DATA_SOURCE（fixture/remote）で選べる。既定は .fixture。
    //  - Releaseでは環境変数を読まず常に .fixture（ローカル開発用Backend URLをReleaseの既定に固定しない）。
    // Remoteの動作確認時のみ、SchemeのEnvironment Variableから明示的に remote を選ぶ。
    public init() {
        self.init(dataSource: Self.resolvedDataSource())
    }

    // 取得元を明示指定して組み立てる口（動作確認・テスト用）。
    // Remoteは開発既定の接続先(.localDevelopment=localhost:8080)を使う。接続先の切り替えが要る場合は
    // 本型の内部でAPIConfigurationを差し替える（Viewや上位にAPIConfigurationを露出させない）。
    public init(dataSource: RecipeDataSource) {
        let recipeRepository: any RecipeRepository = Self.makeRecipeRepository(for: dataSource)
        self.init(
            recipeRepository: recipeRepository,
            mealLogRepository: Self.makePersistentMealLogRepository()
        )
    }

    // MARK: - Factory

    // Preview/Test用のin-memory構成（Recipe=Fixture、SwiftDataを永続化しない）
    public static func inMemory() -> CalendarFeatureDependencies {
        CalendarFeatureDependencies(
            recipeRepository: FixtureRecipeRepository(),
            mealLogRepository: InMemoryMealLogRepository()
        )
    }

    // MARK: - Private Factory

    // 取得元ごとにRecipeRepositoryを組み立てる。FixtureとRemoteは同一Protocolなので、
    // ここで実装を選ぶだけで上位(UseCase/ViewModel/View)は無変更のまま取得元を切り替えられる。
    // Remote失敗時にFixtureへ暗黙フォールバックしない（通信失敗は失敗として上位へ伝える）。
    // (テストから取得元→実装の対応を検証できるよう internal。SwiftData生成の副作用なく確認できる)
    static func makeRecipeRepository(for dataSource: RecipeDataSource) -> any RecipeRepository {
        switch dataSource {
        case .fixture:
            return FixtureRecipeRepository()
        case .remote:
            // 開発時はDocker Composeで起動したGo API(localhost:8080)を既定の接続先にする。
            // Simulatorはlocalhostで到達できるが、実機ではMacのLANアドレス等を注入する必要がある。
            let configuration = APIConfiguration.localDevelopment
            let apiClient = APIClient(
                configuration: configuration,
                httpClient: URLSessionHTTPClient()
            )
            let remote = RemoteRecipeRepository(apiClient: apiClient)
            // RemoteをCachedRecipeRepositoryで包み、オフライン時に保存済みデータを表示できるようにする。
            // キャッシュの名前空間はBase URLのhost:port由来にして、別サーバー(Debug切替等)のデータを混同しない。
            let store = FileRecipeCacheStore(namespace: Self.cacheNamespace(for: configuration))
            return CachedRecipeRepository(remote: remote, store: store)
        }
    }

    // Base URLのhost:portからキャッシュ名前空間を作る（例: localhost_8080）。
    private static func cacheNamespace(for configuration: APIConfiguration) -> String {
        let host = configuration.baseURL.host ?? "unknown-host"
        if let port = configuration.baseURL.port {
            return "\(host)_\(port)"
        }
        return host
    }

    // MealLogのSwiftData(永続)Repository。生成失敗時はInMemoryへフォールバックして起動を守る。
    private static func makePersistentMealLogRepository() -> any MealLogRepository {
        do {
            let container = try MealLogModelContainerFactory.makePersistent()
            return SwiftDataMealLogRepository(modelContainer: container)
        } catch {
            // 永続ストアを開けない場合でもアプリは起動させる（調理記録は当該起動中のみ保持）
            return InMemoryMealLogRepository()
        }
    }

    // 起動時の取得元を解決する。DebugのみRECIPE_DATA_SOURCEを尊重し、Releaseは常に既定(.fixture)。
    // environmentは差し替え可能にしてテストで解決ロジックを検証できるようにする（既定は実プロセス環境）。
    static func resolvedDataSource(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RecipeDataSource {
        #if DEBUG
        if let raw = environment[RecipeDataSource.environmentKey],
           let source = RecipeDataSource(rawValue: raw) {
            return source
        }
        #endif
        return .default
    }
}
