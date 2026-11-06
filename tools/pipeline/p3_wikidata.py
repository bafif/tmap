"""Paso 3: títulos de Wikipedia en español y etiquetas de Wikidata para las entidades de Cliopatria.

Escribe `data/mapa/wikidata_es.json`: {Qid: {"es": título en es.wikipedia, "l": etiqueta en español}}.
La app lo usa para mostrar el artículo en español cuando existe. Los nombres del mapa se revisan aparte, en
`data/mapa/nombres_es.json` (nombre de Cliopatria → nombre en español).
"""

from __future__ import annotations

import json
import subprocess
import time
import urllib.parse

from comun import SALIDA, guardar_json

AGENTE = "TellMAP/0.1 (atlas historico de codigo abierto; https://github.com/bafif/tmap)"


def pedir(ids):
    params = {
        "action": "wbgetentities",
        "ids": "|".join(ids),
        "props": "labels|sitelinks",
        "languages": "es",
        "sitefilter": "eswiki",
        "format": "json",
    }
    url = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode(params)
    # curl en vez de urllib: en algunas redes urllib tarda mucho más en conectar.
    r = subprocess.run(["curl", "-s", "--max-time", "60", "-A", AGENTE, url], capture_output=True, check=True)
    return json.loads(r.stdout)


def main():
    meta = json.load(open(SALIDA / "politico.json", encoding="utf-8"))
    ids = sorted({e["d"] for e in meta["entidades"] if e.get("d", "").startswith("Q")})
    print(f"{len(ids)} ids de Wikidata")
    salida = {}
    for i in range(0, len(ids), 50):
        lote = ids[i : i + 50]
        datos = pedir(lote)
        for qid, ent in datos.get("entities", {}).items():
            item = {}
            es = ent.get("sitelinks", {}).get("eswiki", {}).get("title")
            if es:
                item["es"] = es
            etiqueta = ent.get("labels", {}).get("es", {}).get("value")
            if etiqueta:
                item["l"] = etiqueta
            if item:
                salida[qid] = item
        print(f"  {i + len(lote)}/{len(ids)}", flush=True)
        time.sleep(0.3)
    guardar_json(SALIDA / "wikidata_es.json", salida)
    print(f"Con artículo en español: {sum(1 for v in salida.values() if 'es' in v)}; con etiqueta: {sum(1 for v in salida.values() if 'l' in v)}")


if __name__ == "__main__":
    main()
