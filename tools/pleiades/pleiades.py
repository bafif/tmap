"""Lugares antiguos de Pleiades (https://pleiades.stoa.org) para el mapa.

Pleiades es el diccionario geográfico del mundo antiguo del ISAW (Universidad de Nueva York) y el Ancient World
Mapping Center, hecho a partir del Barrington Atlas; sus datos son CC BY 3.0. Publica cada mañana un volcado en CSV
(https://atlantides.org/downloads/pleiades/dumps/). Esta herramienta baja el de lugares y escribe
`data/pleiades/lugares.json`: por cada lugar con ubicación (precisa, aproximada o tomada de sus partes, como Roma o
Atenas) y con fechas, su id, nombre, coordenadas, años y una categoría propia. Lo demás (descripción, nombres
antiguos, referencias) la app lo pide en vivo a Pleiades cuando alguien abre la ficha, igual que el resumen de
Wikipedia.

Los años son los de los períodos en que Pleiades tiene atestiguado el lugar (arcaico, clásico, helenístico, romano,
tardoantiguo…), no su fundación ni su abandono: un lugar atestiguado hasta hoy llega hasta hoy.

Uso:
  python3 tools/pleiades/pleiades.py            baja el volcado (si no está en la caché de hoy) y escribe el archivo
  python3 tools/pleiades/pleiades.py --resumen  muestra qué quedó: cuántos por categoría y por época, y el tamaño
"""
from __future__ import annotations

import collections
import csv
import datetime
import gzip
import json
import socket
import sys
import urllib.request
from pathlib import Path

# IPv4 primero: con IPv6 roto (pasa en algunas redes), urllib espera el timeout entero antes de probar IPv4.
_getaddrinfo = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: sorted(_getaddrinfo(*a, **k), key=lambda r: r[0] != socket.AF_INET)

RAIZ = Path(__file__).resolve().parents[2]
SALIDA = RAIZ / "data" / "pleiades" / "lugares.json"
CACHE = RAIZ / "tools" / "pipeline" / "cache" / "pleiades-places-latest.csv.gz"
URL = "https://atlantides.org/downloads/pleiades/dumps/pleiades-places-latest.csv.gz"
UA = {"User-Agent": "tmap-pleiades/0.4 (https://bafif.github.io/tmap; tools/pleiades/pleiades.py)"}
ANIO_MAX = 2024  # lo que llega a «hoy» en Pleiades (2099, 2100) se recorta al final de la línea de tiempo

# Categoría propia → tipos de Pleiades (https://pleiades.stoa.org/vocabularies/place-types). Un lugar toma la de su
# primer tipo que aparezca acá; los que no tienen ninguno (ríos, montes, islas, regiones, pueblos, rutas, rótulos del
# atlas) no son un punto en el mapa y quedan afuera.
CATEGORIAS = {
    "asentamiento": ["settlement", "fortified-settlement", "settlement-modern", "urban", "polis", "city-center",
                     "tell", "oasis", "city-block", "district", "deme-attic"],
    "villa": ["villa", "estate", "farm", "townhouse", "house"],
    "fortificacion": ["fort", "fort-2", "fortlet", "hillfort", "castle", "castellum", "citadel", "acropolis",
                      "tower-defensive", "tower-single", "tower-wall", "tower-gate", "fort-group", "barracks",
                      "military-installation-or-camp-temporary", "military-base", "frontier-system-limes",
                      "city-wall", "defensive-wall", "wall-2", "wall", "interior-wall", "city-gate", "gateway",
                      "postern", "earthwork", "earthworks", "nuraghe"],
    "santuario": ["sanctuary", "temple", "temple-2", "shrine", "church", "church-2", "abbey", "abbey-church",
                  "monastery", "priory", "mosque", "synagogue", "altar", "ziggurat", "stupa", "grove",
                  "cahartaq-pre-islamic"],
    "tumba": ["cemetery", "tomb", "tumulus", "pyramid", "cairn", "cenotaph"],
    "puerto": ["port", "harbor", "anchorage", "shipshed", "lighthouse"],
    "camino": ["station", "bridge", "bridge-group", "aqueduct", "aqueduct-group", "dam", "canal", "cistern",
               "reservoir", "tunnel", "causeway", "well", "fountain", "dike", "dike-group", "levee", "sewer",
               "waterwheel", "fishpond"],
    "edificio": ["theatre", "amphitheatre", "bath", "circus", "odeon", "stadion", "forum", "agora", "basilica",
                 "stoa", "gymnasium", "palaestra", "palaistra", "macellum", "ekklesiasterion", "palace",
                 "palace-complex", "plaza", "archive-repository", "treasury", "treasure-house", "building",
                 "architecturalcomplex", "arch", "monument", "lesche", "taberna-shop", "brothel", "swimming-pool",
                 "garden-hortus"],
    "produccion": ["mine", "mine-2", "quarry", "production", "metalworking", "ceramicproduction", "salt-pan-salina",
                   "slag-heap"],
    "sitio": ["archaeological-site", "findspot", "ruin", "unknown", "feature", "numbered feature", "labeled feature",
              "cave", "spring", "centuriation", "landmark"],
}
DE_TIPO = {t: c for c, ts in CATEGORIAS.items() for t in ts}
ORDEN = list(CATEGORIAS)


def bajar() -> Path:
    hoy = datetime.date.today()
    if CACHE.exists() and datetime.date.fromtimestamp(CACHE.stat().st_mtime) == hoy:
        return CACHE
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    print(f"bajando {URL}…")
    with urllib.request.urlopen(urllib.request.Request(URL, headers=UA), timeout=300) as r:
        datos = r.read()
    CACHE.write_bytes(datos)
    print(f"  {len(datos) / 1e6:.1f} MB")
    return CACHE


def anio(texto: str) -> int:
    return min(int(float(texto)), ANIO_MAX)


def armar(ruta: Path) -> dict:
    csv.field_size_limit(10**9)
    lugares = []
    descartados = collections.Counter()
    with gzip.open(ruta, "rt", encoding="utf-8") as f:
        for fila in csv.DictReader(f):
            if fila["locationPrecision"] not in ("precise", "rough", "related"):
                descartados["sin ubicación"] += 1
                continue
            if not fila["reprLat"] or not fila["reprLong"]:
                descartados["sin coordenadas"] += 1
                continue
            if not fila["minDate"] or not fila["maxDate"]:
                descartados["sin fechas"] += 1
                continue
            tipos = [t.strip() for t in fila["featureTypes"].split(",") if t.strip()]
            cat = next((DE_TIPO[t] for t in tipos if t in DE_TIPO), None)
            if cat is None:
                descartados[f"tipo {tipos[0] if tipos else '(ninguno)'}"] += 1
                continue
            # Los sitios que Pleiades no tiene con nombre («Untitled», «Untitled villa») quedan con nombre vacío: la
            # app los muestra como «Villa sin nombre» y no les pone rótulo en el mapa.
            nombre = fila["title"].strip()
            if nombre.lower().startswith("untitled"):
                nombre = ""
            # «Andros (settlement)»: la aclaración repite la categoría, que la ficha ya dice.
            nombre = nombre.removesuffix(" (settlement)")
            desde, hasta = anio(fila["minDate"]), anio(fila["maxDate"])
            if desde > hasta:
                desde, hasta = hasta, desde
            lugares.append([int(fila["id"]), nombre, round(float(fila["reprLong"]), 4),
                            round(float(fila["reprLat"]), 4), desde, hasta, ORDEN.index(cat)])
    lugares.sort(key=lambda l: l[0])
    return {
        "fuente": "Pleiades, https://pleiades.stoa.org",
        "licencia": "CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)",
        "volcado": datetime.date.fromtimestamp(ruta.stat().st_mtime).isoformat(),
        "campos": ["id", "nombre", "lon", "lat", "desde", "hasta", "categoria"],
        "categorias": ORDEN,
        "lugares": lugares,
    }, descartados


def resumen(datos: dict) -> None:
    lug = datos["lugares"]
    print(f"{SALIDA.relative_to(RAIZ)}: {len(lug)} lugares, {SALIDA.stat().st_size / 1e6:.2f} MB, "
          f"volcado del {datos['volcado']}")
    por_cat = collections.Counter(datos["categorias"][l[6]] for l in lug)
    print("  por categoría:", ", ".join(f"{c} {n}" for c, n in por_cat.most_common()))
    epocas = [(-3000, -1000), (-1000, -500), (-500, 0), (0, 500), (500, 1000), (1000, 1500), (1500, 2025)]
    print("  presentes en:", ", ".join(f"{a}..{b}: {sum(1 for l in lug if l[4] < b and l[5] >= a)}"
                                       for a, b in epocas))


def main() -> None:
    if "--resumen" in sys.argv:
        resumen(json.loads(SALIDA.read_text(encoding="utf-8")))
        return
    datos, descartados = armar(bajar())
    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    # Una fila por lugar: el diff de una actualización muestra solo los lugares que cambiaron.
    filas = ",\n".join("    " + json.dumps(l, ensure_ascii=False, separators=(",", ":")) for l in datos["lugares"])
    cabecera = {k: v for k, v in datos.items() if k != "lugares"}
    texto = json.dumps(cabecera, ensure_ascii=False, indent=2)[:-2] + ',\n  "lugares": [\n' + filas + "\n  ]\n}\n"
    json.loads(texto)
    SALIDA.write_text(texto, encoding="utf-8")
    print("descartados:", ", ".join(f"{k} {n}" for k, n in descartados.most_common(12)), "…")
    resumen(datos)


if __name__ == "__main__":
    main()
