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
- **その場のアクション**: 即時実行、pause / resume、tasks.d の reload、
  最終 run ログの Finder 表示 — 失敗は操作したその画面に表示
- **ターミナル不要のデーモン管理**: 「Background daemon」トグルが同梱 CLI
  経由で launch agent を登録/削除。デーモン停止画面には Start / Reinstall
  ボタン
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
