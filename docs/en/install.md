# Install

[Español](../es/instalar.md)

## Download the build for your system

TellMAP doesn't install: you download the zip for your system from the
[latest release](https://github.com/bafif/tmap/releases/latest), unzip it and open it. The data is inside the
executable.

| System | File | What you open |
|---|---|---|
| Linux (x86_64) | `TellMAP-<version>-linux-x86_64.zip` | `TellMAP.x86_64` |
| Windows (x86_64) | `TellMAP-<version>-windows-x86_64.zip` | `TellMAP.exe` |
| macOS (Intel and Apple Silicon) | `TellMAP-<version>-macos-universal.zip` | `TellMAP.app` |

What the app saves (settings, the Wikipedia cache, what you edit with the encyclopedia editor and the data downloaded
by updates) goes in the user folder: `~/.local/share/godot/app_userdata/TellMAP/` on Linux and
`%APPDATA%\Godot\app_userdata\TellMAP\` on Windows. To uninstall it, delete the app's folder and, if you like, the
user folder.

## macOS: the first time

The macOS build has an ad hoc signature and isn't notarized by Apple. The first time, macOS says it can't check it:
open it anyway from **System Settings → Privacy & Security**, or in the Terminal with
`xattr -dr com.apple.quarantine TellMAP.app`.

On macOS the data updates itself but the app doesn't: when there's a new version, the notice leads to the download
page.

## If it shows up black or glitchy

**Settings → Rendering engine** picks how the app draws. "Automatic", the default, uses Vulkan on Linux and Windows
(OpenGL if there's no Vulkan) and OpenGL on macOS; "Compatible (OpenGL)" works on almost any computer and is the one
to pick if the window is black, blotchy or missing the map. When the app reopens with another engine, it asks whether
it looks right; if nobody answers within 20 seconds, it goes back to the previous one.

If not even Settings shows up, open the app with `--rendering-method gl_compatibility`.

## Updates

When it opens, the app checks GitHub for anything new and asks before downloading it. It can be turned off under
**Settings → Updates**. How it works: [Automatic updates](updates.md).

## From the source

You need [Godot 4.7](https://godotengine.org/download), which is free and weighs about 100 MB:

```bash
git clone https://github.com/bafif/tmap.git
godot --path tmap            # or open the folder from the Godot editor
```

The first time, the app imports the project by itself and reopens. That copy doesn't look for updates: it's updated
with `git pull`.

The map data comes already generated in `data/mapa/`. To rebuild it from the original sources, or with another
Cliopatria release, there's [the data pipeline](../../tools/pipeline/README.en.md). To test and see your changes:
[How to work on TellMAP](contributing.md).
