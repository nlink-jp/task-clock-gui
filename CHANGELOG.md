# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) +
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Resizable panel: a bottom-right grip drags the width and list height
  (persisted across launches; MenuBarExtra windows have no native resize
  frame), double-click resets to the defaults

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
