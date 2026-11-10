# The bridge: driving TellMAP and the editor from outside

[Español](README.md)

`addons/tellmap_puente/` lets a program (the terminal, a test or an AI agent) drive the app while it's running and
the Godot editor while it's open. `tools/godot/tmap.py` is the client: Python with no dependencies.

## What it's for

- **See your changes without touching the mouse**: open the app, jump to a year and a place, open a tab and take a
  screenshot, in a second and without restarting.
- **Test the interface like a person would**: clicks, keys, drags and text, in window pixels (the same ones used by
  screenshots and by `arbol`).
- **Iterate fast**: `shader` rereads the shaders from disk and `recargar` rereads the encyclopedia, without closing
  the app.
- **Diagnose**: `errores` returns the engine's errors and warnings with their stack trace; every response also
  includes the errors that showed up during that request. `arbol` shows the nodes with their on-screen rectangle and
  `eval` runs GDScript inside the app.
- **Work with the editor open**: rescan files changed from outside, run and stop the app, open a script at a line.

## Usage

```bash
tools/godot/tmap.py lanzar                       # opens the app with the bridge (headless, it uses cage)
tools/godot/tmap.py anio anio=-1350
tools/godot/tmap.py ir lon=31 lat=27.6 zoom=1.2
tools/godot/tmap.py seleccionar lon=31 lat=27.6
tools/godot/tmap.py pestana n=2
tools/godot/tmap.py captura egipto.png ancho=1200
tools/godot/tmap.py eval 'Enciclopedia.fuentes.size()'
tools/godot/tmap.py ayuda                        # all the app's commands
tools/godot/tmap.py cerrar
```

With the editor open, `--a editor` talks to the editor instead of the app (`estado`, `escanear`, `jugar`, `parar`,
`abrir ruta=scripts/principal.gd linea=40`, `ajuste_editor`, `recargar_plugin`, plus the common ones). To talk to the
editor of another copy of the project: `--proyecto /ruta/al/proyecto`.

Also: `tmap.py revisar` compiles every script without opening the app, `tmap.py prueba` runs the automated test and
`tmap.py doc Clase.metodo` (or `doc ?texto`) shows the exact API for the installed version of Godot; the first time,
it generates it in `~/.cache/tellmap/`.

`tmap.py recorrido` (with the app open) actually clicks every visible button and the clickable charts, across 17
scenarios (each tab of a place, each type of card, layer mode, settings, help and search), and reports how many it
clicked and which ones did nothing; `solo="ficha de familia"` runs a single scenario. While it runs, links don't open
the browser. The automated test includes it and fails if a click throws an error or does nothing.

## Logs

Every time the app runs (or the editor, with the plugin), a log is saved in `.godot/registros/`: messages, errors and
warnings with their GDScript stack trace, and on exit, the nodes left unfreed along with their script. The last 15 of
each are kept.

```bash
tools/godot/tmap.py registros               # the app's latest
tools/godot/tmap.py registros --errores     # only errors and warnings
tools/godot/tmap.py registros editor -n 200 # the editor's latest
tools/godot/tmap.py registros --lista
```

## In the editor

The plugin comes enabled (Project → Project Settings → Plugins → "Puente TellMAP"). It adds the **Puente** (bridge)
panel, which shows every incoming request and has buttons to run the automated test and validate the encyclopedia.
The "Recargar sin preguntar los scripts cambiados afuera" checkbox (reload scripts changed outside without asking)
avoids the editor's prompt every time another program edits a file. The plugin's texts are in Spanish only.

## How it works and why it's safe

- The app turns the bridge on only in debug builds and only if it's opened with `-- --puente` or from the editor. In
  an exported build it does nothing.
- Each bridge listens on `127.0.0.1`, on the first free port starting at 47800, and saves its port and a random token
  in `.godot/puente/<rol>-<pid>.json`. Any request without that token is rejected.
- That file can only be read by those who can already read and modify the repo (and could therefore already change
  the code). The bridge doesn't give access to anyone else.
- Protocol: one JSON line per request, `{"token", "cmd", "args"}`, and one per response,
  `{"ok", "r" | "error", "errores", "ms"}`. Any language with sockets can talk to it.
- Apps opened with `lanzar` close on their own after 15 minutes without requests.
