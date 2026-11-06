"""Paso 2: las unidades del mapa y la historia política de cada una.

1. Rasteriza los ~13 400 registros de entidades políticas de Cliopatria y calcula, para cada píxel de tierra, una
   «firma» con todos los registros que lo cubren. Dos píxeles con la misma firma tuvieron exactamente la misma
   historia política.
2. Siembra celdas (provincias) con densidad adaptativa: más chicas donde hay más fronteras históricas.
3. Corta cada celda por las firmas y funde las astillas chicas. El resultado son las «unidades»: cada una tiene una
   historia política homogénea, así que los bordes del mapa siguen las fronteras reales.
4. Para cada registro calcula qué unidades cubre y arma la línea de tiempo de dueños de cada unidad, como eventos
   (año, unidad, dueño anterior, dueño nuevo) más fotos completas cada tanto para saltar rápido.
5. Calcula la ubicación de las etiquetas (centro, eje, curvatura) de cada registro y asigna colores.

Salida en `data/mapa/`: `unidades.bin` (RG8 crudo comprimido con zlib), `politico.json` y `politico.bin` (zlib).
"""

from __future__ import annotations

import hashlib
import json
import math
import re
import sys
import time
import zlib

import numpy as np
from PIL import Image, ImageFilter

from comun import ALTO, ANCHO, CACHE, SALIDA, anillo_a_px, area_px, guardar_json, poligonos_geojson, rasterizar_anillos

RNG = np.random.default_rng(20261106)
MULT = np.uint64(1099511628211)
PASO_SEMILLA = 6
CELDA_MIN = 11.0  # px (~50 km en el ecuador)
CELDA_MAX = 60.0  # px (~290 km)
ASTILLA_MIN = 24  # px: fragmentos más chicos se funden con un vecino de la misma celda
AÑO_MIN, AÑO_MAX = -3400, 2024


def t():
    return f"[{time.strftime('%H:%M:%S')}]"


# ---------------------------------------------------------------------------------------------------------------
# Lectura de Cliopatria


def leer_registros():
    with open(CACHE / "cliopatria.geojson", encoding="utf-8") as f:
        datos = json.load(f)
    registros = []
    for feat in datos["features"]:
        p = feat["properties"]
        if p.get("Type") != "POLITY" or not feat.get("geometry"):
            continue
        polis = []
        for poli in poligonos_geojson(feat["geometry"]):
            anillos = [anillo_a_px(a) for a in poli if len(a) >= 3]
            if anillos:
                polis.append(anillos)
        if not polis:
            continue
        registros.append(
            {
                "nombre": p["Name"],
                "desde": int(p["FromYear"]),
                "hasta": int(p["ToYear"]),
                "wikipedia": p.get("Wikipedia") or "",
                "wikidata": p.get("Wikidata") or "",
                "seshat": p.get("SeshatID") or "",
                "miembro_de": p.get("MemberOf") or "",
                "area": float(p.get("Area") or 0.0),
                "polis": polis,
            }
        )
    # Orden estable: por año y nombre. La firma depende del orden, así que tiene que ser reproducible.
    registros.sort(key=lambda r: (r["desde"], r["nombre"], r["hasta"]))
    return registros


def mascara_registro(reg):
    anillos = [a for poli in reg["polis"] for a in poli]
    return rasterizar_anillos(anillos)


def etiqueta_de(reg):
    """Geometría de la etiqueta del registro, calculada sobre su polígono más grande."""
    mayor = max(reg["polis"], key=lambda poli: area_px(poli[0]))
    r = rasterizar_anillos(mayor)
    if r is None:
        return None
    x0, y0, m = r
    ys, xs = np.nonzero(m)
    if len(xs) < 40:
        return None
    if len(xs) > 30000:
        sel = RNG.choice(len(xs), 30000, replace=False)
        xs, ys = xs[sel], ys[sel]
    pts = np.stack([xs + x0 + 0.5, ys + y0 + 0.5], axis=1).astype(np.float64)
    media = pts.mean(axis=0)
    c = np.cov((pts - media).T)
    val, vec = np.linalg.eigh(c)
    e1 = vec[:, 1]
    if e1[0] < 0:
        e1 = -e1
    ang = math.atan2(e1[1], e1[0])
    # Limitar la inclinación: los nombres casi verticales se leen mal.
    lim = math.radians(62)
    ang = max(-lim, min(lim, ang))
    e1 = np.array([math.cos(ang), math.sin(ang)])
    e2 = np.array([-e1[1], e1[0]])
    u = (pts - media) @ e1
    v = (pts - media) @ e2
    u_lo, u_hi = np.percentile(u, [4, 96])
    largo = float(u_hi - u_lo)
    if largo < 6:
        return None
    a, b, cc = np.polyfit(u, v, 2) if len(u) > 10 else (0.0, 0.0, 0.0)
    # Curvatura moderada: la flecha no supera el 18 % del largo.
    flecha = abs(a) * (largo / 2) ** 2
    if flecha > 0.18 * largo:
        a *= 0.18 * largo / flecha
    centro_u = (u_lo + u_hi) / 2
    resto = v - (a * u * u + b * u + cc)
    medio = np.abs(u - centro_u) < largo * 0.3
    grosor = float(2.2 * np.std(resto[medio])) if medio.sum() > 10 else float(2.2 * np.std(resto))
    # Reexpresar la curva con origen en centro_u.
    cx, cy = media + e1 * centro_u
    a2 = float(a)
    b2 = float(2 * a * centro_u + b)
    c2 = float(a * centro_u * centro_u + b * centro_u + cc)
    return [round(float(cx), 1), round(float(cy), 1), round(math.degrees(ang), 2), round(largo, 1),
            round(a2, 6), round(b2, 4), round(c2, 2), round(max(grosor, 4.0), 1)]


# ---------------------------------------------------------------------------------------------------------------
# Celdas


def crecer(etiquetas: np.ndarray, permitido: np.ndarray, prob=0.62, max_iter=400):
    """Crecimiento geodésico multi-semilla con ruido: Voronoi orgánico que no cruza el agua."""
    direcciones = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    for it in range(max_iter):
        libres = (etiquetas == 0) & permitido
        if not libres.any():
            break
        cambio = False
        orden = RNG.permutation(4)
        azar = RNG.random(etiquetas.shape, dtype=np.float32) < prob
        for k in orden:
            dy, dx = direcciones[k]
            vecino = np.zeros_like(etiquetas)
            ys = slice(max(dy, 0), etiquetas.shape[0] + min(dy, 0))
            ys_src = slice(max(-dy, 0), etiquetas.shape[0] + min(-dy, 0))
            xs = slice(max(dx, 0), etiquetas.shape[1] + min(dx, 0))
            xs_src = slice(max(-dx, 0), etiquetas.shape[1] + min(-dx, 0))
            vecino[ys, xs] = etiquetas[ys_src, xs_src]
            tomar = libres & (vecino > 0) & azar
            if tomar.any():
                etiquetas[tomar] = vecino[tomar]
                libres &= ~tomar
                cambio = True
        if not cambio and it > 5:
            # Quedan libres sin vecino etiquetado: islas sin semilla.
            break
    return etiquetas


def generar_celdas(tierra: np.ndarray, densidad: np.ndarray) -> np.ndarray:
    """densidad: array chico (ALTO/16, ANCHO/16) en [0, 1]."""
    gy = np.arange(0, ALTO, PASO_SEMILLA)
    gx = np.arange(0, ANCHO, PASO_SEMILLA)
    yy, xx = np.meshgrid(gy, gx, indexing="ij")
    yy = (yy + RNG.integers(0, PASO_SEMILLA, yy.shape)).clip(0, ALTO - 1)
    xx = (xx + RNG.integers(0, PASO_SEMILLA, xx.shape)).clip(0, ANCHO - 1)
    en_tierra = tierra[yy, xx]
    dens = densidad[(yy // 16).clip(0, densidad.shape[0] - 1), (xx // 16).clip(0, densidad.shape[1] - 1)]
    lado = CELDA_MAX / (1.0 + dens * (CELDA_MAX / CELDA_MIN - 1.0))
    prob = (PASO_SEMILLA / lado) ** 2
    acepta = en_tierra & (RNG.random(yy.shape) < prob)
    sy, sx = yy[acepta], xx[acepta]
    etiquetas = np.zeros((ALTO, ANCHO), dtype=np.int32)
    etiquetas[sy, sx] = np.arange(1, len(sy) + 1, dtype=np.int32)
    print(t(), f"Semillas: {len(sy)}")
    crecer(etiquetas, tierra)
    # Islas sin semilla: sembrar en todas las celdas de una grilla gruesa que hayan quedado libres.
    for paso in (10, 5, 2):
        libres = (etiquetas == 0) & tierra
        if not libres.any():
            break
        ly, lx = np.nonzero(libres[::paso, ::paso])
        ly, lx = ly * paso, lx * paso
        sigue = etiquetas.max() + 1
        etiquetas[ly, lx] = np.arange(sigue, sigue + len(ly), dtype=np.int32)
        crecer(etiquetas, tierra)
        print(t(), f"  islas: +{len(ly)} semillas (paso {paso})")
    return etiquetas


# ---------------------------------------------------------------------------------------------------------------
# Colores

# Sin rojos puros: quedan reservados para las entidades fijas (Roma, Inglaterra…).
PALETA = [
    "#b5603b", "#c47a4a", "#c9a04a", "#d4b95e", "#8c8f3e", "#6f8a47", "#4e7d4a", "#3e7f6b", "#3f7c85",
    "#4c6e9c", "#3c5a9a", "#2f4a7a", "#5a4e8c", "#7a4a8a", "#8e3f6e", "#b05a7a", "#c98070", "#cdb892", "#a99a6b",
    "#6f7a86", "#7a5638", "#8b4a2e", "#6e9cc0", "#7fb59a", "#9a8cc0", "#a8552e", "#3f6a3f", "#b9925a", "#5f8fa0",
    "#94604a", "#7d9a5a",
]

# Colores fijos para entidades muy reconocibles. Se busca por palabra completa en el nombre de Cliopatria (en
# inglés) y gana la primera coincidencia, así que los casos más específicos van primero.
FIJOS = [
    (("Holy Roman", "German", "Prussia"), "#6f7a86"),
    (("Byzantine", "Eastern Roman"), "#6b3a7a"),
    (("Roman", "Rome"), "#8e1f1f"),
    (("Egypt", "Ptolemaic"), "#c9a04a"),
    (("Achaemenid", "Sasanian", "Parthian", "Persia", "Persian", "Safavid", "Iran"), "#3e7f6b"),
    (("Ottoman",), "#3b7a5a"),
    (("Caliphate", "Umayyad", "Abbasid", "Rashidun", "Fatimid"), "#4e7d4a"),
    (("Mongol", "Golden Horde", "Ilkhanate", "Chagatai"), "#6f7a86"),
    (("Han", "Tang", "Song", "Ming", "Qing", "Qin", "Zhou", "Shang", "China", "Chinese"), "#d4b95e"),
    (("Maurya", "Gupta", "Mughal"), "#c47a4a"),
    (("Macedon", "Macedonian", "Seleucid"), "#3c5a9a"),
    (("Athens", "Athenian", "Greek", "Greece"), "#4c6e9c"),
    (("Carthage", "Carthaginian"), "#7a4a8a"),
    (("Assyria", "Assyrian"), "#8b4a2e"),
    (("Babylon", "Babylonia", "Babylonian"), "#a8552e"),
    (("Hittite", "Hittites"), "#94604a"),
    (("Franks", "Frankish", "Francia", "France", "French"), "#2f4a7a"),
    (("England", "English", "British", "United Kingdom"), "#9e2b25"),
    (("Spain", "Spanish", "Castile"), "#c9a04a"),
    (("Portugal", "Portuguese"), "#3f6a3f"),
    (("Russia", "Russian", "Muscovy", "Moscow", "Soviet"), "#4e6b3a"),
    (("Inca",), "#c98070"),
    (("Aztec", "Aztecs", "Mexica"), "#3f7c85"),
    (("Argentina", "Argentine", "Río de la Plata", "Rio de la Plata"), "#6e9cc0"),
    (("Venice", "Venetian"), "#b05a7a"),
]


def hex_a_rgb(h):
    return np.array([int(h[i : i + 2], 16) for i in (1, 3, 5)], dtype=np.float64)


def color_fijo(nombre):
    for claves, color in FIJOS:
        if any(re.search(r"\b" + re.escape(c) + r"\b", nombre, re.IGNORECASE) for c in claves):
            return color
    return None


def asignar_colores(polities, vecinos):
    rgb = [hex_a_rgb(c) for c in PALETA]
    colores = {}
    for i, p in enumerate(polities):
        fijo = color_fijo(p["nombre"])
        if fijo:
            colores[i] = fijo
    orden = sorted(range(len(polities)), key=lambda i: -polities[i]["area_max"])
    for i in orden:
        if i in colores:
            continue
        usados = [hex_a_rgb(colores[j]) for j in vecinos.get(i, ()) if j in colores]
        # Vecinos de los vecinos: pesan la mitad (se ven cerca en el mapa aunque no se toquen).
        segundos = {k for j in vecinos.get(i, ()) for k in vecinos.get(j, ())} - set(vecinos.get(i, ())) - {i}
        lejanos = [hex_a_rgb(colores[j]) for j in segundos if j in colores]
        semilla = int(hashlib.md5(polities[i]["nombre"].encode()).hexdigest()[:8], 16)
        mejor, mejor_d = None, -1.0
        for k in range(len(PALETA)):
            idx = (k + semilla) % len(PALETA)
            d1 = min((float(np.linalg.norm(rgb[idx] - u)) for u in usados), default=999.0)
            d2 = min((float(np.linalg.norm(rgb[idx] - u)) * 2.0 for u in lejanos), default=999.0)
            d = min(d1, d2)
            if d > mejor_d + 1e-6:
                mejor, mejor_d = idx, d
            if d >= 999.0:
                break
        colores[i] = PALETA[mejor]
    # Una pequeña variación por entidad para que dos vecinos con el mismo tono base no queden idénticos.
    finales = []
    for i, p in enumerate(polities):
        base = hex_a_rgb(colores[i])
        h = int(hashlib.md5(p["nombre"].encode()).hexdigest()[8:12], 16) / 65535.0
        base = np.clip(base * (0.93 + 0.14 * h), 0, 255)
        finales.append("#%02x%02x%02x" % tuple(int(v) for v in base))
    return finales


# ---------------------------------------------------------------------------------------------------------------


def main():
    tierra = np.load(CACHE / "tierra.npy")
    registros = leer_registros()
    print(t(), f"Registros POLITY: {len(registros)}")

    # --- Pasada 1: firmas y etiquetas ---------------------------------------------------------------------------
    firma = np.zeros((ALTO, ANCHO), dtype=np.uint64)
    etiquetas_reg = []
    for i, reg in enumerate(registros):
        r = mascara_registro(reg)
        reg["caja"] = None
        if r is not None:
            x0, y0, m = r
            reg["caja"] = (x0, y0, m.shape[1], m.shape[0])
            vista = firma[y0 : y0 + m.shape[0], x0 : x0 + m.shape[1]]
            vista[m] = vista[m] * MULT + np.uint64(i + 1)
        etiquetas_reg.append(etiqueta_de(reg))
        if i % 2000 == 0:
            print(t(), f"  firma {i}/{len(registros)}")
    firma[~tierra] = 0
    print(t(), "Firmas listas")

    # --- Densidad de fronteras ---------------------------------------------------------------------------------
    borde = np.zeros((ALTO, ANCHO), dtype=bool)
    borde[:, 1:] |= (firma[:, 1:] != firma[:, :-1]) & tierra[:, 1:] & tierra[:, :-1]
    borde[1:] |= (firma[1:] != firma[:-1]) & tierra[1:] & tierra[:-1]
    chico = np.asarray(Image.fromarray(borde.astype(np.uint8) * 255).resize((ANCHO // 16, ALTO // 16), Image.Resampling.BOX), dtype=np.float32)
    del borde
    chico = np.asarray(Image.fromarray(np.clip(chico * 4, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)), dtype=np.float32) / 255.0
    densidad = np.clip(chico / max(np.percentile(chico[chico > 0], 90), 1e-3), 0, 1) ** 0.7

    # --- Celdas y unidades -------------------------------------------------------------------------------------
    celdas = generar_celdas(tierra, densidad)
    print(t(), f"Celdas: {celdas.max()}, tierra sin celda: {int(((celdas == 0) & tierra).sum())} px")

    clave = celdas.astype(np.uint64) * np.uint64(0x9E3779B97F4A7C15) ^ firma
    del firma
    en = celdas > 0
    _, inv = np.unique(clave[en], return_inverse=True)
    del clave
    frag = np.zeros((ALTO, ANCHO), dtype=np.int32)
    frag[en] = inv.astype(np.int32) + 1
    del inv
    celda_de_frag = np.zeros(frag.max() + 1, dtype=np.int32)
    celda_de_frag[frag[en]] = celdas[en]
    print(t(), f"Fragmentos iniciales: {frag.max()}")

    for ronda in range(4):
        tam = np.bincount(frag.ravel(), minlength=frag.max() + 1)
        tam[0] = 1 << 30
        chicos = tam < ASTILLA_MIN
        if not chicos[1:].any():
            break
        pares = []
        for a, b in ((frag[:, :-1], frag[:, 1:]), (frag[:-1], frag[1:])):
            dif = (a != b) & (a > 0) & (b > 0)
            fa, fb = a[dif], b[dif]
            mismo = celda_de_frag[fa] == celda_de_frag[fb]
            fa, fb = fa[mismo], fb[mismo]
            pares.append(np.stack([fa, fb], 1))
            pares.append(np.stack([fb, fa], 1))
        pares = np.concatenate(pares)
        pares = pares[chicos[pares[:, 0]]]
        if len(pares) == 0:
            break
        cod = pares[:, 0].astype(np.int64) * (1 << 31) + pares[:, 1]
        cod, cuenta = np.unique(cod, return_counts=True)
        fa = (cod >> 31).astype(np.int32)
        fb = (cod & ((1 << 31) - 1)).astype(np.int32)
        # Preferir el vecino con más borde compartido; desempatar por tamaño.
        orden = np.lexsort((tam[fb], cuenta, fa))
        fa, fb = fa[orden], fb[orden]
        ultimo = np.r_[fa[1:] != fa[:-1], True]
        destino = np.arange(len(tam), dtype=np.int32)
        destino[fa[ultimo]] = fb[ultimo]
        # Resolver cadenas a -> b -> c, evitando ciclos entre dos astillas.
        for _ in range(8):
            nuevo = destino[destino]
            ciclo = nuevo == np.arange(len(destino))
            nuevo[ciclo] = np.maximum(np.arange(len(destino)), destino)[ciclo]
            destino = nuevo
        frag = destino[frag]
        print(t(), f"  ronda {ronda}: {int(chicos[1:].sum())} astillas fundidas")

    usados = np.unique(frag)
    usados = usados[usados > 0]
    remap = np.zeros(frag.max() + 1, dtype=np.int32)
    remap[usados] = np.arange(1, len(usados) + 1, dtype=np.int32)
    unidades = remap[frag]
    del frag, celdas
    n = int(unidades.max())
    print(t(), f"Unidades: {n}")
    if n > 65535:
        sys.exit("Demasiadas unidades para codificar en RG8: subí ASTILLA_MIN o CELDA_MIN")

    # Estadísticas por unidad
    plano = unidades.ravel()
    tam = np.bincount(plano, minlength=n + 1).astype(np.int64)
    ys, xs = np.divmod(np.arange(plano.size, dtype=np.int64), ANCHO)
    cx = np.bincount(plano, weights=xs + 0.5, minlength=n + 1) / np.maximum(tam, 1)
    cy = np.bincount(plano, weights=ys + 0.5, minlength=n + 1) / np.maximum(tam, 1)
    del ys, xs

    # Vecindad entre unidades (para colores)
    pares = []
    for a, b in ((unidades[:, :-1], unidades[:, 1:]), (unidades[:-1], unidades[1:])):
        dif = (a != b) & (a > 0) & (b > 0)
        pares.append(np.stack([a[dif], b[dif]], 1))
    pares = np.unique(np.sort(np.concatenate(pares), axis=1), axis=0)
    print(t(), f"Pares de unidades vecinas: {len(pares)}")

    # --- Pasada 2: cobertura de cada registro sobre las unidades --------------------------------------------------
    nombres = sorted({r["nombre"] for r in registros})
    idx_nombre = {nm: i for i, nm in enumerate(nombres)}
    candidatos = [[] for _ in range(n + 1)]  # por unidad: (desde, hasta, entidad, cobertura, area)
    for i, reg in enumerate(registros):
        if reg["caja"] is None:
            continue
        r = mascara_registro(reg)
        if r is None:
            continue
        x0, y0, m = r
        u = unidades[y0 : y0 + m.shape[0], x0 : x0 + m.shape[1]][m]
        u = u[u > 0]
        if u.size == 0:
            continue
        ids, cuenta = np.unique(u, return_counts=True)
        cob = cuenta / tam[ids]
        sel = cob >= 0.5
        if not sel.any():
            mejor = int(np.argmax(cob))
            if cob[mejor] >= 0.15:
                sel = np.zeros_like(sel)
                sel[mejor] = True
        ent = idx_nombre[reg["nombre"]]
        for uid, c in zip(ids[sel].tolist(), cob[sel].tolist()):
            candidatos[uid].append((reg["desde"], reg["hasta"], ent, c, reg["area"]))
        if i % 2000 == 0:
            print(t(), f"  cobertura {i}/{len(registros)}")

    # --- Línea de tiempo por unidad --------------------------------------------------------------------------------
    eventos = []  # (año, unidad, nuevo)
    for uid in range(1, n + 1):
        cands = candidatos[uid]
        if not cands:
            continue
        cortes = sorted({c[0] for c in cands} | {c[1] + 1 for c in cands})
        actual = -1
        for k, año in enumerate(cortes):
            activos = [c for c in cands if c[0] <= año <= c[1]]
            if activos:
                nuevo = max(activos, key=lambda c: (round(c[3], 2), -c[4]))[2]
            else:
                nuevo = -1
            if nuevo != actual:
                eventos.append((año, uid, nuevo))
                actual = nuevo
    eventos.sort()
    print(t(), f"Eventos de cambio de dueño: {len(eventos)}")

    # Simular para conocer el dueño anterior y armar fotos.
    dueño = np.full(n + 1, -1, dtype=np.int32)
    ev = np.zeros((len(eventos), 4), dtype=np.int32)
    fotos = []
    años_foto = []
    ultimo_año = None
    desde_foto = 0
    for k, (año, uid, nuevo) in enumerate(eventos):
        if año != ultimo_año:
            if desde_foto >= 20000:
                fotos.append(dueño.copy())
                años_foto.append(k)  # foto = estado tras aplicar eventos[0:k]
                desde_foto = 0
            ultimo_año = año
        ev[k] = (año, uid, dueño[uid], nuevo)
        dueño[uid] = nuevo
        desde_foto += 1

    # --- Entidades: datos, área máxima y colores -------------------------------------------------------------------
    polities = []
    for nm in nombres:
        regs = [r for r in registros if r["nombre"] == nm]
        ult = max(regs, key=lambda r: r["hasta"])
        polities.append(
            {
                "nombre": nm,
                "desde": min(r["desde"] for r in regs),
                "hasta": max(r["hasta"] for r in regs),
                "wikipedia": ult["wikipedia"],
                "wikidata": ult["wikidata"],
                "seshat": ult["seshat"],
                "miembro_de": ult["miembro_de"],
                "area_max": max(r["area"] for r in regs),
            }
        )
    # Vecinos entre entidades: dueños de unidades vecinas en años de muestra.
    vecinos = {}
    estado = np.full(n + 1, -1, dtype=np.int32)
    k = 0
    for año in range(AÑO_MIN, AÑO_MAX + 1, 20):
        while k < len(ev) and ev[k, 0] <= año:
            estado[ev[k, 1]] = ev[k, 3]
            k += 1
        a, b = estado[pares[:, 0]], estado[pares[:, 1]]
        ok = (a >= 0) & (b >= 0) & (a != b)
        for x, y in np.unique(np.stack([a[ok], b[ok]], 1), axis=0).tolist():
            vecinos.setdefault(x, set()).add(y)
            vecinos.setdefault(y, set()).add(x)
    colores = asignar_colores(polities, vecinos)

    # --- Escribir -------------------------------------------------------------------------------------------------
    SALIDA.mkdir(parents=True, exist_ok=True)
    rg = np.stack([(unidades & 0xFF).astype(np.uint8), (unidades >> 8).astype(np.uint8)], axis=2)
    crudo = rg.tobytes()
    with open(SALIDA / "unidades.bin", "wb") as f:
        f.write(zlib.compress(crudo, 9))

    partes = {}
    bloques = []
    pos = 0

    def agregar(nombre, arr):
        nonlocal pos
        b = np.ascontiguousarray(arr).astype("<i4" if arr.dtype.kind in "iu" else "<f4").tobytes()
        partes[nombre] = {"inicio": pos, "bytes": len(b), "tipo": "i32" if arr.dtype.kind in "iu" else "f32"}
        bloques.append(b)
        pos += len(b)

    agregar("unidad_x", cx.astype(np.float32))
    agregar("unidad_y", cy.astype(np.float32))
    agregar("unidad_tam", tam.astype(np.int32))
    agregar("evento_anio", ev[:, 0].copy())
    agregar("evento_unidad", ev[:, 1].copy())
    agregar("evento_antes", ev[:, 2].copy())
    agregar("evento_despues", ev[:, 3].copy())
    for j, foto in enumerate(fotos):
        agregar(f"foto_{j}", foto)
    crudo_pol = b"".join(bloques)
    with open(SALIDA / "politico.bin", "wb") as f:
        f.write(zlib.compress(crudo_pol, 9))

    etiquetas = []
    for reg, et in zip(registros, etiquetas_reg):
        if et is None:
            continue
        etiquetas.append([reg["desde"], reg["hasta"], idx_nombre[reg["nombre"]]] + et)

    meta = {
        "version": 1,
        "proyeccion": {"tipo": "miller", "ancho": ANCHO, "alto": ALTO, "lat_norte": 83.0, "lat_sur": -57.0},
        "anio_min": AÑO_MIN,
        "anio_max": AÑO_MAX,
        "unidades": n,
        "unidades_bin": {"bytes": len(crudo), "formato": "rg8"},
        "politico_bin": {"bytes": len(crudo_pol), "partes": partes},
        "eventos": int(len(ev)),
        "fotos": [{"evento": int(k), "parte": f"foto_{j}"} for j, k in enumerate(años_foto)],
        "entidades": [
            {
                "n": p["nombre"],
                "c": colores[i],
                "a": p["desde"],
                "b": p["hasta"],
                "w": p["wikipedia"],
                "d": p["wikidata"],
                "s": p["seshat"],
                "m": p["miembro_de"],
            }
            for i, p in enumerate(polities)
        ],
        "etiquetas_formato": ["desde", "hasta", "entidad", "cx", "cy", "angulo", "largo", "a", "b", "c", "grosor"],
        "etiquetas": etiquetas,
        "fuente": "Cliopatria (Seshat Global History Databank), CC BY 4.0, procesado por tools/pipeline/p2_politico.py",
    }
    guardar_json(SALIDA / "politico.json", meta, compacto=True)
    print(t(), f"Listo: {n} unidades, {len(ev)} eventos, {len(fotos)} fotos, {len(etiquetas)} etiquetas")


if __name__ == "__main__":
    main()
