# 0003. SwiftData を Presentation 層から隔離し、@ModelActor Repository で永続化する

- Status: Accepted
- Date: 2026-10-24
- 関連PR: Phase 3（SwiftData による MealLog 永続化基盤）
- 前提: PR #6（Recipe/MealLog Domain・Repository）、PR #7（MVVM + StateMachine）

## Context

Phase 3 で MealLog（調理ログ）のローカル永続化を SwiftData で実装する。
本プロジェクトは Swift 6 language mode（`swiftLanguageModes: [.v6]`）で strict concurrency を有効にしており、
以下の制約がある。

- `ModelContext` は `Sendable` ではなく、スレッド/アクターを越えて共有・操作できない。
- `@Model` で定義する SwiftData Entity は参照型で、`Sendable` ではない。
- 既存の MVVM + StateMachine（`CalendarViewModel` は `@MainActor`、State/Action/Effect は Sendable 値型）と整合させる必要がある。
- `@unchecked Sendable` / `@preconcurrency` / `nonisolated(unsafe)` による警告回避は禁止。

既存の `MealLogRepository` プロトコル（`add/update/delete/summaries(for:)/allSummaries()`、書き込みは `MealLogInput`、読み出しは `MealLogSummary` という Sendable 値型プロジェクション）は、既に「Entity を外へ出さない」前提で設計されている。

## Decision

1. **SwiftData Entity（`MealLogEntity`）は永続化専用**とし、ViewModel / Reducer / State / UseCase へ渡さない。
   境界を越えるのは Sendable 値型 `MealLogSummary` のみ。
2. **`@ModelActor` を採用**し、`SwiftDataMealLogRepository` を actor として実装する。
   `ModelContext` の全操作と Entity → `MealLogSummary` の変換を actor 隔離内で完結させる。
3. 既存の `MealLogRepository` プロトコルに準拠させ、UseCase から差し替え可能にする。
   取得系（`summary(for:)` / `summaries(in:)`）のみ、既存実装を壊さないよう**デフォルト実装付きで最小追加**する。
4. **入力検証は Domain**（`MealLogInput.validate()`）に集約し、Repository は保存前に呼ぶだけにする。
5. ModelContainer は **Composition Root で一度だけ生成**して注入する方針とし、生成は `MealLogModelContainerFactory`（本番/in-memory/URL指定）に集約する。

変換境界:

```
MealLogEntity（@ModelActor隔離内・非Sendable）
  → MealLogSummary（Sendable値型・隔離内で変換）
  → MealLogRepository（Sendable protocol）
  → CalendarUseCase など（将来）
```

## Alternatives

- **View から直接 `@Query` / `@Environment(\.modelContext)` を使う**
  - 利点: ボイラープレートが少なく、SwiftUI と密に統合でき自動更新が得やすい。
  - 欠点: View/State が SwiftData Entity に直接依存し、永続化技術が Presentation 層へ漏れる。
    Entity は非 Sendable のため MVVM + StateMachine（Sendable State、`@MainActor` ViewModel、純粋 Reducer）と相性が悪い。
    テストや Backend 差し替え（将来）時に Repository 境界が無く差し替えづらい。
    → 本プロジェクトの一方向データフロー・差し替え可能性の方針と合わないため不採用。
- **`actor` を自前実装し `ModelContext` を手動管理**
  - `@ModelActor` が生成する `modelExecutor` / `modelContainer` / `init(modelContainer:)` を手書きする必要があり、冗長で誤りやすい。不採用。
- **`MealLogSummary` とは別に読み出し専用 DTO を新設**
  - 既存 `MealLogSummary` が必要情報（id/recipeID/dateKey/cookedAt/rating/memo/servings）を表現できるため不要。新設しない。

## Consequences

- Presentation 層（View/State/Reducer/ViewModel）は SwiftData に依存せず、Repository プロトコル越しにのみ永続化を利用する。
- InMemory 実装（Fixture）と SwiftData 実装を同一プロトコルで差し替えでき、テスト・将来の Backend 統合が容易。
- Entity が隔離外へ出ないため、Swift 6 strict concurrency の警告を回避テクニックなしで満たせる。

### デメリット・トレードオフ

- `@Query` による SwiftUI 自動更新の恩恵を直接は受けられない。将来 View と結線する際は、
  Repository の変更を ViewModel 経由で反映する仕組み（再取得 or 変更通知）が別途必要。
- Entity → `MealLogSummary` の変換コストと、往復の `await`（actor hop）が発生する。
- 取得系の既定実装（`allSummaries()` ベース）は全件取得のため、InMemory では非効率。
  SwiftData 実装では `FetchDescriptor` + `#Predicate` で上書きして効率化している。

## Swift 6 Concurrency への配慮

- `@ModelActor` により `ModelContext`（非 Sendable）を actor 隔離へ閉じ込め、actor 外から直接操作しない。
- actor 境界を越える値は Sendable 値型（`MealLogInput` / `MealLogSummary` / `MealLogID` / `DateKey` / `RecipeID`）に限定。
- Entity（`MealLogEntity`）は Sendable として扱わず、隔離内でのみ生存させる。
- `@unchecked Sendable` / `@preconcurrency` / `nonisolated(unsafe)` は不使用。
- 並行アクセスは actor が直列化するため、複数の非同期処理から同時利用してもデータ競合が起きない
  （テストで50並行 add を検証）。

## SwiftData Entity を Presentation 層へ渡さない理由

- Entity は参照型・非 Sendable であり、`@MainActor` の ViewModel や Sendable な State へ安全に渡せない。
- 永続化技術（SwiftData）を Presentation から分離し、将来の差し替え（Backend 同期など）に備える。
- Reducer を純粋・決定的に保つため、I/O や可変参照（Entity）を State に持ち込まない。

## @ModelActor を採用する理由

- `ModelContext` の隔離・`ModelExecutor`・`init(modelContainer:)` の定型実装を安全に生成でき、
  手書きの actor 実装より誤りが少ない。
- Repository を actor にすることで、CRUD の直列化（データ競合防止）を型レベルで担保できる。
