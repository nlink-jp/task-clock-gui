# AGENTS.md — task-clock-gui

## Summary

task-clock デーモンの macOS メニューバーフロントエンド (SwiftUI
MenuBarExtra)。同梱の署名済み task-clock CLI を `--json` で実行して状態を
表示し、trigger / pause / resume / reload を提供する。正常時は無音、超過
とデーモン停止のみメニューバーで発言する。設計の正は
`docs/ja/task-clock-gui-rfp.ja.md`。

- Bundle ID: `jp.nlink.task-clock-gui` / App 名: TaskClock
- Swift SPM (swift-tools 6.0), macOS 14+, darwin/arm64
- 依存: なし（標準フレームワークのみ）。データ経路は同梱 CLI

## Build / test commands

```bash
make build-app   # 署名済み dist/TaskClock.app（../task-clock/dist/task-clock を同梱）
make test        # swift test（Core の純関数テスト 19+件）
make package     # notarize + staple + zip
make run         # デバッグ実行（メニューバーに出る; DEBUG は dev パスの CLI も探す）
```

CLI が無いと build-app は fail-closed（先に `cd ../task-clock && make build`）。

## Structure

```
Sources/TaskClockGUICore/    # 純関数層（テスト対象）
  Models.swift               #   CLI --json の decode（open-set・欠損許容）
  StateMapping.swift         #   表示状態写像・メニューバー集約・時間整形
  PopoverLayout.swift        #   ポップオーバー高さ（floor/cap）
  SingleInstance.swift       #   単一インスタンス判定（status-lens から移植）
  BinaryResolution.swift     #   CLI バイナリ解決順（bundled が信頼アンカー）
Sources/task-clock-gui/      # UI 層（薄く保つ）
  Entry.swift                #   @main enum Main: version/help → ガード → App.main()
  App.swift                  #   MenuBarExtra(.window) + 起動フック
  AppModel.swift             #   ポーリング（30s/5s）+ App Nap opt-out + アクション
  CLIRunner.swift            #   CLI 実行 + stderr 分類（daemonDown は独立状態）
  PopoverView.swift          #   タスク行 + アクション + エラー表示
Tests/TaskClockGUICoreTests/ # decode fixture / 状態写像 / レイアウト / ガード / 解決順
```

## Gotchas

- CLI の stderr 文言（"daemon is not running" 等）に `CLIRunner.classify` が
  依存。CLI 側の文言変更時はここも追随（テストが fixture で守る）。
- `history` の CLI フラグは位置引数の**前**（stdlib flag: `history -limit 5 <task>`）。
- MenuBarExtra ラベルの `.onAppear` が唯一の起動フック（AppStart.once）。
- デーモン停止 (`CLIError.daemonDown`) はエラーバナーにしない — 独立した
  表示状態（menu bar `clock.badge.questionmark` + ポップオーバー案内文）。
- 詳細な罠一覧は CLAUDE.md の invariants を参照。
