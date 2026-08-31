# RFP: task-clock-gui

> Generated: 2026-08-31
> Status: Draft
> Parent design: the task-clock RFP (docs/ja/task-clock-rfp.ja.md — this GUI was planned there in §4 as a separate project)

## 1. Problem Statement

task-clock records every fire as scheduled-vs-actual, but its only window is
the CLI (`task-clock status` / `history`). The scheduler's value is noticing
a skip or an overrun the moment it happens, which needs an always-visible
surface — the menu bar. task-clock-gui is a thin front end that shows the
daemon's state in the menu bar, surfaces overruns and daemon-down at a
glance, and offers trigger / pause / resume / reload from a popover.

## 2. Functional Specification

- **Menu bar**: quiet when healthy (a plain clock symbol). Only an overrun
  speaks: `clock.badge.exclamationmark` plus the overrun duration ("12m");
  an unreachable daemon shows `clock.badge.questionmark` — "unknown" is
  distinct from both "error" and "fine"
- **Popover**: per task — state (idle / running / overrun / paused /
  disabled), trigger (cron or `success + 30m`), next run, last run. Row
  actions: run now, pause/resume, reveal the last run's log in Finder.
  Footer: reload, version, Quit. Errors appear in the same view the user
  acted in
- **Polling**: 30 s in the background, 5 s while the popover is open. App
  Nap opt-out (NSProcessInfo activity) is mandatory — without it the timer
  freezes and the display silently goes stale
- **Data path**: runs the bundled signed task-clock CLI with `--json` (org
  pattern). Config resolution, the API key and HTTP belong to the CLI; the
  GUI only decodes and renders
- **Daemon control**: sending the user back to a terminal for daemon
  lifecycle while offering a GUI is incoherent (user feedback). The first
  cut was asymmetric (a big button when down, a checkbox when up) — also
  flagged by the user — and became a persistent **pilot lamp + power
  switch** row: the lamp shows the actual state (green running / orange
  registered-but-unresponsive / gray stopped), the switch holds the intent
  (launch-agent registration via the bundled CLI install/uninstall). Their
  independence makes "installed ≠ reachable" directly visible (orange lamp
  on an ON switch is a broken registration; Restart is its repair path)
- **Launch at login**: an SMAppService toggle. Ambiguous statuses
  (`.notFound` etc.) fold into "not enabled yet" and never disable the
  toggle; after acting, the actual state is re-read and a mismatch
  (requiresApproval) is reported in the same view
- **Notifications**: local banners for entering overrun, a failed run, and
  the daemon becoming unreachable (edge-triggered — persisting states do
  not repeat). **TCC authorization is requested at launch** (user
  feedback): the prompt only appears while .notDetermined, and the moment a
  production banner is needed nobody is at the keyboard to answer it.
  Denials surface on stderr with the recovery path

## 3. Design Decisions

- **Swift SPM + SwiftUI MenuBarExtra(.window)** (macOS 14+, darwin/arm64).
  Known traps handled per org lessons: concrete ScrollView height via
  PopoverLayout, root fixedSize, the two-layer single-instance guard
  (LSMultipleInstancesProhibited + a runtime check in `enum Main`)
- **The bundled CLI is the trust anchor** (in Resources, covered by --deep
  signing). The env override works in DEBUG builds only
- **Never disable controls on ambiguous state**: run the action and report
  the daemon's answer. Daemon-down renders as a distinct state, not an
  error banner
- **Out of scope**: editing tasks.d (a text editor's job), full history
  browsing (the CLI's and log files' job), GUI install/uninstall (deferred)

## 4. Development Plan

- Phase 1 (Core): state display + actions (trigger/pause/resume/reload) +
  daemon control + launch-at-login + notifications (the latter three pulled
  forward from Phase 2 on user feedback) + tests (decode fixtures, state
  mapping, transition detection, layout, single-instance, binary
  resolution, post-action verification feedback)
- Phase 2: mini history view
- Phase 3: app icon, release (cask distribution)

## 5. Required API Scopes / Permissions

None (local only; daemon access goes through the bundled CLI).

## 6. Series Placement

Series: **util-series** — the same shape as active-lens-gui /
sensor-lens-gui: a thin menu-bar front end bundling the signed CLI.

## 7. External Platform Constraints

- macOS 14+ (MenuBarExtra). Developer ID signing + notarization + stapling
  required for distribution
- Popover content cannot be opened and verified programmatically — plan on
  a human check on real hardware before release (org lesson)
