# 0006. Recipe と MealLog を統合する Timeline の責務設計

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 6（Recipe & MealLog Timeline Feature）
- 前提: PR #6〜#10（Recipe/MealLog Domain・Repository・StateMachine・SwiftData・Calendar統合・Recipe Detail/MealLog Editor / ADR 0003・0004・0005）

## Context

既存の「一覧」タブを、日付別のレシピ掲載情報とユーザーの調理記録(MealLog)をまとめて閲覧できる
Timeline画面へ発展させる。要件は「日付降順セクション」「種別フィルタ(すべて/レシピ/作った記録)＋検索の組み合わせ」
「レシピ項目→既存Recipe Detailへ遷移・MealLogは閲覧のみ」「Loading/Empty/Error/Retry、検索0件と取得0件の区別」
「保存/編集/削除でTimelineが最新化」。

制約として、CalendarとTimelineでRepositoryを重複実装しないこと、NavigationStackを二重生成しないこと、
既存の月画面(スクロール/今日復帰/タブ復元/イベントドット/掲載マーカー)を壊さないこと、
Swift 6 strict concurrency(@MainActor ViewModel、@unchecked Sendable等の禁止)、
初回取得を全月ではなく期間限定(約60日)にすること、が課される。

## Decision

1. **Timeline専用Repositoryを作らず、UseCaseで既存Repositoryを合成する**:
   `TimelineUseCase.load(in range: ClosedRange<DateKey>)` が
   `RecipeRepository.allRecipes()/allDailyEntries()` と `MealLogRepository.summaries(in:)` を
   `async let` で並行取得し、`TimelinePayload(dailyEntries/mealLogs/recipes)` にまとめて返す。
   掲載割当は取得後に `range.contains($0.dateKey)` で期間内へ絞る。
   - 理由: 「レシピ掲載」と「調理記録」は別Aggregateで既存Repositoryがそれぞれ責務を持つ。
     統合は取得の都合に過ぎず、永続化の責務ではないため、新Repositoryは重複になる。
     UseCaseを合成点にすることでCalendarとTimelineが同じRepositoryを共有し、整合性と差し替え容易性を保つ。

2. **取得(UseCase/Payload)と表示変換(Factory/ViewData)を分離する**:
   期間内の生Domain Model(Payload)を取得する責務と、ViewDataへの変換・結合・グルーピング・並べ替えの責務を分ける。
   `TimelineViewDataFactory` が Payload から `TimelineEntryViewData`(フラットな表示単位)を生成し、
   さらに `makeSections(entries:filter:searchText:)` でフィルタ・検索・日付降順セクション化する。
   - レシピ掲載はRecipeをidで結合し表示名/概要を解決。MealLogは関連レシピ名を同様に解決し、
     解決できない場合も `recipeMissing` を立てて安全に表示する(クラッシュさせない/遷移させない)。
   - 同日内は種別順(掲載レシピ→作った記録)→id の安定順で並べ、描画の揺れを防ぐ。

3. **フィルタ・検索はView側(@State)でローカル適用し、Repositoryへ都度アクセスしない**:
   取得済みの `entries` に対しFactoryが純粋関数的にフィルタ/検索を適用する。
   検索対象は各エントリが事前に持つ `searchableText`(レシピ名/概要、メモ、関連レシピ名を連結)で、
   フィルタと検索は組み合わせ可能。再取得を伴わないため入力に対して即応する。
   - 「取得0件(`isEmptyData`)」と「フィルタ/検索結果0件(`sections.isEmpty`)」をView側で別分岐にし、
     文言を区別する（要件の「検索0件と無データの区別」を満たす）。

4. **非同期状態のみ一方向StateMachineで管理する**:
   読込は `TimelineState(entries/phase/requestID)` + `Action(onAppear/reload/beginLoading/loadSucceeded/loadFailed)`
   + 純粋Reducer + `Effect.load` + ViewModel で表現する。
   - `requestID` による陳腐化チェックで、古い結果が新しい取得を上書きするレースを防ぐ。
   - `loadFailed` は既存 `entries` を保持する（失敗時も直前の表示を消さない）。
   - `onAppear` は `phase == .idle` のときのみ取得し、タブ往復での無駄な再取得を避ける。`reload` は常に再取得。
   - フィルタ/検索は非同期状態ではないためStateMachineに載せず(上記3)、過剰な状態分割を避ける。

5. **初回取得は参照日基準の期間限定(約60日)にする**:
   ViewModelが `referenceDate` から過去45日〜未来15日の `ClosedRange<DateKey>` を算出しUseCaseへ渡す。
   全月を舐めないことで初回コストを抑える。DateKeyはAsia/Tokyo固定暦で安定キー化する(既存方針を踏襲)。

6. **保存結果の反映はDesign B(再取得)をTimelineに採用する**:
   MealLog保存/編集/削除時、ルートの共通クロージャ `handleMealLogSaved` が
   Calendarへは確定値直接反映(Design A、ADR 0005)、Timelineへは `reload` を通知する。
   - 理由: Timelineは「期間内の掲載＋記録の結合リスト」で、Calendarのような月単位の重複抑制キャッシュを持たない。
     再取得しても抑制特例が不要で実装が単純。両者が同一Repositoryを通すため整合性は保たれる。

7. **NavigationStackはTimelineが単一で所有し、既存Routeを再利用する**:
   `TimelineScreen` が `NavigationStack(path: [CalendarRoute])` を1つだけ持ち、
   レシピ項目タップで `CalendarRoute.recipeDetail` を積み、既存 `RecipeDetailScreen` へ遷移する。
   MealLogは閲覧のみ(編集は本PRでは遷移先を設けない)。欠損レシピ(`recipeMissing`)は遷移しない。
   月画面側のNavigationStackとは独立（二重生成しない）。

## Alternatives

- **Timeline専用のStatisticsRepositoryやTimelineRepositoryを新設**: 既存2Repositoryの合成で足りるため重複になり不採用(上記1)。
- **フィルタ/検索もStateMachine/Reducerに載せる**: 非同期でなく純粋変換のため過剰。Factoryの純関数＋単体テストで担保(上記3・4)。
- **保存反映をDesign A(確定値直接反映)でTimelineにも行う**: Timelineは結合リストで挿入位置の再計算が必要になり、
  再取得より複雑。重複抑制も無いためDesign Bで十分(上記6)。
- **掲載割当をRepository側で期間フィルタして取得**: 既存 `allDailyEntries()` を再利用しUseCaseで絞る方が
  Repository APIを増やさずに済む。件数が増えた場合はRepositoryに期間付きAPIを足す余地を残す。

## Consequences

- 既存の月画面・Repository・StateMachine・Recipe Detailを壊さず、1画面で掲載と記録を横断閲覧できる。
- 取得と表示変換の分離により、グルーピング/フィルタ/検索を単体テストで網羅しやすい。
- 保存操作がCalendarとTimelineの双方へ同一データ源経由で反映され、画面間の不整合が起きにくい。

### デメリット・トレードオフ

- `allDailyEntries()` を全件取得してからUseCaseで期間フィルタするため、掲載割当が大規模化すると無駄が増える
  （その時はRepositoryに期間指定APIを追加する想定。現Fixture規模では問題なし）。
- 期間は過去45/未来15日の固定窓で、窓外の記録は表示されない（ページング/期間拡張は後続）。
- MealLogの編集/削除導線はTimelineからは未提供（閲覧のみ）。保存反映の再取得基盤は用意済み。
- フィルタをView @State で持つため、タブ往復時のフィルタ/検索状態の永続化は行わない（都度リセット）。

## テスト方針と既知の制約

- `TimelineViewDataFactory`(グルーピング/降順/同日共存/同一レシピ複数日/複数記録＋未掲載/安定した一意ID/
  欠損レシピの安全表示/年またぎ/各フィルタ/検索＋組み合わせ/検索0件)、`TimelineReducer`(beginLoading/
  陳腐な成功の無視/失敗時のentries保持)、`TimelineViewModel`(onAppear取得/失敗/キャンセル/loaded時のonAppear非再取得/
  reloadで最新反映)を単体テストで検証(Phase 6追加分)。ライブラリ＋Appはクリーンビルドを確認。
- Simulatorでの実画面確認は、月タブ保持・Timeline初期描画・セクション日付降順・掲載レシピ行・
  フィルタ/検索UIの表示までを確認した。一方、セグメント切替タップとリストのスワイプがautomationで安定して
  発火しなかったため、「作った記録フィルタ適用結果」「検索結果の実画面」「Timelineからの詳細遷移」の実機操作は**未検証**。
  これらのロジックは上記単体テストで担保している。実機(物理デバイス)での確認も**未検証**。
