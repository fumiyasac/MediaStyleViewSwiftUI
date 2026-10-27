# MediaStyleViewSwiftUI

[ING] - SwiftUI+MVVM+StateMachineで作るUIサンプル実装例

## テスト

Unit TestはSwift Testing、Visual RegressionはSwift Testing + [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) で実装しています。

```sh
# 全テスト（Unit + Snapshot）
xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Snapshotのみ
xcodebuild test -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AppFeatureTests/CalendarSnapshotTests \
  -only-testing:AppFeatureTests/TimelineSnapshotTests \
  -only-testing:AppFeatureTests/RecipeDetailSnapshotTests \
  -only-testing:AppFeatureTests/MealLogEditorSnapshotTests
```

### Snapshot Testing

主要4画面（Calendar月表示 / Timeline / Recipe Detail / MealLog Editor）のレイアウト・文字・余白・表示要素の
意図しない変更を検出します。アニメーション（Parallax / Collapse / Zoom遷移）の滑らかさはSnapshotの対象外で、
Simulatorの手動確認で担保します。

- 実装: `Tests/AppFeatureTests/Snapshot/`
- 基準画像: `Tests/AppFeatureTests/Snapshot/__Snapshots__/`（Git管理。SPMのリソース処理対象外に`exclude`）
- 依存: `swift-snapshot-testing`（テストターゲット限定。本番`AppFeature`には依存させない）

#### 基準環境（これを変えると文字描画・Safe Area等が変わり差分が出る）

| 項目 | 値 |
|---|---|
| デバイスサイズ | iPhone 13 Pro（390×844pt, @3x。実行Simulator機種に依存しない固定サイズ） |
| iOS Runtime | 基準画像を生成したRuntimeに紐づく（CIでは同一Runtimeが必要） |
| Color Scheme | Light（第一基準）／Dark は追加ケース |
| Dynamic Type | 既定（.large） |
| Locale / Calendar / TimeZone | ja_JP / Gregorian(日曜始まり) / Asia/Tokyo |
| 固定日付 | 2024-06（過去月。`CalendarDateUtil.isToday`=実日付依存の「今日」強調が入らないようにするため） |

設定は `SnapshotTestConfiguration.swift`、固定データは `SnapshotFixtureFactory.swift` に集約しています。

#### 基準画像の生成・更新手順

1. 対象のSnapshotテストを追加/変更する。
2. 初回（基準画像が無い）は実行すると自動記録され、テストは**失敗**する（記録モード）。
3. 生成された `__Snapshots__/.../<test>.1.png` を**目視確認**する。
4. 妥当なら基準画像をコミットする。再実行すると**成功**する（差分比較モード）。
5. 意図的なUI変更時のみ、該当する基準画像を削除→再記録→目視→コミットして更新する。

通常実行・CIでは基準画像を自動で書き換えません（記録は基準が無い場合のみ）。基準画像の更新は、実際のUI変更内容と
対応している必要があります。不安定なテストは許容差分を広げて通すのではなく、原因（非同期描画・現在日時依存・フォント等）を
調査してください。
