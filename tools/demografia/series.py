"""Series por país de Our World in Data: población, esperanza de vida, fecundidad, economía y educación.

La app las muestra en la pestaña «Datos» para el país actual de cada punto del mapa (`data/demografia/
unidades_pais.bin`, que arma `tools/pipeline/p4_paises.py`). Todas usan las fronteras de hoy. Antes de 1950 se guarda
un valor por década y desde 1950 uno por año, para que el archivo no pese más de lo necesario.

Uso:
  python3 tools/demografia/series.py            baja las series y escribe data/demografia/paises.json
  python3 tools/demografia/series.py --resumen  muestra qué quedó (cuántos países por indicador, tamaño)
"""
from __future__ import annotations

import csv
import datetime
import io
import json
import sys
import time
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DIR = RAIZ / "data" / "demografia"
SALIDA = DIR / "paises.json"
CONSULTA = "?v=1&csvType=full&useColumnShortNames=true"
UA = {"User-Agent": "tmap-demografia/0.4 (https://bafif.github.io/tmap; tools/demografia/series.py)"}
HASTA = 2024  # nada de proyecciones: el mapa llega a 2024

# clave, nombre, unidad, decimales, escala logarítmica, [(slug, columna, desde, hasta)] por tramos
INDICADORES = [
    ("poblacion", "Población", "habitantes", 0, True, [("population", "population_historical", 1800, HASTA)]),
    ("esperanza_vida", "Esperanza de vida al nacer", "años", 1, False,
     [("life-expectancy", "life_expectancy_0", 1800, HASTA)]),
    ("fecundidad", "Hijos por mujer", "hijos", 2, False,
     [("children-born-per-woman", "fertility_rate_hist", 1800, HASTA)]),
    ("mortalidad_infantil", "Mueren antes de los 5 años", "%", 1, False,
     [("child-mortality", "child_mortality_rate", 1800, HASTA)]),
    ("edad_mediana", "Edad mediana", "años", 1, False,
     [("median-age", "median_age__sex_all__age_all__variant_estimates", 1950, HASTA)]),
    ("urbana", "Población urbana", "%", 1, False,
     [("urbanization-last-500-years", "urbc_c_share", 1800, 1949),
      ("share-of-population-urban", "share__area_type_urban__data_type_estimates", 1950, HASTA)]),
    ("pib_pc", "PIB per cápita", "US$ de 2011", 0, True,
     [("gdp-per-capita-maddison-project-database", "gdp_per_capita", 1800, HASTA)]),
    ("pobreza_extrema", "Pobreza extrema", "%", 1, False,
     [("share-of-population-in-extreme-poverty",
       "headcount_ratio__ppp_version_2021__poverty_line_300__welfare_type_income_or_consumption__table_income_or_consumption_consolidated__survey_comparability_no_spells",
       1960, HASTA)]),
    ("alfabetizacion", "Adultos alfabetizados", "%", 1, False,
     [("cross-country-literacy-rates", "literacy_rate", 1800, HASTA)]),
    ("escolaridad", "Años de escolaridad promedio", "años", 1, False,
     [("mean-years-of-schooling-long-run", "mf_youth_and_adults__15_64_years__average_years_of_education", 1870, 2020)]),
    ("nacidos_afuera", "Nacidos en otro país", "%", 1, False,
     [("migrant-stock-share", "immigrant_share_of_dest_population_all", 1990, HASTA)]),
]


DESCRIPCIONES = {
    "poblacion": "Habitantes dentro de las fronteras actuales del país.",
    "esperanza_vida": "Años que viviría en promedio quien nace ese año, si se mantuviera la mortalidad de ese año.",
    "fecundidad": "Hijos que tendría en promedio una mujer a lo largo de su vida con la fecundidad de ese año.",
    "mortalidad_infantil": "Porcentaje de los nacidos que muere antes de cumplir cinco años.",
    "edad_mediana": "La mitad de la población es más joven que esta edad y la otra mitad, mayor.",
    "urbana": "Porcentaje de la población que vive en ciudades (antes de 1950, estimación de HYDE).",
    "pib_pc": "Producto por habitante en dólares internacionales de 2011 (paridad de poder adquisitivo), Maddison.",
    "pobreza_extrema": "Porcentaje que vive con menos de 3 dólares por día (paridad de poder adquisitivo de 2021), "
                       "según las encuestas de hogares del Banco Mundial.",
    "alfabetizacion": "Porcentaje de los adultos que sabe leer y escribir.",
    "escolaridad": "Años de escuela promedio de la población de 15 a 64 años.",
    "nacidos_afuera": "Porcentaje de la población nacida en otro país (stock de inmigrantes de la ONU).",
}


def bajar(url: str) -> bytes:
    for intento in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
                return r.read()
        except Exception:  # noqa: BLE001
            if intento == 3:
                raise
            time.sleep(5 * 2 ** intento)
    raise RuntimeError(url)


def vale(anio: int) -> bool:
    """Antes de 1950, un valor por década; desde 1950, todos."""
    return anio >= 1950 or anio % 10 == 0


def main() -> int:
    paises_mapa = json.loads((DIR / "paises_mapa.json").read_text(encoding="utf-8"))["paises"]
    codigos = [p["codigo"] for p in paises_mapa] + ["OWID_WRL"]
    nombres = {p["codigo"]: p["nombre"] for p in paises_mapa}
    nombres["OWID_WRL"] = "Mundo"
    indicadores, series = [], {c: {} for c in codigos}
    for clave, nombre, unidad, dec, log, tramos in INDICADORES:
        valores: dict[str, dict[int, float]] = {c: {} for c in codigos}
        fuentes, urls = [], []
        for slug, col, desde, hasta in tramos:
            url = f"https://ourworldindata.org/grapher/{slug}"
            meta = json.loads(bajar(f"{url}.metadata.json{CONSULTA}"))
            fuentes.append(meta["columns"][col]["citationShort"] + (f" ({desde}-{hasta})" if len(tramos) > 1 else ""))
            urls.append(url)
            for f in csv.DictReader(io.StringIO(bajar(f"{url}.csv{CONSULTA}").decode("utf-8"))):
                c, a, v = f["code"], int(f["year"]), f.get(col, "")
                if c in valores and desde <= a <= hasta and vale(a) and v not in ("", None):
                    valores[c][a] = float(v)
            time.sleep(1)
        anios = sorted({a for d in valores.values() for a in d})
        con_datos = 0
        for c in codigos:
            fila = [None if a not in valores[c] else (int(round(valores[c][a])) if dec == 0 else round(valores[c][a], dec))
                    for a in anios]
            if any(v is not None for v in fila):
                series[c][clave] = fila
                con_datos += 1
        indicadores.append({"clave": clave, "nombre": nombre, "unidad": unidad, "decimales": dec, "log": log,
                            "descripcion": DESCRIPCIONES[clave],
                            "fuente": "; ".join(fuentes), "url": " ".join(urls), "anios": anios})
        print(f"{clave}: {len(anios)} años ({anios[0]}-{anios[-1]}), {con_datos} países", file=sys.stderr)
    datos = {
        "descripcion": "Series por país (fronteras actuales) de Our World in Data, CC BY 4.0. Antes de 1950, un valor "
                       "por década. Cada indicador cita su fuente original.",
        "licencia": "CC BY 4.0 (Our World in Data y fuentes citadas)",
        "descargado": datetime.date.today().isoformat(),
        "indicadores": indicadores,
        "paises": {c: {"nombre": nombres[c], "series": series[c]} for c in codigos if series[c]},
    }
    texto = json.dumps(datos, ensure_ascii=False, separators=(",", ":"))
    SALIDA.write_text(texto + "\n", encoding="utf-8")
    print(f"{len(datos['paises'])} países, {len(texto) / 1e6:.2f} MB → {SALIDA.relative_to(RAIZ)}")
    return 0


def resumen() -> int:
    d = json.loads(SALIDA.read_text(encoding="utf-8"))
    for i in d["indicadores"]:
        n = sum(1 for p in d["paises"].values() if i["clave"] in p["series"])
        print(f"{i['clave']:20} {len(i['anios']):4} años {i['anios'][0]}-{i['anios'][-1]}  {n} países  {i['fuente'][:80]}")
    print(f"{SALIDA.stat().st_size / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(resumen() if "--resumen" in sys.argv else main())
