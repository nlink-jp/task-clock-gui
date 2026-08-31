# RFP: task-clock-gui

> Generated: 2026-08-31
> Status: Draft
> 親設計: task-clock RFP（docs/ja/task-clock-rfp.ja.md — 本 GUI は同 RFP §4 で「別プロジェクト」として計画されたもの）

## 1. Problem Statement

task-clock は周期タスクの「予定 vs 実績」を完全記録するが、その観測窓は CLI
（`task-clock status` / `history`）に限られる。スケジューラーの価値は「スキップや
超過が起きた瞬間に気づける」ことにあり、それには常時視界に入る表示面 — メニュー
バー — が要る。task-clock-gui は task-clock デーモンの状態をメニューバーに常駐
表示し、超過（overrun）とデーモン停止を一目で伝え、トリガー・pause/resume・
reload をポップオーバーから実行できる薄いフロントエンドである。

## 2. Functional Specification

- **メニューバー表示**: 正常時は無音（時計アイコンのみ）。超過発生時のみ
  `clock.badge.exclamationmark` + 超過時間（例 "12m"）、デーモン到達不能時は
  `clock.badge.questionmark`（「不明」は「エラー」とも「正常」とも区別する）
- **ポップオーバー**: タスクごとに 状態（idle / running / overrun / paused /
  disabled）・トリガー（cron 式 or `success + 30m`）・next run・last run を表示。
  行内アクション: 即時実行（trigger）、pause/resume、最終 run ログの Finder 表示。
  フッター: reload・バージョン・Quit。エラーは操作したその画面に表示
- **ポーリング**: 背景 30 秒 / ポップオーバー表示中 5 秒。App Nap opt-out
  （NSProcessInfo activity）必須 — 無いとタイマーが凍り表示が黙って古くなる
- **データ経路**: 同梱の署名済み task-clock CLI を `--json` で実行（org 定型）。
  config 解決・API キー・HTTP は CLI が所有し、GUI は decode と表示のみ

## 3. Design Decisions

- **Swift SPM + SwiftUI MenuBarExtra(.window)**（macOS 14+, darwin/arm64）。
  既知の罠は既存 GUI 群の教訓で対処: ScrollView には PopoverLayout の具体的高さ、
  ルートに fixedSize、単一インスタンス二層ガード（LSMultipleInstancesProhibited +
  enum Main での実行時判定）
- **CLI 同梱**が信頼アンカー（Resources 内、--deep 署名）。env 上書きは DEBUG のみ
- **曖昧状態で UI を disable しない**: 実行して結果を報告する。デーモン停止は
  エラーバナーではなく独立した状態として描く
- **スコープ外**: tasks.d の編集（テキストエディタの領分）、履歴の全文閲覧
  （CLI / ログファイルの領分）、install/uninstall の GUI 化（初期リリースでは見送り）

## 4. Development Plan

- Phase 1 (Core): 状態表示 + アクション（trigger/pause/resume/reload）+ テスト
  （decode fixture・状態写像・レイアウト・単一インスタンス・バイナリ解決）
- Phase 2: 履歴ミニビュー、ログイン時起動（SMAppService — `.notFound` は
  「未登録」に畳む）、通知（overrun streak を UNUserNotification へ）
- Phase 3: アイコン作成、リリース（cask 配布）

## 5. Required API Scopes / Permissions

None（ローカルのみ。デーモンへのアクセスは同梱 CLI 経由）。

## 6. Series Placement

Series: **util-series** — active-lens-gui / sensor-lens-gui と同型の
「署名済み CLI 同梱の薄いメニューバーフロントエンド」。

## 7. External Platform Constraints

- macOS 14+（MenuBarExtra）。Developer ID 署名 + notarize + staple が配布要件
- ポップオーバーの中身はプログラムから開いて検証できない — リリース前に
  実機でユーザー確認する前提で計画（org 教訓）
