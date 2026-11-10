"""Informe de cobertura de la enciclopedia: qué está cubierto y qué no, en `docs/es/cobertura.md`.

Lee los paquetes, la asignación de población (`poblacion_regiones.json`), el extracto de Our World in Data y los datos
del mapa (`data/mapa/`), y escribe un informe que no se edita a mano. Solo usa la biblioteca estándar de Python.

Uso: python3 tools/enciclopedia/cobertura.py              escribe docs/es/cobertura.md
     python3 tools/enciclopedia/cobertura.py --comprobar  sale con 1 si el informe no está al día
"""

from __future__ import annotations

import json
import math
import struct
import sys
import zlib
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PAQ = RAIZ / "data" / "enciclopedia" / "paquetes"
MAPA = RAIZ / "data" / "mapa"
SALIDA = RAIZ / "docs" / "es" / "cobertura.md"
HERR = Path(__file__).resolve().parent
MARCA = "vía Our World in Data"
ANIOS_TABLA = [-10000, -5000, -3000, -1000, 1, 500, 1000, 1300, 1500, 1700, 1800, 1900, 1950, 2000, 2023]
ANCHO, LAT_N, LAT_S = 8192, 83.0, -57.0


# --------------------------------------------------------------------------------------------------- utilidades
def miller_y(lat: float) -> float:
    phi = math.radians(max(-89.9, min(89.9, lat)))
    return 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * phi))


def miller_lat(y: float) -> float:
    return math.degrees(2.5 * math.atan(math.exp(0.8 * y)) - 0.625 * math.pi)


YN, YS = miller_y(LAT_N), miller_y(LAT_S)
ALTO = int(round(ANCHO * (YN - YS) / (2 * math.pi) / 16) * 16)


def dentro(lon: float, lat: float, poli: list) -> bool:
    res = False
    n = len(poli)
    for i in range(n):
        x1, y1 = poli[i][0], poli[i][1]
        x2, y2 = poli[i - 1][0], poli[i - 1][1]
        if (y1 > lat) != (y2 > lat) and lon < (x2 - x1) * (lat - y1) / (y2 - y1) + x1:
            res = not res
    return res


def texto_anio(a: int | None) -> str:
    if a is None:
        return "hoy"
    return f"{-a} a. C." if a < 0 else str(a)


def miles(n: float) -> str:
    return f"{n:,.0f}".replace(",", " ")


def millones(n: float) -> str:
    if n >= 1e9:
        return f"{n / 1e9:.2f} mil millones".replace(".", ",")
    if n >= 1e6:
        return f"{n / 1e6:.1f} millones".replace(".", ",")
    return miles(n)


def pct(a: float, b: float) -> str:
    return f"{100 * a / b:.1f} %".replace(".", ",") if b else "—"


# ------------------------------------------------------------------------------------------------------- datos
def leer_paquetes() -> dict:
    return {f.stem: json.loads(f.read_text(encoding="utf-8")) for f in sorted(PAQ.glob("*.json"))
            if f.name != "familias.json"}


def unidades_y_entidades():
    """(lon, lat, km², entidad en 2024) de cada unidad del mapa, y la lista de entidades."""
    meta = json.loads((MAPA / "politico.json").read_text(encoding="utf-8"))
    crudo = zlib.decompress((MAPA / "politico.bin").read_bytes())

    def parte(nombre):
        p = meta["politico_bin"]["partes"][nombre]
        fmt = "<%d%s" % (p["bytes"] // 4, "f" if p["tipo"] == "f32" else "i")
        return struct.unpack_from(fmt, crudo, p["inicio"])

    xs, ys, tam = parte("unidad_x"), parte("unidad_y"), parte("unidad_tam")
    anio, uni, despues = parte("evento_anio"), parte("evento_unidad"), parte("evento_despues")
    ent = [-1] * len(xs)
    ultimo = [-10 ** 9] * len(xs)
    for a, u, d in zip(anio, uni, despues):
        if a <= 2024 and a >= ultimo[u]:
            ent[u], ultimo[u] = d, a
    out = []
    for x, y, t, e in list(zip(xs, ys, tam, ent))[1:]:  # la unidad 0 es el mar
        lon = x / ANCHO * 360.0 - 180.0
        lat = miller_lat(YN - y / ALTO * (YN - YS))
        kx = 40075.0 * math.cos(math.radians(lat)) / ANCHO
        ky = 6371.0 * (YN - YS) / ALTO * math.cos(math.radians(0.8 * lat))
        out.append((lon, lat, t * kx * ky, e))
    return out, meta["entidades"]


# ----------------------------------------------------------------------------------------------------- informe
def generar() -> str:
    paquetes = leer_paquetes()
    asign = json.loads((HERR / "poblacion_regiones.json").read_text(encoding="utf-8"))
    owid = json.loads((HERR / "datos" / "poblacion-owid.json").read_text(encoding="utf-8"))
    nombres_es = json.loads((MAPA / "nombres_es.json").read_text(encoding="utf-8"))
    regiones = [(paq, r) for paq, d in paquetes.items() for r in d.get("regiones", [])]
    por_id = {r["id"]: (paq, r) for paq, r in regiones}
    primer_nivel = [r for _, r in regiones if not r.get("padre")]

    # cuántos elementos se refieren a cada región
    refs: dict[str, dict[str, int]] = {r["id"]: {"fuentes": 0, "hechos": 0, "lugares": 0} for _, r in regiones}
    for d in paquetes.values():
        for f in d.get("fuentes", []):
            for rid in (f.get("trata") or {}).get("regiones", []):
                if rid in refs:
                    refs[rid]["fuentes"] += 1
        for sec in ("hechos", "lugares"):
            for x in d.get(sec, []):
                for rid in x.get("regiones", []):
                    if rid in refs:
                        refs[rid][sec] += 1
    totales = {s: sum(len(d.get(s, [])) for d in paquetes.values()) for s in ("fuentes", "personas", "hechos", "lugares")}
    sin_lugar = sum(1 for d in paquetes.values() for f in d.get("fuentes", [])
                    if f.get("escrita", {}).get("lon") is None)

    # tierra cubierta, medida con las unidades del mapa
    unidades, entidades = unidades_y_entidades()
    cajas = []
    for r in primer_nivel:
        p = r["poligono"]
        cajas.append((min(v[0] for v in p), max(v[0] for v in p), min(v[1] for v in p), max(v[1] for v in p), p))
    km_total = km_dentro = 0.0
    fuera_por_entidad: dict[int, float] = {}
    for lon, lat, km2, e in unidades:
        km_total += km2
        if any(a <= lon <= b and c <= lat <= d and dentro(lon, lat, p) for a, b, c, d, p in cajas):
            km_dentro += km2
        else:
            fuera_por_entidad[e] = fuera_por_entidad.get(e, 0.0) + km2

    def nombre_entidad(e: int) -> str:
        if e < 0:
            return "Sin entidad política en Cliopatria"
        n = entidades[e]["n"]
        return nombres_es.get(n, n)

    # población: qué parte del mundo tiene serie y qué parte tiene una estimación curada cerca
    anios = owid["anios"]
    valor = {c: dict(zip(anios, p["valores"])) for c, p in owid["paises"].items()}
    mundo = valor.get("OWID_WRL", {})
    series = {rid: s for rid, s in asign["series"].items() if not s.get("agrega")}
    asignados = {c for s in series.values() for c in s["paises"]}
    curadas: dict[str, list[int]] = {}
    for _, r in regiones:
        cur = [e["anio"] for e in r.get("demografia", []) if not str(e.get("fuente", "")).endswith(MARCA)
               and e.get("tipo") != "testimonio-antiguo"]
        if cur:
            curadas[r["id"]] = cur

    def pob(codigos, anio):
        a = 0 if anio == 1 else anio
        return sum(valor[c].get(a) or 0 for c in codigos if c in valor)

    filas_pob = []
    for anio in ANIOS_TABLA:
        a = 0 if anio == 1 else anio
        total = mundo.get(a)
        if not total:
            continue
        con_serie = pob(asignados, anio)
        con_curada = 0
        for rid, s in series.items():
            if any(abs(x - anio) <= 100 for x in curadas.get(rid, [])):
                con_curada += pob(s["paises"], anio)
        filas_pob.append(f"| {texto_anio(anio)} | {millones(total)} | {pct(con_serie, total)} | {pct(con_curada, total)} |")

    # tabla de regiones
    def capas(r):
        return " · ".join(str(len(r.get(c, []))) if r.get(c) else "—" for c in ("religiones", "culturas", "idiomas"))

    def eras(r):
        es = r.get("eras", [])
        if not es:
            return "—"
        desde = [e["desde"] for e in es if e.get("desde") is not None]
        hasta = [e["hasta"] for e in es]
        fin = None if any(h is None for h in hasta) else max(hasta)
        return f"{len(es)} ({texto_anio(min(desde)) if desde else 'sin inicio'} a {texto_anio(fin)})"

    def demografia(r):
        rid = r["id"]
        partes = []
        cur = [e for e in r.get("demografia", []) if not str(e.get("fuente", "")).endswith(MARCA)
               and e.get("tipo") != "testimonio-antiguo"]
        if cur:
            autores = sorted({str(e["fuente"]).split(",")[0].split(" (")[0] for e in cur})
            partes.append(f"curada: {', '.join(autores)} ({texto_anio(min(e['anio'] for e in cur))}–"
                          f"{texto_anio(max(e['anio'] for e in cur))})")
        if rid in asign["series"]:
            s = asign["series"][rid]
            partes.append(("suma de sus hijas: " if s.get("agrega") else "por país: ") + ", ".join(s["paises"]))
        elif rid in asign["sin_serie"]:
            destino = asign["sin_serie"][rid]["cuenta_en"]
            partes.append(f"sin serie propia; cuenta en {por_id.get(destino, (None, {'nombre': destino}))[1]['nombre']}")
        else:
            partes.append("**sin asignar**")
        return "; ".join(partes)

    filas_reg = []
    for paq, r in sorted(regiones, key=lambda x: (x[0], x[1]["nombre"])):
        c = refs[r["id"]]
        nombre = r["nombre"] + (f" (en {por_id[r['padre']][1]['nombre']})" if r.get("padre") in por_id else "")
        filas_reg.append(f"| {nombre} | {paq} | {eras(r)} | {demografia(r)} | {capas(r)} | "
                         f"{c['fuentes']} · {c['hechos']} · {c['lugares']} |")

    sin_capas = sorted(r["nombre"] for _, r in regiones if not any(r.get(c) for c in ("religiones", "culturas", "idiomas")))
    sin_eras = sorted(r["nombre"] for _, r in regiones if not r.get("eras"))
    fuera = sorted(((km, e) for e, km in fuera_por_entidad.items() if km >= 10000), reverse=True)
    no_asignados = sorted(((valor[c].get(2023) or 0, c) for c in valor
                           if c not in asignados and c != "OWID_WRL"), reverse=True)

    L = []
    L.append("# Cobertura de la enciclopedia")
    L.append("")
    L.append("> Este archivo lo genera `tools/enciclopedia/cobertura.py` a partir de los paquetes, de la asignación de "
             "población (`tools/enciclopedia/poblacion_regiones.json`) y de los datos del mapa; no se edita a mano. "
             "`python3 tools/enciclopedia/cobertura.py` lo rehace y `validar.py` avisa cuando quedó viejo.")
    L.append("")
    L.append("## En números")
    L.append("")
    L.append(f"- **Regiones:** {len(regiones)} ({len(primer_nivel)} de primer nivel) en {len(paquetes)} paquetes.")
    L.append(f"- **Tierra firme dentro de alguna región:** {pct(km_dentro, km_total)} de los "
             f"{millones(km_total)} de km² del mapa (sin la Antártida), medido con las {miles(len(unidades))} "
             "unidades del mapa.")
    con_serie_n = sum(1 for _, r in regiones if r["id"] in asign["series"])
    L.append(f"- **Población:** {con_serie_n} regiones tienen serie propia y {len(asign['sin_serie'])} se cuentan "
             f"dentro de otra; {len(curadas)} tienen además estimaciones curadas de especialistas.")
    L.append(f"- **Capas:** {len(regiones) - len(sin_eras)} regiones con eras y "
             f"{len(regiones) - len(sin_capas)} con religiones, culturas o idiomas.")
    L.append(f"- **Elementos:** {totales['fuentes']} fuentes ({sin_lugar} sin lugar de escritura), "
             f"{totales['personas']} personas, {totales['hechos']} hechos y {totales['lugares']} lugares.")
    L.append("")
    L.append("## Población: qué parte del mundo cubre cada época")
    L.append("")
    L.append(f"La población mundial y la de cada país salen de Our World in Data (actualización del "
             f"{owid.get('actualizado')}): HYDE 3.3 hasta 1799, Gapminder v7 de 1800 a 1949 y la ONU (World "
             "Population Prospects 2024) desde 1950, siempre en las fronteras actuales. «Con serie» es la parte de la "
             "población mundial que vive en países asignados a alguna región. «Con estimación curada» es la parte que "
             "vive en regiones que, a menos de cien años de esa fecha, tienen además una estimación publicada por "
             "especialistas para esa región (Russell, Urlanis, Butzer, DellaPergola…); el resto es solo el modelo "
             "por país.")
    L.append("")
    L.append("| Año | Población mundial | Con serie | Con estimación curada |")
    L.append("|---|---|---|---|")
    L += filas_pob
    L.append("")
    L.append("Antes del año 1, HYDE extrapola con modelos de densidad y uso del suelo: las cifras son órdenes de "
             "magnitud, no recuentos. En las islas que se poblaron tarde (Islandia, Madagascar, el Caribe, Nueva "
             "Zelanda) se omiten los años anteriores al poblamiento.")
    L.append("")
    L.append("## Regiones")
    L.append("")
    L.append("Eras: cantidad y período. Población: estimaciones curadas y países que suma la serie (códigos ISO). "
             "Capas: entradas de religión · cultura · idioma. Elementos: fuentes · hechos · lugares que nombran la "
             "región.")
    L.append("")
    L.append("| Región | Paquete | Eras | Población | Capas | Elementos |")
    L.append("|---|---|---|---|---|---|")
    L += filas_reg
    L.append("")
    L.append("## Lo que falta")
    L.append("")
    L.append("### Tierra sin región")
    L.append("")
    L.append(f"{pct(km_total - km_dentro, km_total)} de la tierra firme del mapa queda fuera de toda región. Por "
             "entidad política de Cliopatria en 2024 (solo las que suman más de 10 000 km²):")
    L.append("")
    for km, e in fuera:
        L.append(f"- {nombre_entidad(e)}: {miles(km)} km²")
    L.append("")
    L.append("### Países sin región en la población")
    L.append("")
    if no_asignados:
        L.append("Territorios de la tabla de Our World in Data que ninguna región suma (población de 2023):")
        L.append("")
        for p, c in no_asignados:
            L.append(f"- {owid['paises'][c]['nombre']} ({c}): {miles(p)}")
    else:
        L.append("Ninguno.")
    L.append("")
    L.append("### Regiones sin serie de población propia")
    L.append("")
    L.append("Las series por país no se pueden partir: estas regiones no tienen población propia y se cuentan en otra.")
    L.append("")
    for rid, s in sorted(asign["sin_serie"].items(), key=lambda x: por_id[x[0]][1]["nombre"]):
        L.append(f"- {por_id[rid][1]['nombre']}: {s['nota']}")
    L.append("")
    L.append(f"### Regiones sin religiones, culturas ni idiomas ({len(sin_capas)})")
    L.append("")
    L.append(", ".join(sin_capas) + ".")
    L.append("")
    if sin_eras:
        L.append(f"### Regiones sin eras ({len(sin_eras)})")
        L.append("")
        L.append(", ".join(sin_eras) + ".")
        L.append("")
    L.append("### Límites de los datos de población")
    L.append("")
    L.append("- Las series por país usan las fronteras actuales: una región histórica más chica o más grande que sus "
             "países (la Rus, Mesoamérica, los Andes) recibe la población de los países enteros, y la nota de cada "
             "serie lo dice.")
    L.append("- Entre una estimación curada y la serie por país puede haber un salto: son métodos y territorios "
             "distintos, y el gráfico muestra la fuente de cada punto.")
    L.append("- Our World in Data no publica los escenarios bajo y alto de HYDE, así que las series no tienen rango "
             "de incertidumbre. Las grillas de HYDE, que permitirían sumar la población dentro de cada polígono, "
             "están en el servidor de la Universidad de Utrecht detrás de una verificación anti-bots.")
    L.append("")
    return "\n".join(L)


def main() -> int:
    texto = generar()
    if "--comprobar" in sys.argv:
        actual = SALIDA.read_text(encoding="utf-8") if SALIDA.exists() else ""
        if actual != texto:
            print(f"{SALIDA.relative_to(RAIZ)} está desactualizado: corré python3 tools/enciclopedia/cobertura.py")
            return 1
        return 0
    SALIDA.write_text(texto, encoding="utf-8")
    print(f"escrito {SALIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
