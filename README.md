# Pomodoro

A tiny macOS menu bar Pomodoro timer. It has no Dock icon: the timer lives in the menu bar, where it shows a progress ring and the minutes remaining.

## Features

- Menu-bar progress ring with remaining minutes or seconds.
- Focus, short break, and long break phases.
- Preset regimes: Classic 25/5, Balanced 35/5, Deep Work 50/10, and Long Arc 75/15.
- Settings window for phase durations, long-break cadence, sound, notifications, and auto-start.
- Tasteful neutral completion sound, using macOS Glass by default.

## Build

```bash
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

## Publish to GitHub

This folder is its own git repository. After logging in with `gh auth login`, publish it with:

```bash
gh repo create pomodoro-menu --source . --private --push
```
