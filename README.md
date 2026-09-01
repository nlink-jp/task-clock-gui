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
- **Actions in place**: run now (behind a two-click interlock — the first
  click arms the button, the second within 3 s fires, a stray click decays
  harmlessly), a per-task on/off switch (pause/resume,
  persisted by the daemon so it survives restarts), reload of the task
  definitions, reveal the last run's log in Finder — failures are reported
  in the same popover. Tasks with `enabled = false` in the config show no
  switch: that layer belongs to tasks.d, and a control that does nothing
  would lie
- **Resizable panel**: drag any edge or corner, OS-native; the size is
  remembered across launches
- **Run history**: click a task row for its scheduled-vs-actual record —
  one line per fire (scheduled time, start delay, duration, ok / exit N /
  missed with reason), each with its captured log one click away; live
  while a run is in flight
- **Daemon lifecycle without a terminal**: a persistent pilot-lamp row —
  green (running), orange (should be running but not responding, with a
  Restart button), gray (stopped, or not installed) — with a power switch
  for the run state (`task-clock start`/`stop` via the bundled CLI;
  stopping never kills running tasks, and the stop survives logins).
  Setup is separate: an Install button appears when no launch agent is
  registered, and uninstalling is a double-click control in the footer
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
