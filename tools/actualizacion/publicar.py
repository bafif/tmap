#!/usr/bin/env python3
"""Lo que se publica para las actualizaciones automáticas de TellMAP (docs/es/actualizaciones.md).

  publicar.py sellar
      Escribe data/version.json: la versión de los datos (fecha del último commit, en segundos). Va antes de
      exportar: así el ejecutable sabe de cuándo son sus datos y si una actualización es más nueva.

  publicar.py manifiesto --etiqueta T --salida DIR [--previo actualizacion.json] [--app PLATAFORMA=EJECUTABLE ...]
      Arma DIR/actualizacion.json y deja en DIR los .gz que hay que subir a la versión T de GitHub. Los archivos de
      datos que ya estaban publicados (mismo sha256 en el manifiesto previo) no se vuelven a subir. Con --app (una por
      plataforma: linux-x86_64, windows-x86_64) es una versión de la app, con la de project.godot; sin --app, una
      versión solo de datos, que copia la app del manifiesto previo y pide al menos esa versión.

  publicar.py cambios --previo actualizacion.json
      Sale con 0 si data/ cambió respecto de lo publicado en ese manifiesto, con 1 si es igual.

  publicar.py etiqueta-app --previo actualizacion.json
      Imprime la etiqueta de la última versión de la app publicada (vX.Y.Z).

Sin dependencias: Python 3.10 o más nuevo.
"""

import argparse
import gzip
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
REPO = "bafif/tmap"
FORMATO = 1


def sha256(datos: bytes) -> str:
    return hashlib.sha256(datos).hexdigest()


def archivos_de_datos(datos: Path) -> dict[str, Path]:
    """rel → archivo, de todo data/ menos los .import de Godot y el propio version.json."""
    out = {}
    for p in sorted(datos.rglob("*")):
        rel = p.relative_to(datos).as_posix()
        if p.is_file() and not rel.endswith(".import") and rel != "version.json" and "/" in rel:
            out[rel] = p
    return out


def version_de_git() -> int:
    r = subprocess.run(["git", "log", "-1", "--format=%ct"], cwd=RAIZ, capture_output=True, text=True, check=True)
    return int(r.stdout.strip())


def version_app() -> str:
    m = re.search(r'^config/version="([^"]+)"', (RAIZ / "project.godot").read_text(encoding="utf-8"), re.M)
    if not m:
        sys.exit("project.godot no tiene config/version")
    return m.group(1)


def sellar(datos: Path, version: int) -> dict:
    sello = {"datos": version}
    (datos / "version.json").write_text(json.dumps(sello, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return sello


def _gz(contenido: bytes, destino: Path) -> dict:
    comprimido = gzip.compress(contenido, compresslevel=6, mtime=0)
    destino.write_bytes(comprimido)
    return {"bytes": len(contenido), "sha256": sha256(contenido), "sha256_gz": sha256(comprimido)}


def manifiesto(etiqueta: str, salida: Path, previo: dict | None, apps: dict[str, Path], datos: Path,
               version: int | None = None, base_url: str | None = None, repo: str = REPO) -> dict:
    salida.mkdir(parents=True, exist_ok=True)
    base = base_url or f"https://github.com/{repo}/releases/download/{etiqueta}/"
    if apps:
        v = version_app()
        if etiqueta != f"v{v}" and base_url is None:
            sys.exit(f"La etiqueta {etiqueta} no coincide con la versión de project.godot ({v}): la app se creería vieja.")
        app = {"version": v, "etiqueta": etiqueta, "pagina": f"https://github.com/{repo}/releases/tag/{etiqueta}"}
        for plataforma, exe in apps.items():
            nombre = f"TellMAP-{v}-{plataforma}.gz"
            app[plataforma] = {"url": base + nombre, **_gz(exe.read_bytes(), salida / nombre)}
    else:
        if not previo or "app" not in previo:
            sys.exit("Una versión solo de datos necesita el manifiesto previo (--previo), para copiar la app.")
        app = previo["app"]
    publicados = {}
    for info in (previo or {}).get("datos", {}).get("archivos", {}).values():
        publicados[info["sha256"]] = info
    sello = json.loads((datos / "version.json").read_text(encoding="utf-8")) if (datos / "version.json").exists() else {}
    if version is None:
        version = int(sello.get("datos", 0)) or version_de_git()
    archivos = {}
    for rel, p in archivos_de_datos(datos).items():
        contenido = p.read_bytes()
        h = sha256(contenido)
        if h in publicados:
            archivos[rel] = publicados[h]
            continue
        nombre = f"datos-{h[:24]}.gz"
        archivos[rel] = {"url": base + nombre, **_gz(contenido, salida / nombre)}
        publicados[h] = archivos[rel]
    m = {
        "formato": FORMATO,
        "generado": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "app": app,
        "datos": {
            "version": version,
            "fecha": time.strftime("%Y-%m-%d", time.gmtime(version)),
            "etiqueta": etiqueta,
            # Una versión de datos se prueba con la última app publicada: las anteriores primero se actualizan.
            "app_minima": app["version"],
            "archivos": archivos,
        },
    }
    (salida / "actualizacion.json").write_text(json.dumps(m, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return m


def cambiaron(previo: dict, datos: Path) -> bool:
    antes = {rel: info["sha256"] for rel, info in previo.get("datos", {}).get("archivos", {}).items()}
    ahora = {rel: sha256(p.read_bytes()) for rel, p in archivos_de_datos(datos).items()}
    return antes != ahora


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="orden", required=True)
    s = sub.add_parser("sellar")
    s.add_argument("--version", type=int, help="versión de los datos (por defecto, la fecha del último commit)")
    m = sub.add_parser("manifiesto")
    m.add_argument("--etiqueta", required=True)
    m.add_argument("--salida", type=Path, required=True)
    m.add_argument("--previo", type=Path)
    m.add_argument("--app", action="append", default=[], metavar="PLATAFORMA=EJECUTABLE")
    m.add_argument("--repo", default=REPO)
    c = sub.add_parser("cambios")
    c.add_argument("--previo", type=Path, required=True)
    e = sub.add_parser("etiqueta-app")
    e.add_argument("--previo", type=Path, required=True)
    a = ap.parse_args()
    datos = RAIZ / "data"

    def leer_previo(p: Path | None) -> dict | None:
        return json.loads(p.read_text(encoding="utf-8")) if p and p.exists() else None

    if a.orden == "sellar":
        sello = sellar(datos, a.version or version_de_git())
        print(f"data/version.json: datos {sello['datos']} ({time.strftime('%d/%m/%Y %H:%M', time.gmtime(sello['datos']))} UTC)")
    elif a.orden == "manifiesto":
        apps = {}
        for x in a.app:
            plataforma, _, exe = x.partition("=")
            apps[plataforma] = Path(exe)
        res = manifiesto(a.etiqueta, a.salida, leer_previo(a.previo), apps, datos, repo=a.repo)
        nuevos = sorted(p.name for p in a.salida.glob("*.gz"))
        print(f"{a.salida}/actualizacion.json: app {res['app']['version']}, datos {res['datos']['version']}; "
              f"{len(nuevos)} archivos para subir a {a.etiqueta}")
    elif a.orden == "cambios":
        previo = leer_previo(a.previo)
        si = previo is None or cambiaron(previo, datos)
        print("Los datos cambiaron respecto de lo publicado." if si else "Los datos son iguales a los publicados.")
        sys.exit(0 if si else 1)
    elif a.orden == "etiqueta-app":
        previo = leer_previo(a.previo)
        if not previo:
            sys.exit("No hay manifiesto previo.")
        print(previo["app"]["etiqueta"])


if __name__ == "__main__":
    main()
