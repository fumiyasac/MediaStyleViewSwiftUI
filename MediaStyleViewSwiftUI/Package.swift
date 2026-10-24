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
            dependencies: ["AppFeature"]),
    ],
    // Swift 6 言語モードでビルドし、strict concurrencyの検査を有効にする
    swiftLanguageModes: [.v6]
)
