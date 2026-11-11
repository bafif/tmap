# Datos y licencias

[English](../en/data.md)

Todo lo que muestra TellMAP sale de datos abiertos. Esta página dice de dónde sale cada cosa, qué se le hace y bajo
qué licencia se puede reusar.

## Fuentes

| Dato | Fuente | Licencia | Dónde está |
|---|---|---|---|
| Fronteras políticas de 3400 a. C. a 2024 | [Cliopatria](https://github.com/Seshat-Global-History-Databank/cliopatria) v0.2.1, Seshat Global History Databank ([artículo](https://doi.org/10.1038/s41597-025-04516-9)) | CC BY 4.0 | Se baja con `tools/pipeline/p0_descargar.py` |
| Costas, lagos y ríos | [Natural Earth](https://www.naturalearthdata.com) 1:10 m | Dominio público | `raw_data/ne_10m_*.zip` |
| Países actuales (para armar las regiones que completan el mundo) | Natural Earth 1:10 m, *Admin 0 – countries* | Dominio público | `raw_data/ne_10m_admin_0_countries_lakes.zip` |
| Población por país, de 10 000 a. C. a 2023 | [Our World in Data](https://ourworldindata.org/population-sources), que combina HYDE 3.3 (PBL, hasta 1799), Gapminder v7 (1800-1949) y la ONU, *World Population Prospects 2024* (desde 1950) | CC BY 4.0 | `tools/enciclopedia/datos/poblacion-owid.json`, se baja con `tools/enciclopedia/poblacion.py --descargar` |
| Series por país, de 1800 a 2024: población, esperanza de vida, hijos por mujer, mortalidad antes de los 5 años, edad mediana, población urbana, PIB per cápita, pobreza extrema, alfabetización, años de escolaridad y nacidos en otro país | [Our World in Data](https://ourworldindata.org), que combina la ONU (*World Population Prospects 2024*, *World Urbanization Prospects*, stock de migrantes 2024), el Banco Mundial (PIP), el Maddison Project Database 2023, HYDE, Gapminder, Riley y Zijdeman, la UNESCO y Barro y Lee; cada indicador cita la suya | CC BY 4.0 | `data/demografia/paises.json`, se baja con `tools/demografia/series.py` |
| País actual de cada unidad del mapa (para unir el mapa con las series por país) | Natural Earth 1:10 m, *Admin 0 – countries* | Dominio público | `data/demografia/unidades_pais.bin` y `paises_mapa.json`, los arma `tools/pipeline/p4_paises.py` |
| Elevación | GEBCO 2008, versión en grises de la NASA (Blue Marble) | Dominio público (NASA) | `raw_data/gebco_08_rev_elev_*.tif` |
| Color del terreno | NASA Blue Marble Next Generation, julio de 2004 | Dominio público (NASA) | `raw_data/world.200407.3x5400x2700.jpg` |
| Títulos en español | [Wikidata](https://www.wikidata.org) | CC0 | `data/mapa/wikidata_es.json` |
| Resúmenes de artículos | Wikipedia, API REST, en vivo y con caché local | CC BY-SA 4.0 | `user://wiki/` en la computadora de cada uno |
| Lugares antiguos (unos 27 000, con nombre, años en que están atestiguados y tipo) | [Pleiades](https://pleiades.stoa.org), ISAW (Universidad de Nueva York) y Ancient World Mapping Center, a partir del Barrington Atlas | CC BY 3.0 | `data/pleiades/lugares.json`, se baja con `tools/pleiades/pleiades.py`; la descripción y los nombres antiguos de cada ficha, en vivo, a `user://wiki/` |
| Enciclopedia propia, en español y su traducción al inglés | Paquetes de TellMAP | CC BY-SA 4.0 | `data/enciclopedia/paquetes/` y `data/enciclopedia/traducciones/en/` |
| Tipografías | Cinzel (Natanael Gama) y EB Garamond (Georg Duffner, Octavio Pardo) | SIL Open Font License 1.1 | `assets/fuentes/` |

Las fuentes primarias y los estudios que cita la enciclopedia tienen sus propios derechos: TellMAP guarda su ficha
(título, autor, fechas, resumen propio) y enlaza al texto, priorizando ediciones de dominio público o de acceso
abierto. No copia los textos.

## Cómo se atribuye

- En la app: Ajustes → Datos y créditos, y cada resumen de Wikipedia lleva el enlace al artículo con su licencia.
- Cliopatria pide citar su artículo en *Scientific Data* (2025),
  [doi:10.1038/s41597-025-04516-9](https://doi.org/10.1038/s41597-025-04516-9). Los datos de `data/mapa/politico.*` y `unidades.bin` son una
  adaptación (rasterizada y reorganizada por año) de Cliopatria, bajo la misma CC BY 4.0.
- La población por país se cita como pide Our World in Data: «HYDE (2023); Gapminder (2022); UN WPP (2024) – with
  major processing by Our World in Data». Cada estimación de una región dice en su fuente cuál de las tres usa y que
  llegó «vía Our World in Data».

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
4. **Nombres en español** (`data/mapa/nombres_es.json`): revisados para el mapa; se editan a mano. Con la app en
   inglés, el mapa usa los nombres de Cliopatria tal cual vienen, y los países actuales, los de Natural Earth.
5. **Correcciones** (`data/mapa/correcciones.json`): enlaces a Wikipedia y Wikidata que Cliopatria trae equivocados,
   revisados a mano, con el porqué de cada uno; la app los aplica al cargar. Al cargar también se unifican los 33
   estados que Cliopatria trae dos veces, «X» y «(X)», con el mismo Wikidata: la versión entre paréntesis es el
   conjunto y la otra dice ser parte de ella, así que se muestran como una sola entidad.

## Limitaciones que conviene conocer

- Cliopatria es una versión de las fronteras: hay huecos (pueblos sin estado, regiones poco estudiadas) y fronteras
  discutidas. La app lo dice cuando no hay entidad registrada.
- Las unidades miden entre ~50 y ~300 km según la zona: alcanza para ciudades-estado grandes, no para las más chicas.
- Las capas de religión, cultura e idioma solo existen donde hay regiones cargadas en la enciclopedia, y se pintan por
  región, no por unidad. El resto se ve rayado.
- Las cifras de población antiguas son estimaciones académicas con mucha incertidumbre; los testimonios de autores
  antiguos se muestran aparte y nunca se usan para estimar.
- Las series del bloque «País actual» de la pestaña «Datos» son también de países enteros con las fronteras de hoy
  (en 1914, el punto de Córdoba muestra la Argentina actual). Antes de 1950 hay un valor por década; la app muestra
  el último publicado hasta el año elegido, si no tiene más de 15 años. Cada unidad del mapa se asigna al país que
  cubre la mayor parte de su tierra: en las fronteras, una unidad puede caer del lado vecino.
- Las series de población por país usan las fronteras actuales y se suman a la región que tiene la mayor parte de cada
  país: la nota de cada serie dice qué países suma. Antes del año 1 son modelos de HYDE, no recuentos. Lo que cubren y
  lo que no está en [Cobertura de la enciclopedia](cobertura.md).
