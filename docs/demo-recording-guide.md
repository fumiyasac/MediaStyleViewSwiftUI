# Demo Recording Guide

デモ動画（15〜30 秒想定）を録画するための手順。CI/ヘッドレス環境では自動録画が不安定なため、
手元の Mac + Simulator で手動録画することを推奨する。

## 前提

- Xcode / iOS Simulator（iPhone 17 Pro 相当）
- Fixture モードで録画すれば Backend 不要（オフラインでも安定）。Remote の挙動も見せたい場合は
  Docker Compose で Backend を起動する（`backend/README.md` 参照）。

## 録画シナリオ（約20〜30秒）

1. Calendar を表示（掲載マーカー・今日の強調が見える状態）。
2. 掲載のある日付、または「一覧(Timeline)」からレシピを選ぶ。
3. Recipe Detail へ遷移（Timeline からは Zoom Navigation Transition）。
4. 下方向へスクロールし、Parallax Hero → Collapsing Header（Compact Title）を見せる。
5. 「作った記録を追加」から MealLog Editor を開く。
6. 評価・メモを入力して保存。
7. Calendar / Timeline に保存結果（調理済みマーカー・履歴）が反映されることを見せる。

## 録画コマンド（simctl）

```bash
# 起動中の Simulator に録画開始（Ctrl+C で停止）
xcrun simctl io booted recordVideo --codec=h264 docs/media/demo/recipe-calendar-demo.mp4

# アプリの起動（取得元の指定。Fixture なら省略可）
#   Fixture:
xcrun simctl launch booted com.just1factory.MediaStyleViewSwiftUI
#   Remote（Backend 起動が前提）:
SIMCTL_CHILD_RECIPE_DATA_SOURCE=remote xcrun simctl launch booted com.just1factory.MediaStyleViewSwiftUI
```

## 注意

- 操作を不自然に高速化しない。読み込み完了後の安定した状態を見せる。
- 個人情報・開発用 Secrets が映り込まないようにする。
- ファイルサイズに注意（長尺・高解像度は避ける）。リポジトリを不必要に肥大化させる場合は、
  動画を直接コミットせず、PR やリリースページへの添付・外部ホスティングのリンクを検討する。
- 生成 AI による架空の画面や、実装されていない UI を用いた動画は作成しない。
