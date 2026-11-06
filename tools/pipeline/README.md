# Pipeline de datos

Genera `data/mapa/` a partir de los datos originales. Los resultados ya están en el repo: solo hace falta correrlo para
cambiar la resolución, la proyección o la versión de Cliopatria.

## Requisitos

- Python 3.11 o más nuevo, con `numpy` y `Pillow` (con soporte WebP). Nada más: los shapefiles y el GeoJSON se leen
  con código propio.
- `curl` (para Wikidata).
- Unos 3 GB de memoria libre. El paso 2 tarda ~25 minutos en una CPU de escritorio.

## Pasos

```bash
cd tools/pipeline
python3 p0_descargar.py      # baja Cliopatria a cache/ (46 MB comprimido)
python3 p1_base.py           # tierra, relieve, costas, ríos y color   → terreno.webp, relieve.png
python3 p2_politico.py       # unidades, fronteras e historia política → unidades.bin, politico.json, politico.bin
python3 p3_wikidata.py       # títulos de Wikipedia en español        → wikidata_es.json
python3 vista_previa.py -1350 /tmp/egipto.png 3600 1100 5600 2300   # revisar un año sin abrir Godot
```

El paso 2 cambia los números de las unidades cada vez que se corre: después hay que revisar que
`data/mapa/nombres_es.json` siga cubriendo todas las entidades (las claves son los nombres de Cliopatria, así que no
dependen de las unidades).

## Formatos

- `unidades.bin`: zlib de una imagen cruda RG8 de 8192 × 4016; unidad = R + 256 × G (0 = agua).
- `politico.json`: proyección, lista de entidades (`n` nombre, `c` color, `a`–`b` años, `w` Wikipedia, `d` Wikidata,
  `s` Seshat, `m` miembro de), etiquetas (`desde, hasta, entidad, cx, cy, ángulo, largo, a, b, c, grosor`) y el índice
  de `politico.bin`.
- `politico.bin`: zlib de arrays little-endian (centro y tamaño de cada unidad, eventos año/unidad/antes/después y
  fotos completas de dueños).
- `relieve.png`: R sombreado (128 = llano), G distancia con signo a la costa (128 = costa), B ríos, A distancia mar
  adentro.

Godot no importa nada de `data/mapa/` (tiene `.gdignore`): la app lo lee directo al arrancar.
