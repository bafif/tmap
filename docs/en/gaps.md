# Gaps in what has been researched

[Español](../es/huecos.md)

How to go through the encyclopedia so that no topic is left with gaps in the place and period it already covers: if a
topic has ten of the twelve presidents of its period, two are missing; if it has half the battles of a war, the others
that are just as well known belong too; if a region has religions up to 400 and from 900 on, what lies between is
missing.

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

`informe` shows high and medium priorities by default; `--prioridad baja` shows everything, which is what has to be
filled. Every gap has a stable
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

Work goes in rounds, always started by hand. Each round takes one or more whole packages, not loose gaps from
everywhere, so that each topic gets closed.

1. **Detect.** `huecos.py informe --red [--paquete P]…` counts gaps by package and detector, and
   `huecos.py lotes <folder> --red [--paquete P]…` writes a `.md` and a `.json` per package, with series, wholes,
   authors and axes grouped and each group's key in sight. If a new package has no fixed scope,
   `huecos.py alcances --fijar` infers it: years and regions are checked against the package description and
   corrected by hand before going on.
2. **The mechanical part.** `huecos.py arreglar --escribir` (the `autor_id` whose name matches exactly one person, and
   each author's works) and `python3 tools/enciclopedia/validar.py`.
3. **Triage.** Before writing, whatever is not part of the topic is dismissed in bulk: a series of offices tmap has for
   another reason (three generals who are there for World War II do not make the chiefs of staff a topic), a candidate
   that falls in the regions and years but not in the topic. A dismissal is one line; a badly chosen entry is an entry
   to write, review and translate.
4. **Fill.** One batch per package (one with more than about 60 gaps is split by detector or by period). Each gap ends
   in one of three ways: filled, with its entry in the
   [compact format](../../tools/enciclopedia/compacto/FORMATO.en.md#filling-gaps-in-an-existing-package) inside a
   `huecos-<package>` topic, in a working folder outside the repo; fixed in an entry that already exists, with an item
   in `parches.json`; or not filled, with an item in `decisiones.json` (`descartado` if it is not part of the topic,
   `sin-datos` if it cannot be verified, and the reason in one sentence). Build with `construir.py <folder> --tema
   huecos-<package>` until the report is clean or its warnings are explained.
5. **Review.** Someone who did not write the batch checks it against the list of gaps and against the sources: factual
   errors (dates, places, offices, authorship, figures), bias from any side, gaps closed badly (dismissals that did
   belong to the topic, `sin-datos` that could be verified, entries that do not follow their neighbours' mould) and
   reading links that are not legal or do not lead to the text they claim. The corrections are applied and the batch
   is built again.
6. **Apply.** `huecos.py aplicar <folder>/huecos-<package> <package> --escribir` and
   `huecos.py decidir --archivo <folder>/huecos-<package>/decisiones.json`; then `validar.py` and `cobertura.py`. If
   two batches created the same id, `aplicar` writes nothing: the second one uses the first one's id and is rebuilt.
7. **Check.** The report for those packages is run again: what was taken on must be gone. Whatever new shows up (the
   next link of a chain that was just completed, another battle of the war that was added) is the next round.

Rounds go on until the chosen packages have no gaps left, of any priority: priority orders the work (high first), it
does not decide what is left out. Only decided gaps remain, each with its reason. If a round closes none of the gaps it
took on, something is wrong (a scope that is too wide, a noisy detector) and it is looked into before going on:
otherwise the search would go round in circles.

When finished:

- **English.** `python3 tools/traduccion/enciclopedia.py estado`, `extraer <folder>`, the translation of each batch and
  `aplicar <answers>`; then `python3 tools/traduccion/probar.py`.
- **Places and links.** If ancient places were added, `python3 tools/pleiades/enlazar.py` links them to Pleiades;
  new reading links get their Wayback Machine copy with `python3 tools/enciclopedia/enlaces.py`.
- **Test.** `validar.py`, `cobertura.py --comprobar`, `tools/godot/tmap.py prueba` and `prueba --idioma en`, and
  `tmap.py registros --errores`.
- **Record.** In PROGRESO.md and PROGRESO.en.md, what was done; under "To do", what was left `sin-datos` and is worth
  looking for again, and whatever turned up outside the scope.

## Criteria

- **Wikidata suggests, it does not decide.** A candidate is a lead: it goes in if it belongs to the topic and can be
  verified, because Wikidata makes mistakes too (a wrong place of death is enough to put someone in another topic's
  region). Every fact is checked against the full article in two languages
  (`tools/enciclopedia/compacto/consultar.py texto <title>` and `texto <title> es`), not just its introduction, which
  sometimes contradicts the body or the other language; `construir.py` also compares dates with Wikidata and warns
  when they differ. If Wikidata, Wikipedia and the literature disagree, the primary source or the specialist
  literature wins, not the most repeated version.
- **Documents first.** For disputed events, first what the documents show, then, attributed, who interprets it how. No
  propaganda from any side and no official history taken as truth. Wikipedia is read critically, and what is already
  in tmap is not true just because it is there: if a mistake turns up in an old entry while filling, it is fixed with
  a patch.
- **Nothing made up.** What is uncertain goes with `aprox`, `confianza: baja` or a `nota`, or does not go. A gap that
  cannot be filled with verifiable data stays `sin-datos`, with the reason.
- **Layer order matters.** With no majority entry, the app paints the first entry in force; a small region with layers
  covers the larger one that contains it. Before adding an entry or a whole layer, check what the map will paint there.
- **The same mould.** A gap is filled like its neighbours: if the package has an event for each presidency, the
  missing president gets one too; if the battles of the war cite the battle report, the missing one does too.
- **Extras.** What turns up while researching and falls inside the scope goes in; what falls outside is recorded under
  "To do", not lost.
