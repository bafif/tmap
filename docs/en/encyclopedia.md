# The encyclopedia

[Español](../es/enciclopedia.md)

TellMAP's encyclopedia isn't written in one go: it's filled in by stages, starting where it gets used most, and every
piece of data says where it came from.

## What's there today

- **Borders and entities** for the whole world (Cliopatria): each entity comes with its Wikipedia article and its
  Wikidata id.
- **Live Wikipedia summaries**, in the app's language (or the one chosen in Settings) and in the other one if there's
  no article, cached for 30 days.
- **Twelve packages** in `data/enciclopedia/paquetes/`, plus `familias.json` with the religions, cultures and
  languages. Together they add up to 88 regions covering 99.6% of the land surface, and each one has an estimated
  population from 10,000 BC or is counted within another. What's covered and what's missing is in
  [Encyclopedia coverage](coverage.md), which is generated automatically:
  - `egipto.json`, the pilot: 4 regions (with 18 eras for Egypt), 37 sources, 18 people, 24 events and 14 places.
  - `mundo.json`, a sample of eleven regions (Mesopotamia, the Levant, Anatolia, Greece, Italy, Persia, China, India,
    Mesoamerica, the Andes and the Río de la Plata).
  - `edad-media.json`, medieval Europe from the sack of Rome to 1500, with an emphasis on the history of philosophy:
    15 regions (the Iberian Peninsula, France, Britain, Ireland, Germany and the Low Countries, Scandinavia, Iceland,
    Poland, Bohemia, Hungary, the Balkans, Wallachia and Moldavia, the Baltic, Rus' and Sicily), 173 sources, 215
    people, 125 events and 120 places. The Spanish Wikipedia titles, the Wikidata ids and the coordinates come from
    Wikidata; the life dates were cross-checked against Wikidata and the 104 reading links (Wikisource and Project
    Gutenberg) were checked one by one. The demography follows Russell (1972) and Urlanis (1941).
  - `tierra-santa.json`, the Holy Land from Antiquity to today, with the early Islamic expansion, Byzantium, the
    Crusades and the thought of Jews, Christians and Muslims: 7 regions (the Holy Land, Lebanon, Syria and
    Transjordan within the Levant, plus Arabia, the Maghreb and Cyprus), 176 sources, 198 people, 172 events and 75
    places. It includes the scriptures (the Torah, the Tanakh, the New Testament, the Quran, the Dead Sea Scrolls),
    the chronicles of the Crusades from every side, the calls to jihad and to crusade, and the modern documents
    (Balfour, the Peel report, Resolution 181, the 1988 Hamas Charter, Oslo). Verified against Wikipedia and Wikidata
    like the previous one; its 95 reading links (Wikisource, Gutenberg, Yale's Avalon Project, Fordham's Medieval
    Sourcebook, Sefaria and others) returned 200. The demography of the Holy Land follows DellaPergola (2001) and the
    Mandate censuses. Later, Armenia (the Armenian Highlands) and Cilicia were added to it, and Finland, Sardinia and
    Corsica and the Pontic steppe to `edad-media.json`, with their eras, religions, cultures and languages.
  - `regiones-del-mundo.json`, the 46 regions that complete the map (from Siberia and Japan to Africa, the Americas
    and Oceania), built from the borders of present-day countries in Natural Earth: summary, eras and population. They
    don't have religions, cultures or languages yet.
  - **The contemporary era**, in seven thematic packages with no regions of their own (629 sources, 510 people, 440
    events and 86 places), verified the same way as the others: `pensamiento-economico` (from Smith to the Austrian
    school, Keynes, Chicago, libertarianism and ECLAC), `ideas-politicas` (socialism, anarchism, Zionism, fascism,
    totalitarianism and its critics, decolonization, feminism, environmentalism), `argentina-contemporanea` (from 1880
    to today, with Peronist doctrine, the dictatorship, the Falklands/Malvinas, the censuses and the court cases
    against Kirchnerism), `ciencia-y-tecnologia` (the publications that opened up technologies, with their Nobels),
    `cultura-libre-y-hackers` (GNU, cypherpunks, WikiLeaks, Anonymous), `guerras-y-orden-mundial` (declarations of
    war, treaties and resolutions from 1914 to today) and `letras-y-pensamiento-del-siglo-xx`.
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
  separate layer built with `tools/traduccion/enciclopedia.py` ([the schema](../../data/enciclopedia/ESQUEMA.en.md#translations)).
  With the app in English those texts are the ones you read; anything not translated yet shows in Spanish.
- **An editor inside the app** to load and fix all of that without touching JSON (see [below](#the-editor)).

## What about Grokipedia?

As of November 2026, **Grokipedia has no official API**. What exists are unofficial clients that read the site (for
example, PyPI packages or services that mirror it) and at least one site with a similar name that claims to offer an
API and isn't from xAI. On top of that, its content was frozen between March and September 2026, and a good part of
it was derived from Wikipedia.

That's why TellMAP doesn't depend on Grokipedia: it uses Wikipedia (public, stable API, CC BY-SA), Wikidata
(structured data, CC0) and, for the long entries, AI that writes *from cited sources*. Grokipedia's entry style (a
long, orderly, readable article) is the reference for form, not for content.

## Four entry levels

| Level | What it is | Status |
|---|---|---|
| 0 | Cliopatria data: name, years and territory | The whole world |
| 1 | Live Wikipedia summary | Everything that has an article |
| 2 | Curated entry: eras, primary and secondary sources, people, events, population, religion, culture and language | Egypt and the world sample |
| 3 | Extended "encyclopedia-style" entry: full history by sections, written with AI from cited sources and reviewed | Tools ready (0.3); published as they get reviewed |

## How it gets filled in

1. **Usage says what's missing.** The app logs in `user://pendientes.json` whatever gets opened and has no curated
   entry: the entity, its Wikidata, the place, the years looked up and how many times. It never leaves the computer.
   In Settings → Encyclopedia you can see the most looked-up ones and copy the queue. (On Linux, `user://` is
   `~/.local/share/godot/app_userdata/TellMAP/`.)
2. **Automatic draft.** `python3 tools/enciclopedia/borradores.py` takes the most looked-up entries (`-n 3` by
   default; `--cola` for a copied queue, `--wikidata Q12560` for a specific entity) and gathers:
   - from Wikidata, the capital with its coordinates, the key people (those who held its offices and the best known of
     its time) with dates and places of birth and death, and the dated events it took part in;
   - from Wikipedia, the summary and the full article by sections, in Spanish or, if there's none, in English;
   - from Cliopatria, the entity's years.

   It leaves this in `data/enciclopedia/paquetes/borradores/`, in the schema format and marked "unreviewed".
3. **AI writing, with mandatory citations.** `python3 tools/enciclopedia/redactar.py <borrador>` passes Claude the
   draft's sources, numbered (each section of the article and the Wikidata record), and asks it for the history by
   sections, citing in each paragraph which source it comes from. Then, without trusting the model, it discards
   paragraphs with no valid citation, flags for review the years and figures that don't appear in the sources they
   cite, and checks one by one the reading links it suggests. It needs the SDK (`pip install anthropic`) and an API
   credential; each entry costs on the order of USD 0.15 to 0.40 with the default model.
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
project, send those files. Regions can be edited in their main data, their area and their eras; religions, cultures,
languages and demography are still entered by hand in the JSON.

## Editorial rules

- **Nothing made up.** If a date is uncertain it's marked `aprox` and the `confianza` is lowered; if a piece of data
  has no source, it doesn't get loaded.
- **Primary sources first**, in public-domain or open-access editions when they exist.
- **Two coordinates per text**: where and when it was written, and what place and period it's about.
- **Estimates with their author and their range.** Figures from ancient authors are testimonies, not estimates.
- **More than one tradition.** Each region's eras use its own periodization; the European periodization appears only
  as a global reference, and it's stated that it's approximate.
- **Clear licenses.** Whatever is derived from Wikipedia inherits CC BY-SA 4.0 and is attributed.
