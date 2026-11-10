# Compact format for writing encyclopedia topics

[Español](FORMATO.md)

TellMAP is a historical atlas (Godot) with an encyclopedia of **entries**: sources (texts: books, articles,
manifestos, laws, rulings, speeches), people, events and places, located in space and time. The app doesn't store
the texts: it stores the entry (title, author, dates, its own summary) and **links** to where to read them. Full
schema: [data/enciclopedia/ESQUEMA.en.md](../../../data/enciclopedia/ESQUEMA.en.md).

Writing hundreds of entries directly in JSON is slow and error-prone. This text format, with one line or one block
per item, is quick to write, and `construir.py` turns it into verified packages. That's how the Middle Ages, Holy
Land and contemporary era packages were built. Each topic lives in `<topics folder>/<topic>/` (the folder can be
outside the repo: what matters are the packages it produces) and is built with:

    python3 tools/enciclopedia/compacto/construir.py <topics folder> --tema <topic>

which resolves each Wikipedia article (redirects, disambiguation pages, Spanish title and Wikidata QID), takes
coordinates and places from Wikidata, compares the dates against Wikidata, checks that every reading link returns
200, and leaves in the topic's folder `informe.txt` with the warnings and `salida.json` with the package. **You
iterate until the report is clean** (or its warnings are explained). With `--tema` it doesn't write to the repo; without `--tema`
and with `--escribir` it builds all the topics together, resolves the cross-references between them and writes the
packages to `data/enciclopedia/paquetes/`.

## Content rules

- Everything in **neutral Rioplatense Spanish**, with accents, brief, precise and **verifiable**. Nothing made up: if
  a fact isn't certain, mark it as approximate (`~`) and `c: media`/`baja`, or leave it out. When in doubt,
  `consultar.py resumen <título>`.
- **Neutrality**: describe what each work says and what happened, without taking sides. On disputed topics
  (Peronism, Kirchnerism, Zionism, socialism, libertarianism, wars), say who holds what and what the main criticism
  is, in one sentence. Court rulings: court, date, what it decided, sentences, instances and whether it's final; if
  the convicted person denounces it as persecution, say so.
- Summaries: 2 to 4 sentences for sources (`r`) and 1 to 2 for `p` (why it matters); 1 to 3 sentences for people,
  events and places. No opinion adjectives (“brilliant”, “nefarious”).
- Events after 2024: confirm them with `consultar.py resumen` (your memory may be outdated or wrong).
- Ids: lowercase, no accents, with hyphens (`teoria-general-keynes`, `keynes`). Before creating one, check whether it
  already exists in another package: if it does, **use that id** and don't redefine it (the builder warns “ID QUE YA
  EXISTE”). If several topics are being written at the same time, it's best to agree beforehand on which topic
  defines each shared figure or work.

## Topic files

All UTF-8, with `#` for comments. Fields separated by ` | ` (never use `|` inside a text).

### `meta.txt`
    paquete: <package-name>
    descripcion: <one sentence>

### `personas.txt`
    # id | name | birth | death | active | roles | English article | summary
    keynes | John Maynard Keynes | 1883 @wd | 1946 @wd | @cambridge 1909-1946 | economista | John Maynard Keynes | Economista británico...

- birth/death: `year [place]`; empty if alive or unknown. Place: `@wd` (takes it from Wikidata: the easiest),
  `@key` (from the gazetteer), `@key=Text`, or `=Text` (no coordinates).
- active: `@key year-year` (where they worked and when); empty if the birth is enough.
- `~` at the end of a year = approximate. Negative years = BC.

### `fuentes*.txt` (there can be several: `fuentes1.txt`, `fuentes2.txt`…)
    ## teoria-general-keynes
    t: Teoría general de la ocupación, el interés y el dinero
    to: The General Theory of Employment, Interest and Money
    a: keynes                      (person id; or =Name if they have no entry)
    k: secundaria economia         (type: primaria|secundaria; genre, see below)
    e: 1936 @londres               (year or year-year range, and place where it was written or published)
    tr: britania,norteamerica 1929-1936   (regions it covers and years it spans; "-" if universal)
    io: Inglés
    so: Libro                      (optional)
    r: Resumen...
    p: Por qué importa...
    w: The General Theory of Employment, Interest and Money   (English article; `es:Title` if there's only a Spanish one)
    c: alta

- type: `primaria` = a document from its time about its time (manifesto, law, ruling, speech, letter, treaty,
  original scientific paper, theory book written by its author); `secundaria` = a later study about another period
  (historiography). Almost everything in this batch is primary.
- genres: `religioso historia cronica literatura poesia filosofia legal administrativo epistolar inscripcion
  geografia ciencia medicina sabiduria viajes ensayo arqueologia economia politica manifiesto discurso tecnologia
  periodismo`. Rulings, laws, treaties, resolutions and constitutions: `legal`. Scientific papers: `ciencia`.

### `hechos.txt`
    # id | title | years | place | type | sources | English article | summary | extra regions
    conferencia-de-bretton-woods | Conferencia de Bretton Woods | 1944 | @bretton-woods | economico | acuerdos-de-bretton-woods | Bretton Woods Conference | Resumen... |

- years: `1944`, `1914-1918`, `1944~`. place: as in people; `@=Text` uses the coordinates of the article itself.
- type: `politico batalla fundacion religioso cultural cientifico economico desastre tratado construccion
  exploracion revolucion judicial`. Whole wars: `batalla` with a year range; rulings: `judicial`.
- sources: ids separated by commas (from any topic or package), or empty.
- extra regions (optional): region ids besides the one the point falls in (the `id`s of the regions in the packages).

### `lugares.txt`
    # id | name | founding | abandonment | type | importance | English article | summary | [lon,lat if Wikidata doesn't have them]
    bell-labs | Laboratorios Bell | 1925 | - | laboratorio | 2 | Bell Labs | Resumen...

- type: `ciudad capital templo puerto sitio-arqueologico biblioteca universidad laboratorio institucion sitio-historico`.
- importance 1 (local) to 3 (first rank). Only places that matter in their own right (a laboratory, a square, a
  court, a clandestine detention center); cities where something was written go in the gazetteer.

### `gaz.txt` (gazetteer: points for `@key`, not entries)
    # key | name | English article | [lon,lat if Wikidata doesn't have them]
    londres | Londres | London
    cambridge | Cambridge | Cambridge

The **places** in the packages already work as `@key` (`@roma`, `@paris`, `@jerusalen`, `@buenos-aires`…): before
adding a key, check whether it already exists.

### `leer.txt` (where to read each source; only links that return 200)
    # source | pg:<number>, ws:<language>:<title> or url:<https://...> | description | language | [dp if a url is public domain]
    manifiesto-gnu | url:https://www.gnu.org/gnu/manifesto.es.html | Texto en español en gnu.org | es |

Priority: public domain or open access and **official** (Wikisource, Project Gutenberg, Internet Archive, Yale's
Avalon Project, UN sites, gnu.org, arXiv, the journal's or the author's site, the CIJ of the Argentine Supreme Court,
InfoLEG, the Boletín Oficial, mises.org for the Austrian school, marxists.org for socialism and anarchism). Never
pirated copies of copyrighted books: if there's no legal copy, the source stays without a link (the entry is still
worth it). `pg:` and `ws:` are marked public domain automatically; with `url:`, add `dp` only if it is.

## Tools

`python3 tools/enciclopedia/compacto/consultar.py` (with no arguments it shows the help):
`resumen`, `buscar`, `titulos` (checks many titles at once, separated by ` ;; `), `wd`, `url`, `ws`, `pg`.
