# Data pipeline

[Español](README.md)

Builds `data/mapa/` from the source data. The output is already in the repo: you only need to run it to change the
resolution, the projection or the Cliopatria version.

## Requirements

- Python 3.11 or newer, with `numpy` and `Pillow` (with WebP support). Nothing else: the shapefiles and the GeoJSON
  are read with custom code.
- `curl` (for Wikidata).
- About 3 GB of free memory. Step 2 takes ~25 minutes on a desktop CPU.

## Steps

```bash
cd tools/pipeline
python3 p0_descargar.py      # downloads Cliopatria to cache/ (46 MB compressed)
python3 p1_base.py           # land, relief, coastlines, rivers and color → terreno.webp, relieve.png
python3 p2_politico.py       # units, borders and political history       → unidades.bin, politico.json, politico.bin
python3 p3_wikidata.py       # Spanish Wikipedia titles                   → wikidata_es.json
python3 p4_paises.py         # present-day country of each unit           → ../../data/demografia/unidades_pais.bin
python3 vista_previa.py -1350 /tmp/egipto.png 3600 1100 5600 2300   # check a year without opening Godot
```

Step 2 renumbers the units every time it runs: afterwards you have to check that `data/mapa/nombres_es.json` still
covers every entity (the keys are the Cliopatria names, so they don't depend on the units).

You also have to rerun step 4, which assigns each unit to its present-day country for the per-country series
(`tools/demografia/series.py`).

## Formats

- `unidades.bin`: zlib-compressed raw RG8 image, 8192 × 4016; unit = R + 256 × G (0 = water).
- `politico.json`: projection, list of entities (`n` name, `c` color, `a`–`b` years, `w` Wikipedia, `d` Wikidata,
  `s` Seshat, `m` member of), labels (`desde, hasta, entidad, cx, cy, ángulo, largo, a, b, c, grosor`) and the index
  of `politico.bin`.
- `politico.bin`: zlib-compressed little-endian arrays (center and size of each unit, year/unit/before/after events
  and full ownership snapshots).
- `relieve.png`: R shading (128 = flat), G signed distance to the coast (128 = coastline, 4 values per pixel,
  positive on water), B rivers, A distance out to sea. The G channel comes from the Natural Earth polygons, with
  sub-pixel precision and a minimum width of 1.5 px for narrow land (`costa.py`, which `p1_base.py` uses);
  `python3 costa.py` rewrites it alone, without redoing the rest (one minute).

Godot doesn't import anything from `data/mapa/` (it has a `.gdignore`): the app reads it directly at startup.
