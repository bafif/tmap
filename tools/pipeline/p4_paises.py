"""País actual de cada unidad del mapa, para mostrar las series por país (población, esperanza de vida…).

Rasteriza los países de Natural Earth (Admin 0, 1:10 m, con lagos) en la misma proyección que las unidades y le asigna
a cada unidad el país que cubre la mayor parte de sus píxeles de tierra. Las series de Our World in Data usan las
fronteras actuales, así que esta es la unión que corresponde: en 1900, el punto de Córdoba muestra la población que
tenía entonces el territorio de la Argentina de hoy.

Salida en `data/demografia/`:
- `unidades_pais.bin`: un byte por unidad (índice en la lista de países, 0 = ninguno), comprimido con zlib.
- `paises_mapa.json`: la lista de países en ese orden (código de Our World in Data y nombre en español y en inglés).

Uso: python3 tools/pipeline/p4_paises.py
"""
from __future__ import annotations

import json
import zlib

import numpy as np
from PIL import Image, ImageDraw

import comun

SALIDA = comun.RAIZ / "data" / "demografia"
ZIP = comun.CRUDOS / "ne_10m_admin_0_countries_lakes.zip"
# Natural Earth → código de Our World in Data, para los territorios sin ISO propio. None = sin país (zonas en disputa
# sin serie: el glaciar de Siachen, el campo de hielo patagónico, Bir Tawil, arrecifes).
CODIGOS = {"KOS": "OWID_KOS", "SOL": "SOM", "CYN": "CYP", "CNM": "CYP", "ESB": "CYP", "WSB": "CYP", "USG": "CUB",
           "KAS": None, "SPI": None, "BRT": None, "PGA": None, "BJN": None, "SER": None, "SCR": None}
NOMBRES = {"OWID_KOS": "Kosovo", "SOM": "Somalia", "CYP": "Chipre", "CUB": "Cuba"}
# Los mismos en inglés, y los que Natural Earth da con el nombre largo.
NOMBRES_EN = {"OWID_KOS": "Kosovo", "SOM": "Somalia", "CYP": "Cyprus", "CUB": "Cuba", "CHN": "China", "USA": "United States"}


def texto(v) -> str:
    return str(v).replace("\x00", "").strip()


def main() -> None:
    meta = json.loads((comun.SALIDA / "politico.json").read_text(encoding="utf-8"))
    n = int(meta["unidades"])
    crudo = zlib.decompress((comun.SALIDA / "unidades.bin").read_bytes())
    alto, ancho = meta["proyeccion"]["alto"], meta["proyeccion"]["ancho"]
    unidades = np.frombuffer(crudo, dtype="<u2").reshape(alto, ancho)

    registros = comun.leer_shapefile(ZIP, "ne_10m_admin_0_countries_lakes")
    codigos: list[str] = []
    nombres: dict[str, str] = {}
    nombres_en: dict[str, str] = {}
    etiqueta = np.zeros((alto, ancho), dtype=np.uint16)
    for attrs, partes in registros:
        a3 = texto(attrs["ADM0_A3"])
        iso = texto(attrs["ISO_A3_EH"])
        codigo = CODIGOS[a3] if a3 in CODIGOS else (iso if iso not in ("-99", "") else a3)
        if codigo is None or not partes:
            continue
        if codigo not in codigos:
            codigos.append(codigo)
            nombres[codigo] = NOMBRES.get(codigo) or texto(attrs.get("NAME_ES", "")) or texto(attrs["NAME"])
            nombres_en[codigo] = NOMBRES_EN.get(codigo) or texto(attrs.get("NAME_EN", "")) or texto(attrs["NAME"])
        idx = codigos.index(codigo) + 1
        anillos = [comun.anillo_a_px(p) for p in partes if len(p) >= 3]
        todos = np.concatenate(anillos)
        x0 = max(int(np.floor(todos[:, 0].min())) - 1, 0)
        y0 = max(int(np.floor(todos[:, 1].min())) - 1, 0)
        x1 = min(int(np.ceil(todos[:, 0].max())) + 2, ancho)
        y1 = min(int(np.ceil(todos[:, 1].max())) + 2, alto)
        if x1 <= x0 or y1 <= y0:
            continue
        mascara = np.zeros((y1 - y0, x1 - x0), dtype=bool)
        for a in anillos:
            # cada anillo en su propia caja: los países con miles de islas no arman un lienzo enorme por isla
            ax0 = max(int(np.floor(a[:, 0].min())) - 1, x0)
            ay0 = max(int(np.floor(a[:, 1].min())) - 1, y0)
            ax1 = min(int(np.ceil(a[:, 0].max())) + 2, x1)
            ay1 = min(int(np.ceil(a[:, 1].max())) + 2, y1)
            if ax1 <= ax0 or ay1 <= ay0:
                continue
            lienzo = Image.new("1", (ax1 - ax0, ay1 - ay0), 0)
            ImageDraw.Draw(lienzo).polygon([(float(px - ax0), float(py - ay0)) for px, py in a], fill=1)
            mascara[ay0 - y0:ay1 - y0, ax0 - x0:ax1 - x0] ^= np.asarray(lienzo, dtype=bool)
        etiqueta[y0:y1, x0:x1][mascara] = idx
    if len(codigos) > 254:
        raise SystemExit(f"demasiados países para un byte: {len(codigos)}")

    # el país de cada unidad: el de más píxeles dentro de ella
    sel = (unidades > 0) & (etiqueta > 0)
    clave = unidades[sel].astype(np.int64) * 256 + etiqueta[sel]
    cuenta = np.bincount(clave, minlength=(n + 1) * 256).reshape(n + 1, 256)
    pais = cuenta.argmax(axis=1).astype(np.uint8)
    pais[cuenta.max(axis=1) == 0] = 0
    sin_pais = int((pais[1:] == 0).sum())

    SALIDA.mkdir(exist_ok=True)
    (SALIDA / "unidades_pais.bin").write_bytes(zlib.compress(pais.tobytes(), 9))
    lista = [{"codigo": c, "nombre": nombres[c], "nombre_en": nombres_en[c]} for c in codigos]
    datos = {"fuente": "Natural Earth 1:10 m, Admin 0 – countries (con lagos), dominio público; país de cada unidad "
                       "por mayoría de píxeles (tools/pipeline/p4_paises.py)",
             "unidades": n, "paises": lista}
    comun.guardar_json(SALIDA / "paises_mapa.json", datos)
    usados = len(set(pais.tolist()) - {0})
    print(f"{len(codigos)} países, {usados} con alguna unidad; {sin_pais} de {n} unidades sin país (mar, hielo, disputas)")


if __name__ == "__main__":
    main()
