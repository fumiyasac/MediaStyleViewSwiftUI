# 0014. Calendar / Timeline / Recipe DetailへのRemote Recipe統合

- ステータス: 承認
- 日付: 2026-10-29
- 関連: [0008](0008-recipe-centric-calendar.md) / [0012](0012-go-backend-recipe-calendar-api.md) / [0013](0013-swift-remote-repository-go-backend-api-boundary.md)

## コンテキスト

PR #18(ADR 0012)でGo Backend API、PR #19(ADR 0013)でSwift側の`RemoteRecipeRepository`を用意した。
本フェーズ(Phase 14)では、それらを既存のSwiftUIアプリ(Calendar / Timeline / Recipe Detail)へ接続し、
MySQL由来のレシピデータをGo API経由で表示する一連のフルスタックデータフローを完成させる。

制約:

- 既存のMVVM + StateMachine設計(Calendar/Timeline/RecipeDetailのState/Action/Effect/Reducer)を維持する。
  Remote対応のためにStateMachineを全面的に書き直さない。
- `RecipeRepository` Protocolに準拠する形で取得元を切り替える。UI/ViewModel/UseCaseは取得元を意識しない。
- MealLogの保存先は取得元に関わらずSwiftDataのまま。MealLogのRemote同期は実装しない。
- Remote失敗時にFixtureへ暗黙フォールバックしない(通信失敗は失敗として見えるようにする)。
- Offline Cache/Fallbackは次PR(#21)へ延期する。
- 既存のアニメーション(Parallax/Collapsing/Zoom)・Navigation・Snapshot基準画像を変更しない。
- Base URLをViewに書かない。ATSをグローバル無効化しない。

## 決定

### 取得元の選択をComposition Rootへ集約

`RecipeDataSource`(fixture/remote)を導入し、`CalendarFeatureDependencies`が起動時に1度だけ
取得元を決めて`RecipeRepository`実装を組み立てる。全画面はこの単一インスタンスを共有する
(ViewからRepositoryを生成しない・画面ごとに実装が食い違わない・多重生成しない)。

- Debug: 環境変数`RECIPE_DATA_SOURCE`(fixture/remote)で選択。既定は`.fixture`。
- Release: 環境変数を読まず常に`.fixture`(ローカル開発用URLをReleaseの既定に固定しない)。
- `inMemory()`(Preview/Test)はFixture構成のまま。

FixtureとRemoteは同一の`RecipeRepository`に準拠するため、ここで実装を差し替えるだけで
上位は無変更で取得元を切り替えられる。

### 「必要な範囲だけ」取得する境界(dailyEntries(in:))

Calendarは月単位、Timelineは期間単位でデータが必要になる。Calendar APIはレンジ(from/to, 最大92日)で
掲載を返すため、`RecipeRepository`に範囲取得メソッドを追加した。

```swift
func dailyEntries(in range: ClosedRange<DateKey>) async throws -> [DailyRecipeEntry]
```

- Protocolの「要件」として宣言し、既定実装はextensionに置く(全件取得→範囲フィルタ)。
  要件にしないと`any RecipeRepository`越し呼び出しで既定実装が静的ディスパッチされ、
  RemoteのAPI呼び出しへ切り替わらない(動的ディスパッチのために必須)。
- Remoteはこれをoverrideし、範囲をそのままCalendar API(from/to)へ渡す。
- Fixtureは既定実装のまま(従来と同じ結果)。

これにより、Remoteでは`CalendarUseCase.loadMonth`が当月(約31日)、`TimelineUseCase.load`が期間
(約60日)のCalendar APIを1回ずつ呼ぶ。全期間の過剰取得を避け、いずれも92日上限以内に収まる。

### データフロー(Before / After)

Before(Fixtureのみ):

```
Calendar/Timeline/Detail → ViewModel → UseCase → RecipeRepository = FixtureRecipeRepository(同梱データ)
```

After(取得元を切替可能):

```
Calendar/Timeline/Detail → ViewModel → UseCase → RecipeRepository
   ├─ .fixture → FixtureRecipeRepository(同梱データ)
   └─ .remote  → RemoteRecipeRepository → APIClient → URLSession → Go API → MySQL
MealLog(全取得元共通) → MealLog UseCase → MealLogRepository → SwiftDataMealLogRepository → SwiftData
```

### 各画面の統合

- **Calendar**: `loadMonth`が`dailyEntries(in: 当月範囲)`で掲載を取得(マーカー用)。月ごとの
  読込状態・requestID照合・重複抑制(PR #9)はそのまま。失敗月は再表示(onAppear再発火)で再取得する。
- **Timeline**: `load(in:)`が`allRecipes()`(名称解決用)＋`dailyEntries(in: 期間)`＋SwiftDataの
  MealLogを統合する。掲載日と調理日は別物のまま保持。検索・フィルタ・Empty/Error/Retryは既存UIを踏襲。
- **Recipe Detail**: `recipe(for:)`で詳細取得。404は`nil`→「見つかりません」。失敗時に再読み込みボタンを追加。
  Hero画像はローカルAsset(Recipe ID由来)で、無ければプレースホルダー(既存挙動)。

### N+1の回避

- Calendar: 月あたりCalendar API 1回。掲載件数ぶんの詳細取得はしない(マーカーはID/件数で足りる)。
- Timeline: 一覧API(ページング1系統)＋Calendar API 1回。行のタイトルは一覧の概要で解決し、掲載ごとの
  詳細取得(N+1)を発生させない。
- Recipe Detail: 遷移時に`/recipes/{id}`を1回。

### Recipe IDの整合性

Remote Recipeも既存のDomain型`RecipeID`(文字列ラップ)をそのまま使い、IDを振り直さない。
これによりGo APIのRecipeとSwiftDataのMealLog(recipeIDを保持)が同一レシピを指せる。
Remote側でRecipeが取得できなくなっても、既存MealLogは`recipeID`を保持するだけなのでクラッシュしない
(Timelineは参照解決できない項目を遷移不可として扱う)。

### 失敗時の扱いと中断

- `APIClientError`を`LocalizedError`化し、画面に出す日本語メッセージを型側に持たせた。
- 通信失敗・タイムアウト・500・404・デコード/変換失敗を型で区別し、`CancellationError`は
  サーバー障害と区別して画面エラーにしない(既存方針を踏襲)。
- Remote失敗時にFixtureへ暗黙フォールバックしない。

### ATS

`NSAllowsArbitraryLoads`(グローバル無効化)をやめ、`NSAllowsLocalNetworking`へ変更した。
ローカル(localhost/*.local)宛てのみ平文HTTPを許可し、インターネット宛てのATS保護は維持する。

## 代替案

- **UseCase/ViewModelを取得元ごとに分岐**: 画面コードが取得元を意識し密結合になる。Composition Root集約を選択。
- **allDailyEntries()を使い続けてRemoteで全期間取得**: Calendar APIはレンジ前提で全期間概念が無く、
  過剰取得になる。範囲取得メソッドで必要分だけ取る。
- **Remote失敗時にFixtableへフォールバック**: 障害を隠す。本PRは失敗を可視化する方針。
- **ATSグローバル無効化の継続**: 要件に反する。ローカル限定例外に縮小。

## 影響・非対象

- StateMachine(State/Action/Effect/Reducer)は非変更。範囲取得のためUseCaseと`RecipeRepository`に
  最小の追加(dailyEntries(in:))のみ。
- SwiftData Schema/MealLog保存仕様/アニメーション/Navigation/Snapshot基準画像は非変更。
- Offline Cache・MealLogのRemote同期・Backend改修は本PRの対象外。

## トレードオフ

- `allDailyEntries()`はProtocolに残す(範囲外の全走査が要る実装・既定実装の土台として)。Remoteの
  `allDailyEntries()`は基準日±45日の有限ウィンドウのままで、Calendar/Timelineは範囲取得を使う。
- Debug環境変数での取得元切替は、実行中の切替UIを持たない(本PRは起動時選択で十分という判断)。
- GUIでの画面表示確認は実機/Simulator手動QAに委ね、自動テストはUseCase経由のE2E(実API接続)で担保する。
