# Mac Window Layout

A menu bar app that saves where your windows sit on a display and puts them back with one click or a global shortcut.

## Features

- **Save New Preset…** captures every visible window on the display under the mouse.
- **Apply** a preset from the menu or with its shortcut. It lays the windows out on the display under the mouse, scaled to that display's size.
- Set, clear, rename, update or delete presets in **Settings…**.
- Turn on **Launch at login** in Settings.
- Hide the menu bar icon in Settings. Open the app again (e.g. from Finder) to bring it back.

## Requirements

- macOS 14+
- Accessibility permission (the app asks on first launch)

## Build

```bash
./build-app.sh
```

This builds `Mac Window Layout.app` and signs it with `Apple Development`. To sign with another identity, set `SIGN_ID`. A stable signature keeps the Accessibility grant across rebuilds.

Launch at login works only from the built `.app`, not from `swift run`.

## Test

```bash
swift test
```

## Data

Presets are stored in `~/Library/Application Support/WindowLayout/presets.json`.
