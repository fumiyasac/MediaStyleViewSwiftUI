// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// SwiftUIプロジェクトのMultiModule構成ことはじめ
// 参考: https://zenn.dev/kalupas226/articles/73118709e316ad

let package = Package(
    name: "MediaStyleViewSwiftUI",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "AppFeature"),
    ]
)
