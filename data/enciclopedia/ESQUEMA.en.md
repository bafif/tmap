# TellMAP encyclopedia schema

[Español](ESQUEMA.md)

The encyclopedia lives in JSON files (UTF-8, 2-space indentation) inside `data/enciclopedia/paquetes/`. Each package
is a self-contained file (`egipto.json`, `mundo.json`…) and the program merges them on startup. If two packages carry
the same `id` in the same section, the first one in alphabetical order wins and a warning shows up in the console.

They can be edited by hand or with the app's editor (Settings → "Open the encyclopedia editor", or "Edit this entry"
on any entry), which saves in this same format: a package that is read and written back comes out identical.

All text is in **Spanish** (neutral Rioplatense, with accents), short and verifiable. Nothing made up: if a date or a
fact isn't certain, mark it `"aprox": true` and `"confianza": "baja"`, or leave it out. Translations live separately,
in another folder: see [Translations](#translations). Field names and fixed values are in Spanish too, and the
examples below keep the Spanish text they would have in a package.

## Conventions

- **Years:** integers. Negative = before Christ. **There is no year 0**: `-1` is 1 BCE and `1` is 1 CE (the same
  convention as Cliopatria).
- **Coordinates:** `lon` and `lat` in decimal degrees (WGS84). Mind the order: polygons use `[lon, lat]`.
- **Ids:** lowercase, no accents, with hyphens: `textos-de-las-piramides`, `herodoto`.
- **Wikipedia:** `{"es": "Título exacto del artículo en es.wikipedia", "en": "Exact title on en.wikipedia"}`. Only
  titles that exist; if there's no article in one language, that key is left out.
- **Reading links (`leer`):** only checked URLs (that answer 200), preferably full text and public domain or open
  access: Wikisource, Project Gutenberg, Perseus, Internet Archive, ETCSL, LacusCurtius, the Biblioteca Virtual Miguel
  de Cervantes, university sites. Never links to pirated copies. Each link's Wayback Machine copy doesn't go in the
  package: `tools/enciclopedia/enlaces.py` looks it up and it lives in `data/enciclopedia/archivo.json`.

## Package file

```json
{
  "paquete": "egipto",
  "descripcion": "Piloto: el antiguo Egipto, de la unificación a la conquista árabe",
  "regiones": [],
  "fuentes": [],
  "personas": [],
  "hechos": [],
  "lugares": [],
  "familias": []
}
```

### `regiones`

A region is an area of study. It's drawn with a rough polygon (10 to 40 vertices; up to 60 for regions built from the
borders of present-day countries) and it can sit inside another one. The polygon has to be a simple ring, with no
repeated vertices and no crossing edges: with the even-odd rule the app uses, a ring that crosses itself leaves pieces
of the region out. The validator checks it.

```json
{
  "id": "egipto",
  "nombre": "Egipto",
  "padre": null,
  "poligono": [[25.0, 31.6], [29.0, 31.0], [32.5, 31.4], [34.2, 31.3], [34.9, 29.5], [33.5, 27.0], [35.8, 23.0], [31.0, 22.0], [25.0, 22.0]],
  "resumen": "Dos a cuatro oraciones que presentan la región y por qué importa para la historia.",
  "eras": [
    {"desde": -3100, "hasta": -2686, "nombre": "Período Dinástico Temprano", "resumen": "Una o dos oraciones."}
  ],
  "demografia": [
    {"anio": -2500, "poblacion": 1600000, "min": 1000000, "max": 2000000, "fuente": "Autor (año), obra", "nota": "Opcional"}
  ],
  "religiones": [
    {"desde": -3100, "hasta": 395, "nombre": "Religión del antiguo Egipto", "familia": "politeismo-egipcio", "peso": "mayoritaria"}
  ],
  "culturas": [
    {"desde": -3100, "hasta": 641, "nombre": "Egipcia", "familia": "egipcia", "peso": "mayoritaria"}
  ],
  "idiomas": [
    {"desde": -3100, "hasta": 1600, "nombre": "Egipcio (luego copto)", "familia": "egipcio", "peso": "mayoritaria"}
  ]
}
```

- `resumen`: two to four sentences that introduce the region and say why it matters for history. Era summaries take
  one or two.
- `peso`: `"mayoritaria"` (majority), `"importante"` (significant) or `"minoritaria"` (minority). The map paints the
  majority one.
- In the religion, culture and language modes, the polygon marks the area of study. Inside it, the map paints in solid
  color the areas that belong to some Cliopatria entity in that year, and the rest (deserts, areas with no recorded
  state) with hatching in the same color: that way you see the real outline of each period, like the Nile valley in
  ancient Egypt, even though the polygon is approximate.
- `desde` and `hasta` in eras, religions, cultures and languages: `"hasta": null` means it lasts until today. In
  religions, cultures and languages `desde` is required: the app would read a `null` as "since forever" (3400 BCE) and
  paint the map that way. If something predates the record, use the earliest date there's evidence for (the conquest,
  the first mention, the arrival) and a `nota` explaining it; `validar.py` rejects the `null`.
- `familia` (required in religions, cultures and languages): the `id` of a family of the same layer in the
  [`familias`](#familias) section. It groups entries to color the map, gives the name shown in the legend and opens
  the family's entry. The entry's `nombre` can be more specific for that region ("Islam sunní (conquistadores y
  conversos)").
- `demografia`: only published estimates, with their actual source (for example McEvedy and Jones, *Atlas of World
  Population History*, 1978; Scheidel; Bagnall and Frier). With `min` and `max` when the literature gives a range. If
  there's no source, it doesn't go in. Figures given by ancient authors (Diodorus, Josephus…) carry
  `"tipo": "testimonio-antiguo"`: the app shows them separately and never uses them to estimate or to plot.
  Entries whose source ends in "vía Our World in Data" are written by `tools/enciclopedia/poblacion.py` (the sum of
  the countries that `tools/enciclopedia/poblacion_regiones.json` assigns to the region) and are replaced every time
  it runs: they aren't edited by hand. Curated estimates take precedence over them.
- Any entry in `eras`, `demografia`, `religiones`, `culturas` or `idiomas` can carry a `nota` with whatever
  clarification it needs (uncertainty, debates).
- `extendida` (optional): the extended entry, the full history in sections (level 3 of
  [the encyclopedia](../../docs/en/encyclopedia.md)). Every claim carries the `[n]` mark of its source in the text,
  and each section lists them in `citas`; every `n` is in `referencias` with its URL. If an AI drafted it, it carries
  `ia` (model and date) and isn't published without `revision` (date and a note from whoever reviewed it): the
  validator requires it.
- `origen` (optional): which draft the region came from, when it was generated and when it was reviewed. The editor
  sets it when it approves the draft.

```json
"extendida": {
  "secciones": [
    {"titulo": "Orígenes", "texto": "El Estado otomano nació de un beylicato turco de Anatolia [1].", "citas": [1]}
  ],
  "referencias": [
    {"n": 1, "titulo": "Wikipedia (es), «Imperio otomano», Introducción", "url": "https://es.wikipedia.org/wiki/Imperio_otomano"}
  ],
  "ia": {"modelo": "claude-opus-5-5", "fecha": "2026-11-07"},
  "revision": {"fecha": "2026-11-08", "nota": "Revisada contra el artículo; corregida la fecha de Bursa."}
}
```

### `familias`

The religions, cultures and languages the regions use, with their hierarchy. Today they all live in `familias.json`.

```json
{
  "capa": "religiones",
  "id": "islam-sunni",
  "nombre": "Islam sunita",
  "padre": "islam",
  "color": "#3f8a4e",
  "nota": "Opcional: una aclaración (agrupaciones discutibles, incertidumbre).",
  "wikipedia": {"es": "Sunismo", "en": "Sunni Islam"}
}
```

- `capa`: `religiones`, `culturas` or `idiomas`. The `id` is unique within each layer (`arabe` can be both a culture
  and a language).
- `padre`: the larger family, from the same layer, or `null`. That's how the chain Sunni Islam → Islam → Abrahamic
  religions is built. A family with children can also be used directly in a region (`cristianismo`).
- `color`: `#rrggbb`, fixed so the same religion always has the same color. Children get a color close to their
  parent's.
- `nota` (optional): a clarification (debatable groupings, uncertainty).
- The family's entry shows the Wikipedia summary, where it is in each year and with what weight, the regions' notes and
  their sources: there's no need to write a summary of its own.

### `fuentes`

The heart of the project: texts placed in space and time. A source has **two coordinates**: where and when it was
written (`escrita`) and what place and period it's about (`trata`). An Egyptian papyrus is written in, and is about,
the same place and time; Herodotus wrote in the 5th century BCE about an Egypt centuries older; a 20th-century
historian wrote in London about the New Kingdom.

```json
{
  "id": "textos-de-las-piramides",
  "titulo": "Textos de las Pirámides",
  "titulo_original": null,
  "autor": null,
  "autor_id": null,
  "tipo": "primaria",
  "genero": "religioso",
  "escrita": {"anio": -2350, "anio_hasta": -2180, "aprox": true, "lugar": "Saqqara", "lon": 31.216, "lat": 29.871},
  "trata": {"regiones": ["egipto"], "desde": -2400, "hasta": -2180},
  "idioma_original": "Egipcio antiguo",
  "soporte": "Inscripciones en muros de pirámides",
  "resumen": "Dos a cuatro oraciones: qué es, qué contiene.",
  "por_que_importa": "Una o dos oraciones: qué se aprende leyéndola.",
  "leer": [
    {"titulo": "Traducción inglesa de S. A. B. Mercer (1952)", "url": "https://...", "idioma": "en", "dominio_publico": false}
  ],
  "wikipedia": {"es": "Textos de las pirámides", "en": "Pyramid Texts"},
  "confianza": "alta"
}
```

- `resumen`: two to four sentences on what it is and what it contains. `por_que_importa`: one or two sentences on what
  you learn by reading it.
- `tipo`: `"primaria"` (primary: produced in the period and place it's about: documents, inscriptions, contemporary
  chronicles, literature of the time) or `"secundaria"` (secondary: a later study: ancient historians writing about
  earlier periods, modern historiography, archaeology).
- `genero`: `religioso`, `historia`, `cronica`, `literatura`, `poesia`, `filosofia`, `legal`, `administrativo`,
  `epistolar`, `inscripcion`, `geografia`, `ciencia`, `medicina`, `sabiduria`, `viajes`, `ensayo`, `arqueologia`,
  `economia`, `politica`, `manifiesto`, `discurso`, `tecnologia`, `periodismo`. Laws, court rulings, treaties,
  resolutions and constitutions go as `legal`; scientific papers, as `ciencia`.
- `escrita.anio_hasta`: optional, for texts composed over a period of time.
- `autor_id`: the `id` of a person if they're in some package; otherwise `null`, with just the name in `autor`.
- `confianza`: how certain the dating is (`alta`, `media`, `baja`: high, medium, low).

### `personas`

```json
{
  "id": "herodoto",
  "nombre": "Heródoto",
  "nacimiento": {"anio": -484, "aprox": true, "lugar": "Halicarnaso", "lon": 27.424, "lat": 37.038},
  "muerte": {"anio": -425, "aprox": true, "lugar": "Turios", "lon": 16.49, "lat": 39.71},
  "activo": {"lugar": "Atenas", "lon": 23.727, "lat": 37.984},
  "roles": ["historiador", "viajero"],
  "resumen": "Dos o tres oraciones.",
  "obras": ["historias-herodoto"],
  "wikipedia": {"es": "Heródoto", "en": "Herodotus"},
  "wikidata": "Q26825"
}
```

- `activo` is optional: where they worked, if it isn't their birthplace. It can carry `desde` and `hasta` (a reign or
  a known period of activity): `"activo": {"lugar": "Amarna", "lon": 30.896, "lat": 27.645, "desde": -1352, "hasta":
  -1336, "aprox": true}`. Without those years, the map shows them at `activo` while they're alive; with them, only
  during those years, and before that at their birthplace and afterwards where they died, if known (Pedro de Mendoza,
  in Guadix until 1536). For people without birth or death dates, those years also place their life.
  Without any year, the person doesn't show up on the map or in "people alive".
- For ancient people with uncertain dates, `aprox: true` and the best scholarly estimate.

### `hechos`

```json
{
  "id": "batalla-de-qadesh",
  "titulo": "Batalla de Qadesh",
  "anio": -1274,
  "anio_hasta": null,
  "aprox": true,
  "lugar": "Qadesh, sobre el Orontes",
  "lon": 36.51,
  "lat": 34.56,
  "tipo": "batalla",
  "resumen": "Dos o tres oraciones.",
  "regiones": ["egipto", "levante"],
  "fuentes": ["poema-de-pentaur"],
  "wikipedia": {"es": "Batalla de Qadesh", "en": "Battle of Kadesh"}
}
```

- `tipo`: `politico`, `batalla`, `fundacion`, `religioso`, `cultural`, `cientifico`, `economico`, `desastre`,
  `tratado`, `construccion`, `exploracion`, `revolucion`, `judicial` (sentences and court rulings). A whole war goes
  as `batalla` with `anio_hasta`.
- `fuentes`: ids of the sources that document it (they can be from another package).

### `lugares`

Cities, temples and sites that appear on the map while they exist.

```json
{
  "id": "menfis",
  "nombre": "Menfis",
  "lon": 31.255,
  "lat": 29.845,
  "fundacion": -3100,
  "abandono": 641,
  "aprox": true,
  "tipo": "ciudad",
  "importancia": 3,
  "resumen": "Una o dos oraciones.",
  "regiones": ["egipto"],
  "wikipedia": {"es": "Menfis (Egipto)", "en": "Memphis, Egypt"}
}
```

- `tipo`: `ciudad`, `capital`, `templo`, `puerto`, `sitio-arqueologico`, `biblioteca`, `universidad`,
  `laboratorio`, `institucion` (a congress, a court, the seat of a government or an agency), `sitio-historico` (a
  square, a concentration camp, a clandestine detention center, a battlefield).
- `fundacion`: the year from which it exists and is shown on the map. An ancient city or temple of unknown origin can
  have `null` (it is shown in every era). A library, a university, a laboratory, an institution or a historic site
  must have it (`validar.py` requires it). For a building or an institution, its opening (if unknown, the first event
  that makes it relevant, with `aprox` if the year is uncertain); for a site or a natural place that matters because
  of an event (an island, a beach, a spot on a road, the house where something was signed), the year of that event or
  the year it became known, so the map does not show it under its name too early.
- `abandono`: the year it stops being inhabited or relevant; `null` if it still is.
- `importancia`: 1 (local) to 3 (of the first rank). It decides from which zoom level it shows.

## Translations

Packages aren't translated: each one's translation lives in `traducciones/<idioma>/<paquete>.json` (only `en` for
now), with one entry per text. With the app in English, every translated text replaces the Spanish one when the
package loads; anything without a translation shows in Spanish. The app's editor always works on the Spanish.

```json
{
 "paquete": "egipto",
 "idioma": "en",
 "textos": {
  "regiones/egipto/eras.0.nombre": {"hash": "3f0c9a51e2", "texto": "Early Dynastic Period"},
  "familias/religiones:islam-sunni/nombre": {"hash": "9b7d20c4aa", "texto": "Sunni Islam"}
 }
}
```

- The key is section, id and field. The field is a path with dots and positions (`eras.0.nombre`, `escrita.lugar`,
  `roles.1`); in `familias` the id goes with its layer.
- `hash`: the beginning of the sha256 of the Spanish text that was translated. If the Spanish changes later, the app
  keeps showing the translation it had and the tool counts it as stale so it gets translated again. The same happens
  if an entry is inserted in the middle of a list (an era, for example): the ones after it change position.
- The texts people read are translated: in `regiones`, `nombre`, `resumen`, the `nombre`, `resumen` and `nota` of the
  eras, the `nota` of the demographics, the `nombre` and `nota` of religions, cultures and languages, and the `titulo`
  and `texto` of the extended entry's sections; in `familias`, `nombre` and `nota`; in `fuentes`, `titulo`, `autor`,
  `escrita.lugar`, `idioma_original`, `soporte`, `resumen`, `por_que_importa` and the `titulo` of each `leer` link;
  in `personas`, `nombre`, `roles`, the `lugar` of `nacimiento`, `muerte` and `activo`, and `resumen`; in `hechos`,
  `titulo`, `lugar` and `resumen`; in `lugares`, `nombre` and `resumen`. Proper names are translated only if they
  have a form of their own in the other language (Heródoto → Herodotus).
- Not translated: ids and the fields that hold ids (`familia`, `padre`, `regiones`, `obras`, `fuentes`, `autor_id`),
  fixed values (`peso`, `tipo`, `genero`, `confianza`, `capa`: the app translates them itself), years, coordinates,
  colors, `wikipedia` (it already has `en`), `wikidata`, the `url` of each `leer` link (its `titulo` is translated),
  the demographics' `fuente`, the extended entry's references, `titulo_original`, or anything the app doesn't show
  (the package's `descripcion`, `ia`, `revision`, `origen`).
- The layers are built with `tools/traduccion/enciclopedia.py`: `estado` counts what's translated, what's missing and
  what's stale, `extraer <carpeta>` pulls out what's pending in JSON batches for translation, and `aplicar
  <respuestas>` writes the translations in with their hash. They aren't edited by hand.

## Drafts

`paquetes/borradores/*.json` has the format of a package plus one more section, `borrador`: the origin (the
Cliopatria entity, its Wikidata item and how many times it was looked up), the date, the status ("sin revisar", not
reviewed), the sources and the Wikipedia article by section, suggestions for the reviewer and, if it was drafted with
AI, `ia` with the warnings from the automatic check, what was discarded and the reading sources it suggests. The app
doesn't load drafts: they're reviewed and approved in the editor, which moves their items into a package. They're
built by `tools/enciclopedia/borradores.py` and `tools/enciclopedia/redactar.py` (see
[the encyclopedia](../../docs/en/encyclopedia.md)).

`python3 tools/enciclopedia/validar.py --borradores` validates them together with the packages; in a draft, a missing
area of study or review is a warning, not an error.
