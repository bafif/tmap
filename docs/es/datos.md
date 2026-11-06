# Datos y licencias

Todo lo que muestra TellMAP sale de datos abiertos. Esta página dice de dónde sale cada cosa, qué se le hace y bajo
qué licencia se puede reusar.

## Fuentes

| Dato | Fuente | Licencia | Dónde está |
|---|---|---|---|
| Fronteras políticas de 3400 a. C. a 2024 | [Cliopatria](https://github.com/Seshat-Global-History-Databank/cliopatria) v0.2.1, Seshat Global History Databank ([artículo](https://doi.org/10.1038/s41597-025-04516-9)) | CC BY 4.0 | Se baja con `tools/pipeline/p0_descargar.py` |
| Costas, lagos y ríos | [Natural Earth](https://www.naturalearthdata.com) 1:10 m | Dominio público | `raw_data/ne_10m_*.zip` |
| Elevación | GEBCO 2008, versión en grises de la NASA (Blue Marble) | Dominio público (NASA) | `raw_data/gebco_08_rev_elev_*.tif` |
| Color del terreno | NASA Blue Marble Next Generation, julio de 2004 | Dominio público (NASA) | `raw_data/world.200407.3x5400x2700.jpg` |
| Títulos en español | [Wikidata](https://www.wikidata.org) | CC0 | `data/mapa/wikidata_es.json` |
| Resúmenes de artículos | Wikipedia, API REST, en vivo y con caché local | CC BY-SA 4.0 | `user://wiki/` en la computadora de cada uno |
| Enciclopedia propia | Paquetes de TellMAP | CC BY-SA 4.0 | `data/enciclopedia/paquetes/` |
| Tipografías | Cinzel (Natanael Gama) y EB Garamond (Georg Duffner, Octavio Pardo) | SIL Open Font License 1.1 | `assets/fuentes/` |

Las fuentes primarias y los estudios que cita la enciclopedia tienen sus propios derechos: TellMAP guarda su ficha
(título, autor, fechas, resumen propio) y enlaza al texto, priorizando ediciones de dominio público o de acceso
abierto. No copia los textos.

## Cómo se atribuye

- En la app: Ajustes → Datos y créditos, y cada resumen de Wikipedia lleva el enlace al artículo con su licencia.
- Cliopatria pide citar su artículo en *Scientific Data* (2025),
  [doi:10.1038/s41597-025-04516-9](https://doi.org/10.1038/s41597-025-04516-9). Los datos de `data/mapa/politico.*` y `unidades.bin` son una
  adaptación (rasterizada y reorganizada por año) de Cliopatria, bajo la misma CC BY 4.0.

## Qué hace el pipeline

Ver [tools/pipeline/README.md](../../tools/pipeline/README.md) para correrlo. En resumen:

1. **Base física** (`p1_base.py`): rasteriza la tierra y los lagos de Natural Earth en la proyección de Miller
   (8192 × 4016 px), reproyecta la elevación y el color, calcula el sombreado del relieve, la distancia a la costa
   (para suavizar costas y dibujar el agua) y los ríos.
2. **Unidades y fronteras** (`p2_politico.py`): rasteriza los ~13 400 registros de Cliopatria, calcula una «firma» por
   píxel con todos los registros que lo cubren, siembra celdas más chicas donde hay más fronteras, las corta por las
   firmas y funde las astillas. Después calcula el dueño de cada unidad en cada momento, los eventos de cambio, las
   fotos para saltos largos, la geometría de los nombres y los colores (vecinos con colores distintos y colores fijos
   para entidades muy conocidas, como Roma o Egipto).
3. **Wikidata** (`p3_wikidata.py`): títulos de Wikipedia en español para las entidades.
4. **Nombres en español** (`data/mapa/nombres_es.json`): revisados para el mapa; se editan a mano.

## Limitaciones que conviene conocer

- Cliopatria es una versión de las fronteras: hay huecos (pueblos sin estado, regiones poco estudiadas) y fronteras
  discutidas. La app lo dice cuando no hay entidad registrada.
- Las unidades miden entre ~50 y ~300 km según la zona: alcanza para ciudades-estado grandes, no para las más chicas.
- Las capas de religión, cultura e idioma solo existen donde hay regiones cargadas en la enciclopedia, y se pintan por
  región, no por unidad. El resto se ve rayado.
- Las cifras de población antiguas son estimaciones académicas con mucha incertidumbre; los testimonios de autores
  antiguos se muestran aparte y nunca se usan para estimar.
