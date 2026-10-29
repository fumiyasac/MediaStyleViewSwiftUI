# 0015. Remote Recipeの永続キャッシュと通信障害時の復旧戦略

- ステータス: 承認
- 日付: 2026-10-30
- 関連: [0012](0012-go-backend-recipe-calendar-api.md) / [0013](0013-swift-remote-repository-go-backend-api-boundary.md) / [0014](0014-remote-recipe-integration-calendar-timeline-detail.md)

## コンテキスト

PR #20までで、Go Backend APIとSwiftUIのRemote Recipe連携(Calendar/Timeline/Recipe Detail)が完成した。
本フェーズ(Phase 15)では、Go Backendへ接続できない場合でも、過去に正常取得したRecipeとCalendar掲載情報を
利用できるようにする。ただしキャッシュ(保存済み)とサーバーの最新データを混同させない。

制約:

- MealLogは引き続きSwiftData。MealLogの新規キャッシュやRemote同期は実装しない。
- 既存のRecipeRepository Protocol(Domainのみ返す)とMVVM + StateMachineを大きく変えない。
- Remote失敗時にFixtureへ暗黙フォールバックしない。CancellationはFallbackトリガーにしない。
- Swift 6のActor Isolationに適合（@unchecked Sendable等を使わない）。
- 既存UI・Snapshot基準画像を大きく変えない。

## 決定

### 永続化方式: Codable + JSON File + actor

URLCache / JSON File / SwiftData を比較し、**Codable + JSON File + actor** を採用する。

| 方式 | 長所 | 短所 | 判断 |
|---|---|---|---|
| URLCache | 透過的・容易 | 取得日時/鮮度/取得元をアプリが制御しにくい。Domain変換後の保存に不向き | ✗ |
| SwiftData | クエリ・リレーション | 既存MealLog Schemaへ影響。Recipeキャッシュ用に別Schema導入は重い | ✗ |
| JSON File + actor | Schema Version・取得日時・取得範囲をアプリで明示管理。小規模データに十分。テストしやすい | 大規模データには非効率 | ✓採用 |

保存先はApplication Support配下(`RecipeCache/<namespace>/`)。OS管理の一時Cacheではなく「アプリが必要とする
保存済みコンテンツ」として扱う（ただしアプリ削除/障害で失われ得る前提は保つ）。ファイル書き込みはatomic write。

### CacheStoreの責務とActor Isolation

`FileRecipeCacheStore`(actor)がファイル読み書きを担う。actorにする理由は、同一ファイルへの複数Taskからの
同時書き込みで破損し得るため直列化して競合を防ぐこと。SwiftUI/Gin/MySQLは一切知らない。

- 読み込みは失敗(未存在/破損/未知Schema)時に`nil`(=キャッシュ無し)を返し、画面を壊さない。
- 書き込みはベストエフォート（失敗しても正常取得データの表示を妨げない）。
- 保存時に既存レコードより古い`fetchedAt`なら上書きしない（古い通信結果が新しいキャッシュを壊さない）。

### キャッシュキーと期間完全性

- レシピ一覧: 固定キー（全件概要）。初回ページのみを全件として扱わない。
- レシピ詳細: Recipe ID単位。詳細API由来(材料・手順あり)のみ`hasDetail=true`で保存し、一覧由来の概要
  (`hasDetail=false`)を詳細として扱わない（完全性の区別）。
- カレンダー掲載: 取得期間(from/to)をそのままキー(`<from>_<to>`)にする。別範囲は別キャッシュ。
  一部期間を期間全体の完全な結果として扱わない。
- 名前空間: API Base URLのhost:port由来。Debug等で接続先が変わっても別サーバーのデータを混同しない。
- Recipe IDはGo API/Domainで一致させ、保存時にUUIDを新規生成しない。

### Fresh / Stale / Expired

`RecipeCachePolicy`が`fetchedAt`と注入された現在時刻から判定する（テストは固定Clockで実時刻に非依存）。

- Fresh: 最終正常取得から24時間以内
- Stale: 24時間超〜30日以内（表示は許容するが「保存済み・要更新」を提示）
- Expired: 30日超（フォールバックに使わない）
- `fetchedAt`が未来（端末時計ズレ）の場合は負経過で誤判定しないようFresh扱い。

### 取得戦略: Network-first + Cacheフォールバック

`CachedRecipeRepository`がRemoteとCacheを調停する。常にRemoteを試み、成功したらキャッシュ更新＋最新を返す。
通信障害クラスの失敗時のみ、期限内の保存済みをStale表示で返す。

| ケース | 挙動 |
|---|---|
| A: キャッシュ無/Remote成功 | 取得→変換→保存→最新表示 |
| B: キャッシュ有/Remote成功 | 再取得して最新へ更新・保存（常にサーバー変更を反映） |
| C: キャッシュ有/Remote失敗(通信障害) | 保存済みをStale表示＋取得日時提示＋再試行 |
| D: キャッシュ無/Remote失敗 | エラー表示＋再試行（Fixtureへ切替えない） |
| E: Remoteが空配列 | 正常な空として保存（古いデータで補完しない） |

cache-first(早期表示→再取得)でなくNetwork-firstにした理由: 既存の単一returnなRepository/UseCase/ViewModelを
大きく変えずに「オフラインで保存済みを出す」主目的を満たすため。オフラインは接続失敗が即座に返るため実用上の
待ちは小さい。二段階のcache-then-refreshは次PRの検討事項（トレードオフ）。

### HTTP Error別のFallback方針

| 失敗種別 | フォールバック |
|---|---|
| 未接続 / connection refused / timeout / HTTP 5xx / 不正応答 | 可（保存済みがあればStale表示） |
| HTTP 400 / 404 / Decoding / Mapping | 不可（オフライン障害と同一視しない。伝搬する） |
| Cancellation | 不可（トリガーにしない。CancellationErrorのまま伝搬） |

404は「見つからない(nil)」として返し、古い詳細を黙って表示し続けない。Decoding/Mapping Errorもキャッシュで
隠さず伝搬する。

### 取得元(RecipeDataOrigin)のUI伝達

Domainへ出所を混ぜず、`RecipeDataOrigin`(remote / cache(fetchedAt,isStale))をUseCaseのPayloadとViewModelの
Stateへ添えて表示層まで運ぶ。`CacheAwareRecipeReading`(出所付きの読み込み)をCachedRepositoryが提供し、UseCaseは
実体が対応していれば出所付きで読む（Fixture等は`.remote`扱い）。保存済み表示中は共通バナー(`OfflineCacheBanner`)で
保存日時とStaleを提示する。`.remote`では非表示のため従来画面・Snapshotの見た目を保つ。

### キャッシュとLocal MealLogの所有関係

キャッシュはRecipe/掲載の「サーバー由来データの写し」。MealLogはユーザーが作成した一次データでSwiftDataが所有する。
`removeAll()`はキャッシュ名前空間のディレクトリのみ削除し、SwiftData(MealLog)には一切触れない。

### 失効・破損・Schema変更

- 期限(Expired)超過はフォールバックに使わない。
- 破損JSON/未知Schemaは読み込み時に`nil`で安全に無視（例外を投げない）。
- フィールド構造変更時は`RecipeCacheSchema.current`を増やし、旧レコードは無視（誤移行による事故防止）。

## Consequences

- オフラインで取得済みのCalendar月/Timeline/Recipe詳細を閲覧できる。未取得範囲は空と誤認せずエラーにする。
- キャッシュ/最新を混同せず、保存日時と鮮度を提示できる。
- API復旧後はRetry(既存の再取得)で最新へ更新され、エラー表示が解消される。
- MealLogはキャッシュ削除の影響を受けない。

### パフォーマンス・メモリ

- レシピは数十件規模のためJSONで十分軽量。読み書きはactorで直列化し、1取得=1ファイルI/O程度。
- 一覧/範囲は1ファイルにまとめて保存し、ファイル数の増大を抑える（詳細はID単位）。

## 代替案

- URLCache / SwiftData（上表のとおり不採用）。
- cache-first二段階表示（UX最良だがViewModel改修が大きいため次PRへ）。
- Remote失敗時のFixtureフォールバック（障害を隠すため不採用）。

## トレードオフ

- Network-firstのためオンライン時は毎回Remoteへ出る（サーバー変更を常に反映できる利点と表裏）。
- `allDailyEntries()`はキャッシュ対象外（Calendar/Timelineは範囲取得を使うため実害なし）。
- 取得元のUI提示は最小限のバナーに留め、既存レイアウト・Snapshotへの影響を避けた。
