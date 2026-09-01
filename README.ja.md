# task-clock-gui

[task-clock](https://github.com/nlink-jp/task-clock) スケジューラーの
macOS メニューバーフロントエンド。

task-clock は全発火を「予定 vs 実績」で記録します。本アプリはその記録を
「実際に気づける場所」= メニューバーに置きます。すべて定刻どおりの間は
無音（時計アイコンのみ）、タスクが予定を食い潰した瞬間に超過バッジ
（"⚠ 12m"）で発言し、デーモン自体に到達できないときは疑問符の別状態を
示します。ポップオーバーには全タスクの状態・次回実行・最終結果が並び、
即時実行・pause/resume・reload・最終 run ログの Finder 表示ができます。

## 特長

- **既定で無音のメニューバー**: 正常時は時計のみ。超過時のみ超過時間付き
  バッジ、デーモン到達不能時は疑問符 — 「不明」を「正常」とも「エラー」とも
  偽装しない
- **タスク行**: 状態（idle / running / overrun / paused / disabled）、
  トリガー（`*/30 * * * *` or `success + 30m`）、next run（具体時刻 /
  「after current run」/「on success + N」）、last run（ok / exit N /
  missed+理由）
- **その場のアクション**: 即時実行（2 クリックのインターロック付き —
  1 回目で武装、3 秒以内の 2 回目で実行、放置すれば自動解除）、タスクごとのオン/オフスイッチ
  （pause/resume — デーモンが永続化するので再起動を跨いで持続）、タスク定義の
  reload、最終 run ログの Finder 表示 — 失敗は操作したその画面に表示。
  config で `enabled = false` のタスクにはスイッチを出さない（その層は
  tasks.d の領分で、何も起きないコントロールは嘘になるため）
- **パネルのサイズ変更**: 端・角のドラッグで自由に変更（OS ネイティブ）。
  サイズは記憶されます
- **run 履歴**: タスク行をクリックすると予定 vs 実績の記録 — 発火ごとに
  1 行（予定時刻・開始遅延・所要時間・ok / exit N / missed+理由）、各行から
  収集ログを 1 クリックで表示。実行中の run はライブ更新
- **ターミナル不要のデーモン管理**: 常設のパイロットランプ行 — 緑（稼働）/
  橙（動くはずなのに無応答、Restart ボタン付き）/ 灰（停止、または未インス
  トール）— と、動作状態の電源スイッチ（同梱 CLI の `task-clock start`/
  `stop`。停止しても実行中タスクは殺されず、停止はログインを跨いで持続）。
  未セットアップの機体では最初のスイッチ ON が launch agent のインストール
  を兼ねる。明示のセットアップ操作（インストール / 2 クリックのアンインス
  トール）はフッターの Reload の隣に
- **ログイン時起動**トグル（SMAppService）。System Settings での承認が要る
  場合は正直にそう伝える
- **通知**: overrun への突入・run 失敗・デーモン到達不能でバナー表示。
  許可は初回起動時に要求（一度きりのプロンプトに応答してください）。継続中の
  状態はバナーを繰り返さない
- **自己完結**: Developer ID 署名済み task-clock CLI を同梱し `--json` で
  実行。config・API キー・デーモン接続は CLI が所有

## 動作要件

- macOS 14+（Apple Silicon）
- 設定済みの task-clock デーモン（[task-clock README](https://github.com/nlink-jp/task-clock)
  参照）— アプリ自体に設定は不要

## ビルド

```bash
cd ../task-clock && make build   # CLI が .app に同梱される
cd ../task-clock-gui
make build-app                   # dist/TaskClock.app（署名済み）
make test
```

## ドキュメント

- [RFP / 設計文書](docs/ja/task-clock-gui-rfp.ja.md)
  （[English](docs/en/task-clock-gui-rfp.md)）
- [English README](README.md)

## ライセンス

[MIT](LICENSE)
