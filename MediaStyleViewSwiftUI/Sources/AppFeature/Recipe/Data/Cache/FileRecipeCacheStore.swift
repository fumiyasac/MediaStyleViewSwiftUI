//
//  FileRecipeCacheStore.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// JSONファイルによるRecipeCacheStore実装。ファイル読み書きをactorへ隔離する。
//
// なぜactorか:
//  - 同一ファイルへ複数Taskから同時に書き込むと破損し得る。actorで直列化して競合を防ぐ。
//  - Swift 6のデータ競合безопасность（@unchecked Sendable等に頼らず安全に共有可変状態を扱う）。
//
// なぜApplication Supportか:
//  - OS管理の一時Cache(URLCache/Caches)ではなく、アプリが必要とする「保存済みコンテンツ」として管理するため。
//    ただしアプリ削除やストレージ障害で失われ得る前提は保つ（永続化失敗で画面表示を止めない）。
//
// なぜ名前空間(namespace)で分けるか:
//  - Debug等でAPI Base URLが変わると別サーバーのデータになる。host由来のnamespaceでディレクトリを分け、
//    異なるサーバーのデータを混同しない。
//
// 保存はatomic write。読み込みは破損/未知Schemaで nil を返し、画面を壊さない。

import Foundation

actor FileRecipeCacheStore: RecipeCacheStore {

    // MARK: - Property

    private let rootDirectory: URL
    // ディレクトリ用意に失敗した場合でも落とさず、保存を諦める（読み込みは常にnil）
    private var isDirectoryReady = false

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initializer

    // namespace: API接続先(host等)由来の識別子。directoryRoot未指定ならApplication Support配下。
    init(namespace: String, directoryRoot: URL? = nil) {
        let base = directoryRoot ?? Self.defaultApplicationSupportRoot()
        self.rootDirectory = base
            .appendingPathComponent("RecipeCache", isDirectory: true)
            .appendingPathComponent(Self.sanitize(namespace), isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - RecipeCacheStore (list)

    func loadRecipeList() async -> RecipeCacheRecord<[CachedRecipe]>? {
        read([CachedRecipe].self, fileName: "recipe-list.json")
    }

    func saveRecipeList(_ recipes: [CachedRecipe], fetchedAt: Date) async {
        write(recipes, fileName: "recipe-list.json", fetchedAt: fetchedAt)
    }

    // MARK: - RecipeCacheStore (detail)

    func loadRecipeDetail(id: String) async -> RecipeCacheRecord<CachedRecipe>? {
        read(CachedRecipe.self, fileName: "detail-\(Self.sanitize(id)).json")
    }

    func saveRecipeDetail(_ recipe: CachedRecipe, fetchedAt: Date) async {
        write(recipe, fileName: "detail-\(Self.sanitize(recipe.id)).json", fetchedAt: fetchedAt)
    }

    // MARK: - RecipeCacheStore (daily entries)

    func loadDailyEntries(rangeKey: String) async -> RecipeCacheRecord<[CachedDailyEntry]>? {
        read([CachedDailyEntry].self, fileName: "entries-\(Self.sanitize(rangeKey)).json")
    }

    func saveDailyEntries(_ entries: [CachedDailyEntry], rangeKey: String, fetchedAt: Date) async {
        write(entries, fileName: "entries-\(Self.sanitize(rangeKey)).json", fetchedAt: fetchedAt)
    }

    // MARK: - RecipeCacheStore (clear)

    func removeAll() async {
        // このキャッシュ名前空間のディレクトリのみ削除。MealLog(SwiftData)等には一切触れない。
        try? FileManager.default.removeItem(at: rootDirectory)
        isDirectoryReady = false
    }

    // MARK: - Private: IO

    // 破損/未知Schema/未存在は nil（安全）。
    private func read<Payload: Codable & Sendable>(
        _ type: Payload.Type,
        fileName: String
    ) -> RecipeCacheRecord<Payload>? {
        let url = rootDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else {
            return nil // 未存在/読み取り不可はキャッシュ無し扱い
        }
        guard let record = try? decoder.decode(RecipeCacheRecord<Payload>.self, from: data) else {
            return nil // 破損JSONは無視（例外を投げず画面を壊さない）
        }
        guard record.schemaVersion == RecipeCacheSchema.current else {
            return nil // 未知/旧Schemaは安全に無視（誤った移行による事故を防ぐ）
        }
        return record
    }

    // ベストエフォート。失敗しても投げない（正常取得データの表示を妨げない）。
    private func write<Payload: Codable & Sendable>(
        _ payload: Payload,
        fileName: String,
        fetchedAt: Date
    ) {
        guard ensureDirectory() else { return }
        let url = rootDirectory.appendingPathComponent(fileName)

        // 既存レコードより古い取得結果での上書きを防ぐ（古い通信結果が新しいキャッシュを壊さない）。
        // 通常運用ではfetchedAt=現在時刻のため後着＝新しい取得が勝つ。
        if let existing = existingFetchedAt(at: url), existing >= fetchedAt {
            return
        }

        let record = RecipeCacheRecord(payload: payload, fetchedAt: fetchedAt)
        guard let data = try? encoder.encode(record) else { return }
        // atomic write: 書き込み途中の中断でも中途半端なファイルを残さない
        try? data.write(to: url, options: [.atomic])
    }

    // payloadを読まずに既存レコードのfetchedAtだけ取り出す（破損/旧Schema/未存在はnil）。
    private func existingFetchedAt(at url: URL) -> Date? {
        guard let data = try? Data(contentsOf: url),
              let header = try? decoder.decode(RecipeCacheHeader.self, from: data),
              header.schemaVersion == RecipeCacheSchema.current else {
            return nil
        }
        return header.fetchedAt
    }

    // ディレクトリを用意（失敗時はfalse＝保存を諦める）
    private func ensureDirectory() -> Bool {
        if isDirectoryReady { return true }
        do {
            try FileManager.default.createDirectory(
                at: rootDirectory,
                withIntermediateDirectories: true
            )
            isDirectoryReady = true
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private: Helpers

    private static func defaultApplicationSupportRoot() -> URL {
        let fileManager = FileManager.default
        if let url = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return url
        }
        // 取得できない場合の最終手段（テスト/異常系）。実アプリでは通常発生しない。
        return fileManager.temporaryDirectory
    }

    // ファイル名/ディレクトリ名に使えるよう、英数字と一部記号以外を "_" へ置換する。
    private static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(scalars)
        return result.isEmpty ? "default" : result
    }
}
