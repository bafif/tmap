# Storage and downloads: how TellMAP grows without becoming unmanageable

[Español](../es/almacenamiento.md)

TellMAP is going to take in a huge amount of information: the contemporary era, people from Wikidata, places from Pleiades, population
grids, books, court rulings, treaties. This page says how much all of that actually weighs, where each thing lives, how
the app downloads it without bogging down anyone's computer, and in what order it gets done. Decided on November 10, 2026.

## The real numbers: it's not terabytes

TellMAP **doesn't store the texts**: it stores each work's entry (title, author, dates, place, its own summary) and links
to where it can be read (Wikisource, Project Gutenberg, Internet Archive, the official site). It doesn't store Wikipedia either: it requests
an article's summary when someone opens it. That's why what has to be distributed is small:

| What | Today | When complete | Notes |
|---|---|---|---|
| Map (terrain, relief, units, borders) | 25 MB | 25-60 MB | Grows if the 3D view or finer coastlines are added |
| Curated encyclopedia (entries) | 3.8 MB, 3263 items | 15-150 MB | ~1.5 KB per item: 10,000 items ≈ 15 MB (3 MB compressed) |
| Per-country series (demographics, economy) | 0.9 MB | 2-5 MB | Our World in Data, one value per year since 1950 and per decade before that |
| Wikidata people with a date and place (0.4) | — | 60-600 MB | ~1 to 10 million people, ~60 bytes each in binary |
| Pleiades places (0.4) | — | ~5 MB | ~36,000 ancient places |
| HYDE population grids (0.4) | — | 30 MB to 1 GB | At half a degree, ~30 MB compressed; at 5 arcminutes, ~1 GB |
| Full texts for offline reading | — | whatever each person picks | Optional: downloaded one at a time, on request |

What does weigh terabytes (book scans, full Wikipedia dumps, high-resolution grids for every
year) **isn't distributed**: it stays at its source and the app links to it. The total that TellMAP hosts itself
will be somewhere between tens and a few hundred MB, and nobody has to download all of it.

## Three layers

1. **The core, inside the executable** (up to ~150 MB): the app, the map, the curated encyclopedia as long as it stays under
   the threshold below, the per-country series, and an **index of everything** (id, type, years, coordinates, title, which
   tile it's in), so search and markers work offline.
2. **On-demand tiles**: the bulk data (Wikidata people, grids, large packages) split by era and region,
   each tile 50 to 500 KB compressed. Downloaded the first time it's needed and kept in the user's folder.
3. **External, live**: Wikipedia summaries and reading links. Requested one at a time, when someone taps something,
   never in bulk.

## Where to host each thing

| Option | Cost | Limits | What it's for |
|---|---|---|---|
| **GitHub Releases** (what the updater already uses) | Free on a public repo | 2 GB per file; GitHub doesn't cap total size or release traffic | **The main location**: the executable, the data, and the tiles, with their manifest and sha256 |
| **Internet Archive** | Free | No practical limit; slower | **Permanent mirror** of every data release and of the large datasets |
| **Zenodo** (CERN) | Free | 50 GB per record | Publishing the datasets with a DOI, so they can be cited |
| Cloudflare R2 | 10 GB free per month, no traffic charges; after that, ~0.015 USD per GB per month | Requires a card | Only if someday there are lots of small tiles or lots of traffic: Bautista decides |
| Google Drive | Free up to the account's quota | Cuts off downloads of popular files (“Download quota exceeded”), shows a warning screen before downloading large files, and depends on a personal account | **Not usable as a source the app downloads from.** Fine as a personal backup of `raw_data/` |

Decision: **GitHub Releases as the main source** (already integrated and tested: manifest, sha256, partial
per-file downloads), **Internet Archive and Zenodo as permanent mirrors**. If GitHub stopped responding, the app
tries the mirror: the manifest carries both addresses for each file.

### When external sources go down

- **Reading links**: every `leer` gets an `archivo` field with its copy on the Wayback Machine, which the app offers if
  the original doesn't respond. A tool (`tools/enciclopedia/enlaces.py`, to be written) checks every link and
  asks the Wayback Machine for a copy when a new one is added; it's run by hand before each release.
- **Wikipedia**: if it doesn't respond, the entry's own content is still there; the Wikipedia summary is cached the first time.
- **Source data** (Our World in Data, Cliopatria, Natural Earth, HYDE): never queried live. Copied into the
  repo or a release (the licenses allow it: CC BY and public domain) and everything is built from there.

## Keeping the app from stalling: download rules

The risk isn't the total size but downloading or processing a lot at once, for example while someone is dragging the
timeline. The rules:

1. **Moving the year downloads nothing.** While the timeline is being dragged or playing, the app uses only what it
   already has in memory. Downloads come from an explicit action: selecting a place, opening an entry, or choosing
   “Download this era” in Settings.
2. **Wait for the year to settle.** Only 400 ms after the last year change can the tile for the region and era
   being viewed be prefetched, at the lowest priority.
3. **A single download manager** (autoload `Descargas`): a priority queue (what was tapped, what's visible, what's
   prefetched), at most two requests at a time, cancellation of prefetches that are no longer needed,
   retries with increasing backoff, an “Offline” notice instead of an error, and a per-server cap (Wikipedia: one
   request per second).
4. **Nothing heavy on the main thread.** Reading and preparing a tile happens on a separate thread (`WorkerThreadPool`); the
   result is merged into the main thread in small chunks per frame, so the animation doesn't stutter.
5. **Disk budget**: the cache in the user's folder has a cap (500 MB by default, adjustable in
   Settings between 100 MB and 10 GB) and evicts the least used. Settings shows how much it takes up and has “Clear cache”.
6. **Memory budget**: loaded tiles live in a capped list (64 MB by default); the least used one is
   dropped and read back from disk if needed.
7. **Integrity**: every file comes with its sha256 in the manifest (as the updater does today); one that doesn't match is
   discarded and requested again.
8. **Never block**: if a tile fails to download, the panel says “Couldn't download” with a retry button; the rest
   of the app carries on as usual.

## Tiles: how they're split

- **Key**: era × macro-region. Finer eras where there's more data: 1000-year spans before 1000 BC,
  one century up to 1500, 25 years up to 1900, and one decade from 1900 on. Macro-regions: about twelve (Europe,
  Near East, North Africa, Sub-Saharan Africa, Central Asia, South Asia, East Asia, Southeast
  Asia and Oceania, North America, Mesoamerica and the Caribbean, South America).
- Each item goes into the tile for its main year and place (a source, where it was written; a person, where they lived).
  The core index says which tile each one is in.
- Thematic packages remain the way to **write** (readable JSON, with diffs in git). Tiles are the
  way to **distribute**: they're built by a publishing step (`tools/actualizacion/publicar.py`), not edited by hand.

## Work order

| Step | When | What |
|---|---|---|
| 0 | Done (Nov 10, 2026) | The per-country series are only loaded when the “Data” tab is opened (29 ms), and the app measures at startup how much the encyclopedia weighs and how long it takes (with the contemporary era, 3.8 MB in 150 to 230 ms on the dev PC) |
| 1 | When the encyclopedia goes past **10 MB** or takes more than 1 s to open | Reading the packages on a separate thread while the loading screen is shown; compact in-memory index |
| 2 | With 0.4 (Wikidata people, Pleiades) or when it goes past **50 MB** | Tiles, download manager, capped cache, and the Settings section; tiles in GitHub Releases |
| 3 | With the HYDE grids | Raster tiles per era, mirror on Internet Archive and Zenodo |
| 4 | Before 1.0 | `archivo` field in reading links and `enlaces.py`; texts for offline reading, one at a time |

Going by today's measurement (40 to 110 ms per MB on this PC, depending on whether the disk is cached; on an old laptop it could
be three times that), everything loaded so far, including the contemporary era, fits in layer 1 without changing
anything else.
