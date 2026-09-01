# AGENTS.md — task-clock-gui

## Summary

task-clock デーモンの macOS メニューバーフロントエンド (AppKit の
NSStatusItem + リサイズ可能 NSPanel が殻、中身は SwiftUI)。同梱の署名済み task-clock CLI を `--json` で実行して状態を
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
  App.swift                  #   NSApplicationDelegateAdaptor + placeholder Settings scene
  AppController.swift        #   NSStatusItem + リサイズ可能 NSPanel（起動フック・TCC 要求・ボタン描画）
  AppModel.swift             #   ポーリング（30s/5s）+ App Nap opt-out + アクション + 遷移通知
  CLIRunner.swift            #   CLI 実行 + stderr 分類（daemonDown は独立状態）
  LoginItem.swift            #   SMAppService（曖昧 status は「未登録」に畳む）
  Notifier.swift             #   UNUserNotificationCenter（起動時に許可要求・拒否は stderr）
  PopoverView.swift          #   タスク行 + アクション + デーモン/ログイントグル + エラー表示
  HistoryView.swift          #   run 履歴ビュー（行タップで遷移、戻るで復帰; 表示写像は Core の HistoryRow.swift）
Tests/TaskClockGUICoreTests/ # decode fixture / 状態写像 / レイアウト / ガード / 解決順
```

## Gotchas

- **通知許可プロンプト未回答のまま kill 厳禁**（永久 denied 化 — 復旧は
  System Settings › Notifications のみ）。.app スモークテストで kill する前に
  プロンプトの有無を必ず確認。TCC 要求は AppStart.once（起動時）にある。
- daemonInstalled（plist 存在）と daemonUp（API 応答）は別状態。plist パスは
  Core の `daemonPlistPath`（CLI の label `jp.nlink.task-clock` が契約）。
- **殻は AppKit**（AppController: NSStatusItem + NSPanel）— MenuBarExtra は
  ユーザーリサイズ不可のため移行済み（グリップ方式は違和感で廃案）。NSPanel の
  鉄則: styleMask に `.nonactivatingPanel` 必須（無いと起動直後~30s 開かない）、
  `hidesOnDeactivate` 禁止（isVisible が腐りトグルが空振り）、click-away は
  applicationDidResignActive で明示 orderOut + 表示直後 0.5s の grace、
  setFrameAutosaveName + 表示時に visibleFrame へクランプ。移植元は
  instant-translate の AppController。
- **click-away は didResignActive だけでは不完全** — .nonactivatingPanel は
  アプリが一度も active にならない経路があり resign が来ない。表示中のみ
  global+local マウスモニタで自前クローズ（status-lens 移植; local は
  status button の window を除外しないと close→再 open で閉じられなくなる。
  NSEvent は非 Sendable — window を先に取り出してから assumeIsolated）。
- タスク行の HStack: テキスト側は `frame(maxWidth:.infinity)` + truncate、
  コントロール側は `fixedSize()+layoutPriority(1)` — 長い状態文でボタンが
  押し出される回帰を防ぐ組。片方だけでは効かない。
- 即時実行ボタンは 2 クリックインターロック（TaskRow の runArmed、3s で
  自動解除）— 単発クリックでタスクを起動させない（ユーザー要件）。
- **daemon-down 通知は「登録が残ったまま落ちた」ときだけ**（KeepAlive 失敗 =
  異常）。登録ごと消えた停止（GUI スイッチ OFF / `task-clock uninstall`）は
  意図的停止なので通知しない — 意図は intent フラグでなく観測可能な状態
  （installedNow）から導く。transitionEvents のテストがこの規則を固定。

- CLI の stderr 文言（"daemon is not running" 等）に `CLIRunner.classify` が
  依存。CLI 側の文言変更時はここも追随（テストが fixture で守る）。
- `history` の CLI フラグは位置引数の**前**（stdlib flag: `history -limit 5 <task>`）。
- デーモン停止 (`CLIError.daemonDown`) はエラーバナーにしない — 独立した
  表示状態（menu bar `clock.badge.questionmark` + ポップオーバー案内文）。
- 詳細な罠一覧は CLAUDE.md の invariants を参照。
