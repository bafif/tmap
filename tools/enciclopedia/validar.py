"""Valida los paquetes de la enciclopedia (data/enciclopedia/paquetes/*.json) contra data/enciclopedia/ESQUEMA.md.

Uso: python3 tools/enciclopedia/validar.py              (sale con código 1 si hay errores)
     python3 tools/enciclopedia/validar.py --borradores  (también los borradores de paquetes/borradores/)

Revisa: JSON válido, ids únicos entre paquetes, referencias (autor_id, obras, fuentes, regiones, padre, familia), que no
haya año 0, coordenadas dentro de rango, polígonos de al menos tres puntos que no se crucen, valores permitidos en los campos cerrados y
la sección `familias` (capa, padre sin ciclos, color) y la ficha extendida de las regiones (cada cita apunta a una
referencia con URL, y lo redactado con IA tiene su revisión humana).

Un borrador puede no tener todavía el área de estudio ni la revisión: en los borradores eso es un aviso, no un error.
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
               "tratado", "construccion", "exploracion", "revolucion", "judicial"}
TIPOS_LUGAR = {"ciudad", "capital", "templo", "puerto", "sitio-arqueologico", "biblioteca", "universidad",
               "laboratorio", "institucion", "sitio-historico"}
# Lugares que no existen desde siempre: sin `fundacion` la app los mostraría desde 3400 a. C. Una ciudad o un templo
# antiguos pueden ir sin fecha; un sitio que importa por un hecho lleva el año desde el que se muestra.
TIPOS_LUGAR_CON_FECHA = {"biblioteca", "universidad", "laboratorio", "institucion", "sitio-historico"}
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


def poligono_roto(poli) -> str:
    """Describe por qué un polígono no es un anillo simple (vértices repetidos o lados que se cruzan), o devuelve ''.

    Con la regla par-impar que usa la app, un anillo que se pellizca o se cruza deja afuera pedazos de la región o
    mete pedazos de las vecinas.
    """
    p = [tuple(v[:2]) for v in poli]
    if len(set(p)) < len(p):
        repetidos = sorted({v for v in p if p.count(v) > 1})
        return f"vértice repetido {list(repetidos[0])}"

    def giro(a, b, c):
        v = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        return (v > 1e-12) - (v < -1e-12)

    n = len(p)
    for i in range(n):
        a, b = p[i], p[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = p[j], p[(j + 1) % n]
            if giro(a, b, c) * giro(a, b, d) < 0 and giro(c, d, a) * giro(c, d, b) < 0:
                return f"el lado {i} se cruza con el lado {j}"
    return ""


def extendida(ext, d, es_borrador):
    if not isinstance(ext, dict):
        errores.append(f"{d}: la ficha extendida no tiene el formato del esquema")
        return
    refs = {x.get("n") for x in ext.get("referencias", [])}
    for x in ext.get("referencias", []):
        if not str(x.get("url", "")).startswith(("https://", "http://")):
            errores.append(f"{d}/extendida: la referencia {x.get('n')} no tiene URL")
    for s in ext.get("secciones", []):
        if not s.get("titulo") or not s.get("texto"):
            errores.append(f"{d}/extendida: hay una sección sin título o sin texto")
        citas = set(s.get("citas", [])) | {int(m) for m in re.findall(r"\[(\d+)\]", s.get("texto", ""))}
        for c in sorted(citas - refs):
            errores.append(f"{d}/extendida: «{s.get('titulo')}» cita [{c}], que no está en las referencias")
        if not citas:
            errores.append(f"{d}/extendida: «{s.get('titulo')}» no cita ninguna fuente")
    if isinstance(ext.get("ia"), dict) and not isinstance(ext.get("revision"), dict):
        (avisos if es_borrador else errores).append(
            f"{d}/extendida: redactada con IA y sin revisión humana (falta «revision»)")


def controlar_cobertura():
    """Avisa si la población o los informes de cobertura (docs/es/cobertura.md y docs/en/coverage.md) no están al día
    con los paquetes."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    try:
        import cobertura
        import poblacion
    except ImportError as e:
        avisos.append(f"no se pudo revisar la cobertura: {e}")
        return
    mapa, datos = poblacion.cargar()
    paquetes = {f: json.loads(f.read_text(encoding="utf-8")) for f in sorted(DIR.glob("*.json"))
                if f.name != "familias.json"}
    regiones = {r["id"]: r for d in paquetes.values() for r in d.get("regiones", [])}
    for p in poblacion.controlar(mapa, datos, set(regiones)):
        avisos.append(f"población: {p} (tools/enciclopedia/poblacion_regiones.json)")
    for rid, r in regiones.items():
        if r.get("demografia", []) != poblacion.demografia(r, mapa["series"].get(rid), datos):
            avisos.append(f"población: la serie de {rid} no está al día (corré python3 tools/enciclopedia/poblacion.py)")
    for idioma, salida in cobertura.SALIDAS.items():
        actual = salida.read_text(encoding="utf-8") if salida.exists() else ""
        if actual != cobertura.generar(idioma):
            avisos.append(f"{salida.relative_to(cobertura.RAIZ).as_posix()} está desactualizado "
                          "(corré python3 tools/enciclopedia/cobertura.py)")


def main():
    con_borradores = "--borradores" in sys.argv[1:]
    todo = {s: {} for s in SECCIONES}
    familias = {c: {} for c in CAPAS}
    archivos = sorted(DIR.glob("*.json")) + (sorted((DIR / "borradores").glob("*.json")) if con_borradores else [])
    for archivo in archivos:
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
                todo[s][i] = (archivo.name if archivo.parent == DIR else "borradores/" + archivo.name, item)

    regiones = todo["regiones"]
    usadas: set = set()
    for i, (arch, r) in regiones.items():
        d = f"{arch}/regiones/{i}"
        if r.get("padre") and r["padre"] not in regiones:
            errores.append(f"{d}: padre «{r['padre']}» no existe")
        poli = r.get("poligono", [])
        if len(poli) < 3:
            (avisos if arch.startswith("borradores/") else errores).append(f"{d}: polígono con menos de 3 puntos")
        if "extendida" in r:
            extendida(r["extendida"], d, arch.startswith("borradores/"))
        for p in poli:
            if not (-180 <= p[0] <= 180 and -90 <= p[1] <= 90):
                errores.append(f"{d}: vértice fuera de rango {p}")
                break
        if len(poli) >= 3 and (motivo := poligono_roto(poli)):
            (avisos if arch.startswith("borradores/") else errores).append(f"{d}: el polígono no es un anillo simple ({motivo})")
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
                    # La app lee un «desde» vacío como «desde 3400 a. C.» y pinta el mapa así: los Balcanes con
                    # religión romana en el Neolítico. Si algo es anterior a lo que se sabe, va la primera mención.
                    if e.get("desde") is None:
                        errores.append(f"{d}/{capa}: «{e.get('nombre')}» sin «desde» (poné desde cuándo hay registro)")
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
        if l.get("tipo") in TIPOS_LUGAR_CON_FECHA and l.get("fundacion") is None:
            (avisos if arch.startswith("borradores/") else errores).append(
                f"{d}: {l['tipo']} sin fundacion (aparecería en todas las épocas)")
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

    # La unión con Pleiades (tools/pleiades/enlazar.py) nombra lugares por id: si uno cambió, queda vieja.
    union = RAIZ / "data" / "pleiades" / "enciclopedia.json"
    if union.exists():
        for i in json.loads(union.read_text(encoding="utf-8")).get("lugares", {}):
            if i not in todo["lugares"]:
                avisos.append(f"data/pleiades/enciclopedia.json: el lugar «{i}» ya no existe "
                              "(corré python3 tools/pleiades/enlazar.py)")

    # Copias de los enlaces de lectura en la Wayback Machine (tools/enciclopedia/enlaces.py).
    ruta_copias = RAIZ / "data" / "enciclopedia" / "archivo.json"
    if ruta_copias.exists():
        copias = json.loads(ruta_copias.read_text(encoding="utf-8")).get("copias", {})
        sin = {l["url"] for _, f in todo["fuentes"].values() for l in f.get("leer") or []
               if "archive.org/" not in l.get("url", "") and l.get("url") not in copias}
        if sin:
            avisos.append(f"{len(sin)} enlaces de lectura sin copia archivada (corré python3 tools/enciclopedia/enlaces.py)")

    controlar_cobertura()

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
