# Automatic updates

[Español](../es/actualizaciones.md)

The downloaded version of TellMAP updates itself. There are two kinds of update:

- **App updates**: new code. The new executable is downloaded, replaces the one that's running, and opens the next
  time (or with "Restart now"). It bundles the data from its own release.
- **Data-only updates**: more sources, people, events, regions or a corrected map, without changing the code. Only the
  files that changed are downloaded; the app isn't reinstalled. The new encyclopedia shows up right away; a new map,
  when you reopen the app.

When running from source (`godot --path .` or the editor), nothing is checked: that copy is updated with `git pull`.

## What the user sees

On startup, and then every hour while it's open, if the **Settings → Updates** checkbox is ticked (it is by default),
TellMAP checks the manifest on GitHub. If there's something new, it offers it in a banner at the top center, above
everything else ("There's an update: TellMAP 0.3.3 and data from November 12, 2026. Install it?"), with **Update** and
**Not now**, and it doesn't download anything until the user says yes. With "Not now" (or the close button) nothing
changes and the app carries on as it was; the banner comes back the next time it's opened (the hourly check doesn't
repeat it). If the startup check can't finish (for example, offline), a notice says so, with **Try again**; the result
of every check goes to the app's log (`[actualizacion] al abrir: …`). With "Update" it downloads it, checks its sha256,
installs it and lets the user
know in the same spot when it's done. If the executable can't be replaced (for example, because it's in a folder
without write permission), it doesn't ask: the notice links to the download page. Settings shows the status, "Check
now" (which installs without asking, since it's already a request) and the checkbox to turn it off. The check doesn't
send anything about the user: it's a request to GitHub, like opening the project's page.

## How it works

- **The manifest** is `actualizacion.json`, a file in the fixed `actualizaciones` release of the repo on GitHub
  (marked as a prerelease so it's never "the latest"). It lists the latest app version, with a `.gz` of the executable
  per platform, and the latest data version, with every file in `data/`: sha256, size and the URL of its `.gz`. Each
  `.gz` has its sha256 in the name and is uploaded only once: a data version uploads only the files that changed and
  reuses the URLs of the rest.
- **The data version** is the commit date, in seconds. `tools/actualizacion/publicar.py sellar` writes it to
  `data/version.json` before exporting (that file isn't committed to the repo). Which files the executable bundles is
  worked out by the app when it installs an update (the sha256 of each one), and that's how it decides what to
  download.
- **Downloaded data** goes into the user folder, under `datos/<versión>/`, by group (`mapa`, `enciclopedia`): if one
  file in a group changed, the whole group is read from there and overrides the bundled one, so two versions never get
  mixed. `datos/activo.json` says which one is in effect; it's replaced in one go once the install finishes, so if
  something gets interrupted the previous one stays in effect. `Datos.ruta()` (`scripts/nucleo/datos.gd`) translates
  each `res://data/` path. Whatever is edited with the encyclopedia editor in the exported version still goes to
  `enciclopedia/` and overrides both. That's why, when the first copy of a package is saved, its base (what was
  underneath) is saved next to it, in `enciclopedia_base/`: if a data update or a new app later brings another
  version of that package, on startup (or when the install finishes) a notice says so and offers to bring what's new
  into the copy (a three-way merge per item: what the copy changed stays and the rest comes from the new version; if
  an item changed on both sides, the copy's wins and the notice says so) or to discard it (`Edicion.tapadas()` and
  `AvisoCopias`). The English translation of the encyclopedia (`enciclopedia/traducciones/en/`)
  is part of the `enciclopedia` group: a new or corrected translation arrives like any other data update.
- **Compatibility**: a data version states the minimum app version it needs (`app_minima`, the latest one published
  when it was built). An older app won't install it: the app has to be updated first. And downloaded data only counts
  if it's newer than the data bundled in the executable: when a new app is installed, if it bundles newer data, the
  old data folder is deleted automatically.
- **The executable**: it's downloaded to the user folder, verified, written next to the current one as `.nuevo` and
  renamed over it. On Linux the running process keeps the old file; on Windows, which doesn't allow overwriting an
  open executable, the old one is renamed to `.viejo` and deleted the next time.
- **macOS**: the app doesn't replace itself. The executable lives inside `TellMAP.app`, signed (ad hoc), and changing
  it would invalidate the signature: the manifest has no `macos-*` entry and the app announces that there's a new
  version with a link to the download page. Data does update automatically, because it goes to the user folder.

## Publishing

- **An app version**: publish the `vX.Y.Z` release on GitHub, with `config/version` in
  `project.godot` set to `X.Y.Z` (if they don't match, the workflow fails: the app would think it's outdated forever).
  `version.yml` exports, stamps the data, uploads the `.gz` files and the new manifest.
- **Data only**: just get the `data/` changes into `main`. `datos.yml` checks whether they changed compared to what's
  published, validates the encyclopedia, runs the full automated test **with the code of the latest published app
  version** and the new data, and if it passes publishes a `datos-AAAAMMDD-HHMMSS` release and the new manifest. If
  the test fails, it's because the data needs new code: it goes out with the next app version. It can also be run
  manually from the Actions tab.
- Both workflows upload `actualizacion.json` and share the `actualizaciones` `concurrency` group, so they never run at
  the same time: otherwise a push that touches `data/` and publishes a version could overwrite the new manifest with
  one built earlier.

## Testing

`python3 tools/actualizacion/probar.py` builds a fake published release, serves it on `127.0.0.1` and runs the app
with `-- --actualizaciones=<url>` and a separate user folder: it checks that on startup it offers what's new and that
"Not now" doesn't download or change anything, that with "Update" it downloads and installs new data, that the app
reads it, that when up to date it doesn't ask anything, that it rejects a tampered file and that it leaves nothing
behind. With `--ejecutable build/linux/TellMAP.x86_64` (an executable exported after `publicar.py sellar`) it also
checks that "Not now" leaves the executable as it was, that the app replaces itself and that it starts up again.

App flags for manual testing: `--actualizaciones=<url del manifiesto>` turns on the updater even when running from
source, `--actualizar-y-salir` checks, installs and exits (0 if it went well, 1 if not),
`--preguntar-y-salir=si|no` does the same as on startup and answers the banner with "Update" or "Not now", and
`--ejecutable=<ruta>` chooses which executable to replace (also from source: any file will do).
