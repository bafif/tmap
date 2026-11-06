"""Paso 1: la base física del mapa.

Produce en `data/mapa/`:
- `terreno.webp`: color del terreno (Blue Marble de la NASA, julio de 2004, regraduado hacia una paleta de mapa pintado).
- `relieve.png`: RGBA de datos para el shader:
    R = sombreado del relieve (128 = llano), G = distancia con signo a la costa (128 = costa, >128 agua),
    B = ríos (cobertura 0..255), A = distancia al agua lejana (0 en tierra, hasta 255 px mar adentro).
Y en `tools/pipeline/cache/`: `tierra.npy` (máscara booleana) y `elevacion.npy` (uint8), que usan los pasos siguientes.

Fuentes: Natural Earth 10m (tierra, lagos, ríos; dominio público), GEBCO 2008 en la versión de la NASA (elevación) y
NASA Blue Marble Next Generation (color).
"""

from __future__ import annotations

import math
import sys
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from comun import (
    ALTO,
    ANCHO,
    CACHE,
    CRUDOS,
    SALIDA,
    anillo_a_px,
    leer_shapefile,
    lonlat_a_px,
    rasterizar_anillos,
    reproyectar_equirect,
    reproyectar_equirect_float,
)

RIOS_ZIP = CRUDOS / "ne_10m_rivers_lake_centerlines.zip"


def t():
    return f"[{time.strftime('%H:%M:%S')}]"


def mascara_de_shapefile(zip_nombre, capa, filtro=None) -> np.ndarray:
    m = np.zeros((ALTO, ANCHO), dtype=bool)
    for attrs, partes in leer_shapefile(CRUDOS / zip_nombre, capa):
        if filtro and not filtro(attrs):
            continue
        if not partes:
            continue
        anillos = [anillo_a_px(p) for p in partes if len(p) >= 3]
        if not anillos:
            continue
        r = rasterizar_anillos(anillos)
        if r is None:
            continue
        x0, y0, sub = r
        m[y0 : y0 + sub.shape[0], x0 : x0 + sub.shape[1]] ^= sub
    return m


def gauss_f(a: np.ndarray, radio: float) -> np.ndarray:
    """Desenfoque gaussiano separable en float32 (sin pasar por 8 bits)."""
    if radio <= 0:
        return a
    r = int(math.ceil(radio * 3))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-0.5 * (x / radio) ** 2)
    k /= k.sum()
    out = np.zeros_like(a)
    for i, w in enumerate(k):
        out += np.roll(a, i - r, axis=1) * w
    out2 = np.zeros_like(a)
    for i, w in enumerate(k):
        out2 += np.roll(out, i - r, axis=0) * w
    return out2


def distancia(mascara_origen: np.ndarray, maximo: int) -> np.ndarray:
    """Distancia aproximada (octogonal) en píxeles desde `mascara_origen`, saturada en `maximo`."""
    dist = np.full(mascara_origen.shape, maximo, dtype=np.uint8)
    dist[mascara_origen] = 0
    frente = mascara_origen.copy()
    for d in range(1, maximo):
        nuevo = frente.copy()
        nuevo[1:] |= frente[:-1]
        nuevo[:-1] |= frente[1:]
        nuevo[:, 1:] |= frente[:, :-1]
        nuevo[:, :-1] |= frente[:, 1:]
        if d % 2 == 0:  # alternar con 8-vecinos para aproximar un círculo
            diag = nuevo.copy()
            diag[1:, 1:] |= frente[:-1, :-1]
            diag[:-1, :-1] |= frente[1:, 1:]
            diag[1:, :-1] |= frente[:-1, 1:]
            diag[:-1, 1:] |= frente[1:, :-1]
            nuevo = diag
        alcanzados = nuevo & ~frente
        if not alcanzados.any():
            break
        dist[alcanzados] = d
        frente = nuevo
    return dist


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    print(t(), f"Mapa de {ANCHO} x {ALTO} px (Miller)")

    # --- Tierra y lagos --------------------------------------------------------------------------------------
    if (CACHE / "tierra.npy").exists() and "--rehacer" not in sys.argv:
        tierra = np.load(CACHE / "tierra.npy")
    else:
        tierra = mascara_de_shapefile("ne_10m_land.zip", "ne_10m_land")
        lagos = mascara_de_shapefile(
            "ne_10m_lakes.zip", "ne_10m_lakes", lambda a: (a.get("scalerank") or 99) <= 5
        )
        tierra &= ~lagos
        np.save(CACHE / "tierra.npy", tierra)
    print(t(), f"Tierra: {tierra.mean() * 100:.1f} % del mapa")

    # --- Elevación (GEBCO de la NASA, 8 bits, solo tierra) ----------------------------------------------------
    # Los mosaicos se reducen en punto flotante: promediar ~5x5 píxeles recupera precisión por debajo del escalón
    # de 8 bits y evita las terrazas falsas en las llanuras.
    mosaico = np.zeros((4096, 8192), dtype=np.float32)
    for i, col in enumerate("ABCD"):
        for j, fila in enumerate("12"):
            im = Image.open(CRUDOS / f"gebco_08_rev_elev_{col}{fila}_grey_geo.tif").convert("F")
            im = im.resize((2048, 2048), Image.Resampling.BOX)
            mosaico[j * 2048 : (j + 1) * 2048, i * 2048 : (i + 1) * 2048] = np.asarray(im, dtype=np.float32)
    elev_f = reproyectar_equirect_float(mosaico)
    del mosaico
    elev_f[~tierra] = 0.0
    elev = np.clip(elev_f + 0.5, 0, 255).astype(np.uint8)
    np.save(CACHE / "elevacion.npy", elev)
    print(t(), "Elevación lista")

    # Sombreado: luz del noroeste, como en los mapas pintados. En las llanuras se usa una elevación más suavizada.
    def sombrear(radio, exageracion):
        e = gauss_f(elev_f, radio) * exageracion
        gy, gx = np.gradient(e)
        azimut, altura = np.radians(315.0), np.radians(42.0)
        pendiente = np.arctan(np.hypot(gx, gy) / 8.0)
        aspecto = np.arctan2(-gx, gy)
        hs = np.sin(altura) * np.cos(pendiente) + np.cos(altura) * np.sin(pendiente) * np.cos(azimut - aspecto)
        return (hs / np.sin(altura)).astype(np.float32), np.hypot(gx, gy).astype(np.float32)

    hs_fino, _ = sombrear(1.0, 6.0)
    hs_suave, pend = sombrear(5.0, 6.0)
    peso = np.clip((pend - 0.25) / 0.6, 0, 1)
    hs = hs_suave * (1 - peso) + hs_fino * peso
    del hs_fino, hs_suave, pend, peso, elev_f
    sombreado = np.clip(128.0 * hs, 0, 255).astype(np.uint8)
    del hs
    sombreado[~tierra] = 128
    print(t(), "Sombreado listo")

    # --- Costa: distancia con signo y distancia lejana ---------------------------------------------------------
    agua = ~tierra
    d_fuera = distancia(tierra, 32).astype(np.float32)  # en el agua, distancia a la tierra
    d_dentro = distancia(agua, 32).astype(np.float32)  # en la tierra, distancia al agua
    sdf = np.where(agua, d_fuera - 0.5, -(d_dentro - 0.5))
    del d_fuera, d_dentro
    costa = np.clip(128.0 + sdf * 4.0, 0, 255).astype(np.uint8)
    del sdf
    chico = np.asarray(Image.fromarray(tierra.astype(np.uint8) * 255).resize((ANCHO // 4, ALTO // 4), Image.Resampling.BOX)) > 127
    lejos = distancia(chico, 64).astype(np.float32) * 4.0
    lejos = Image.fromarray(np.clip(lejos, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
    lejos = np.asarray(lejos.resize((ANCHO, ALTO), Image.Resampling.BICUBIC))
    lejos = np.where(agua, lejos, 0).astype(np.uint8)
    print(t(), "Distancias a la costa listas")

    # --- Ríos --------------------------------------------------------------------------------------------------
    esc = 2
    lienzo = Image.new("L", (ANCHO * esc, ALTO * esc), 0)
    dib = ImageDraw.Draw(lienzo)
    n_rios = 0
    for attrs, partes in leer_shapefile(RIOS_ZIP, "ne_10m_rivers_lake_centerlines"):
        if attrs.get("featurecla", "").lower().startswith("lake"):
            continue
        rango = attrs.get("scalerank") or 99
        if rango > 9:
            continue
        ancho = {0: 6, 1: 6, 2: 5, 3: 5, 4: 4, 5: 4, 6: 3, 7: 3, 8: 2, 9: 2}[int(rango)]
        for p in partes:
            x, y = lonlat_a_px(p[:, 0], p[:, 1])
            pts = list(zip((x * esc).tolist(), (y * esc).tolist()))
            if len(pts) >= 2:
                dib.line(pts, fill=255, width=ancho, joint="curve")
                n_rios += 1
    rios = np.asarray(lienzo.resize((ANCHO, ALTO), Image.Resampling.BOX))
    del lienzo, dib
    rios = np.where(tierra, rios, 0).astype(np.uint8)
    print(t(), f"Ríos: {n_rios} tramos")

    relieve = np.stack([sombreado, costa, rios, lejos], axis=2)
    Image.fromarray(relieve, "RGBA").save(SALIDA / "relieve.png", optimize=False, compress_level=6)
    del relieve, sombreado, costa, rios, lejos
    print(t(), "relieve.png guardado")

    # --- Color del terreno -------------------------------------------------------------------------------------
    bm = np.asarray(Image.open(CRUDOS / "world.200407.3x5400x2700.jpg").convert("RGB"), dtype=np.float32) / 255.0
    lum = bm @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    sat = 0.82
    bm = lum[..., None] + (bm - lum[..., None]) * sat  # algo menos saturado
    bm = bm * np.array([1.05, 1.0, 0.88], dtype=np.float32)  # más cálido
    bm = 0.12 + bm * 1.0  # levantar sombras: tono de lámina pintada
    bm = np.clip(bm, 0, 1) ** 0.85
    bm8 = (np.clip(bm, 0, 1) * 255 + 0.5).astype(np.uint8)
    del bm, lum
    color = reproyectar_equirect(bm8)
    del bm8

    # Rellenar el mar (y la franja costera azulada de la foto) con colores de tierra cercanos, para que el filtrado
    # del shader no traiga azul a la costa.
    r, g, b = (color[..., k].astype(np.int16) for k in range(3))
    azulado = (b > r + 8) & (b >= g) & ((r + g + b) < 300)
    interior = tierra & ~azulado
    interior[1:] &= tierra[:-1]
    interior[:-1] &= tierra[1:]
    interior[:, 1:] &= tierra[:, :-1]
    interior[:, :-1] &= tierra[:, 1:]
    del r, g, b, azulado
    pequeno = (ANCHO // 8, ALTO // 8)
    m_peq = np.asarray(Image.fromarray(interior.astype(np.uint8) * 255).resize(pequeno, Image.Resampling.BOX), dtype=np.float32) / 255.0
    c_peq = np.asarray(
        Image.fromarray(np.where(interior[..., None], color, 0).astype(np.uint8)).resize(pequeno, Image.Resampling.BOX),
        dtype=np.float32,
    ) / 255.0
    relleno = np.zeros_like(c_peq)
    peso = np.zeros_like(m_peq)
    for radio in (1, 3, 8, 24):
        mb = np.asarray(Image.fromarray((m_peq * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radio)), dtype=np.float32) / 255.0
        cb = np.asarray(Image.fromarray((c_peq * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radio)), dtype=np.float32) / 255.0
        nuevo = cb / np.maximum(mb[..., None], 1e-4)
        usar = (peso < 0.5) & (mb > 0.02)
        relleno[usar] = nuevo[usar]
        peso[usar] = 1.0
    relleno[peso < 0.5] = np.array([0.55, 0.52, 0.42])
    relleno_full = np.asarray(
        Image.fromarray((np.clip(relleno, 0, 1) * 255).astype(np.uint8)).resize((ANCHO, ALTO), Image.Resampling.BILINEAR)
    )
    color = np.where(interior[..., None], color, relleno_full)
    del relleno_full, interior
    Image.fromarray(color, "RGB").save(SALIDA / "terreno.webp", quality=88, method=4)
    print(t(), "terreno.webp guardado")


if __name__ == "__main__":
    main()
