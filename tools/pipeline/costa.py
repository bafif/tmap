"""Distancia con signo a la costa, calculada desde los polígonos de Natural Earth y no desde una máscara de píxeles.

Es el canal G de `relieve.png` (128 = costa, 4 valores por píxel, >128 agua). Antes salía de la máscara de tierra con
distancias enteras: en la costa el valor saltaba de 126 a 130 y, de cerca, el shader dibujaba los escalones de los
píxeles. Ahora:

1. **Signo**: regla par-impar evaluada en el centro exacto de cada píxel, renglón por renglón, sobre los mismos
   anillos (tierra menos los lagos grandes). No depende de cómo rasteriza Pillow.
2. **Franja exacta**: para cada píxel a menos de `FRANJA` px de la costa, la distancia a los segmentos del contorno
   (subdivididos en tramos de menos de un píxel) y el punto más cercano.
3. **Propagación**: *jump flooding* lleva ese punto más cercano hasta `MAXIMO` px, así que mar adentro la distancia
   también es euclídea y continua (las líneas de carta náutica del agua salen de ella).
4. **Tierra angosta**: una lengua de tierra más angosta que un píxel (el istmo de Curlandia, Hel, los Outer Banks)
   puede no tener ningún centro de píxel adentro, y el shader la dibujaría punteada o no la dibujaría. Para cada tramo
   se mide el ancho de la tierra hacia adentro (la distancia al tramo de enfrente) y, si es menor que `ANCHO_MINIMO`,
   se la engruesa hasta ese ancho, con una transición suave entre 1 y 2 px para que el campo siga continuo. Las islas
   que miden menos de `ISLA_MINIMA` px de lado pasan a ser un disco de ese diámetro en su centro, que siempre cubre
   un centro de píxel. El agua angosta (fiordos, el Bósforo) no se ensancha: se ve como una línea de costa.

Los huecos chicos (lagunas dentro de la tierra) se descartan, y los bordes del corte en el antimeridiano no cuentan
como costa.

Uso suelto (reescribe solo el canal G de `data/mapa/relieve.png`, sin rehacer el resto del paso 1):

    python3 costa.py
"""

from __future__ import annotations

import math
import time

import numpy as np
from PIL import Image

from comun import ALTO, ANCHO, CRUDOS, SALIDA, leer_shapefile, lonlat_a_px

FRANJA = 2  # px alrededor del contorno donde la distancia se calcula contra los tramos
MAXIMO = 32.0  # px: el canal G satura acá (128 ± 4 × 32)
ISLA_MINIMA = 1.5  # px: diámetro de las islas que entran en un cuadrado de este lado (siempre cubre un centro de píxel)
ANCHO_MINIMO = 1.5  # px: ancho mínimo de la tierra angosta (con poco más de 1 px, en diagonal, la interpolación bilineal
#                     la estrangula y se ve como un rosario de cuentas)
LAGOS_RANGO = 5  # lagos de ne_10m_lakes con scalerank <= este valor (los mismos que resta p1_base)


def t():
    return f"[{time.strftime('%H:%M:%S')}]"


def _area_firmada(xy: np.ndarray) -> float:
    x, y = xy[:, 0], xy[:, 1]
    return 0.5 * float(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


def _disco(cx: float, cy: float, r: float, lados: int = 16) -> np.ndarray:
    a = np.linspace(0, 2 * math.pi, lados, endpoint=False)
    return np.stack([cx + r * np.cos(a), cy + r * np.sin(a)], axis=1)


def anillos(zip_nombre: str, capa: str, filtro=None, es_lago=False):
    """Anillos en píxeles, con las islas chicas como discos y los huecos chicos descartados.

    Devuelve (lista de (anillo, encierra_tierra), cuántas islas se agrandaron, cuántos huecos se descartaron).
    """
    salida = []
    agrandadas = descartados = 0
    for attrs, partes in leer_shapefile(CRUDOS / zip_nombre, capa):
        if filtro and not filtro(attrs):
            continue
        for p in partes:
            if len(p) < 4:
                continue
            # En el shapefile, el anillo exterior va en sentido horario (área negativa en lon/lat) y los huecos al revés.
            # Encierra tierra un anillo exterior de tierra o un hueco de lago (una isla en el lago).
            tierra = (_area_firmada(p) < 0) != es_lago
            x, y = lonlat_a_px(p[:, 0], p[:, 1])
            xy = np.stack([x, y], axis=1)
            lado = (xy.max(axis=0) - xy.min(axis=0)).max()
            if lado < ISLA_MINIMA:
                if tierra:
                    c = (xy.max(axis=0) + xy.min(axis=0)) / 2
                    salida.append((_disco(float(c[0]), float(c[1]), ISLA_MINIMA / 2), True))
                    agrandadas += 1
                else:
                    descartados += 1
                continue
            salida.append((xy, tierra))
    return salida, agrandadas, descartados


def _aristas(lista):
    """Aristas de los anillos, cerrando cada uno: filas (x0, y0, x1, y1, nx, ny), con (nx, ny) la normal unitaria que
    apunta hacia la tierra."""
    filas = []
    for xy, tierra in lista:
        b = np.roll(xy, -1, axis=0)
        d = b - xy
        largo = np.maximum(np.hypot(d[:, 0], d[:, 1]), 1e-12)
        # Con área positiva (en estas coordenadas), el interior queda a la izquierda de cada arista: (-dy, dx).
        signo = 1.0 if _area_firmada(xy) > 0 else -1.0
        if not tierra:
            signo = -signo
        n = np.stack([-d[:, 1], d[:, 0]], axis=1) * (signo / largo)[:, None]
        filas.append(np.concatenate([xy, b, n], axis=1))
    a = np.concatenate(filas)
    return a[(a[:, 0] != a[:, 2]) | (a[:, 1] != a[:, 3])]


def par_impar(aristas: np.ndarray) -> np.ndarray:
    """Máscara (ALTO, ANCHO): True si el centro del píxel queda adentro según la regla par-impar."""
    x0, y0, x1, y1 = (aristas[:, k] for k in range(4))
    ymin, ymax = np.minimum(y0, y1), np.maximum(y0, y1)
    # Renglones r cuyo centro r + 0,5 cumple ymin <= r + 0,5 < ymax.
    r0 = np.clip(np.ceil(ymin - 0.5).astype(np.int64), 0, ALTO)
    r1 = np.clip(np.ceil(ymax - 0.5).astype(np.int64), 0, ALTO)
    n = np.maximum(r1 - r0, 0)
    cual = np.repeat(np.arange(len(aristas)), n)
    inicio = np.repeat(np.cumsum(n) - n, n)
    fila = r0[cual] + (np.arange(len(cual)) - inicio)
    yc = fila + 0.5
    xi = x0[cual] + (yc - y0[cual]) * (x1[cual] - x0[cual]) / (y1[cual] - y0[cual])
    # Cada cruce cambia el estado de los píxeles cuyo centro c + 0,5 queda a su derecha.
    col = np.clip(np.floor(xi - 0.5).astype(np.int64) + 1, 0, ANCHO)
    cambios = np.bincount(fila * (ANCHO + 1) + col, minlength=ALTO * (ANCHO + 1)).astype(np.uint8)
    cambios = cambios.reshape(ALTO, ANCHO + 1)[:, :ANCHO]
    return (np.cumsum(cambios, axis=1, dtype=np.uint8) & 1).astype(bool)


def _subdividir(aristas: np.ndarray) -> np.ndarray:
    """Parte las aristas en tramos de menos de un píxel (la normal se conserva)."""
    largo = np.hypot(aristas[:, 2] - aristas[:, 0], aristas[:, 3] - aristas[:, 1])
    partes = np.maximum(np.ceil(largo / 0.9).astype(np.int64), 1)
    cual = np.repeat(np.arange(len(aristas)), partes)
    inicio = np.repeat(np.cumsum(partes) - partes, partes)
    k = (np.arange(len(cual)) - inicio).astype(np.float64)
    f0 = k / partes[cual]
    f1 = (k + 1) / partes[cual]
    a = aristas[cual]
    dx, dy = a[:, 2] - a[:, 0], a[:, 3] - a[:, 1]
    return np.stack(
        [a[:, 0] + dx * f0, a[:, 1] + dy * f0, a[:, 0] + dx * f1, a[:, 1] + dy * f1, a[:, 4], a[:, 5]], axis=1
    )


def _dist_segmento(qx, qy, ax, ay, bx, by):
    """Distancia de los puntos q a los segmentos ab y el punto más cercano (todo con broadcasting)."""
    vx, vy = bx - ax, by - ay
    l2 = np.maximum(vx * vx + vy * vy, 1e-12)
    tt = np.clip(((qx - ax) * vx + (qy - ay) * vy) / l2, 0.0, 1.0)
    px_, py_ = ax + tt * vx, ay + tt * vy
    return np.hypot(qx - px_, qy - py_), px_, py_


def anchos(tramos: np.ndarray) -> np.ndarray:
    """Ancho de la tierra del lado de cada tramo: distancia desde su punto medio al tramo de enfrente más cercano
    (con la normal opuesta y del lado de la tierra). inf si no hay ninguno a menos de ANCHO_MINIMO."""
    mx = (tramos[:, 0] + tramos[:, 2]) / 2
    my = (tramos[:, 1] + tramos[:, 3]) / 2
    cx = np.clip(np.floor(mx).astype(np.int64), -3, ANCHO + 2)
    cy = np.clip(np.floor(my).astype(np.int64), -3, ALTO + 2)
    fila = ANCHO + 8  # celdas de 1 px, con margen para que los vecinos no den la vuelta
    clave = (cy + 4) * fila + (cx + 4)
    orden = np.argsort(clave, kind="stable")
    claves = clave[orden]
    resultado = np.full(len(tramos), np.inf)
    r = int(math.ceil(ANCHO_MINIMO + 0.5))
    lote = 100_000
    for i0 in range(0, len(tramos), lote):
        ii = np.arange(i0, min(i0 + lote, len(tramos)))
        for oy in range(-r, r + 1):
            for ox in range(-r, r + 1):
                k = clave[ii] + oy * fila + ox
                lo = np.searchsorted(claves, k, "left")
                hi = np.searchsorted(claves, k, "right")
                n = hi - lo
                if not n.any():
                    continue
                a = np.repeat(ii, n)
                inicio = np.repeat(np.cumsum(n) - n, n)
                b = orden[np.repeat(lo, n) + (np.arange(len(a)) - inicio)]
                nax, nay = tramos[a, 4], tramos[a, 5]
                enfrente = nax * tramos[b, 4] + nay * tramos[b, 5] < -0.3
                bmx = (tramos[b, 0] + tramos[b, 2]) / 2
                bmy = (tramos[b, 1] + tramos[b, 3]) / 2
                enfrente &= (bmx - mx[a]) * nax + (bmy - my[a]) * nay > 0.0
                a, b = a[enfrente], b[enfrente]
                d, _, _ = _dist_segmento(mx[a], my[a], tramos[b, 0], tramos[b, 1], tramos[b, 2], tramos[b, 3])
                np.minimum.at(resultado, a, d)
    resultado[resultado >= ANCHO_MINIMO] = np.inf
    return resultado


def franja(tramos: np.ndarray, engrosar: np.ndarray | None = None):
    """Para los píxeles a menos de FRANJA px de algún tramo: la distancia exacta y el punto más cercano.

    Con `engrosar` (px por tramo), en vez de la distancia d devuelve d - e·clamp(2 - d, 0, 1): la distancia al tramo
    engrosado e px de cada lado, que vuelve a ser la distancia común a 2 px. Devuelve (valor, px, py), arrays planos
    de ALTO × ANCHO; fuera de la franja, valor = inf.
    """
    total = ALTO * ANCHO
    mejor = np.full(total, np.inf, dtype=np.float32)
    cerca_x = np.zeros(total, dtype=np.float32)
    cerca_y = np.zeros(total, dtype=np.float32)
    lado = 2 * FRANJA + 3
    ox, oy = np.meshgrid(np.arange(lado), np.arange(lado))
    ox, oy = ox.ravel()[None, :], oy.ravel()[None, :]
    lote = 150_000
    for i in range(0, len(tramos), lote):
        s = tramos[i : i + lote]
        ax, ay, bx, by = s[:, 0:1], s[:, 1:2], s[:, 2:3], s[:, 3:4]
        cx = np.floor(np.minimum(ax, bx)).astype(np.int64) - FRANJA - 1 + ox
        cy = np.floor(np.minimum(ay, by)).astype(np.int64) - FRANJA - 1 + oy
        d, px_, py_ = _dist_segmento(cx + 0.5, cy + 0.5, ax, ay, bx, by)
        validos = (cx >= 0) & (cx < ANCHO) & (cy >= 0) & (cy < ALTO) & (d <= FRANJA)
        if engrosar is not None:
            d = d - engrosar[i : i + lote, None] * np.clip(2.0 - d, 0.0, 1.0)
        idx = (cy * ANCHO + cx)[validos]
        d = d[validos].astype(np.float32)
        px_, py_ = px_[validos].astype(np.float32), py_[validos].astype(np.float32)
        orden = np.lexsort((d, idx))
        idx, d, px_, py_ = idx[orden], d[orden], px_[orden], py_[orden]
        primero = np.ones(len(idx), dtype=bool)
        primero[1:] = idx[1:] != idx[:-1]
        idx, d, px_, py_ = idx[primero], d[primero], px_[primero], py_[primero]
        mejora = d < mejor[idx]
        idx = idx[mejora]
        mejor[idx] = d[mejora]
        cerca_x[idx] = px_[mejora]
        cerca_y[idx] = py_[mejora]
    return mejor, cerca_x, cerca_y


def propagar(mejor: np.ndarray, cerca_x: np.ndarray, cerca_y: np.ndarray) -> np.ndarray:
    """*Jump flooding*: cada píxel toma el punto de costa más cercano entre los de sus vecinos a distancia k."""
    hay = np.isfinite(mejor)
    sx = np.where(hay, cerca_x, np.nan).astype(np.float32).reshape(ALTO, ANCHO)
    sy = np.where(hay, cerca_y, np.nan).astype(np.float32).reshape(ALTO, ANCHO)
    del hay
    xs = (np.arange(ANCHO, dtype=np.float32) + 0.5)[None, :]
    ys = (np.arange(ALTO, dtype=np.float32) + 0.5)[:, None]
    d2 = (sx - xs) ** 2 + (sy - ys) ** 2
    d2[np.isnan(d2)] = np.inf
    pasos = [16, 8, 4, 2, 1, 2, 1]  # alcanza 31 px; las dos últimas pasadas corrigen los errores típicos del método
    for k in pasos:
        for dx in (-k, 0, k):
            for dy in (-k, 0, k):
                if dx == 0 and dy == 0:
                    continue
                # El píxel [y, x] prueba la semilla de [y + dy, x + dx].
                dst_y = slice(max(0, -dy), ALTO - max(0, dy))
                dst_x = slice(max(0, -dx), ANCHO - max(0, dx))
                src_y = slice(max(0, dy), ALTO - max(0, -dy))
                src_x = slice(max(0, dx), ANCHO - max(0, -dx))
                cx = sx[src_y, src_x]
                cy = sy[src_y, src_x]
                nd2 = (cx - xs[:, dst_x]) ** 2 + (cy - ys[dst_y, :]) ** 2
                mejora = nd2 < d2[dst_y, dst_x]  # NaN compara falso
                d2[dst_y, dst_x][mejora] = nd2[mejora]
                sx[dst_y, dst_x][mejora] = cx[mejora]
                sy[dst_y, dst_x][mejora] = cy[mejora]
                del nd2, mejora
    return np.sqrt(d2)


def distancia_con_signo():
    """sdf en píxeles (float32, positivo en el agua, saturado en ±MAXIMO), lista para `codificar`."""
    tierra_a, agrandadas, descartados = anillos("ne_10m_land.zip", "ne_10m_land")
    lagos_a, agr_l, desc_l = anillos(
        "ne_10m_lakes.zip", "ne_10m_lakes", lambda a: (a.get("scalerank") or 99) <= LAGOS_RANGO, es_lago=True
    )
    print(
        t(),
        f"Costa: {len(tierra_a)} anillos de tierra y {len(lagos_a)} de lagos; {agrandadas + agr_l} islas chicas "
        f"como discos de {ISLA_MINIMA} px y {descartados + desc_l} huecos chicos descartados",
    )
    ar_tierra = _aristas(tierra_a)
    ar_lagos = _aristas(lagos_a)
    tierra = par_impar(ar_tierra) & ~par_impar(ar_lagos)
    print(t(), f"  signo: tierra en {tierra.mean() * 100:.1f} % de los centros de píxel")

    aristas = np.concatenate([ar_tierra, ar_lagos])
    # El corte del antimeridiano (lon = ±180) no es costa.
    borde = ((aristas[:, 0] <= 1e-6) & (aristas[:, 2] <= 1e-6)) | (
        (aristas[:, 0] >= ANCHO - 1e-6) & (aristas[:, 2] >= ANCHO - 1e-6)
    )
    aristas = aristas[~borde]
    fuera = (np.maximum(aristas[:, 1], aristas[:, 3]) < -FRANJA - 1) | (
        np.minimum(aristas[:, 1], aristas[:, 3]) > ALTO + FRANJA + 1
    )
    tramos = _subdividir(aristas[~fuera])
    print(t(), f"  {len(tramos)} tramos de costa de menos de un píxel")
    mejor, cx, cy = franja(tramos)
    print(t(), f"  franja exacta: {int(np.isfinite(mejor).sum())} píxeles")
    d = propagar(mejor, cx, cy)
    del mejor, cx, cy
    sdf = np.where(tierra, -np.minimum(d, MAXIMO), np.minimum(d, MAXIMO)).astype(np.float32)
    del d, tierra
    print(t(), "  distancia propagada")

    w = anchos(tramos)
    angostos = np.isfinite(w)
    engrosar = (ANCHO_MINIMO - w[angostos]) / 2
    g, _, _ = franja(tramos[angostos], engrosar)
    g = g.reshape(ALTO, ANCHO)
    cambia = g < sdf
    a_tierra = int((cambia & (g < 0) & (sdf > 0)).sum())
    sdf[cambia] = g[cambia]
    print(
        t(),
        f"  tierra angosta: {int(angostos.sum())} tramos engrosados hasta {ANCHO_MINIMO} px "
        f"({a_tierra} centros de píxel pasan a tierra)",
    )
    return sdf


def codificar(sdf: np.ndarray) -> np.ndarray:
    """Canal G de relieve.png: 128 + 4 × distancia, redondeado."""
    return np.clip(np.round(128.0 + sdf * 4.0), 0, 255).astype(np.uint8)


def main():
    ruta = SALIDA / "relieve.png"
    rel = np.asarray(Image.open(ruta).convert("RGBA")).copy()
    viejo = rel[..., 1].copy()
    rel[..., 1] = codificar(distancia_con_signo())
    Image.fromarray(rel, "RGBA").save(ruta, compress_level=9)
    cambio = np.abs(rel[..., 1].astype(np.int16) - viejo).mean()
    print(t(), f"relieve.png: canal G reescrito (cambio medio {cambio:.2f} valores)")


if __name__ == "__main__":
    main()
