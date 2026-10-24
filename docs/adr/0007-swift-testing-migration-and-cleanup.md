# 0007. Swift Testingへの移行とコードベース整理（型消去・旧サンプルコード）

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 7（Swift Testing Migration & Codebase Cleanup）
- 前提: PR #6〜#11（Recipe/MealLog/Calendar/Timeline / ADR 0003・0004・0005・0006）

## Context

PR #11までで Recipe / MealLog / Calendar / Timeline の機能が揃った。本PRは**機能・UI・永続化・Navigationを変更しない**
前提で、(1) Unit TestをXCTestからSwift Testingへ移行、(2) 不要な型消去の整理、(3) 旧サンプルコードの必要性調査と削除、
を行い、テストしやすく実装を追いやすい状態へ整える。Swift 6 strict concurrencyは維持する。

## Decision

### 1. Unit TestをSwift Testingへ全面移行する

- 全8テストファイル（104論理ケース）を `XCTest` → `Testing` へ移行した。`XCTestCase`継承を廃し、
  テストごとに値型が生成される `struct` の `@Suite` へ整理した。`XCTAssert*`→`#expect`、`XCTUnwrap`→`#require`、
  エラー検証は `#expect(throws:)`（Equatableなエラー値を直接指定）へ置換。
- 本リポジトリに `XCUIApplication` を使うUI Automation Testやパフォーマンス測定は存在しないため、XCTestに残す対象は無い。
  移行後、テスト側に `import XCTest` は一切残っていない。
- **検証能力は維持または強化**。`for invalid in [...]` のループ検証や重複していた祝日判定の3メソッドは
  `@Test(arguments:)` でパラメータ化し、各ケースが個別に報告されるようにした（カバレッジは同等以上）。
  Swift Testing上のテスト数は102（うち2つがパラメータ化テストで計6ケースを内包）＝旧104ケースに対応。

### 2. 並列実行を前提としたテスト設計

- 共有可変状態を持たない。`Calendar` などの定数は immutable な Sendable 値としてファイルスコープの `let` で共有し、
  Reducer/Factory はテストごとの `struct` インスタンスが保持する。
- Repository・UseCase・ViewModel はテストごとに新規生成する。テストダブルは `actor`（Stub Repository/UseCase）で
  Sendable 安全にし、`@unchecked Sendable` を使わない。
- SwiftData テストは毎回専用の ModelContainer（in-memory もしくはユニーク名の一時ファイル）を生成し、
  **本番ストア（makePersistent）へはアクセスしない**。一時ファイルは `defer` で後始末する。
- 非同期の待ち合わせは `Task.sleep` を使わず、ViewModel が公開する `loadTask` / `loadTasks` / `saveTask` を
  `await` して確定させる（決定的・フレーク無し）。
- 以上により `@Suite(.serialized)` は不要（本PRでは一つも使用していない）。

### 3. 型消去（any / AnyView / AnyHashable / Any）の方針

- 調査の結果、`Sources` 配下に `AnyView` / `AnyHashable` / `Any` / `AnyObject` は**一つも存在しない**。
  型消去は Repository / UseCase の `any Protocol`（Protocol Existential）のみ。
- これらの `any` は**DIのために必要**であり、本PRでは**すべて維持**する（不要な型消去は無かった）。
  - `any MealLogRepository`: 本番は `SwiftDataMealLogRepository`、生成失敗時フォールバックや
    テストは `InMemoryMealLogRepository` / Stub actor と、**同一の格納先に異なる実装を保持**する必要があるため存在的型が必須。
  - `any RecipeRepository` / `any CalendarUseCase` / `any TimelineUseCase`: 本番の具体型とテストのStubを差し替えるため維持。
- Generics（`some`/型パラメータ）化は採らない。ViewModel/UseCaseを総ジェネリック化すると `@State` の所有や
  公開APIが複雑化し、型消去の目的（実装差し替え）に対して利得が無い。`any` の存在的ボックス化のコストは
  本UI規模では無視できる。

### 4. 旧サンプルコードの整理

- **削除**: 旧「一覧」タブのUI 4ファイル（`CalendarListScreen` / `CalendarEventListView` /
  `CalendarDaySectionView` / `CalendarEventRowView`）。Phase 6 で一覧タブが `TimelineScreen` へ置換された結果、
  これらは相互参照と各自の `#Preview` 以外から到達不能なデッドコードになっていた（`CalendarRootView` も App も不参照）。
  参照グラフを確認し、`Views/List/` ディレクトリごと削除した。
- **保持**: `CalendarSampleData.swift`（および `CalendarEvent` / `CalendarDay` / `CalendarCategory`）。
  これらは現在も**実行時に月グリッドのイベントドット**へ供給されている
  （`CalendarSampleData.days` → `CalendarFeatureDependencies.days` → `CalendarRootView` → `CalendarMonthScreen`
  → `CalendarMonthGridView` → `CalendarDayViewDataFactory.make(events:)` → `CalendarDayCellView` のドット）。
  削除すると月画面の表示（カテゴリドット）が変わるため、
  「実行時参照が無い」「ドットの意味が変わらない」という削除条件を満たさない。本PRの「UI不変」方針に従い**削除は見送る**。

### 5. Swift 6 Concurrency の維持

- ViewModel は `@MainActor`、Domain Model / State / Action / Effect は Sendable、Repository/UseCase Protocolは
  `Sendable` 制約、SwiftDataアクセスは `@ModelActor` で隔離（境界外へはSendableな `MealLogSummary` のみ）を維持。
- 本PRで Actor 境界は変更していない。`@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency` /
  不要な `Task.detached` は追加していない（既存にも無い）。

## Alternatives

- **XCTestとSwift Testingの併存**: 併存は可能だが、本リポジトリは全てUnit Testで移行に支障が無いため全面移行した。
- **`any`をGenericsへ変更**: 上記3の理由で不採用。
- **CalendarSampleDataをPreview専用Fixtureへ移動して削除**: 月グリッドのドットが実行時に依存しているため、
  移動＝UI変更になる。ドット自体を廃止するかはプロダクト判断であり、本「リファクタリングPR」の範囲外として見送る。
- **CalendarEventの未使用フィールド削減**: `title`/`location`/時刻は現在ドット表示に使われず書き込み専用に近いが、
  モデル変更はリスクがあり、サンプル削除方針が決まってからまとめて行う方が安全なため本PRでは触れない。

## Consequences

- テストが `struct` + `@Suite` + `#expect` で宣言的になり、並列実行・パラメータ化で見通しと実行が改善した。
- 旧一覧UIの削除でCalendar配下の到達可能な表示コードが減り、Timelineが唯一の一覧系UIであることが明確になった。
- 型消去の意図（DIのための `any`）がADRで明文化され、以後「`any`を機械的に消す」誤ったリファクタを防げる。

### デメリット・トレードオフ / 残課題

- 月グリッドには依然としてレシピと無関係なダミーのイベントカテゴリドット（work/health等）が表示される。
  これを廃止するかは**UX/プロダクト判断**で、合意が取れ次第 `CalendarSampleData` と `CalendarEvent` の未使用部を
  まとめて整理する余地がある（次PR候補）。
- UIスナップショット自動テストは引き続き未導入。

## テストと検証

- iOSシミュレータ(iPhone 17 Pro)で `xcodebuild test -scheme AppFeature` → `** TEST SUCCEEDED **` /
  `Test run with 102 tests in 18 suites passed`。
- App Target（`xcodebuild build -scheme MediaStyleViewSwiftUI`）→ `** BUILD SUCCEEDED **`。
  （`swift build` はmacOSホスト向けとなり `@ModelActor` のmacOS 14制約で失敗するため、検証はiOS向けで行う。）
