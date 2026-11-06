"""Vista previa del mapa político de un año, sin Godot: sirve para revisar los datos que produce el pipeline.

Uso: python3 vista_previa.py -1350 salida.png [x0 y0 x1 y1]   (recorte opcional en píxeles del mapa)
"""

from __future__ import annotations

import json
import sys
import zlib

import numpy as np
from PIL import Image, ImageDraw

from comun import SALIDA

Image.MAX_IMAGE_PIXELS = None


def cargar():
    meta = json.load(open(SALIDA / "politico.json", encoding="utf-8"))
    crudo = zlib.decompress(open(SALIDA / "politico.bin", "rb").read())
    partes = meta["politico_bin"]["partes"]

    def parte(n):
        p = partes[n]
        dt = "<i4" if p["tipo"] == "i32" else "<f4"
        return np.frombuffer(crudo[p["inicio"] : p["inicio"] + p["bytes"]], dtype=dt)

    w, h = meta["proyeccion"]["ancho"], meta["proyeccion"]["alto"]
    u = np.frombuffer(zlib.decompress(open(SALIDA / "unidades.bin", "rb").read()), dtype=np.uint8).reshape(h, w, 2)
    unidades = u[..., 0].astype(np.int32) | (u[..., 1].astype(np.int32) << 8)
    return meta, parte, unidades


def duenos_en(meta, parte, anio):
    ev_anio = parte("evento_anio")
    k = int(np.searchsorted(ev_anio, anio, side="right"))
    d = np.full(meta["unidades"] + 1, -1, dtype=np.int32)
    uni, desp = parte("evento_unidad")[:k], parte("evento_despues")[:k]
    d[uni] = desp  # el último evento de cada unidad gana (están ordenados por año)
    return d


def main():
    anio = int(sys.argv[1])
    salida = sys.argv[2]
    meta, parte, unidades = cargar()
    d = duenos_en(meta, parte, anio)
    colores = np.array([[int(e["c"][i : i + 2], 16) for i in (1, 3, 5)] for e in meta["entidades"]] + [[0, 0, 0]], dtype=np.uint8)
    terreno = np.asarray(Image.open(SALIDA / "terreno.webp").convert("RGB"))
    v = d[unidades]
    pol = colores[np.where(v >= 0, v, len(colores) - 1)]
    img = np.where((v >= 0)[..., None], (terreno * 0.35 + pol * 0.65).astype(np.uint8), terreno)
    img[unidades == 0] = (30, 52, 66)
    borde = np.zeros(v.shape, bool)
    borde[:, 1:] |= v[:, 1:] != v[:, :-1]
    borde[1:] |= v[1:] != v[:-1]
    img[borde & (unidades > 0)] = (25, 20, 15)
    im = Image.fromarray(img)
    if len(sys.argv) >= 7:
        im = im.crop(tuple(int(a) for a in sys.argv[3:7]))
    dib = ImageDraw.Draw(im)
    dib.text((10, 10), f"{anio}", fill=(255, 255, 255))
    im.thumbnail((1600, 1600))
    im.save(salida)
    activos = sorted({int(x) for x in d[d >= 0]}, key=lambda i: -int((d == i).sum()))[:12]
    print(anio, "entidades con territorio:", len(set(d[d >= 0].tolist())))
    print("  mayores:", ", ".join(meta["entidades"][i]["n"] for i in activos))


if __name__ == "__main__":
    main()
