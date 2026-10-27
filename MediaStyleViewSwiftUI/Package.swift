// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// SwiftUIプロジェクトのMultiModule構成ことはじめ
// 参考: https://zenn.dev/kalupas226/articles/73118709e316ad

let package = Package(
    name: "MediaStyleViewSwiftUI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"])
    ],
    dependencies: [
        // 祝祭日判定に自作パッケージ CalculateCalendarLogic を利用する
        .package(url: "https://github.com/fumiyasac/handMadeCalendarAdvance", from: "0.8.2"),
        // Snapshot Testing（テストターゲット限定。本番AppFeatureには依存させない）
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "CalculateCalendarLogic", package: "handMadeCalendarAdvance"),
            ],
            // レシピのHero画像（Asset Catalog）をBundle.module経由で読み込む
            resources: [
                .process("Resources/RecipeImages.xcassets"),
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            // 基準画像(__Snapshots__)はSPMのリソース処理対象にしない（テストが#filePath基準でファイルシステムから読む）
            exclude: ["Snapshot/__Snapshots__"]
        ),
    ],
    // Swift 6 言語モードでビルドし、strict concurrencyの検査を有効にする
    swiftLanguageModes: [.v6]
)
