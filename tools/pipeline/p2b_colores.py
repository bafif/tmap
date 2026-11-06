"""Paso 2b: recalcula solo los colores de las entidades (sin rehacer el paso 2, que tarda).

Lee data/mapa/politico.*, arma la vecindad entre entidades muestreando cada 20 años y reescribe el campo `c`.
"""

from __future__ import annotations

import numpy as np

from comun import SALIDA, guardar_json
from p2_politico import AÑO_MAX, AÑO_MIN, asignar_colores
from vista_previa import cargar


def main():
    meta, parte, unidades = cargar()
    pares = []
    for a, b in ((unidades[:, :-1], unidades[:, 1:]), (unidades[:-1], unidades[1:])):
        dif = (a != b) & (a > 0) & (b > 0)
        pares.append(np.stack([a[dif], b[dif]], 1))
    pares = np.unique(np.sort(np.concatenate(pares), axis=1), axis=0)
    ev_anio, ev_u, ev_d = parte("evento_anio"), parte("evento_unidad"), parte("evento_despues")
    tam = parte("unidad_tam")
    n_ent = len(meta["entidades"])
    estado = np.full(meta["unidades"] + 1, -1, dtype=np.int32)
    vecinos = {}
    area_max = np.zeros(n_ent)
    k = 0
    for anio in range(AÑO_MIN, AÑO_MAX + 1, 20):
        fin = int(np.searchsorted(ev_anio, anio, side="right"))
        estado[ev_u[k:fin]] = ev_d[k:fin]
        k = fin
        a, b = estado[pares[:, 0]], estado[pares[:, 1]]
        ok = (a >= 0) & (b >= 0) & (a != b)
        for x, y in np.unique(np.stack([a[ok], b[ok]], 1), axis=0).tolist():
            vecinos.setdefault(x, set()).add(y)
            vecinos.setdefault(y, set()).add(x)
        sel = estado >= 0
        area_max = np.maximum(area_max, np.bincount(estado[sel], weights=tam[sel], minlength=n_ent))
    entidades = [{"nombre": e["n"], "area_max": float(m)} for e, m in zip(meta["entidades"], area_max)]
    colores = asignar_colores(entidades, vecinos)
    for e, c in zip(meta["entidades"], colores):
        e["c"] = c
    guardar_json(SALIDA / "politico.json", meta, compacto=True)
    print("Colores reasignados:", len(colores))


if __name__ == "__main__":
    main()
