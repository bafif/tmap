# Install

[Español](../es/instalar.md)

## Download the build for your system

On Linux and Windows, TellMAP doesn't install: you download the zip for your system from the
[latest release](https://github.com/bafif/tmap/releases/latest), unzip it and open it. The data is inside the
executable. On macOS, use the installer ([below](#macos)).

| System | File | What you open |
|---|---|---|
| Linux (x86_64) | `TellMAP-<version>-linux-x86_64.zip` | `TellMAP.x86_64` |
| Windows (x86_64) | `TellMAP-<version>-windows-x86_64.zip` | `TellMAP.exe` |
| macOS with Apple Silicon (M1, M2…) | `TellMAP-<version>-macos-arm64.dmg` (or `.zip`) | `TellMAP.app` |
| macOS with Intel | `TellMAP-<version>-macos-x86_64.dmg` (or `.zip`) | `TellMAP.app` |

What the app saves (settings, the Wikipedia cache, what you edit with the encyclopedia editor and the data downloaded
by updates) goes in the user folder: `~/.local/share/godot/app_userdata/TellMAP/` on Linux and
`%APPDATA%\Godot\app_userdata\TellMAP\` on Windows and `~/Library/Application Support/Godot/app_userdata/TellMAP/`
on macOS. To uninstall it, delete the app's folder and, if you like, the
user folder.

## macOS

Open Terminal (Applications → Utilities → Terminal), paste this and press Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/bafif/tmap/main/tools/instalar-macos.sh | bash
```

The installer ([`tools/instalar-macos.sh`](../../tools/instalar-macos.sh)) checks whether the Mac is Intel or Apple
Silicon, downloads that build of the latest GitHub release, checks its signature, puts it in `/Applications` (or in
`~/Applications` if it can't write there) and opens it. It works on any Mac with macOS 11 or newer, and the app opens
right away.

### Why an installer and not a double click

The app has an ad hoc signature and isn't notarized by Apple (that takes an Apple Developer account, 99 USD a year).
What a browser downloads is marked as "quarantined", and macOS won't open a quarantined app that isn't notarized: it
says "“TellMAP” can't be opened because Apple cannot check it for malicious software". What `curl` downloads from
Terminal isn't quarantined, so macOS opens it without asking.

If you downloaded the `.dmg` or the `.zip` with a browser, the first time you have to open it from **System Settings →
Privacy & Security**, further down, with "Open Anyway", or remove the quarantine in Terminal with
`xattr -dr com.apple.quarantine /Applications/TellMAP.app`.

### Updating

On macOS the data updates itself but the app doesn't: when there's a new version, the notice leads to the release
page, and to install it you run the same command again.

## If it shows up black or glitchy

**Settings → Rendering engine** picks how the app draws. "Automatic", the default, uses Vulkan on Linux and Windows
(OpenGL if there's no Vulkan) and OpenGL on macOS; "Compatible (OpenGL)" works on almost any computer and is the one
to pick if the window is black, blotchy or missing the map. When the app reopens with another engine, it asks whether
it looks right; if nobody answers within 20 seconds, it goes back to the previous one.

If not even Settings shows up, open the app with `--rendering-method gl_compatibility`.

## Updates

When it opens, and then every hour, the app checks GitHub for anything new and asks before downloading it. It can be
turned off under **Settings → Updates**. How it works: [Automatic updates](updates.md).

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
