# Copyparty Godot Client

A Godot 4 dual-pane UI for the [copyparty](https://github.com/9001/copyparty) file server. Runs as a native desktop app, on Android, or as a web export.

## Features

- **Dual-pane layout** — left pane browses the local filesystem, right pane browses the server; drag between panes to transfer files
- **Browse** server directories with icon-annotated file lists
- **Sortable columns** — click column headers to sort by name, size, or date, ascending or descending
- **Navigate** with back/forward history, breadcrumb path, home button, keyboard shortcuts
- **Upload** files and folders via the OS file picker or by dragging from the OS
- **Download** files to the local pane by dragging, or open in the system browser
- **Create folders** on the server
- **Delete** files and directories (with confirmation)
- **Multi-select** — select multiple entries to transfer or delete at once
- **Move / Copy** files between server paths
- **Sync** — compare a same-named file in both panes (timestamp + size) and choose which copy to keep
- **Search** the server index (copyparty search syntax)
- **Markdown viewer/editor** — open `.md` files rendered in-app, edit and save them back, create new markdown files
- **Authentication** via session login (username + password) or password-only (`?pw=` on web)
- **Themes** — dark, light, green, custom
- **Font selector** — switch the UI font, including the bundled OpenDyslexic accessibility font (Noto symbol/emoji fallbacks)
- **Opacity slider** for desktop window transparency
- **Responsive layout** — compact mode on narrow windows with a collapsible left pane (mobile friendly)
- **Web export** supported — OS folder drag-drop preserves folder structure via JavaScript bridge

## Supported Builds

| Platform | Builds |
|---|---|
| Windows | x86_64, x86_32 |
| Linux | x86_64, x86_32, arm64 |
| macOS | `.app` bundle (zipped) |
| Android | APK |
| Web | HTML5 export |

All builds are exported by the GitHub Actions workflow (`.github/workflows/export.yml`) on every `v*` tag and attached to a GitHub Release. The workflow can also be triggered manually (`workflow_dispatch`).

## Requirements

- Godot 4.6
- A running copyparty server

## Quick Start

1. Open the project in Godot (`File → Open Project`, select the `project/` folder)
2. Press **F5** to run
3. Enter your server URL (e.g. `http://localhost:3923`) and press **Connect**
4. Optionally enter a username and/or password and press **Auth**

## Authentication

| Scenario | How it works |
|---|---|
| Username + password (desktop) | Session POST login; subsequent requests use a session cookie |
| Username + password (web) | Same session POST login (multipart/form-data — CORS-safe) |
| Password only | Appended as `?pw=password` on every request |
| No auth | Unauthenticated access |

## Keyboard Shortcuts

| Key | Action |
|---|---|
| Enter / Numpad Enter | Open file or enter folder |
| Backspace | Go back |
| F5 | Refresh |
| Delete | Delete selected |

## Drag and Drop

| Source | Target | Result |
|---|---|---|
| Local pane | Remote pane | Upload file or folder to server |
| Remote pane | Local pane | Download file or folder locally |
| OS / desktop | Remote pane | Upload; folder structure preserved (desktop and web) |
| OS / desktop | Local pane | Save files locally |

## Project Structure

```
.github/
└── workflows/
    └── export.yml        # CI: exports all platform builds on v* tags → GitHub Release
project/
├── project.godot
├── export_presets.cfg    # Export presets for all supported platforms
├── fonts/                # Roboto, OpenDyslexic, Noto Symbols/Emoji (subsets)
├── scenes/
│   ├── Main.tscn         # Main scene
│   ├── FilePane.tscn     # Reusable pane (LOCAL or REMOTE source)
│   └── images/           # Logos
└── scripts/
    ├── CopypartyAPI.gd   # HTTP API client (all methods async)
    ├── FilePane.gd       # Per-pane browse, sorting, signals, drag-drop
    ├── Format.gd         # Shared static helpers: Format.size(), Format.ts()
    ├── Main.gd           # Dual-pane orchestration, transfers, dialogs, themes
    └── Markdown.gd       # Minimal markdown → BBCode renderer for the viewer
```
