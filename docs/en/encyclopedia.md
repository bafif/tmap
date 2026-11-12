# The encyclopedia

[Español](../es/enciclopedia.md)

TellMAP's encyclopedia isn't written in one go: it's filled in by stages, starting where it gets used most, and every
piece of data says where it came from.

## What's there today

- **Borders and entities** for the whole world (Cliopatria): each entity comes with its Wikipedia article and its
  Wikidata id.
- **Live Wikipedia summaries**, in the app's language (or the one chosen in Settings) and in the other one if there's
  no article, cached for 30 days.
- **Packages** in `data/enciclopedia/paquetes/`, plus `familias.json` with the families of religions, cultures and
  languages. Their regions cover 99.6% of the land, and each one has an estimated population from 10,000 BC or is
  counted within another. How many entries there are and what's missing is in
  [Encyclopedia coverage](coverage.md), which is generated automatically:
  - `egipto`, the pilot: ancient Egypt, with its eras from unification to modern times.
  - `mundo`, a sample of eleven regions (Mesopotamia, the Levant, Anatolia, Greece, Italy, Persia, China, India,
    Mesoamerica, the Andes and the Río de la Plata).
  - `edad-media`, medieval Europe from the sack of Rome to 1500, with an emphasis on the history of philosophy, and its
    regions, from the Iberian Peninsula to the Rus', with eras, religions, cultures and languages since Antiquity. The
    demography follows Russell (1972) and Urlanis (1941).
  - `tierra-santa`, from Antiquity to today, with the regions of the Levant, Arabia, the Maghreb, Cyprus, Armenia and
    Cilicia: the scriptures, the early Islamic expansion, the Crusades from every side, the thought of Jews,
    Christians and Muslims, and the modern documents. The demography follows DellaPergola (2001) and the Mandate
    censuses.
  - `regiones-del-mundo`, the 46 regions that complete the map (from Siberia and Japan to Africa, the Americas and
    Oceania), built from the borders of present-day countries in Natural Earth: summary, eras and population, still
    without religions, cultures or languages.
  - The contemporary era, in seven thematic packages: `pensamiento-economico`, `ideas-politicas`,
    `argentina-contemporanea` (from 1880 to today), `ciencia-y-tecnologia`, `cultura-libre-y-hackers`,
    `guerras-y-orden-mundial` and `letras-y-pensamiento-del-siglo-xx`.
  - Argentina up to 1912, in seven packages: `pueblos-originarios-del-cono-sur`, `rio-de-la-plata-colonial`,
    `virreinato-e-independencia`, `guerras-civiles-y-organizacion-nacional`, `rosas-y-la-confederacion`,
    `argentina-1862-1912` and `historiografia-argentina`.
  - The Celts, in nine packages: `celtas-origenes-y-prehistoria`, `galos-y-galia`, `celtas-del-danubio-y-galacia`,
    `celtas-de-hispania`, `celtas-de-britania-e-irlanda`, `religion-celta`, `celtas-en-las-fuentes-antiguas`,
    `celtas-legado-e-historiografia` and `mundo-celta`, with seven subregions.

  Since `edad-media`, every package is checked against Wikipedia and Wikidata (titles, ids, coordinates and
  lifespans), and its reading links responded when they were checked.
- **Country series since 1800** (population, life expectancy, fertility, economy, education) in the "Data" tab, for
  the present-day country of each point: `data/demografia/`, from `tools/demografia/series.py`.
- **Population for every region**: `tools/enciclopedia/poblacion.py` adds up, for each region, the Our World in Data
  country series (HYDE 3.3, Gapminder and the UN), according to the assignment in
  `tools/enciclopedia/poblacion_regiones.json`. Curated estimates from specialists take precedence: nothing is added
  for the years they cover. `tools/enciclopedia/cobertura.py` regenerates the coverage report and `validar.py` warns
  if it's out of date.
- The format is in [ESQUEMA.en.md](../../data/enciclopedia/ESQUEMA.en.md) and is validated with
  `python3 tools/enciclopedia/validar.py`. For writing many entries at once there's a [compact
  format](../../tools/enciclopedia/compacto/FORMATO.en.md) in plain text that `tools/enciclopedia/compacto/construir.py`
  turns into packages verified against Wikipedia and Wikidata.
- **The encyclopedia in English**: every package has its translation in `data/enciclopedia/traducciones/en/`, a
  separate layer built with `tools/traduccion/enciclopedia.py`
  ([the schema](../../data/enciclopedia/ESQUEMA.en.md#translations)).
  With the app in English those texts are the ones you read; anything not translated yet shows in Spanish.
- **An editor inside the app** to load and fix all of that without touching JSON (see [below](#the-editor)).

## What about Grokipedia?

TellMAP doesn't use Grokipedia: as of November 2026 it has no official API (there are only unofficial clients that
read the site) and a good part of its content is derived from Wikipedia. It uses Wikipedia (public, stable API,
CC BY-SA), Wikidata (structured data, CC0) and, for the long entries, AI that writes *from cited sources*.

## Four entry levels

| Level | What it is | Status |
|---|---|---|
| 0 | Cliopatria data: name, years and territory | The whole world |
| 1 | Live Wikipedia summary | Everything that has an article |
| 2 | Curated entry: eras, primary and secondary sources, people, events, population, religion, culture and language | The regions and topics in the packages |
| 3 | Extended "encyclopedia-style" entry: full history by sections, written with AI from cited sources and reviewed | The tools are ready; no entries published yet |

## How it gets filled in

1. **Usage says what's missing.** The app logs in `user://pendientes.json` whatever gets opened and has no curated
   entry: the entity, its Wikidata, the place, the years looked up and how many times. It never leaves the computer.
   In Settings → Encyclopedia you can see the most looked-up ones and copy the queue. (On Linux, `user://` is
   `~/.local/share/godot/app_userdata/TellMAP/` in the installed version and `~/.local/share/TellMAP-codigo/` from
   source; `borradores.py` reads the installed one by default.)
2. **Automatic draft.** `python3 tools/enciclopedia/borradores.py` takes the most looked-up entries (`-n 3` by
   default; `--cola` for a copied queue, `--wikidata Q12560` for a specific entity) and gathers:
   - from Wikidata, the capital with its coordinates, the key people (those who held its offices and the best known of
     its time) with dates and places of birth and death, and the dated events it took part in;
   - from Wikipedia, the summary and the full article by sections, in Spanish or, if there's none, in English;
   - from Cliopatria, the entity's years.

   It leaves this in `data/enciclopedia/paquetes/borradores/`, in the schema format and marked "unreviewed".
3. **AI writing, with mandatory citations.** `python3 tools/enciclopedia/redactar.py <borrador>` passes an Anthropic
   model the draft's sources, numbered (each section of the article and the Wikidata record), and asks it for the
   history by sections, citing in each paragraph which source it comes from. Then, without trusting the model, it
   discards paragraphs with no valid citation, flags for review the years and figures that don't appear in the
   sources they cite, and checks one by one the reading links it suggests. It needs Anthropic's SDK
   (`pip install anthropic`) and an API credential; each entry costs on the order of USD 0.15 to 0.40 with the default
   model.
4. **Human review.** In the app, Settings → "Open the encyclopedia editor" → Drafts: the study area is computed from
   the Cliopatria territory, each item is opened and corrected, the extended entry is read along with the
   verification warnings and, when everything is right, you tick "I checked every fact and every section against its
   sources" and approve it. Only then do the items move into a package, with the date and the review note. An
   AI-written entry without review doesn't pass the validator.
5. **Little by little, by hand.** It's run in small batches, when needed, never unattended: that keeps the cost under
   control, and the quality too.

## The editor

From Settings → "Open the encyclopedia editor", or with "Edit this entry" on any source, person, event, place or
region entry:

- **Forms** for each section, with the schema fields: years are written "-1274" or "1274 BC", id lists separated by
  commas, and reading links and eras as rows you add and remove.
- **Coordinates with one click**: "Pick on the map" and the next click on the map sets them; "Show" takes the map to
  them.
- **Validation on save**: years with no year 0, coordinates in range, ids and references that exist, closed fields.
  Errors block saving; warnings (a source with no place of writing, for example) are only shown.
- **The same format**: it saves into the JSON of each item's package, or into the one you pick for a new item,
  without changing anything else in the file. On save, the map and the entries update on their own.

From the source code (with Godot) it writes to the project files. In an exported build, where the packages are bundled
inside the executable, it saves copies in the user folder (`user://enciclopedia/`; on Windows,
`%APPDATA%\Godot\app_userdata\TellMAP\enciclopedia\`) that override the bundled ones: to add those changes to the
project, send those files. Regions can be edited in their main data, their area, their eras, their religions,
cultures and languages (the family is picked from those in `familias.json`) and their population. The Our World in
Data population figures are neither shown nor touched: `tools/enciclopedia/poblacion.py` writes them, and it has to be
run again when the curated estimates change (the editor warns about it).

## Editorial rules

- **Nothing made up.** If a date is uncertain it's marked `aprox` and the `confianza` is lowered; if a piece of data
  has no source, it doesn't get loaded.
- **Primary sources first**, in public-domain or open-access editions when they exist.
- **Two coordinates per text**: where and when it was written, and what place and period it's about.
- **Estimates with their author and their range.** Figures from ancient authors are testimonies, not estimates.
- **More than one tradition.** Each region's eras use its own periodization; the European periodization appears only
  as a global reference, and it's stated that it's approximate.
- **Clear licenses.** Whatever is derived from Wikipedia inherits CC BY-SA 4.0 and is attributed.
