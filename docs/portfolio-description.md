# Portfolio Description — Daily Recipe Calendar

ポートフォリオサイト掲載用の紹介文。誇張を避け、実装したことと技術的に考慮した点を具体的に記す。

## A. 短い紹介文（作品一覧カード用）

カレンダーからレシピを見つけ、材料と手順を確認し、作った記録を残せる iOS アプリ。SwiftUI と Swift 6 Concurrency で実装し、レシピは Go 製 API（MySQL）から取得、オフライン用に永続キャッシュを備えています。

## B. 詳しい紹介文

「Daily Recipe Calendar」は、日々の献立をカレンダー起点で楽しむ iOS アプリです。カレンダーには日ごとの掲載レシピと自分の調理記録がマーカーで表示され、レシピ詳細では写真を主役にした Parallax Hero と Collapsing Header で材料・調理手順を閲覧できます。一覧（Timeline）では掲載レシピと調理履歴を日付別に振り返り、検索・フィルタで絞り込めます。

UI は SwiftUI、状態管理は MVVM + 単方向の StateMachine（State / Action / Effect / Reducer）で構成し、Reducer は純粋関数、非同期 I/O は Effect 側に分離しています。レシピデータは Go（Gin / GORM）+ MySQL のバックエンドから URLSession 経由で取得し、Repository パターンで Fixture（同梱データ）と Remote を差し替え可能にしました。通信できないときは端末に保存した永続キャッシュを表示し、保存日時と「要更新」を提示します。調理記録は SwiftData にローカル保存します。

テストは Swift Testing（Unit）と Snapshot Testing（画面の視覚回帰）、Go 側は Unit / Race / MySQL 結合テストを用意し、Docker Compose でバックエンドを再現できるようにしています。

## C. 技術スタック

- iOS: Swift 6 / SwiftUI / Observation / Swift Concurrency / SwiftData / Swift Testing / swift-snapshot-testing
- Backend: Go 1.23 / Gin / GORM / MySQL 8.4
- Infra & Docs: Docker / Docker Compose / golang-migrate / Swagger (2.0) / ADR

## D. 技術的なハイライト

- **写真メディア風の UI 表現**: Parallax Hero・Pull-down Stretch・Collapsing Header（Compact Title）・Zoom Navigation Transition を SwiftUI で実装。Reduce Motion / Dynamic Type / VoiceOver / Dark Mode に配慮。
- **MVVM + StateMachine**: 純粋な Reducer と Effect 分離、requestID による古い非同期結果の破棄、月単位の読み込みキャッシュで連続スクロールを破綻させない設計。
- **Swift 6 Concurrency**: `@MainActor` ViewModel、Sendable な Domain / State、`@ModelActor` の SwiftData Repository、Task Cancellation の適切な扱い。`@unchecked Sendable` 等の回避。
- **Backend 設計**: Domain / UseCase / Adapter / Infrastructure に責務を分離（Clean Architecture 寄り）。GORM を永続化層に閉じ込め、Migration と Seed、Swagger を整備。
- **オフライン対応と障害時の表示**: Codable + JSON File + actor の永続キャッシュ、Network-first + Cache フォールバック、鮮度（Fresh / Stale / Expired）管理、通信失敗とデータ 0 件の区別、API 復旧後の再取得。

## E. GitHub

https://github.com/fumiyasac/MediaStyleViewSwiftUI
