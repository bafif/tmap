# Data and licenses

[Español](../es/datos.md)

Everything TellMAP shows comes from open data. This page says where each piece comes from, what's done to it and under
which license it can be reused.

## Sources

| Data | Source | License | Where it is |
|---|---|---|---|
| Political borders from 3400 BCE to 2024 | [Cliopatria](https://github.com/Seshat-Global-History-Databank/cliopatria) v0.2.1, Seshat Global History Databank ([paper](https://doi.org/10.1038/s41597-025-04516-9)) | CC BY 4.0 | Downloaded with `tools/pipeline/p0_descargar.py` |
| Coastlines, lakes and rivers | [Natural Earth](https://www.naturalearthdata.com) 1:10 m | Public domain | `raw_data/ne_10m_*.zip` |
| Present-day countries (to build the regions that fill out the world) | Natural Earth 1:10 m, *Admin 0 – countries* | Public domain | `raw_data/ne_10m_admin_0_countries_lakes.zip` |
| Population by country, from 10,000 BCE to 2023 | [Our World in Data](https://ourworldindata.org/population-sources), which combines HYDE 3.3 (PBL, up to 1799), Gapminder v7 (1800–1949) and the UN's *World Population Prospects 2024* (from 1950) | CC BY 4.0 | `tools/enciclopedia/datos/poblacion-owid.json`, downloaded with `tools/enciclopedia/poblacion.py --descargar` |
| Series by country, from 1800 to 2024: population, life expectancy, children per woman, under-5 mortality, median age, urban population, GDP per capita, extreme poverty, literacy, years of schooling and foreign-born population | [Our World in Data](https://ourworldindata.org), which combines the UN (*World Population Prospects 2024*, *World Urbanization Prospects*, 2024 migrant stock), the World Bank (PIP), the Maddison Project Database 2023, HYDE, Gapminder, Riley and Zijdeman, UNESCO and Barro and Lee; each indicator cites its own | CC BY 4.0 | `data/demografia/paises.json`, downloaded with `tools/demografia/series.py` |
| Present-day country of each map unit (to join the map with the country series) | Natural Earth 1:10 m, *Admin 0 – countries* | Public domain | `data/demografia/unidades_pais.bin` and `paises_mapa.json`, built by `tools/pipeline/p4_paises.py` |
| Elevation | GEBCO 2008, NASA's grayscale version (Blue Marble) | Public domain (NASA) | `raw_data/gebco_08_rev_elev_*.tif` |
| Terrain color | NASA Blue Marble Next Generation, July 2004 | Public domain (NASA) | `raw_data/world.200407.3x5400x2700.jpg` |
| Spanish titles | [Wikidata](https://www.wikidata.org) | CC0 | `data/mapa/wikidata_es.json` |
| Article summaries | Wikipedia, REST API, live with a local cache | CC BY-SA 4.0 | `user://wiki/` on each user's computer |
| Ancient places (some 27,000, with name, years in which they are attested and type) | [Pleiades](https://pleiades.stoa.org), ISAW (New York University) and the Ancient World Mapping Center, built from the Barrington Atlas | CC BY 3.0 | `data/pleiades/lugares.json`, downloaded with `tools/pleiades/pleiades.py`; each entry's description and ancient names, live, cached in `user://wiki/` |
| Which encyclopedia place is which Pleiades place | [Wikidata](https://www.wikidata.org), property P1584 (Pleiades ID), from each place's Wikipedia article | CC0 | `data/pleiades/enciclopedia.json`, built by `tools/pleiades/enlazar.py` |
| TellMAP's own encyclopedia, in Spanish and its English translation | TellMAP packages | CC BY-SA 4.0 | `data/enciclopedia/paquetes/` and `data/enciclopedia/traducciones/en/` |
| Copies of the reading links | Internet Archive's [Wayback Machine](https://web.archive.org): only the address of each copy | Those of each text | `data/enciclopedia/archivo.json`, built by `tools/enciclopedia/enlaces.py` |
| Typefaces | Cinzel (Natanael Gama) and EB Garamond (Georg Duffner, Octavio Pardo) | SIL Open Font License 1.1 | `assets/fuentes/` |

The primary sources and studies the encyclopedia cites have their own rights: TellMAP stores their record (title,
author, dates, its own summary) and links to the text, favoring public-domain or open-access editions. It doesn't copy
the texts.

## How attribution works

- In the app: Settings → Data and credits, and every Wikipedia summary carries a link to the article with its license.
- Cliopatria asks that you cite its paper in *Scientific Data* (2025),
  [doi:10.1038/s41597-025-04516-9](https://doi.org/10.1038/s41597-025-04516-9). The data in `data/mapa/politico.*` and
  `unidades.bin` are an adaptation (rasterized and reorganized by year) of Cliopatria, under the same CC BY 4.0.
- Population by country is cited the way Our World in Data asks: “HYDE (2023); Gapminder (2022); UN WPP (2024) – with
  major processing by Our World in Data”. Each estimate for a region states in its source which of the three it uses
  and that it came “via Our World in Data”.

## What the pipeline does

See [tools/pipeline/README.en.md](../../tools/pipeline/README.en.md) to run it. In short:

1. **Physical base** (`p1_base.py`): rasterizes Natural Earth's land and lakes in the Miller projection
   (8192 × 4016 px), reprojects elevation and color, and computes relief shading, distance to the coast (to smooth
   coastlines and draw the water) and rivers.
2. **Units and borders** (`p2_politico.py`): rasterizes Cliopatria's ~13,400 records, computes a “signature” per
   pixel with all the records that cover it, seeds smaller cells where there are more borders, cuts them along the
   signatures and merges the slivers. Then it computes the owner of each unit at each point in time, the change
   events, the snapshots for long jumps, the label geometry and the colors (neighbors get different colors, and very
   well-known entities, like Rome or Egypt, get fixed ones).
3. **Wikidata** (`p3_wikidata.py`): Spanish Wikipedia titles for the entities.
4. **Spanish names** (`data/mapa/nombres_es.json`): reviewed for the map; edited by hand. With the app in English,
   the map uses Cliopatria's names as they come, and present-day countries use Natural Earth's.
5. **Corrections** (`data/mapa/correcciones.json`): Wikipedia and Wikidata links that Cliopatria gets wrong,
   reviewed by hand, with the reason for each one; the app applies them on load. Also on load, the 33 states that
   Cliopatria lists twice, “X” and “(X)”, with the same Wikidata, are unified: the parenthesized version is the whole
   and the other one claims to be part of it, so they're shown as a single entity.

## Limitations worth knowing

- Cliopatria is one version of the borders: there are gaps (stateless peoples, little-studied regions) and disputed
  borders. The app says so when there's no recorded entity.
- Units measure between ~50 and ~300 km depending on the area: enough for large city-states, not for the smallest ones.
- The religion, culture and language layers only exist where there are regions loaded in the encyclopedia, and they're
  painted by region, not by unit. The rest shows up hatched.
- Ancient population figures are scholarly estimates with a lot of uncertainty; testimonies from ancient authors are
  shown separately and never used for estimates.
- The series in the “Current country” block of the “Data” tab are also for whole countries with today's borders
  (in 1914, the Córdoba point shows present-day Argentina). Before 1950 there's one value per decade; the app shows
  the latest one published up to the selected year, as long as it's no more than 15 years old. Each map unit is
  assigned to the country that covers most of its land: along borders, a unit may fall on the neighboring side.
- The population-by-country series use present-day borders and are added to the region that holds most of each
  country: each series' note says which countries it adds up. Before year 1 they're HYDE models, not counts. What they
  cover and what they don't is in [Encyclopedia coverage](coverage.md).
