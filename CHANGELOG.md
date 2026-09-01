# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) +
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- A failing run longer than one poll interval now raises its failure
  banner: the previous poll sees the run open under the same id, and the
  old new-id-only check read that as "already notified" (verification
  finding) — only runs that started AND failed inside a single poll
  interval ever notified
- Adopted runs (the population the stop/start switch creates) show as
  `running (unmanaged)`, and their finalization — exit unknowable, not a
  failure — no longer risks a false "failed" banner (the daemon records
  it without an exit code, and the banner requires one)
- No control in the panel takes keyboard focus any more
  (`.focusable(false)` across the board): the daemon power switch could
  end up focused, and an accidental Space press stopped the daemon —
  and with it the running tasks (field incident)
- Esc now goes through the same close path as click-away (StatusPanel
  routes cancelOperation to the controller), so closing with Esc no
  longer leaves the 5-second foreground poll running forever
  (verification finding A2)
- Foreground notifications keep a Notification Center entry (`.list`
  added to willPresent) instead of vanishing after the banner (A1)
- Reload is no longer disabled while the daemon is unreachable —
  "down" also covers "starting right now", and a failed reload reports
  in the same view (A5)

### Changed

- The power switch now flips only the daemon's run state (`task-clock
  start`/`stop` — stopping never kills running tasks) instead of
  registering/removing the launch agent: stopping is a daily operation,
  installing is setup, and one switch for both meant uninstalling to
  pause (user feedback). On a fresh machine the first switch-on installs
  the launch agent too (the switch is the run intent; setup is included
  the one time it is needed). The explicit setup control sits in the
  footer beside Reload — install plainly, uninstall behind the
  run-now-style two-click interlock (armed shows as color only). The
  lamp distinguishes gray "stopped (by you)" from orange "should be
  running but isn't", and a deliberate stop still never notifies
- The panel got a design pass against visual noise (user feedback: the
  piecemeal additions read as clutter). State has one idiom everywhere —
  a small dot in the lamp's color grammar (green/orange/red/gray) with
  the caption text carrying the reason; the per-state SF-symbol zoo is
  gone. Three text levels only (title / task name / gray caption).
  Switches align in one right-edge column; header composition is fixed
  in every state (Restart moved into the stalled explanation, the
  freshness timestamp into the lamp tooltip, the cron spec into the
  history header, and the task rows' duplicate reveal-log button was
  removed — each run's log is in the history view). Footer, two rows:
  borderless icon+label Reload and Install/Uninstall on top; the
  launch-at-login checkbox, selectable version, and a power-icon Quit
  (no confirmation — quitting the app never touches the daemon) on the
  bottom row
- Daemon lifecycle actions (start/stop/install/uninstall) run strictly
  in order — a rapid off→on executes the stop fully before the start, so
  interleaved launchctl calls cannot leave the switch and the daemon
  disagreeing
- Panel content is built on open and torn down on close (the org's
  lazy-popover shape) — nothing renders while hidden (A3)
- A hard notification denial is stated in the footer with an Open
  Settings shortcut instead of only on stderr (A6)
- Every SF Symbol name lives in a tested inventory (Symbols); the
  version label is selectable for bug reports (A4, A7)

## [0.4.1] - 2026-09-01

### Fixed

- Clicking outside the panel now closes it. applicationDidResignActive
  alone cannot cover a .nonactivatingPanel (the app may never have been
  active, so no resign event arrives); shown-only global/local mouse
  monitors handle click-away, with the status button excluded so its
  toggle keeps working

## [0.4.0] - 2026-09-01

### Added

- The panel is now natively resizable: drag any edge or corner, and the
  size is remembered. The menu-bar shell moved from `MenuBarExtra` to
  AppKit (`NSStatusItem` + a resizable `NSPanel`), the org's proven shape
  for exactly this — an interim grip-based resize was scrapped as unusable

## [0.3.0] - 2026-09-01

### Fixed

- A long state line squeezed the row's action buttons out of view — the
  text now truncates inside the leftover width and the controls keep
  layout priority

### Changed

- The run-now button is behind a two-click interlock: the first click
  arms it (orange confirm state), the second within 3 seconds fires, and
  a stray click decays harmlessly
- Bundled task-clock CLI updated to v0.3.0 (live reload of [hooks] and
  retention_days)

## [0.2.1] - 2026-08-31

### Changed

- Bundled task-clock CLI updated to v0.2.1 (fixes `validate` panicking on
  watermark tasks). The GUI itself never calls `validate`, so no GUI code
  changed — this release just stops shipping a binary with a known crash

## [0.2.0] - 2026-08-31

### Added

- Run-history view (Phase 2): click a task row for its scheduled-vs-actual
  record — one line per fire with start delay, duration, result and a
  reveal-log button; live-updating while the popover is open

## [0.1.1] - 2026-08-31

### Fixed

- Version in the popover footer showed a doubled prefix ("vv0.1.0") —
  `appVersion` already carries the v from git describe
- Homebrew cask now declares the real macOS floor (`:sonoma`, 14+ —
  MenuBarExtra requirement) instead of the template default

## [0.1.0] - 2026-08-31

### Added

- Phase 1 (RFP §4): menu-bar app over the task-clock daemon — quiet-by-
  default label with overrun badge and distinct daemon-down state; per-task
  popover rows (state / trigger / next run / last run) with run-now,
  pause/resume, reload, and reveal-log actions; App Nap-proof polling
  (30 s background / 5 s open); bundled signed CLI as the data path
- Daemon lifecycle from the GUI: a persistent pilot-lamp row (green
  running / orange registered-but-unresponsive with Restart / gray
  stopped) and a power switch driving install/uninstall via the bundled
  CLI, with post-action state verification
- Launch-at-login toggle (SMAppService; ambiguous statuses never disable
  the control, mismatches are reported honestly)
- Local notifications for overrun entry, run failure, and daemon-down
  (edge-triggered — and silent for a deliberate stop, i.e. when the
  registration was removed with the daemon), with TCC authorization
  requested at launch
- Per-task on/off switch (pause/resume, persisted by the daemon across
  restarts); config-disabled tasks show no switch — that layer belongs to
  tasks.d
- Generated app icon (scripts/gen-icon.swift), pilot-lamp daemon row, and
  a single unambiguous "Reload task definitions" control
- Project scaffold: SPM package (Core + app + tests), signed .app pipeline
  (codesign / notarize / cask generation), two-layer single-instance guard,
  RFP (ja/en), README (en/ja)
