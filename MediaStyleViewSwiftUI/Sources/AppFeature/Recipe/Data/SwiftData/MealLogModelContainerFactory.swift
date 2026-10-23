//
//  MealLogModelContainerFactory.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/24.
//

// MealLog用ModelContainerの生成を1か所に集約するファクトリ。
// Schemaの定義もここへ集約し、本番(永続)・テスト(in-memory)・ファイル指定の各Containerを作り分ける。
//
// 多重生成防止の方針:
//  ModelContainerはComposition Root(App起動時)で一度だけ生成し、
//  そこから生成したRepositoryを注入して使い回す。グローバルなstaticシングルトンは持たず
//  （生成がthrowするため・テストでの差し替えを容易にするため）、生成箇所を単一にすることで多重生成を避ける。

import Foundation
import SwiftData

enum MealLogModelContainerFactory {

    // MARK: - Schema

    // MealLog永続化のSchema（Entityを増やす際はここへ追加する）
    static let schema = Schema([MealLogEntity.self])

    // MARK: - Factory

    // 永続ストアのContainer（本番・既定の保存先）
    static func makePersistent() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // in-memoryのContainer（テスト・プレビュー用。ディスクに残さない）
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // 保存先URLを指定したContainer（再オープンの永続化検証などに使う）
    static func make(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
