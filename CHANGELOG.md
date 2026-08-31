# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) +
[Semantic Versioning](https://semver.org/).

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
