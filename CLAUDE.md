# CLAUDE.md — task-clock-gui (TaskClock)

Org rules: nlink-jp/.github `CONVENTIONS.md`。設計の正は
`docs/ja/task-clock-gui-rfp.ja.md`。親プロジェクトは ../task-clock。

## Project invariants

- **薄いフロントエンドに徹する。** config 解決・API キー・HTTP・スケジュール
  判断はすべて同梱 CLI（task-clock）が所有。GUI は `--json` を decode して
  表示・操作するだけ。エンジンのロジックを複製しない。
- **同梱 CLI が信頼アンカー**（`CLIRunner` の解決順）。env 上書き
  （TASK_CLOCK_GUI_BIN）は DEBUG ビルド限定を維持。
- **ロジックは TaskClockGUICore へ**（純関数 + テスト）。UI 層は薄く。
- **メニューバーは既定で無音。** 発言するのは overrun とデーモン到達不能のみ。
  「不明」を「正常」にも「エラー」にも畳まない。
- **曖昧状態でコントロールを disable しない** — 実行して結果を同じ画面に表示。
- **MenuBarExtra の罠**: ScrollView には `PopoverLayout.contentHeight` の
  具体的高さ（ideal 高さ 0 で潰れる）、ルートに
  `.fixedSize(horizontal: false, vertical: true)`。
- **単一インスタンス二層ガード**: Info.plist の LSMultipleInstancesProhibited +
  `enum Main` での実行時判定（@main struct App にしない — @StateObject が
  ガードより先に走る）。
- **App Nap opt-out**（AppModel.start の beginActivity）を外さない — 外すと
  ポーリングが凍って表示が黙って古くなる。
- ポップオーバーの中身はプログラムから検証できない — リリース前に実機で
  人間が確認する工程を必ず挟む。

## Build

- `make build-app` → 署名済み dist/TaskClock.app（CLI 同梱; 先に
  ../task-clock で `make build`）
- `make test` をコミット前に必ず実行
