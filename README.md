# task-clock-gui

Menu-bar front end for the [task-clock](https://github.com/nlink-jp/task-clock)
scheduler on macOS.

task-clock records every scheduled fire as scheduled-vs-actual; this app puts
that record where you will actually notice it. The menu bar stays quiet while
everything runs on time, speaks up the moment a task overruns its schedule
("⚠ 12m"), and shows a distinct question-mark state when the daemon itself is
unreachable. The popover lists every task with its state, next run, and last
result, and offers run-now, pause/resume, reload, and one-click access to the
last run's captured log.

## Features

- **Quiet-by-default menu bar**: a plain clock when healthy; the overrun
  badge with the overrun duration when a task is eating its schedule; a
  question mark when the daemon is unreachable — "unknown" is never dressed
  up as either "fine" or "error"
- **Per-task rows**: state (idle / running / overrun / paused / disabled),
  trigger (`*/30 * * * *` or `success + 30m`), next run (a concrete time,
  "after current run", or "on success + N"), last run (ok / exit N / missed
  with reason)
- **Actions in place**: run now, pause / resume, reload tasks.d, reveal the
  last run's log in Finder — failures are reported in the same popover
- **Daemon lifecycle without a terminal**: a persistent pilot-lamp row —
  green (running), orange (registered but not responding, with a Restart
  button), gray (stopped) — with a power switch that registers/removes the
  launch agent via the bundled CLI
- **Launch at login** toggle (SMAppService), with honest feedback when
  macOS wants approval in System Settings
- **Notifications**: a banner when a task enters overrun, when a run
  fails, and when the daemon becomes unreachable — permission is requested
  at first launch (answer the one-time prompt), and persisting states never
  repeat their banner
- **Self-contained**: bundles the Developer-ID-signed task-clock CLI and
  drives it with `--json`; the CLI owns the config, the API key, and the
  daemon connection

## Requirements

- macOS 14+ (Apple Silicon)
- A configured task-clock daemon (see the
  [task-clock README](https://github.com/nlink-jp/task-clock)) — the app
  itself needs no configuration

## Building

```bash
cd ../task-clock && make build   # the CLI gets bundled into the .app
cd ../task-clock-gui
make build-app                   # dist/TaskClock.app (signed)
make test
```

## Documentation

- [RFP / design document](docs/en/task-clock-gui-rfp.md)
  ([日本語](docs/ja/task-clock-gui-rfp.ja.md))
- [README in Japanese](README.ja.md)

## License

[MIT](LICENSE)
