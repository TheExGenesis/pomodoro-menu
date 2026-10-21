# Pomodoro

A tiny macOS menu bar Pomodoro timer. It has no Dock icon: the timer lives in the menu bar, where it shows a progress ring and the minutes remaining.

## Features

- Menu-bar progress ring beside the remaining minutes or seconds.
- Focus, short break, and long break phases.
- Preset regimes: Classic 25/5, Balanced 35/5, Deep Work 50/10, and Long Arc 75/15.
- Settings window for phase durations, long-break cadence, sound, notifications, and auto-start.
- Tasteful neutral completion sound, using macOS Glass by default.
- Cute tomato app icon.

## Build

```bash
./scripts/make_icon.sh
./scripts/build.sh
```

The app bundle is written to:

```text
dist/Pomodoro Menu.app
```

## Install

```bash
./scripts/install.sh
open "/Applications/Pomodoro Menu.app"
```

You can also run it without installing:

```bash
open "dist/Pomodoro Menu.app"
```

Click the menu bar item to start, pause, reset, switch phases, pick a regime, toggle sound/notifications, open settings, or quit.

If the menu bar is crowded, macOS can hide items behind the camera notch. Pomodoro starts near the right edge and remembers its position; hold Command and drag it to rearrange it. Opening Pomodoro Menu again while it is running also shows its timer controls at the pointer, even if the menu bar item is hidden.

For local development, `./script/build_and_run.sh` builds and relaunches the app. Add `--verify` to check that it started, or `--telemetry` to inspect menu bar diagnostics. The Codex Run action uses this script.

## Publish to GitHub

This folder is its own git repository. After logging in with `gh auth login`, publish it with:

```bash
gh repo create pomodoro-menu --source . --private --push
```
