"""Valida los paquetes de la enciclopedia (data/enciclopedia/paquetes/*.json) contra data/enciclopedia/ESQUEMA.md.

Uso: python3 tools/enciclopedia/validar.py        (sale con código 1 si hay errores)

Revisa: JSON válido, ids únicos entre paquetes, referencias (autor_id, obras, fuentes, regiones, padre, familia), que no
haya año 0, coordenadas dentro de rango, polígonos de al menos tres puntos, valores permitidos en los campos cerrados y
la sección `familias` (capa, padre sin ciclos, color).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DIR = RAIZ / "data" / "enciclopedia" / "paquetes"
SECCIONES = ["regiones", "fuentes", "personas", "hechos", "lugares"]
TIPOS_HECHO = {"politico", "batalla", "fundacion", "religioso", "cultural", "cientifico", "economico", "desastre",
               "tratado", "construccion", "exploracion", "revolucion"}
TIPOS_LUGAR = {"ciudad", "capital", "templo", "puerto", "sitio-arqueologico", "biblioteca", "universidad"}
PESOS = {"mayoritaria", "importante", "minoritaria"}
CAPAS = ("religiones", "culturas", "idiomas")

errores: list[str] = []
avisos: list[str] = []


def anio(valor, donde):
    if valor is None:
        return
    if not isinstance(valor, int):
        errores.append(f"{donde}: el año {valor!r} no es entero")
    elif valor == 0:
        errores.append(f"{donde}: no existe el año 0")


def punto(d, donde):
    if not isinstance(d, dict) or d.get("lon") is None:
        return
    if not (-180 <= d["lon"] <= 180 and -90 <= d.get("lat", 0) <= 90):
        errores.append(f"{donde}: coordenadas fuera de rango ({d['lon']}, {d.get('lat')})")


def main():
    todo = {s: {} for s in SECCIONES}
    familias = {c: {} for c in CAPAS}
    for archivo in sorted(DIR.glob("*.json")):
        try:
            datos = json.loads(archivo.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errores.append(f"{archivo.name}: JSON inválido ({e})")
            continue
        for f in datos.get("familias", []):
            c, i = f.get("capa"), f.get("id")
            if c not in CAPAS:
                errores.append(f"{archivo.name}/familias/{i}: capa inválida {c!r}")
            elif not i:
                errores.append(f"{archivo.name}/familias: familia sin id")
            elif i in familias[c]:
                errores.append(f"familia «{c}/{i}» repetida ({familias[c][i][0]} y {archivo.name})")
            else:
                familias[c][i] = (archivo.name, f)
        for s in SECCIONES:
            for item in datos.get(s, []):
                i = item.get("id")
                if not i:
                    errores.append(f"{archivo.name}/{s}: elemento sin id")
                    continue
                if i in todo[s]:
                    errores.append(f"{s} «{i}» repetido ({todo[s][i][0]} y {archivo.name})")
                    continue
                todo[s][i] = (archivo.name, item)

    regiones = todo["regiones"]
    usadas: set = set()
    for i, (arch, r) in regiones.items():
        d = f"{arch}/regiones/{i}"
        if r.get("padre") and r["padre"] not in regiones:
            errores.append(f"{d}: padre «{r['padre']}» no existe")
        poli = r.get("poligono", [])
        if len(poli) < 3:
            errores.append(f"{d}: polígono con menos de 3 puntos")
        for p in poli:
            if not (-180 <= p[0] <= 180 and -90 <= p[1] <= 90):
                errores.append(f"{d}: vértice fuera de rango {p}")
                break
        for capa in ("eras", "religiones", "culturas", "idiomas"):
            for e in r.get(capa, []):
                anio(e.get("desde"), f"{d}/{capa}")
                anio(e.get("hasta"), f"{d}/{capa}")
                if e.get("desde") is not None and e.get("hasta") is not None and e["desde"] > e["hasta"]:
                    errores.append(f"{d}/{capa}: «{e.get('nombre')}» termina antes de empezar")
                if capa != "eras" and e.get("peso") not in PESOS:
                    errores.append(f"{d}/{capa}: peso inválido {e.get('peso')!r}")
                if capa != "eras":
                    usadas.add((capa, e.get("familia")))
                    if not e.get("familia"):
                        errores.append(f"{d}/{capa}: «{e.get('nombre')}» sin familia")
                    elif e["familia"] not in familias[capa]:
                        errores.append(f"{d}/{capa}: familia «{e['familia']}» no existe en la sección familias")
        for e in r.get("demografia", []):
            anio(e.get("anio"), f"{d}/demografia")
            if not e.get("fuente"):
                errores.append(f"{d}/demografia {e.get('anio')}: sin fuente")

    for i, (arch, f) in todo["fuentes"].items():
        d = f"{arch}/fuentes/{i}"
        if f.get("tipo") not in ("primaria", "secundaria"):
            errores.append(f"{d}: tipo inválido {f.get('tipo')!r}")
        e = f.get("escrita", {})
        anio(e.get("anio"), d + "/escrita")
        anio(e.get("anio_hasta"), d + "/escrita")
        punto(e, d + "/escrita")
        if e.get("lon") is None:
            avisos.append(f"{d}: sin lugar de escritura (no aparece en el mapa)")
        t = f.get("trata", {})
        anio(t.get("desde"), d + "/trata")
        anio(t.get("hasta"), d + "/trata")
        for r in t.get("regiones", []):
            if r not in regiones:
                errores.append(f"{d}: trata sobre la región «{r}», que no existe")
        if f.get("autor_id") and f["autor_id"] not in todo["personas"]:
            errores.append(f"{d}: autor_id «{f['autor_id']}» no existe")
        for l in f.get("leer", []):
            if not str(l.get("url", "")).startswith("https://") and not str(l.get("url", "")).startswith("http://"):
                errores.append(f"{d}: enlace de lectura inválido {l.get('url')!r}")

    for i, (arch, p) in todo["personas"].items():
        d = f"{arch}/personas/{i}"
        for clave in ("nacimiento", "muerte"):
            if isinstance(p.get(clave), dict):
                anio(p[clave].get("anio"), f"{d}/{clave}")
                punto(p[clave], f"{d}/{clave}")
        punto(p.get("activo"), d + "/activo")
        if isinstance(p.get("activo"), dict):
            anio(p["activo"].get("desde"), d + "/activo")
            anio(p["activo"].get("hasta"), d + "/activo")
        anios = [x.get("anio") for x in (p.get("nacimiento"), p.get("muerte")) if isinstance(x, dict)]
        if isinstance(p.get("activo"), dict):
            anios += [p["activo"].get("desde"), p["activo"].get("hasta")]
        if all(a is None for a in anios):
            avisos.append(f"{d}: sin ningún año (no se ubica en el tiempo)")
        for o in p.get("obras", []):
            if o not in todo["fuentes"]:
                errores.append(f"{d}: obra «{o}» no existe")

    for i, (arch, h) in todo["hechos"].items():
        d = f"{arch}/hechos/{i}"
        anio(h.get("anio"), d)
        anio(h.get("anio_hasta"), d)
        punto(h, d)
        if h.get("tipo") not in TIPOS_HECHO:
            avisos.append(f"{d}: tipo no previsto {h.get('tipo')!r}")
        for r in h.get("regiones", []):
            if r not in regiones:
                errores.append(f"{d}: región «{r}» no existe")
        for f in h.get("fuentes", []):
            if f not in todo["fuentes"]:
                errores.append(f"{d}: fuente «{f}» no existe")

    for i, (arch, l) in todo["lugares"].items():
        d = f"{arch}/lugares/{i}"
        anio(l.get("fundacion"), d)
        anio(l.get("abandono"), d)
        punto(l, d)
        if l.get("tipo") not in TIPOS_LUGAR:
            avisos.append(f"{d}: tipo no previsto {l.get('tipo')!r}")
        for r in l.get("regiones", []):
            if r not in regiones:
                errores.append(f"{d}: región «{r}» no existe")

    for c in CAPAS:
        for i, (arch, f) in familias[c].items():
            d = f"{arch}/familias/{c}/{i}"
            if not f.get("nombre"):
                errores.append(f"{d}: sin nombre")
            if f.get("color") is not None and not re.fullmatch(r"#[0-9a-fA-F]{6}", str(f["color"])):
                errores.append(f"{d}: color inválido {f['color']!r} (va #rrggbb)")
            elif f.get("color") is None and (c, i) in usadas:
                avisos.append(f"{d}: sin color (el mapa le da uno derivado del nombre)")
            vistos, actual = [i], f.get("padre")
            while actual:
                if actual not in familias[c]:
                    errores.append(f"{d}: padre «{actual}» no existe en {c}")
                    break
                if actual in vistos:
                    errores.append(f"{d}: ciclo de padres ({' → '.join(vistos + [actual])})")
                    break
                vistos.append(actual)
                actual = familias[c][actual][1].get("padre")
            if not f.get("wikipedia"):
                avisos.append(f"{d}: sin artículo de Wikipedia")

    print("Totales:", ", ".join(f"{s}: {len(todo[s])}" for s in SECCIONES),
          "| familias:", ", ".join(f"{c} {len(familias[c])}" for c in CAPAS))
    for a in avisos:
        print("aviso:", a)
    for e in errores:
        print("ERROR:", e)
    print(f"{len(errores)} errores, {len(avisos)} avisos")
    sys.exit(1 if errores else 0)


if __name__ == "__main__":
    main()
