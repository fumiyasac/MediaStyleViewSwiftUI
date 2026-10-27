# 0011. Swift TestingとSnapshot Testingを組み合わせたiOS Visual Regression戦略

- Status: Accepted
- Date: 2026-10-27
- 関連PR: Phase 11（iOS Visual Regression & Snapshot Testing）
- 前提: PR #6〜#16（Recipe/MealLog/Calendar/Timeline・Media Style UI・Zoom遷移 / ADR 0003〜0010）

## Context

PR #16までで主要4画面（Calendar月表示 / Timeline / Recipe Detail / MealLog Editor）のUIが安定した。
これらのレイアウト・文字・余白・表示要素の意図しない変更を検出するVisual Regression基盤を、
既存のSwift Testingを維持したまま構築する。新機能は追加しない。

## Decision

1. **ライブラリ選定: swift-snapshot-testing（Point-Free）1.19.7**:
   Swift 6 / Swift Testing 対応版で、`assertSnapshot` が Swift Testing コンテキストを検出し `Issue.record` で失敗を報告する。
   デファクトで保守され、UIImage比較・デバイス構成・精度指定が揃う。依存は**テストターゲット限定**で、
   本番 `AppFeature` には追加しない。既存Unit TestはXCTestへ戻さない。

2. **Swift Testingとの共存**:
   SnapshotテストもSwift Testingの `@Suite`/`@Test` で実装し、UI描画のため `@MainActor` を付ける。
   既存のReducer/ViewModel/Repository/ViewData/Geometry/Navigation IdentityのSwift Testingは維持し、
   Snapshotは「レイアウトの回帰検出」という補助的な位置づけにする（アニメーションの滑らかさは手動確認）。

3. **Test Target構成**:
   新Test Targetは作らず、既存 `AppFeatureTests` 内の `Snapshot/` に配置する（Scheme影響を避ける）。
   基準画像 `Snapshot/__Snapshots__/` はテストが `#filePath` 基準でファイルシステムから読むため、
   SPMのリソース処理対象にしない（`exclude: ["Snapshot/__Snapshots__"]`）。

4. **Fixtureの固定（決定性）**:
   現在日時・乱数・実行環境に依存しない固定値のみを使う（`SnapshotFixtureFactory`）。
   - 日付: Asia/Tokyo固定Calendar、**過去月(2024年6月)** を基準にする。
     理由: Calendarセルの「今日」強調は `CalendarDateUtil.isToday`(実日付依存)で描かれるため、過去月なら永遠に「今日」が入らず決定的になる。
   - レシピ: 既存 `RecipeFixtureData` の固定レシピ（固定タイトル/材料/手順＋Asset Catalogのバンドル画像）を再利用。
   - MealLog: 固定の調理日/評価/メモ。SwiftDataストアやRepository通信は発生させず、SendableなDomain/ViewDataだけを組み立てる。

5. **描画対象は同期的な責務独立Viewにする**:
   非同期ロード（ViewModelの`.task{load()}`）を避け、データを直接受け取る実コンポーネントを描く:
   `CalendarMonthView` / `TimelineDaySectionView`(List) / `RecipeDetailContent` / `RecipeHeroView` / `MealLogEditorSheet`。
   これにより「非同期完了前に撮影」の不安定要因を排除する。`RecipeDetailContent` は従来privateだったが、
   Snapshotから同期検証するためinternalへ変更（可視性のみ、挙動は不変）。本番ViewのNavigationStackは二重化しない。

6. **Xcode/Simulator環境の固定**:
   実行Simulator機種に依存しない固定サイズ `ViewImageConfig.iPhone13Pro`(390×844pt)でレンダリングする。
   Color SchemeはLightを第一基準、Darkは追加ケース。Dynamic Typeは既定。これらは `SnapshotTestConfiguration` に集約。
   文字描画はiOS Runtime依存のため、基準画像は生成時Runtimeに紐づく（CIは同一Runtimeが必要＝後述の課題）。

7. **精度**:
   `precision = 1.0`（ピクセル一致）＋`perceptualPrecision = 0.98`（Runtime差のサブピクセル描画のみ最小限許容）。
   許容差を広げて無理に通すためではなく、アンチエイリアスの誤検出を避けるための最小設定とする。

8. **基準画像の生成・承認手順**:
   初回は自動記録されテストは失敗（記録モード）→生成画像を**目視確認**→妥当ならコミット→再実行で成功（比較モード）。
   通常実行・CIでは自動上書きしない。意図的なUI変更時のみ、該当基準画像を削除→再記録→目視→コミットで更新する。
   「自動生成しただけで成功とみなさない」「更新は実際のUI変更内容と対応する」ことをレビュー方針とする。

## Alternatives

- **A. swift-snapshot-testing（採用）**: Swift Testing対応・保守性・機能が揃う。テスト限定依存で本番に影響しない。
- **B. Xcode/UIKit/SwiftUI標準の自前実装**: 画像比較・差分表示を自作する負担が大きく不採用。
- **C. 基準画像＋手動回帰のみ**: 自動差分検出が得られず、本PRの目的（回帰検出）を満たさないため不採用。

## Consequences

- 主要4画面＋Heroの6基準画像で、レイアウト/文字/余白/表示要素の退行を自動検出できる。
- 既存Swift Testingは不変で共存（合計127 tests / 23 suites）。本番コードはRecipeDetailContentの可視性のみ変更。
- Fixtureが決定的なため、同一環境で繰り返し実行しても結果が変わらない。

### Snapshotで検証できること / できないこと

- できる: 固定状態でのレイアウト・文字・色・余白・マーカー・画像配置の差分検出。
- できない: アニメーションの途中フレーム（Parallax/Stretch/Collapse/Zoom遷移）、実機の操作性・スクロール挙動、
  非同期ロードの体感。これらはSimulatorの手動確認を継続する。

### CI導入時の課題

- 基準画像はiOS Runtime/フォントに依存するため、CIはローカルと**同一のXcode/Simulator Runtime**を固定する必要がある。
  不一致は「環境差の偽陽性」を生むため、`perceptualPrecision`で吸収しきれない場合はRuntime統一が前提。
- 記録モードの暴発防止（CIでは`record`を有効にしない）。差分失敗時のアーティファクト（期待/実際/差分画像）の収集。

### 保守負担とトレードオフ

- UI変更のたびに基準画像の更新・目視が必要（意図的変更の検知コスト）。ケース数は4画面＋α（現状6枚）に限定し、
  全画面・全状態・全デバイスへ広げない方針で保守コストを抑える。

## 検証

- `xcodebuild test -scheme AppFeature`（iPhone 17 Pro Simulator）→ `** TEST SUCCEEDED **` / 127 tests / 23 suites。
  Snapshot 6枚は記録→目視確認→比較モードで成功。App `xcodebuild build` も成功（本番は依存非追加）。
- 基準画像は目視で内容の妥当性（6月2024・今日強調なし・マーカー・材料/手順・調理記録・編集フォーム・Dark）を確認済み。
