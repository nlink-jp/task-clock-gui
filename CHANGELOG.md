# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) +
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Phase 1 (RFP §4): menu-bar app over the task-clock daemon — quiet-by-
  default label with overrun badge and distinct daemon-down state; per-task
  popover rows (state / trigger / next run / last run) with run-now,
  pause/resume, reload, and reveal-log actions; App Nap-proof polling
  (30 s background / 5 s open); bundled signed CLI as the data path
- Daemon lifecycle from the GUI: "Background daemon" toggle
  (install/uninstall via the bundled CLI) and Start/Reinstall on the
  daemon-down view, with post-action state verification
- Launch-at-login toggle (SMAppService; ambiguous statuses never disable
  the control, mismatches are reported honestly)
- Local notifications for overrun entry, run failure, and daemon-down
  (edge-triggered), with TCC authorization requested at launch
- Project scaffold: SPM package (Core + app + tests), signed .app pipeline
  (codesign / notarize / cask generation), two-layer single-instance guard,
  RFP (ja/en), README (en/ja)
