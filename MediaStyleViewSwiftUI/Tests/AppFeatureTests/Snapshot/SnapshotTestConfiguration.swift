//
//  SnapshotTestConfiguration.swift
//  MediaStyleViewSwiftUI
//
//  Created by 酒井文也 on 2026/10/27.
//

// Snapshotテストの基準環境を一箇所に固定する。機種・配色・Dynamic Type・精度を揃えることで、
// 実行環境差による誤検出と、実際のUI退行を区別しやすくする。
//
// 基準環境（README/ADRにも明記）:
//  - デバイスサイズ: iPhone 13 Pro（390x844pt, @3x）※実行Simulatorの機種に依存しない固定サイズ
//  - Color Scheme: Light（第一基準）／Dark は追加ケース
//  - Dynamic Type: 既定（.large）／特大は追加ケース
//  - Locale/Calendar/TimeZone: ja_JP / Gregorian(日曜始まり) / Asia/Tokyo（ViewとFixtureで固定）
//  - 文字描画はiOS Runtimeに依存するため、基準画像はPhase 11生成時のRuntimeに紐づく（CIでは同一Runtime必須）。

import SnapshotTesting
import UIKit

enum SnapshotConfig {

    // 固定デバイスサイズ（実行Simulator機種に依存しない）
    static let device: ViewImageConfig = .iPhone13Pro

    // 配色トレイト
    static let light = UITraitCollection(userInterfaceStyle: .light)
    static let dark = UITraitCollection(userInterfaceStyle: .dark)

    // 精度。ピクセル完全一致を基本とし、Runtime差のサブピクセル描画のみ知覚精度で微小に許容する
    // （許容差を大きくして無理に通すためではなく、アンチエイリアスの誤検出を避けるための最小限）。
    static let precision: Float = 1.0
    static let perceptualPrecision: Float = 0.98
}
