# 0005. Recipe Detail と MealLog Editor の状態管理・保存結果の反映方針

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 5（Recipe Detail & MealLog Editor）
- 前提: PR #6〜#9（Recipe/MealLog Domain・Repository・StateMachine・SwiftData・Calendar統合 / ADR 0003・0004）

## Context

カレンダーで発見したレシピを閲覧し、実際に作った記録をSwiftDataへ保存して、その結果をカレンダーの
調理済みマーカーへ反映する体験を、既存の一方向データフロー・SwiftData隔離(ADR 0003)・月ごとStateキャッシュ
(ADR 0004)を壊さずに追加する。既存Calendar(スクロール/タブ/イベントドット/一覧検索)は維持する。

## Decision

1. **Recipe DetailとCalendarの責務境界**: Recipe DetailはRecipeID起点で独立して動く画面。
   Calendarは「どの日にどのレシピが掲載されているか」と「どの日に調理記録があるか」の表示に責務を限定し、
   レシピ本体の取得・表示はDetail側が担う。CalendarはNavigationでRecipeIDを渡すだけ。
2. **Editor専用StateMachineを採用する**: 保存の非同期状態(editing/saving/saved/failed)は二重保存防止・
   失敗時の入力保持・再試行の要があるため、`MealLogEditorState/Action/Effect/Reducer/ViewModel`を新設する。
   一方、Recipe Detailの読込はloading/loaded/failedの素直な3値で、専用Reducerは設けずViewModelに畳む
   （「重要な非同期状態遷移を明示」しつつ過剰な分割を避ける）。
3. **保存結果をCalendarへ反映する方法（Design A: State直接反映）**:
   保存で得た確定値`MealLogSummary`を `CalendarAction.mealLogSaved` でCalendarViewModelへ送り、
   Reducerが該当「調理日の月」のmealLogsへ直接反映する。再取得(Design B)は採らない。
   - 理由: ADR 0004のReducerは既読/読込中の月の再読込を抑制するため、Design Bは「強制再読込」の特例が必要になり
     複雑化する。また再取得は非同期で、古い結果が新しい保存を上書きするレースの余地がある。
     確定値を直接入れるDesign Aはレース無し・即時反映で、掲載日≠調理日/別月/同日複数/編集での日付変更に強い。
   - 編集で調理日(=月)が変わるケースに備え、`mealLogSaved`は同一idを全月から除いてから対象月へ入れ直す。
     削除は`mealLogDeleted`で全月から除去。
4. **調理日と掲載日を区別**: Editorの調理日初期値はユーザーの現在日付(`Date()`)で、掲載日は流用しない。
   EntityはcookedAtから導出した`dayKey`(調理日)を保持し、掲載日(`DailyRecipeEntry.dateKey`)と混同しない。
5. **Navigation設計**: 既存`CalendarMonthScreen`の単一NavigationStackを尊重し、型付き`CalendarRoute`と
   `path: [CalendarRoute]`(MonthScreenの@State)で遷移する。RouteにはRecipeID/DateKeyのみ載せ、SwiftData Entityは渡さない。
   掲載なしの日は遷移しない。複数掲載日は先頭レシピを開く（ピッカーUIは後続）。
6. **SwiftDataとのActor Isolation**: 保存はPR #8の`@ModelActor SwiftDataMealLogRepository`を再利用。
   ModelContextとEntityはactor内に留め、境界外へはSendableな`MealLogSummary`のみ返す。
   EditorのViewModelは`@MainActor`、保存Taskは`[weak self]`で保持し、Sheet離脱で永続化を中断しない
   （保存中は対話的dismissを抑止）。保存成功時のみSheetを閉じる。

## Alternatives

- **保存後に影響月を再取得(Design B)**: 上記3の理由で不採用（重複抑制との競合・レース）。
- **Recipe Detailにも専用Reducer**: 読込3値に対し過剰。ViewModelへ畳んで単体テストで担保。
- **MealLogUseCaseを新設**: 既存MealLogRepositoryのCRUDで足りるため重複新設せず、ViewModelへRepositoryを注入。
- **SwiftData `@Query`をDetail/Editorで直接使用**: EntityがPresentationへ漏れ、ADR 0003の方針と相反→不採用。

## Consequences

- カレンダー体験を保ったまま、閲覧→記録→反映のループが成立する。
- 確定値の直接反映により、保存直後にマーカーがレースなく更新される。
- Recipe本体はDomain Modelのまま（SwiftData化しない）で、Repository差し替え・テストが容易。

### デメリット・トレードオフ

- `mealLogSaved`はまだ読み込んでいない月にも反映するため、その月に未ロードのログがあると「保存分のみ表示」になる
  （次回その月をロードすれば全件に揃う。実害は小さい）。
- 複数掲載日のレシピ選択UIは未実装（先頭を開く）。1日複数掲載は現Fixtureでは発生しない。
- 編集・削除UIは本PRでは未提供（Reducer/通知基盤は用意済み）。

## テスト方針と既知の制約

- Reducer(Editor/Calendar反映)とViewModel(Editor/Detail)を単体テスト。保存の成功/失敗/再試行/二重抑制/キャンセル、
  掲載日≠調理日の反映、再取得での非重複、編集での月移動、削除を検証。SwiftData CRUD/再起動永続はPR #8のテストを再利用。
- UIスナップショット自動化は未導入。Simulatorでの戻る操作はautomationで不安定なため、
  「保存→Calendarマーカー更新」の実画面は単体テスト＋保存成功パスの発火確認で担保し、実機スクショは一部未取得。
