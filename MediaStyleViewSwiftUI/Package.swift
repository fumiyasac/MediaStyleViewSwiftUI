// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// SwiftUIプロジェクトのMultiModule構成ことはじめ
// 参考: https://zenn.dev/kalupas226/articles/73118709e316ad

let package = Package(
    name: "MediaStyleViewSwiftUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "AppFeature"),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature"]),
    ],
    // Swift 6 言語モードでビルドし、strict concurrencyの検査を有効にする
    swiftLanguageModes: [.v6]
)
