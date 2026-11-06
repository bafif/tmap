"""Piezas comunes del pipeline de TellMAP: proyección, rutas y lectura de formatos geográficos.

Todo el mapa usa la proyección cilíndrica de Miller, recortada entre LAT_NORTE y LAT_SUR. Godot repite exactamente
estas fórmulas en `scripts/nucleo/proyeccion.gd`: si se cambia una, hay que cambiar la otra.
"""

from __future__ import annotations

import json
import math
import struct
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None

RAIZ = Path(__file__).resolve().parents[2]
CRUDOS = RAIZ / "raw_data"
SALIDA = RAIZ / "data" / "mapa"
CACHE = RAIZ / "tools" / "pipeline" / "cache"

ANCHO = 8192
LAT_NORTE = 83.0
LAT_SUR = -57.0


def miller_y(lat_grados):
    """Coordenada y de Miller (adimensional) para una latitud en grados. Acepta escalares o arrays."""
    phi = np.radians(np.clip(lat_grados, -89.9, 89.9))
    return 1.25 * np.log(np.tan(np.pi / 4 + 0.4 * phi))


def miller_lat(y):
    """Inversa de miller_y."""
    return np.degrees(2.5 * np.arctan(np.exp(0.8 * np.asarray(y))) - 0.625 * np.pi)


Y_NORTE = float(miller_y(LAT_NORTE))
Y_SUR = float(miller_y(LAT_SUR))
# El ancho cubre 2π en x; el alto se elige para que la escala sea la misma en los dos ejes.
ALTO = int(round(ANCHO * (Y_NORTE - Y_SUR) / (2 * math.pi) / 16) * 16)


def lonlat_a_px(lon, lat):
    """Lon/lat (grados) a píxel del mapa (float). Acepta arrays."""
    x = (np.asarray(lon, dtype=np.float64) + 180.0) / 360.0 * ANCHO
    y = (Y_NORTE - miller_y(np.asarray(lat, dtype=np.float64))) / (Y_NORTE - Y_SUR) * ALTO
    return x, y


def px_a_lonlat(x, y):
    lon = np.asarray(x, dtype=np.float64) / ANCHO * 360.0 - 180.0
    lat = miller_lat(Y_NORTE - np.asarray(y, dtype=np.float64) / ALTO * (Y_NORTE - Y_SUR))
    return lon, lat


def latitudes_de_filas():
    """Latitud del centro de cada fila del mapa."""
    _, lat = px_a_lonlat(np.zeros(ALTO), np.arange(ALTO) + 0.5)
    return lat


def reproyectar_equirect(img: np.ndarray, lat_arriba=90.0, lat_abajo=-90.0) -> np.ndarray:
    """Pasa una imagen equirectangular (que cubre -180..180) a la grilla Miller de ANCHO x ALTO.

    Primero se ajusta el ancho con PIL (filtro de calidad) y después se remuestrean las filas con interpolación lineal.
    """
    alto_src = img.shape[0]
    modo = "L" if img.ndim == 2 else "RGB"
    pil = Image.fromarray(img, modo).resize((ANCHO, alto_src), Image.Resampling.LANCZOS)
    src = np.asarray(pil)
    lat = latitudes_de_filas()
    fila = (lat_arriba - lat) / (lat_arriba - lat_abajo) * alto_src - 0.5
    fila = np.clip(fila, 0, alto_src - 1)
    f0 = np.floor(fila).astype(np.int32)
    f1 = np.minimum(f0 + 1, alto_src - 1)
    t = (fila - f0).astype(np.float32)
    out = np.empty((ALTO,) + src.shape[1:], dtype=np.uint8)
    for ini in range(0, ALTO, 256):
        fin = min(ini + 256, ALTO)
        tt = t[ini:fin, None, None] if src.ndim == 3 else t[ini:fin, None]
        bloque = src[f0[ini:fin]].astype(np.float32) * (1 - tt) + src[f1[ini:fin]].astype(np.float32) * tt
        out[ini:fin] = np.clip(bloque + 0.5, 0, 255).astype(np.uint8)
    return out


def reproyectar_equirect_float(img: np.ndarray, lat_arriba=90.0, lat_abajo=-90.0) -> np.ndarray:
    """Como reproyectar_equirect, pero para un array float32 de un canal que ya tiene ANCHO columnas."""
    alto_src = img.shape[0]
    lat = latitudes_de_filas()
    fila = np.clip((lat_arriba - lat) / (lat_arriba - lat_abajo) * alto_src - 0.5, 0, alto_src - 1)
    f0 = np.floor(fila).astype(np.int32)
    f1 = np.minimum(f0 + 1, alto_src - 1)
    t = (fila - f0).astype(np.float32)[:, None]
    return img[f0] * (1 - t) + img[f1] * t


# ---------------------------------------------------------------------------------------------------------------
# Rasterizado de polígonos


def anillo_a_px(anillo) -> np.ndarray:
    a = np.asarray(anillo, dtype=np.float64)
    x, y = lonlat_a_px(a[:, 0], a[:, 1])
    return np.stack([x, y], axis=1)


def rasterizar_anillos(anillos_px, escala=1):
    """Rasteriza una lista de anillos (en píxeles) con regla par-impar.

    Devuelve (x0, y0, mascara_bool) recortada a la caja que ocupa, o None si cae fuera del mapa.
    """
    todos = np.concatenate(anillos_px)
    x0 = max(int(math.floor(todos[:, 0].min())) - 1, 0)
    y0 = max(int(math.floor(todos[:, 1].min())) - 1, 0)
    x1 = min(int(math.ceil(todos[:, 0].max())) + 2, ANCHO * escala)
    y1 = min(int(math.ceil(todos[:, 1].max())) + 2, ALTO * escala)
    if x1 <= x0 or y1 <= y0:
        return None
    mascara = np.zeros((y1 - y0, x1 - x0), dtype=bool)
    for anillo in anillos_px:
        if len(anillo) < 3:
            continue
        lienzo = Image.new("1", (x1 - x0, y1 - y0), 0)
        pts = [(float(px - x0), float(py - y0)) for px, py in anillo]
        ImageDraw.Draw(lienzo).polygon(pts, fill=1)
        mascara ^= np.asarray(lienzo, dtype=bool)
    return x0, y0, mascara


def area_px(anillo_px) -> float:
    x, y = anillo_px[:, 0], anillo_px[:, 1]
    return 0.5 * abs(float(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1))))


def poligonos_geojson(geom):
    """Lista de polígonos (cada uno, lista de anillos lon/lat) de un Polygon o MultiPolygon."""
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return list(geom["coordinates"])
    return []


# ---------------------------------------------------------------------------------------------------------------
# Shapefiles (lectura mínima, sin dependencias)


def leer_shapefile(zip_path: Path, nombre: str):
    """Devuelve una lista de (atributos, partes) leyendo .shp y .dbf de un zip de Natural Earth.

    `partes` es una lista de arrays Nx2 (lon, lat). Sirve para polígonos (tipo 5) y líneas (tipo 3).
    """
    with zipfile.ZipFile(zip_path) as z:
        shp = z.read(f"{nombre}.shp")
        dbf = z.read(f"{nombre}.dbf")
    registros = _leer_dbf(dbf)
    formas = []
    pos = 100
    while pos < len(shp):
        _num, largo = struct.unpack(">ii", shp[pos : pos + 8])
        contenido = shp[pos + 8 : pos + 8 + largo * 2]
        pos += 8 + largo * 2
        tipo = struct.unpack("<i", contenido[:4])[0]
        if tipo == 0:
            formas.append([])
            continue
        n_partes, n_puntos = struct.unpack("<ii", contenido[36:44])
        partes_idx = list(struct.unpack(f"<{n_partes}i", contenido[44 : 44 + 4 * n_partes]))
        ini = 44 + 4 * n_partes
        pts = np.frombuffer(contenido[ini : ini + 16 * n_puntos], dtype="<f8").reshape(-1, 2)
        partes_idx.append(n_puntos)
        formas.append([pts[partes_idx[i] : partes_idx[i + 1]] for i in range(n_partes)])
    return list(zip(registros, formas))


def _leer_dbf(datos: bytes):
    n_reg, largo_cab, largo_reg = struct.unpack("<IHH", datos[4:12])
    campos = []
    pos = 32
    while datos[pos] != 0x0D:
        nombre = datos[pos : pos + 11].split(b"\0")[0].decode("latin-1")
        tipo = chr(datos[pos + 11])
        largo = datos[pos + 16]
        campos.append((nombre, tipo, largo))
        pos += 32
    registros = []
    for i in range(n_reg):
        ini = largo_cab + i * largo_reg + 1
        reg = {}
        for nombre, tipo, largo in campos:
            crudo = datos[ini : ini + largo].decode("utf-8", errors="replace").strip()
            ini += largo
            if tipo in "NF":
                try:
                    reg[nombre] = float(crudo) if crudo else None
                except ValueError:
                    reg[nombre] = None
            else:
                reg[nombre] = crudo
        registros.append(reg)
    return registros


def guardar_json(ruta: Path, datos, compacto=False):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with open(ruta, "w", encoding="utf-8") as f:
        if compacto:
            json.dump(datos, f, ensure_ascii=False, separators=(",", ":"))
        else:
            json.dump(datos, f, ensure_ascii=False, indent=1)


def dilatar(m: np.ndarray) -> np.ndarray:
    """Dilatación 4-vecinos de una máscara booleana (sin envolver los bordes)."""
    d = m.copy()
    d[1:] |= m[:-1]
    d[:-1] |= m[1:]
    d[:, 1:] |= m[:, :-1]
    d[:, :-1] |= m[:, 1:]
    return d
