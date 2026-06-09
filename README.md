# Copyparty Godot Client

A Godot 4 dual-pane UI for the [copyparty](https://github.com/9001/copyparty) file server. Runs as a native desktop app or as a web export.

## Features

- **Dual-pane layout** — left pane browses the local filesystem, right pane browses the server; drag between panes to transfer files
- **Browse** server directories with icon-annotated file lists
- **Navigate** with back/forward history, breadcrumb path, keyboard shortcuts
- **Upload** files and folders via the OS file picker or by dragging from the OS
- **Download** files to the local pane by dragging, or open in the system browser
- **Create folders** on the server
- **Delete** files and directories (with confirmation)
- **Move / Copy** files between server paths
- **Search** the server index (copyparty search syntax)
- **Authentication** via session login (username + password) or password-only (`?pw=` on web)
- **Themes** — dark, light, green, custom
- **Opacity slider** for desktop window transparency
- **Web export** supported — OS folder drag-drop preserves folder structure via JavaScript bridge

## Requirements

- Godot 4.2 or later
- A running copyparty server

### Web export: server CORS requirements

Cross-origin POST requests (upload, mkdir, delete, move, copy) require the server to permit them. Add one of these to your copyparty config:

```ini
# Specific origin (recommended)
acao = https://your-app-origin.example.com
acam = GET,HEAD,POST,PUT,DELETE

# Or: bypass all origin checks (private servers only)
allow-csrf
```

## Quick Start

1. Open the project in Godot (`File → Open Project`, select this folder)
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
godot_copyparty/
├── project.godot
├── scenes/
│   ├── Main.tscn         # Main scene
│   └── FilePane.tscn     # Reusable pane (LOCAL or REMOTE source)
└── scripts/
    ├── CopypartyAPI.gd   # HTTP API client (all methods async)
    ├── FilePane.gd       # Per-pane browse, signals, drag-drop
    ├── Format.gd         # Shared static helpers: Format.size(), Format.ts()
    └── Main.gd           # Dual-pane orchestration, transfers, dialogs
```

## API Coverage

| Operation | Endpoint | Method |
|---|---|---|
| List directory | `/{path}?ls` | GET |
| Download file | `/{path}` | GET |
| Upload file (desktop) | `/{path}/{filename}` | PUT |
| Upload file (web) | `/{path}` (multipart) | POST |
| Create folder | `/{path}` (multipart) | POST |
| Delete | `/{path}?delete` | POST |
| Move | `/{src}?move={dst}` | POST |
| Copy | `/{src}?copy={dst}` | POST |
| Search | `/{path}` (JSON body) | POST |
| Login | `/` (multipart) | POST |
| Logout | `/` (multipart) | POST |
