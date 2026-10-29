//
//  RecipeCacheError.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/30.
//

// キャッシュ永続化で起こり得る失敗。
//
// 方針: キャッシュの読み書き失敗は「正常取得したRemoteデータの表示」を妨げてはならない。
// そのためStoreの読み込みは失敗時にエラーを投げず nil(=キャッシュ無し扱い) を返し、
// 書き込みはベストエフォート(失敗しても画面表示を止めない)とする。
// 本型はStore内部のログや、エンコード/デコード単体の検証で使う。

import Foundation

enum RecipeCacheError: Error, Sendable, Equatable {
    // 保存先ディレクトリを用意できない
    case directoryUnavailable
    // 書き込み失敗（容量不足・権限等）
    case writeFailed(message: String)
    // 読み込み失敗（ファイル破損・権限等）
    case readFailed(message: String)
    // Schema Versionが現行と不一致（古い/未知の形式）
    case schemaMismatch(found: Int, expected: Int)
    // JSONとして解釈できない（破損）
    case decodingFailed(message: String)
}
