#!/usr/bin/env python3
"""Capa de traducción de la enciclopedia: data/enciclopedia/traducciones/<idioma>/<paquete>.json.

Los paquetes se escriben en español y no cambian. Cada paquete puede tener al lado una capa con sus textos en otro
idioma: {"textos": {"sección/id/campo": {"hash": …, "texto": …}}}, donde el hash es del texto español que se tradujo.
La app la aplica al cargar los paquetes (Enciclopedia._traducir); lo que no está en la capa se ve en español. Qué
campos se traducen: CAMPOS, más abajo, y la sección «Traducciones» de data/enciclopedia/ESQUEMA.md.

Uso:  python3 tools/traduccion/enciclopedia.py estado
          Cuántos textos hay, cuántos están traducidos, cuántos faltan y cuántos quedaron viejos (el español cambió).
      python3 tools/traduccion/enciclopedia.py extraer <carpeta>
          Escribe en <carpeta> los textos que faltan o están viejos, en lotes 001.json, 002.json… de unos 20 000
          caracteres: {"paquete/sección/id/campo": "texto en español"}. Un texto nunca se parte entre lotes y los
          campos de un mismo elemento van juntos. Un texto repetido (un rol, un lugar) va una sola vez. Deja además
          extraccion.json, con el hash de cada texto, para aplicar.
      python3 tools/traduccion/enciclopedia.py aplicar <respuestas> [--extraccion <carpeta>]
          Lee las respuestas ({"paquete/sección/id/campo": "texto traducido"}, en .json, .md o .txt; puede venir
          dentro de un bloque de código), avisa las claves que faltan o sobran y vuelca las traducciones en la capa con
          el hash del español que se extrajo. Sin --extraccion, busca extraccion.json en <respuestas> y en la carpeta de
          arriba. Saca de la capa lo que ya no existe en los paquetes.

Opciones: --idioma en (el único que hay por ahora), --tam 20000 (caracteres por lote), --capa <carpeta> (otra raíz
para las capas, en vez de data/enciclopedia/traducciones; la usa la prueba).

Sin dependencias: Python 3.10 o más nuevo.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PAQUETES = RAIZ / "data" / "enciclopedia" / "paquetes"
CAPAS = RAIZ / "data" / "enciclopedia" / "traducciones"
MANIFIESTO = "extraccion.json"

# Campos que se traducen, por sección. «*» es cualquier posición de una lista. Lo demás no se toca: ids y campos que
# son ids (familia, padre, regiones, obras, fuentes, autor_id), valores cerrados (peso, tipo, genero, confianza,
# capa), años, coordenadas, colores, wikipedia y wikidata, las direcciones de leer (su título sí), las fuentes bibliográficas de la
# demografía y las referencias de la ficha extendida, los títulos originales y lo que no se muestra (la descripción del
# paquete, ia, revision, origen).
CAMPOS: dict[str, list[str]] = {
    "regiones": [
        "nombre", "resumen",
        "eras.*.nombre", "eras.*.resumen", "eras.*.nota",
        "demografia.*.nota",
        "religiones.*.nombre", "religiones.*.nota",
        "culturas.*.nombre", "culturas.*.nota",
        "idiomas.*.nombre", "idiomas.*.nota",
        "extendida.secciones.*.titulo", "extendida.secciones.*.texto",
    ],
    "familias": ["nombre", "nota"],
    "fuentes": [
        "titulo", "autor", "escrita.lugar", "idioma_original", "soporte", "resumen", "por_que_importa",
        "leer.*.titulo",
    ],
    "personas": ["nombre", "roles.*", "nacimiento.lugar", "muerte.lugar", "activo.lugar", "resumen"],
    "hechos": ["titulo", "lugar", "resumen"],
    "lugares": ["nombre", "resumen"],
}
CITA = re.compile(r"\[\d+\]")


def hash_corto(texto: str) -> str:
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()[:10]


def _caminos(valor, patron: list[str], hecho: list[str]):
    """Recorre un patrón de campo («eras.*.nombre») y devuelve (camino concreto, texto) de cada texto que existe."""
    if not patron:
        if isinstance(valor, str) and valor.strip():
            yield ".".join(hecho), valor
        return
    paso, resto = patron[0], patron[1:]
    if paso == "*":
        if isinstance(valor, list):
            for i, x in enumerate(valor):
                yield from _caminos(x, resto, hecho + [str(i)])
    elif isinstance(valor, dict) and paso in valor:
        yield from _caminos(valor[paso], resto, hecho + [paso])


def id_de(seccion: str, item: dict) -> str:
    return f"{item.get('capa')}:{item['id']}" if seccion == "familias" else str(item["id"])


def textos_de_paquete(datos: dict) -> dict[str, str]:
    """Los textos traducibles de un paquete, en orden: {"sección/id/campo": texto}."""
    out: dict[str, str] = {}
    for seccion, campos in CAMPOS.items():
        for item in datos.get(seccion, []):
            if not isinstance(item, dict) or "id" not in item:
                continue
            for campo in campos:
                for camino, texto in _caminos(item, campo.split("."), []):
                    out[f"{seccion}/{id_de(seccion, item)}/{camino}"] = texto
    return out


def paquetes() -> dict[str, dict[str, str]]:
    """paquete (nombre del archivo sin .json) → sus textos traducibles."""
    out = {}
    for ruta in sorted(PAQUETES.glob("*.json")):
        out[ruta.stem] = textos_de_paquete(json.loads(ruta.read_text(encoding="utf-8")))
    return out


def leer_capa(raiz: Path, idioma: str, paquete: str) -> dict[str, dict]:
    ruta = raiz / idioma / f"{paquete}.json"
    if not ruta.exists():
        return {}
    return json.loads(ruta.read_text(encoding="utf-8")).get("textos", {})


def escribir_capa(raiz: Path, idioma: str, paquete: str, textos: dict[str, dict]) -> None:
    ruta = raiz / idioma / f"{paquete}.json"
    if not textos:
        if ruta.exists():
            ruta.unlink()
        return
    ruta.parent.mkdir(parents=True, exist_ok=True)
    lineas = [f"  {json.dumps(k, ensure_ascii=False)}: "
              f"{json.dumps({'hash': v['hash'], 'texto': v['texto']}, ensure_ascii=False)}" for k, v in textos.items()]
    cuerpo = ",\n".join(lineas)
    ruta.write_text(f'{{\n "paquete": {json.dumps(paquete)},\n "idioma": {json.dumps(idioma)},\n "textos": {{\n'
                    f"{cuerpo}\n }}\n}}\n", encoding="utf-8")


def pendientes(raiz: Path, idioma: str) -> tuple[dict[str, str], dict[str, int]]:
    """Los textos que faltan o están viejos ({"paquete/sección/id/campo": texto}) y la cuenta de cada caso."""
    out: dict[str, str] = {}
    cuenta = {"textos": 0, "al_dia": 0, "faltan": 0, "viejos": 0, "sobran": 0}
    for paquete, textos in paquetes().items():
        capa = leer_capa(raiz, idioma, paquete)
        for clave, texto in textos.items():
            cuenta["textos"] += 1
            t = capa.get(clave)
            if t is None or not t.get("texto"):
                cuenta["faltan"] += 1
                out[f"{paquete}/{clave}"] = texto
            elif t.get("hash") != hash_corto(texto):
                cuenta["viejos"] += 1
                out[f"{paquete}/{clave}"] = texto
            else:
                cuenta["al_dia"] += 1
        cuenta["sobran"] += len(set(capa) - set(textos))
    return out, cuenta


# ---------------------------------------------------------------------------------------------------------------


def estado(raiz: Path, idioma: str) -> int:
    _, c = pendientes(raiz, idioma)
    print(f"{c['textos']} textos traducibles en {idioma}: {c['al_dia']} al día, {c['faltan']} sin traducir, "
          f"{c['viejos']} viejos (el español cambió) y {c['sobran']} en la capa que ya no existen.")
    return 0


def extraer(carpeta: Path, raiz: Path, idioma: str, tam: int) -> int:
    textos, cuenta = pendientes(raiz, idioma)
    carpeta.mkdir(parents=True, exist_ok=True)
    # Una extracción anterior en la misma carpeta se reemplaza entera; otros archivos con esos nombres, no.
    viejos = sorted(carpeta.glob("[0-9][0-9][0-9].json"))
    if viejos and not (carpeta / MANIFIESTO).exists():
        print(f"{carpeta} ya tiene lotes que no son de una extracción ({viejos[0].name}…): elegí otra carpeta.")
        return 2
    for v in viejos + [carpeta / MANIFIESTO]:
        if v.exists():
            v.unlink()
    # Los textos repetidos van una sola vez (con la primera clave); los demás se completan al aplicar.
    primera: dict[str, str] = {}
    iguales: dict[str, list[str]] = {}
    for clave, texto in textos.items():
        if texto in primera:
            iguales[primera[texto]].append(clave)
        else:
            primera[texto] = clave
            iguales[clave] = []
    # Agrupados por elemento (paquete/sección/id), en el orden de los paquetes.
    elementos: dict[str, list[str]] = {}
    for clave in iguales:
        elementos.setdefault("/".join(clave.split("/", 3)[:3]), []).append(clave)
    lotes: list[dict[str, str]] = []
    actual: dict[str, str] = {}
    largo = 0
    for claves in elementos.values():
        largo_el = sum(len(textos[c]) for c in claves)
        if actual and largo + largo_el > tam:
            lotes.append(actual)
            actual, largo = {}, 0
        for c in claves:
            # Un elemento más largo que un lote se parte entre campos, nunca dentro de un texto.
            if actual and largo + len(textos[c]) > tam:
                lotes.append(actual)
                actual, largo = {}, 0
            actual[c] = textos[c]
            largo += len(textos[c])
    if actual:
        lotes.append(actual)
    manifiesto = {"idioma": idioma, "fecha": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                  "lotes": {}, "textos": {}}
    total = 0
    for i, lote in enumerate(lotes, 1):
        nombre = f"{i:03d}.json"
        (carpeta / nombre).write_text(json.dumps(lote, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        manifiesto["lotes"][nombre] = list(lote)
        for clave, texto in lote.items():
            total += len(texto)
            manifiesto["textos"][clave] = {"hash": hash_corto(texto), "iguales": iguales[clave]}
    (carpeta / MANIFIESTO).write_text(json.dumps(manifiesto, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    repetidos = sum(len(v) for v in iguales.values())
    print(f"{len(textos)} textos para traducir a {idioma} ({cuenta['faltan']} sin traducir y {cuenta['viejos']} viejos); "
          f"{repetidos} repetidos van una sola vez.")
    print(f"{len(lotes)} lotes en {carpeta}: {len(manifiesto['textos'])} claves, {total} caracteres.")
    return 0


def leer_respuesta(ruta: Path) -> dict:
    """Un JSON de claves a textos; tolera que venga dentro de un bloque de código o con texto alrededor."""
    texto = ruta.read_text(encoding="utf-8").strip()
    bloque = re.search(r"```(?:json)?\s*\n(.*?)\n```", texto, re.DOTALL)
    if bloque:
        texto = bloque.group(1)
    elif not texto.startswith("{"):
        a, b = texto.find("{"), texto.rfind("}")
        texto = texto[a:b + 1] if a >= 0 and b > a else texto
    datos = json.loads(texto)
    if not isinstance(datos, dict):
        raise ValueError("no es un objeto JSON")
    return datos


def aplicar(respuestas: Path, extraccion: Path | None, raiz: Path, idioma: str) -> int:
    if extraccion is None:
        extraccion = next((c for c in (respuestas, respuestas.parent) if (c / MANIFIESTO).exists()), None)
        if extraccion is None:
            print(f"No encuentro {MANIFIESTO} en {respuestas} ni arriba: pasá --extraccion <carpeta de extraer>.")
            return 2
    manifiesto = json.loads((extraccion / MANIFIESTO).read_text(encoding="utf-8"))
    if manifiesto.get("idioma", idioma) != idioma:
        print(f"La extracción es para {manifiesto['idioma']}, no para {idioma}.")
        return 2
    esperadas: dict[str, dict] = manifiesto["textos"]
    propios = set(manifiesto["lotes"]) if respuestas.resolve() == extraccion.resolve() else set()
    recibidas: dict[str, str] = {}
    errores = 0
    archivos = sorted(p for p in respuestas.iterdir()
                      if p.is_file() and p.suffix in (".json", ".md", ".txt") and p.name != MANIFIESTO
                      and p.name not in propios)
    if not archivos:
        print(f"No hay respuestas en {respuestas}.")
        return 2
    for ruta in archivos:
        try:
            datos = leer_respuesta(ruta)
        except (ValueError, json.JSONDecodeError) as e:
            print(f"{ruta.name}: no se pudo leer ({e}).")
            errores += 1
            continue
        for clave, valor in datos.items():
            recibidas[clave] = valor
    sobran = [c for c in recibidas if c not in esperadas]
    faltan = [c for c in esperadas if c not in recibidas]
    for c in sobran[:20]:
        print(f"sobra: {c}")
    for c in faltan[:20]:
        print(f"falta: {c}")
    # Lo que vale: un texto no vacío que conserva las marcas de cita [n] del español.
    actuales = paquetes()
    nuevas: dict[str, dict[str, dict]] = {}
    malas = 0
    for clave, info in esperadas.items():
        valor = recibidas.get(clave)
        if valor is None:
            continue
        paquete, resto = clave.split("/", 1)
        original = actuales.get(paquete, {}).get(resto)
        if not isinstance(valor, str) or not valor.strip():
            print(f"vacía o no es texto: {clave}")
            malas += 1
            continue
        if original is not None and sorted(CITA.findall(original)) != sorted(CITA.findall(valor)):
            print(f"no conserva las citas [n]: {clave}")
            malas += 1
            continue
        for c in [clave] + info.get("iguales", []):
            p, r = c.split("/", 1)
            nuevas.setdefault(p, {})[r] = {"hash": info["hash"], "texto": valor.strip()}
    # Cada capa queda en el orden de los textos del paquete y sin lo que ya no existe.
    aplicadas = 0
    quitadas = 0
    for paquete, textos in actuales.items():
        capa = leer_capa(raiz, idioma, paquete)
        capa.update(nuevas.get(paquete, {}))
        aplicadas += len(nuevas.get(paquete, {}))
        quitadas += len(set(capa) - set(textos))
        escribir_capa(raiz, idioma, paquete, {k: capa[k] for k in textos if k in capa})
    print(f"{aplicadas} textos en la capa de {idioma} ({len(recibidas)} recibidos de {len(archivos)} archivos); "
          f"{len(faltan)} faltan, {len(sobran)} sobran, {malas} rechazados, {quitadas} quitados porque ya no existen.")
    return 1 if errores or malas or faltan or sobran else 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    def opcion(nombre: str, defecto=None):
        if nombre in args:
            i = args.index(nombre)
            valor = args[i + 1]
            del args[i:i + 2]
            return valor
        return defecto

    idioma = opcion("--idioma", "en")
    tam = int(opcion("--tam", "20000"))
    raiz = Path(opcion("--capa", str(CAPAS)))
    extraccion = opcion("--extraccion")
    orden = args[0]
    if orden == "estado":
        return estado(raiz, idioma)
    if orden == "extraer" and len(args) == 2:
        return extraer(Path(args[1]), raiz, idioma, tam)
    if orden == "aplicar" and len(args) == 2:
        return aplicar(Path(args[1]), Path(extraccion) if extraccion else None, raiz, idioma)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
