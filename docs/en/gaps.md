# Gaps in what has been researched

[Español](../es/huecos.md)

How to go through the encyclopedia so that no topic is left with gaps in the place and period it already covers: if a
topic has ten of the twelve presidents of its period, two are missing; if it has half the battles of a war, the others
that are just as well known belong too; if a region has religions up to 400 and from 900 on, what lies between is
missing. It is meant for people and for AI agents.

## What a gap is

Each package is a topic researched in a place and a period. Its **scope**, in
[`tools/enciclopedia/huecos/alcances.json`](../../tools/enciclopedia/huecos/alcances.json), says:

- `desde` and `hasta`: the years it covers;
- `regiones`: where, and `nucleo`, the regions where the topic actually happens rather than just appearing (the
  most cited ones up to 60 % of its entries, plus the ones the package defines): candidates are searched there;
- `hechos` and `ocupaciones`: its axes, that is, the event types and person roles the topic covers with at least three
  entries. In topics about ideas rather than a place (science, economic thought, literature), `ocupaciones` is left
  empty: the people they are missing come up through their works, offices and successions, not through where they
  were born;
- `profundidad`: how well known the least known thing in the topic is, measured in Wikipedias (the lower quartile of
  the Wikidata sitelinks of its events, sources and people), plus the median.

A gap is something that falls **inside** the scope and is **at least as notable** as what the topic already has, but
is missing. What falls outside is not a gap but an expansion: it goes to "To do" in
[PROGRESO.en.md](../../PROGRESO.en.md).

Scope and depth are fixed once (`huecos.py alcances --fijar` infers them from the data and the package description,
and then they are checked by hand) and are never recomputed on their own: if every round lowered the bar, the search
would never end. To go deeper into a topic they are changed by hand, and that is a decision, not a side effect.

## The detectors

`python3 tools/enciclopedia/huecos.py` (with no arguments it prints its help). Without the network, the detectors take
less than a second:

| detector | what it finds | priority |
|---|---|---|
| `capas` | researched years in which a region has no era, religion, culture or language, and no region containing it has one either (that is what the app shows instead) | high if it cuts a layer that was started; medium if it is missing at the edge or the whole layer is missing |
| `tramos` | stretches with no events or sources of the topic in one of its regions, between stretches that have them | medium; low if other packages cover that stretch |
| `referencias` | authors with an entry but no `autor_id` and works not synced (fixed automatically), events without sources or coordinates, sources without a reading link or a place of writing | high for the mechanical ones, low for the rest |

With `--red` they query Wikidata through [QLever](https://qlever.dev) (much faster than the official service) and the
Wikipedia API, and keep the answers in `tools/enciclopedia/huecos/cache/`, outside git. QLever throttles rapid requests,
so the first full run can take half an hour; later ones come from the cache (`rm -r tools/enciclopedia/huecos/cache` to
query again):

| detector | what it finds | priority |
|---|---|---|
| `series` | holders of an office (P39) between the first and the last ones tmap has | high with three or more holders present and half the series; medium with a quarter; low outside that window but inside the scope |
| `sucesiones` | missing links in a chain of events or works (P155/P156) | high between two that are present; medium at the end of a chain, inside the scope and the depth |
| `partes` | parts (P361) of a whole the topic already has half of, as notable as the topic | high if half are present; medium otherwise |
| `obras` | works (P50) by authors who already have an entry, as notable as the topic's sources | high above the topic's median; medium otherwise |
| `candidatos` | events on the topic's axes (battles, treaties, revolutions, disasters, expeditions, councils) and people in its occupations, located in its regions and years | medium above the topic's median; low otherwise |

`informe` shows high and medium priorities by default (`--prioridad baja` for everything). Every gap has a stable
**key** (`serie:Q12969145:Q254041`, `capa:levante:eras:1292:1515`…). A filled gap disappears by itself, because the
detectors compare by QID, by id and by years. One that will not be filled is recorded in
[`decisiones.json`](../../tools/enciclopedia/huecos/decisiones.json), with the date and the reason:

    python3 tools/enciclopedia/huecos.py decidir <key> descartado "not part of the topic: …"
    python3 tools/enciclopedia/huecos.py decidir <key> sin-datos "no source gives the date"
    python3 tools/enciclopedia/huecos.py decidir --archivo decisiones.json   # [{"clave", "decision", "motivo"}]

A decision applies to its key and to every key that starts with it: `serie:Q123` dismisses the whole series and
`capa:nubia` every layer of Nubia; `candidato:<package>:personas`, every person candidate of a package, if that axis
is not part of the topic.

## A round

Work goes in rounds started by hand, never unattended. Each round takes on one or more whole packages, not loose gaps
from everywhere, so that each topic gets closed.

1. **Detect.** `huecos.py informe --red [--paquete P]…` counts gaps by package and detector, and
   `huecos.py lotes <folder> --red [--paquete P]…` writes a `.md` and a `.json` per package. If a new package has no
   fixed scope, `huecos.py alcances --fijar` infers it: years and regions are checked against the package description
   and corrected by hand before going on.
2. **The mechanical part.** `huecos.py arreglar --escribir` (the `autor_id` whose name matches exactly one person, and
   each author's works) and `python3 tools/enciclopedia/validar.py`.
3. **Triage.** Whoever coordinates reads the batches and dismisses in bulk what is not part of the topic: a series of
   offices tmap has for another reason (three generals who are there for World War II do not make the chiefs of staff a
   topic), a candidate that falls in the regions and years but not in the topic. It is the cheapest step and the one
   that saves the most: a dismissal is one line; a badly chosen entry is a writer, a reviewer and a translation.
4. **Fill.** One writer per batch; a batch of more than about 60 gaps is split by detector or by period. The writer
   uses the [compact format](../../tools/enciclopedia/compacto/FORMATO.en.md#filling-gaps-in-an-existing-package) to
   write a `huecos-<package>` topic in a working folder outside the repo, the changes to existing entries in
   `parches.json` and what it decides not to fill in `decisiones.json`, and builds with `construir.py <folder> --tema
   huecos-<package>` until the report is clean. See [the writer's brief](#the-writers-brief).
5. **Review.** One adversarial reviewer per batch, not the one who wrote it: see
   [the reviewer's brief](#the-reviewers-brief). The writer, or whoever coordinates, applies the corrections and builds
   again.
6. **Apply.** `huecos.py aplicar <folder>/huecos-<package> <package> --escribir` and
   `huecos.py decidir --archivo <folder>/huecos-<package>/decisiones.json`; then `validar.py` and `cobertura.py`. If
   two batches created the same id, `aplicar` writes nothing: the second one uses the first one's id and is rebuilt.
7. **Check.** The report for those packages is run again: what was taken on must be gone. Whatever new shows up (the
   next link of a chain that was just completed, another battle of the war that was added) is the next round.

It stops when nothing of high or medium priority is left in the chosen packages, when a round closes less than half of
what it took on (something is wrong: look before going on), when the task's budget is reached, or after three rounds.
A search is never left open with no limit.

At the end of the task, not of each round:

- **English.** `python3 tools/traduccion/enciclopedia.py estado`, `extraer <folder>` in batches, each batch translated
  by a small model, and `aplicar <answers>`; then `python3 tools/traduccion/probar.py`.
- **Places and links.** If ancient places were added, `python3 tools/pleiades/enlazar.py` links them to Pleiades;
  new reading links get their Wayback Machine copy with `python3 tools/enciclopedia/enlaces.py`.
- **Test.** `validar.py`, `cobertura.py --comprobar`, `tools/godot/tmap.py prueba` and `prueba --idioma en`, and
  `tmap.py registros --errores`.
- **Record.** In PROGRESO.md and PROGRESO.en.md, what was done with its date; under "To do", what was left `sin-datos`
  and is worth looking for again, and whatever turned up outside the scope.

## Criteria

- **Wikidata suggests, it does not decide.** A candidate is a lead: it goes in if it belongs to the topic and can be
  verified (in November 2026 Wikidata had Alexandra Kollontai dying in Bahía Blanca, which is why she showed up among
  the candidates for Argentina from 1862 to 1912). Every fact is checked with
  `tools/enciclopedia/compacto/consultar.py resumen <title>` and the article; `construir.py` also compares dates with
  Wikidata and warns when they differ. If Wikidata, Wikipedia and the literature disagree, the primary source or the
  specialist literature wins, not the most repeated version.
- **Documents first.** For disputed events, first what the documents show, then, attributed, who interprets it how. No
  propaganda from any side and no official history taken as truth. Wikipedia is read critically, and what is already
  in tmap is not true just because it is there: if a mistake turns up in an old entry while filling, it is fixed with
  a patch.
- **Nothing made up.** What is uncertain goes with `aprox`, `confianza: baja` or a `nota`, or does not go. A gap that
  cannot be filled with verifiable data stays `sin-datos`, with the reason.
- **The same mould.** A gap is filled like its neighbours: if the package has an event for each presidency, the
  missing president gets one too; if the battles of the war cite the battle report, the missing one does too.
- **Extras.** What turns up while researching and falls inside the scope goes in; what falls outside is recorded under
  "To do", not lost.

## The writer's brief

Whoever coordinates fills in what is between braces. The entries themselves are written in Spanish, like the whole
encyclopedia; the English comes later, in the translation layer.

> You are filling the gaps of "{package}" in the TellMAP encyclopedia ({repo}). The list is in {batch}.md: each gap
> has its key, its Wikidata QID when there is one and the reason it counts as a gap.
>
> Before writing, read `tools/enciclopedia/compacto/FORMATO.en.md` (how to write; above all "Filling gaps in an
> existing package"), `data/enciclopedia/ESQUEMA.en.md` (what each field means) and the "Criteria" section of
> `docs/en/gaps.md`. Look at how the package treats each gap's neighbours (the JSON in `data/enciclopedia/paquetes/`)
> and follow the same mould. Check every fact with `python3 tools/enciclopedia/compacto/consultar.py`.
>
> You work only in {folder}/huecos-{package}/, with `paquete: huecos-{package}` in meta.txt. Each gap ends in one of
> three ways:
>
> 1. filled: its entry in the compact format (personas.txt, hechos.txt, fuentes*.txt, lugares.txt, leer.txt,
>    familias.txt), using existing ids where they apply, never redefining one;
> 2. fixed in an entry that already exists: an item in parches.json (a region's eras and layers, an event's sources,
>    a reading link, a corrected fact);
> 3. not filled: an item in decisiones.json, `descartado` (not part of the topic) or `sin-datos` (cannot be
>    verified), with the reason in one sentence.
>
> None is left unanswered. Build with `python3 tools/enciclopedia/compacto/construir.py {folder} --tema
> huecos-{package}` until informe.txt is clean or its warnings are explained. Never use `--escribir` and never touch
> `data/`: whoever coordinates applies it.
>
> When you finish, report how many you filled, fixed and dismissed, the warnings left and why, and anything you found
> outside the scope that is worth recording.

## The reviewer's brief

> You are reviewing, without having written it, what is about to be added to "{package}" in the TellMAP encyclopedia
> ({repo}): what is in {folder}/huecos-{package}/ (salida.json, parches.json, decisiones.json), against the batch
> {batch}.md and the "Criteria" section of `docs/en/gaps.md`. Look for:
>
> - factual errors: dates, places, offices, authorship, figures; confirm them with
>   `python3 tools/enciclopedia/compacto/consultar.py resumen <title>` and, if needed, with the primary source;
> - bias from any side: opinion adjectives, an interpretation presented as fact, a single version of something
>   disputed, propaganda or an official history taken as truth;
> - gaps closed badly: dismissals that did belong to the topic, `sin-datos` that could be verified, entries that do not
>   follow their neighbours' mould;
> - reading links that are not legal or do not lead to the text they claim.
>
> Do not rewrite: return a list of concrete corrections (id, field, what it says, what it should say and on which
> source), from the most serious to the least, or "no remarks".

## Cost

- The detectors cost nothing but network time, and the coordinator's triage is cheap. The writer and the reviewer are
  the expensive part, which is why dismissing before writing pays off.
- A mid-sized model is enough to write, because `construir.py` checks titles, QIDs, dates and links. To review, the
  most capable one for disputed topics (politics, religion, recent wars) and the mid-sized one for the rest. To
  translate, the smallest.
- Batches run in parallel, four or five at a time. If two batches may need the same person or work, who defines it is
  decided beforehand.
- Before the first round, check the available budget; after the first one, measure what it cost and use that to
  decide how many more fit.
