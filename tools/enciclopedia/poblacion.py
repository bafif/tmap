"""Población estimada de cada región, sumando la serie histórica por país de Our World in Data.

Our World in Data (OWID) publica en una sola tabla la población de cada país actual desde el 10 000 a. C. hasta hoy,
combinando tres fuentes: HYDE 3.3 (PBL, 2023) hasta 1799, Gapminder v7 (2022) de 1800 a 1949 y la ONU (World Population
Prospects 2024) desde 1950. Siempre en las fronteras actuales.

`poblacion_regiones.json` dice qué países suma cada región. Las entradas que escribe esta herramienta llevan una fuente
que termina en «vía Our World in Data»: se reemplazan cada vez que se corre. Las estimaciones curadas de un paquete
(Russell, Urlanis, DellaPergola…) mandan: en los años que cubren, más un margen de un siglo, no se agrega nada.

Uso:
  python3 tools/enciclopedia/poblacion.py --descargar   baja la tabla y guarda el extracto en tools/enciclopedia/datos/
  python3 tools/enciclopedia/poblacion.py               escribe la demografía de las regiones en los paquetes
  python3 tools/enciclopedia/poblacion.py --comprobar   sale con 1 si los paquetes no están al día con el extracto
"""

from __future__ import annotations

import csv
import datetime
import io
import json
import sys
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PAQ = RAIZ / "data" / "enciclopedia" / "paquetes"
MAPA = Path(__file__).with_name("poblacion_regiones.json")
EXTRACTO = Path(__file__).with_name("datos") / "poblacion-owid.json"
URL = "https://ourworldindata.org/grapher/population"
CONSULTA = "?v=1&csvType=full&useColumnShortNames=true"
MARCA = "vía Our World in Data"
ANIOS = list(range(-10000, 0, 1000)) + [0] + list(range(100, 1800, 100)) + [1750, 1800, 1850, 1900, 1925, 1950, 1975,
                                                                         2000, 2023]
ANIOS = sorted(set(ANIOS))
MARGEN = 100  # años alrededor de una serie curada en los que no se agrega nada


def fuente(anio: int) -> str:
    if anio < 1800:
        return f"HYDE 3.3 (PBL, 2023), {MARCA}"
    if anio < 1950:
        return f"Gapminder, Population v7 (2022), {MARCA}"
    return f"ONU, World Population Prospects 2024, {MARCA}"


def bajar(url: str) -> bytes:
    pedido = urllib.request.Request(url, headers={"User-Agent": "tmap-enciclopedia/0.4"})
    with urllib.request.urlopen(pedido, timeout=120) as r:
        return r.read()


def descargar() -> None:
    meta = json.loads(bajar(f"{URL}.metadata.json{CONSULTA}"))
    filas = csv.DictReader(io.StringIO(bajar(f"{URL}.csv{CONSULTA}").decode("utf-8")))
    col = meta["columns"]
    variable = next(iter(col))
    paises: dict[str, dict] = {}
    for f in filas:
        codigo = f["code"]
        # sin agregados (continentes, grupos de ingreso) ni países que ya no existen; sí Kosovo y el mundo
        if not codigo or codigo == "ANT" or (codigo.startswith(("OWID_", "UN_"))
                                              and codigo not in ("OWID_KOS", "OWID_WRL")):
            continue
        anio = int(f["year"])
        if anio not in ANIOS:
            continue
        p = paises.setdefault(codigo, {"nombre": f["entity"], "valores": [None] * len(ANIOS)})
        p["valores"][ANIOS.index(anio)] = int(float(f[variable]))
    datos = {
        "fuente": col[variable]["citationLong"],
        "url": f"{URL}{CONSULTA}",
        "licencia": "CC BY 4.0",
        "actualizado": col[variable].get("lastUpdated"),
        "descargado": datetime.date.today().isoformat(),
        "anios": ANIOS,
        "paises": dict(sorted(paises.items())),
    }
    EXTRACTO.parent.mkdir(exist_ok=True)
    texto = json.dumps(datos, ensure_ascii=False, indent=1)
    EXTRACTO.write_text(texto + "\n", encoding="utf-8")
    print(f"{len(paises)} países y territorios, {len(ANIOS)} años → {EXTRACTO.relative_to(RAIZ)}")


def cargar() -> tuple[dict, dict]:
    return json.loads(MAPA.read_text(encoding="utf-8")), json.loads(EXTRACTO.read_text(encoding="utf-8"))


def controlar(mapa: dict, datos: dict, regiones: set[str]) -> list[str]:
    """Problemas de la asignación: países repetidos o inexistentes, regiones sin asignar."""
    problemas = []
    vistos: dict[str, str] = {}
    agregadas = {h for s in mapa["series"].values() for h in s.get("agrega", [])}
    for rid, s in mapa["series"].items():
        if rid not in regiones:
            problemas.append(f"la región {rid} no existe")
        for c in s["paises"]:
            if c not in datos["paises"]:
                problemas.append(f"{rid}: el país {c} no está en el extracto")
            if s.get("agrega"):
                continue
            if c in vistos:
                problemas.append(f"el país {c} está en {vistos[c]} y en {rid}")
            vistos[c] = rid
    for rid in mapa["sin_serie"]:
        if rid not in regiones:
            problemas.append(f"la región {rid} no existe")
    for rid in sorted(regiones - set(mapa["series"]) - set(mapa["sin_serie"]) - agregadas):
        problemas.append(f"la región {rid} no tiene serie ni dice dónde se cuenta")
    return problemas


def serie(paises: list[str], datos: dict, desde: int | None = None) -> list[tuple[int, int]]:
    """(año, población) sumando los países; se omite un año si falta un país que pese más del 5 % en 1950.

    `desde`: año del primer poblamiento documentado; HYDE a veces da valores de modelo para islas todavía deshabitadas
    (Islandia antes de 874, por ejemplo), y esos años se omiten.
    """
    i1950 = ANIOS.index(1950)
    peso = {c: datos["paises"][c]["valores"][i1950] or 0 for c in paises}
    total1950 = sum(peso.values()) or 1
    out = []
    for i, anio in enumerate(ANIOS):
        if desde is not None and anio < desde:
            continue
        valores = {c: datos["paises"][c]["valores"][i] for c in paises}
        if any(v is None and peso[c] / total1950 > 0.05 for c, v in valores.items()):
            continue
        suma = sum(v for v in valores.values() if v)
        if suma > 0:
            out.append((anio, suma))
    return out


def demografia(region: dict, cfg: dict | None, datos: dict) -> list[dict]:
    propias = [e for e in region.get("demografia", []) if not str(e.get("fuente", "")).endswith(MARCA)]
    if cfg is None:
        return propias
    curadas = [e["anio"] for e in propias if e.get("tipo") != "testimonio-antiguo"]
    nuevas = []
    for anio, pob in serie(cfg["paises"], datos, cfg.get("poblada_desde")):
        if curadas and min(curadas) - MARGEN < anio < max(curadas) + MARGEN:
            continue
        e = {"anio": anio or 1, "poblacion": pob, "fuente": fuente(anio)}
        if not nuevas:
            e["nota"] = cfg["nota"]
        nuevas.append(e)
    return sorted(propias + nuevas, key=lambda e: e["anio"])


def main() -> int:
    if "--descargar" in sys.argv:
        descargar()
        return 0
    mapa, datos = cargar()
    paquetes = {f: json.loads(f.read_text(encoding="utf-8")) for f in sorted(PAQ.glob("*.json"))
                if f.name != "familias.json"}
    regiones = {r["id"] for d in paquetes.values() for r in d.get("regiones", [])}
    problemas = controlar(mapa, datos, regiones)
    for p in problemas:
        print("error:", p)
    if problemas:
        return 1
    desactualizados = []
    for f, d in paquetes.items():
        cambio = False
        for r in d.get("regiones", []):
            nueva = demografia(r, mapa["series"].get(r["id"]), datos)
            if nueva != r.get("demografia", []):
                cambio = True
                if nueva:
                    r["demografia"] = nueva
                else:
                    r.pop("demografia", None)
        if not cambio:
            continue
        desactualizados.append(f.name)
        if "--comprobar" not in sys.argv:
            original = f.read_text(encoding="utf-8")
            fin = "\n" if original.endswith("\n") else ""
            f.write_text(json.dumps(d, ensure_ascii=False, indent=2) + fin, encoding="utf-8")
    if "--comprobar" in sys.argv:
        for n in desactualizados:
            print(f"desactualizado: {n} (corré python3 tools/enciclopedia/poblacion.py)")
        return 1 if desactualizados else 0
    print("paquetes actualizados:", ", ".join(desactualizados) or "ninguno")
    return 0


if __name__ == "__main__":
    sys.exit(main())
