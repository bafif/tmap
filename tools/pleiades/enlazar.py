"""Une los lugares de la enciclopedia con los de Pleiades: escribe `data/pleiades/enciclopedia.json`.

Para cada lugar de la enciclopedia con artículo de Wikipedia, busca su elemento de Wikidata y, ahí, su id de Pleiades
(propiedad P1584). Se acepta solo si el punto de Pleiades está cerca del de la ficha (a menos de MAX_KM): un artículo
puede hablar de la región o de la ciudad moderna y no del sitio antiguo. Con eso la app no dibuja dos veces el mismo
lugar (Roma como ciudad de la enciclopedia y como punto de Pleiades) y suma a la ficha de la enciclopedia los nombres
antiguos de Pleiades. Los paquetes no se tocan: la unión vive aparte y se regenera cuando cambian.

Uso:
  python3 tools/pleiades/enlazar.py           consulta Wikipedia y Wikidata y escribe el archivo
  python3 tools/pleiades/enlazar.py --lista   además, muestra cada unión y lo que se descartó por lejos
"""
from __future__ import annotations

import json
import math
import socket
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# IPv4 primero: con IPv6 roto (pasa en algunas redes), urllib espera el timeout entero en cada pedido antes de
# probar IPv4. IPv6 queda de respaldo.
_getaddrinfo = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: sorted(_getaddrinfo(*a, **k), key=lambda r: r[0] != socket.AF_INET)

RAIZ = Path(__file__).resolve().parents[2]
PAQUETES = RAIZ / "data" / "enciclopedia" / "paquetes"
LUGARES_PLEIADES = RAIZ / "data" / "pleiades" / "lugares.json"
SALIDA = RAIZ / "data" / "pleiades" / "enciclopedia.json"
UA = {"User-Agent": "tmap-pleiades/0.4 (https://bafif.github.io/tmap; tools/pleiades/enlazar.py)"}
MAX_KM = 25.0
LOTE = 40


def pedir(url: str, params: dict) -> dict:
    q = urllib.parse.urlencode({**params, "format": "json", "formatversion": 2})
    for intento in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(f"{url}?{q}", headers=UA), timeout=60) as r:
                return json.load(r)
        except OSError as e:
            if intento == 3:
                raise
            print(f"  reintento ({e})")
            time.sleep(3 * (intento + 1))
    return {}


def km(a: tuple[float, float], b: tuple[float, float]) -> float:
    (lon1, lat1), (lon2, lat2) = a, b
    p1, p2 = math.radians(lat1), math.radians(lat2)
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
    return 2 * 6371 * math.asin(math.sqrt(h))


def qids(idioma: str, titulos: list[str]) -> dict[str, str]:
    """título → QID, por la API de Wikipedia (sigue redirecciones)."""
    out = {}
    for i in range(0, len(titulos), LOTE):
        lote = titulos[i:i + LOTE]
        r = pedir(f"https://{idioma}.wikipedia.org/w/api.php", {"action": "query", "prop": "pageprops",
                  "ppprop": "wikibase_item", "redirects": 1, "titles": "|".join(lote)})["query"]
        destino = {t: t for t in lote}
        for paso in ("normalized", "redirects"):
            for n in r.get(paso, []):
                for t, d in destino.items():
                    if d == n["from"]:
                        destino[t] = n["to"]
        por_titulo = {p["title"]: p.get("pageprops", {}).get("wikibase_item") for p in r["pages"]}
        for t, d in destino.items():
            if por_titulo.get(d):
                out[t] = por_titulo[d]
    return out


def pleiades_de(lista: list[str]) -> dict[str, list[int]]:
    """QID → ids de Pleiades (P1584)."""
    out = {}
    for i in range(0, len(lista), LOTE):
        r = pedir("https://www.wikidata.org/w/api.php", {"action": "wbgetentities", "ids": "|".join(lista[i:i + LOTE]),
                  "props": "claims"})
        for q, ent in r.get("entities", {}).items():
            ids = []
            for c in ent.get("claims", {}).get("P1584", []):
                v = c.get("mainsnak", {}).get("datavalue", {}).get("value")
                if isinstance(v, str) and v.isdigit():
                    ids.append(int(v))
            if ids:
                out[q] = ids
    return out


def main() -> None:
    lugares = []
    for ruta in sorted(PAQUETES.glob("*.json")):
        for l in json.loads(ruta.read_text(encoding="utf-8")).get("lugares", []):
            if l.get("lon") is not None and l.get("lat") is not None and l.get("wikipedia"):
                lugares.append(l)
    pleiades = {l[0]: (l[2], l[3], l[1]) for l in json.loads(LUGARES_PLEIADES.read_text(encoding="utf-8"))["lugares"]}
    qid_de = {}
    for idioma in ("en", "es"):
        titulos = sorted({l["wikipedia"][idioma] for l in lugares if l["wikipedia"].get(idioma)})
        print(f"{len(titulos)} títulos en {idioma}.wikipedia…")
        por_titulo = qids(idioma, titulos)
        for l in lugares:
            t = l["wikipedia"].get(idioma)
            if t in por_titulo and l["id"] not in qid_de:
                qid_de[l["id"]] = por_titulo[t]
    print(f"{len(qid_de)} lugares con elemento de Wikidata; buscando P1584…")
    p_de = pleiades_de(sorted(set(qid_de.values())))
    union, lejos = {}, []
    for l in lugares:
        candidatos = p_de.get(qid_de.get(l["id"], ""), [])
        mejor = None
        for pid in candidatos:
            if pid in pleiades:
                d = km((l["lon"], l["lat"]), pleiades[pid][:2])
                if d <= MAX_KM and (mejor is None or d < mejor[1]):
                    mejor = (pid, d)
                elif d > MAX_KM:
                    lejos.append((l["id"], pid, pleiades[pid][2], round(d)))
        if mejor:
            union[l["id"]] = mejor[0]
    texto = json.dumps({"fuente": "Wikidata P1584 (identificador de Pleiades), a partir del artículo de Wikipedia de "
                        "cada lugar", "lugares": dict(sorted(union.items()))}, ensure_ascii=False, indent=1) + "\n"
    SALIDA.write_text(texto, encoding="utf-8")
    print(f"{SALIDA.relative_to(RAIZ)}: {len(union)} de {len(lugares)} lugares unidos con Pleiades; "
          f"{len(lejos)} descartados por estar a más de {MAX_KM:.0f} km")
    if "--lista" in sys.argv:
        for i, pid in sorted(union.items()):
            print(f"  {i} → {pid} {pleiades[pid][2]}")
        for i, pid, nombre, d in lejos:
            print(f"  lejos: {i} → {pid} {nombre} ({d} km)")


if __name__ == "__main__":
    main()
