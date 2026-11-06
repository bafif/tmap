"""Lámina estática de alta calidad de un año y una zona, sin Godot (para documentación o para imprimir).

Imita el shader de la app: relieve, agua con líneas de costa, colores políticos con brillo interior, fronteras,
nombres curvos en Cinzel y ciudades de la enciclopedia.

Uso: python3 lamina.py ANIO x0 y0 x1 y1 salida.png [ancho_salida]
     (la zona en píxeles del mapa de 8192 x 4016; por ejemplo 3700 1050 5750 2200 es el Mediterráneo oriental)
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from comun import RAIZ, SALIDA, lonlat_a_px
from vista_previa import cargar, duenos_en

Image.MAX_IMAGE_PIXELS = None
FUENTE = RAIZ / "assets" / "fuentes" / "Cinzel.ttf"


def hexrgb(h):
    return np.array([int(h[i : i + 2], 16) for i in (1, 3, 5)], dtype=np.float32) / 255.0


def suavizar(m, r):
    return np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)), dtype=np.float32) / 255.0


def main():
    anio = int(sys.argv[1])
    x0, y0, x1, y1 = (int(a) for a in sys.argv[2:6])
    salida = sys.argv[6]
    ancho_salida = int(sys.argv[7]) if len(sys.argv) > 7 else 1920
    meta, parte, unidades = cargar()
    d = duenos_en(meta, parte, anio)
    u = unidades[y0:y1, x0:x1]
    v = np.where(u > 0, d[u], -1)

    ter = np.asarray(Image.open(SALIDA / "terreno.webp").convert("RGB").crop((x0, y0, x1, y1)), dtype=np.float32) / 255.0
    rel = np.asarray(Image.open(SALIDA / "relieve.png").crop((x0, y0, x1, y1)), dtype=np.float32) / 255.0
    hs = np.clip(1.0 + (rel[..., 0] * 2.0 - 1.0) * 0.7, 0.4, 1.5)
    sd = (rel[..., 1] - 0.5) * 255.0 / 4.0
    tierra_a = np.clip(0.5 - sd / 1.2, 0, 1)
    rio = rel[..., 2]
    lejos = rel[..., 3]

    # Agua
    profundo, costa_c = hexrgb("#13263a"), hexrgb("#38616f")
    t = np.clip(lejos / 0.6, 0, 1)[..., None]
    agua = costa_c * (1 - t) + profundo * t
    agua = agua + (costa_c * 1.18 - agua) * (np.exp(-np.maximum(sd, 0) / 3.5) * 0.4)[..., None]
    paso = 5.5
    dl = np.abs(((sd / paso) % 1.0) - 0.5) * paso
    linea = np.clip(1.0 - dl / 0.8, 0, 1) * np.clip((30 - sd) / 24, 0, 1) * np.clip((sd - 1.5) / 2, 0, 1)
    agua = agua + ((agua * 1.25 + 0.02) - agua) * (linea * 0.5)[..., None]

    # Tierra
    tierra = ter * hs[..., None]
    rio_c = hexrgb("#335c73")
    tierra = tierra * (1 - rio[..., None] * 0.85) + rio_c * rio[..., None] * 0.85
    colores = np.array([hexrgb(e["c"]) for e in meta["entidades"]] + [np.zeros(3)], dtype=np.float32)
    pc = colores[np.where(v >= 0, v, len(colores) - 1)]
    hay = (v >= 0)[..., None]
    pintado = pc * np.clip(1.0 + (rel[..., 0:1] * 2.0 - 1.0) * 0.5, 0.55, 1.3)
    tierra = np.where(hay, tierra * 0.34 + pintado * 0.66, tierra)
    gris = tierra.mean(axis=2, keepdims=True)
    tierra = np.where(hay | (u == 0)[..., None], tierra, (tierra * 0.6 + gris * np.array([1.02, 0.99, 0.93]) * 0.4) * 0.94)

    # Fronteras y brillo interior
    borde = np.zeros(v.shape, bool)
    for a, b, sl_a, sl_b in (((slice(None), slice(1, None)), (slice(None), slice(None, -1)), None, None),
                             ((slice(1, None), slice(None)), (slice(None, -1), slice(None)), None, None)):
        va, vb, ua, ub = v[a], v[b], u[a], u[b]
        diff = (va != vb) & (ua > 0) & (ub > 0)
        borde[a] |= diff
        borde[b] |= diff
    b_suave = np.clip(suavizar(borde.astype(np.float32), 1.1) * 2.2, 0, 1)
    glow = np.clip(suavizar(borde.astype(np.float32), 5.0) * 4.0, 0, 1) * (1 - b_suave)
    tierra = np.where(hay, tierra + ((pc * 1.15 + 0.05) - tierra) * (glow * 0.35)[..., None], tierra)
    oscuro = np.where(hay, pc * 0.32, np.array([0.12, 0.11, 0.1]))
    tierra = tierra + (oscuro - tierra) * (b_suave * 0.9)[..., None]

    col = agua * (1 - tierra_a[..., None]) + tierra * tierra_a[..., None]
    costa_l = np.clip(1.0 - np.abs(sd) / 0.9, 0, 1)
    col = col + (np.array([0.09, 0.10, 0.11]) - col) * (costa_l * 0.6)[..., None]
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))
    escala = ancho_salida / img.width
    img = img.resize((ancho_salida, int(img.height * escala)), Image.Resampling.LANCZOS).convert("RGBA")

    # Nombres curvos
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for e in meta["etiquetas"]:
        desde, hasta, ent, cx, cy, ang, largo, a, b, c, grosor = e
        if not (desde <= anio <= hasta) or not (d == ent).any():
            continue
        if not (x0 - largo < cx < x1 + largo and y0 - largo < cy < y1 + largo):
            continue
        nombre = meta["entidades"][ent]["n"]
        nombres_es = SALIDA / "nombres_es.json"
        if nombres_es.exists():
            nombre = json.load(open(nombres_es, encoding="utf-8")).get(nombre, nombre)
        texto = nombre.upper()
        base = 64
        fuente = ImageFont.truetype(str(FUENTE), base)
        try:
            fuente.set_variation_by_axes([600])
        except Exception:
            pass
        anchos = [fuente.getlength(ch) for ch in texto]
        esp = 0.32 * base
        total = sum(anchos) + esp * (len(texto) - 1)
        s = min(largo * 0.8 / total, grosor * 0.95 / base)
        if base * s * escala < 11:
            continue
        tam = max(int(base * s * escala), 8)
        f2 = ImageFont.truetype(str(FUENTE), tam)
        try:
            f2.set_variation_by_axes([600])
        except Exception:
            pass
        th = math.radians(ang)
        e1 = np.array([math.cos(th), math.sin(th)])
        e2 = np.array([-e1[1], e1[0]])
        uu = -total * s * 0.5
        for ch, w in zip(texto, anchos):
            ww = w * s
            uc = uu + ww * 0.5
            vv = a * uc * uc + b * uc + c
            pend = 2 * a * uc + b
            p = (np.array([cx, cy]) + e1 * uc + e2 * vv - np.array([x0, y0])) * escala
            rot = math.degrees(th + math.atan(pend))
            lado = tam * 2
            letra = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
            dl_ = ImageDraw.Draw(letra)
            dl_.text((lado / 2, lado / 2), ch, font=f2, anchor="mm", fill=(247, 237, 214, 235),
                     stroke_width=max(1, tam // 9), stroke_fill=(20, 15, 12, 140))
            letra = letra.rotate(-rot, resample=Image.Resampling.BICUBIC)
            capa.alpha_composite(letra, (int(p[0] - lado / 2), int(p[1] - lado / 2)))
            uu += ww + esp * s
    img.alpha_composite(capa)

    # Ciudades de la enciclopedia
    dib = ImageDraw.Draw(img)
    fuente_c = ImageFont.truetype(str(FUENTE), 19)
    for paquete in sorted((RAIZ / "data" / "enciclopedia" / "paquetes").glob("*.json")):
        for l in json.load(open(paquete, encoding="utf-8")).get("lugares", []):
            fun = l.get("fundacion") or -99999
            aba = l.get("abandono") or 99999
            if not (fun <= anio <= aba) or int(l.get("importancia", 2)) < 3:
                continue
            px, py = lonlat_a_px(l["lon"], l["lat"])
            px, py = (float(px) - x0) * escala, (float(py) - y0) * escala
            if not (0 <= px < img.width and 0 <= py < img.height):
                continue
            r = 5
            dib.ellipse((px - r - 2, py - r - 2, px + r + 2, py + r + 2), fill=(20, 17, 15, 230))
            dib.ellipse((px - r, py - r, px + r, py + r), fill=(245, 235, 210, 255))
            dib.ellipse((px - 2.2, py - 2.2, px + 2.2, py + 2.2), fill=(140, 38, 30, 255))
            dib.text((px + 10, py), l["nombre"], font=fuente_c, anchor="lm", fill=(250, 243, 225, 255),
                     stroke_width=3, stroke_fill=(15, 12, 10, 200))

    # Viñeta y título
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    dist = np.sqrt(((xx / w - 0.5) * 1.35) ** 2 + (yy / h - 0.5) ** 2)
    vin = np.clip((dist - 0.38) / 0.47, 0, 1) * 0.42
    over = Image.fromarray(np.dstack([np.full((h, w, 3), 10, np.uint8), (vin * 255).astype(np.uint8)]), "RGBA")
    img.alpha_composite(over)
    img.convert("RGB").save(salida, quality=92)
    print("Lámina:", salida, img.size)


if __name__ == "__main__":
    main()
