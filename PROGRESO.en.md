# TellMAP progress

[Español](PROGRESO.md)

Log of what's done and what's left. Every pending task has its GitHub issue and is on the project board;
`tools/github/organizar.py` creates any that are missing. It's updated with every change: finished items move to **Done**
with their date, and anything new that comes up is added to **To do**, in its block. Each block is sorted by priority,
top to bottom. The overall view by version is in [the plan's roadmap](docs/en/plan.md#roadmap).

## To do

### Now: everything you see can be clicked (0.2)

The interface already looks complete, but several things are just information. The goal of this block: everything you
see responds to a click and leads somewhere useful.

Block finished on November 6, 2026 (see **Done**).

### Map, performance and distribution (0.2)

- [ ] **Test on other machines.** Windows, a Mac with Apple Silicon, a laptop with integrated graphics and a
      touchscreen (a laptop or a tablet running Windows or Linux: there's no Android or iPad version yet; 1.0's web
      version would cover them). The 0.3.0
      `.exe` already passed `--verificar` and the full test with wine; a real Windows machine is still missing. The
      Intel Mac has been tested (see 0.3.4 under **Done**). On Apple Silicon, since 0.3.4, `verificar-macos` takes a
      screenshot and checks it isn't flat, but nobody has looked at the app on a real one yet; a Mac with Radeon hasn't
      been tested either. Before each release, on the Intel MacBook:
      `TellMAP.app/Contents/MacOS/TellMAP -- --captura=x.png --comprobar_dibujo` (the GitHub runner doesn't have that
      GPU). OpenGL mode was already tested on the GTX 1050 Ti: it looks the same as with Vulkan.
- [ ] **Make the macOS app update itself too.** Today on macOS only the data updates; for a new app version, the notice
      leads to the download page. Replacing the binary inside `TellMAP.app` would invalidate its signature: the whole
      `.app` has to be downloaded (a zip), swapped in one go and reopened.
- [ ] **Sign and notarize the macOS version** with an Apple Developer account (99 USD a year), so it opens with a
      double click without going through Privacy & Security. Bautista decides.
- [ ] **See the macOS `.dmg` working.** Since November 11, 2026, `verificar-macos` builds with `hdiutil` a `.dmg` with
      `TellMAP.app` and a shortcut to Applications, after checking the app, and adds it to the release (if that step
      fails, the release keeps the zip). Opening it from Applications avoids *App Translocation* (macOS runs
      quarantined apps from a read-only copy), which will matter the day the macOS app updates itself. It still has to
      be seen in the next published release, opened on the MacBook and, if it works, named in the README as a way to
      install. A `.pkg` installer isn't needed: the app installs nothing outside the bundle, and without notarization
      Gatekeeper blocks it anyway.

### Progressive encyclopedia (0.3)

What the roadmap asked for was done on November 7, 2026 (see **Done**). One task that came up along the way remains:

- [ ] **First real run of `redactar.py`.** The verification (citations, figures, links) was tested with a saved
      response; it still has to run against the API with a credential, on a real draft, and the result has to be
      reviewed in the editor. Whoever runs it decides and pays for it.

### Encyclopedia content

What's covered and what's missing, region by region, is in [docs/en/coverage.md](docs/en/coverage.md), generated
by `tools/enciclopedia/cobertura.py` (and `validar.py` warns if it's out of date).

- [ ] **Fill the gaps in what has been researched** ([the procedure](docs/en/gaps.md)). With the Celtic packages,
      `tools/enciclopedia/huecos.py` found about 4,600 gaps in 27 packages; the first two rounds closed the
      high-priority ones and every region layer except those of nine world regions, and about 620 were decided with
      their reason in `tools/enciclopedia/huecos/decisiones.json`. Still to do: the medium priority (mostly candidate
      people and events for each place and period, series and works), the layers of Central Asia, Brazil, the Caribbean,
      Chile, North America and eastern Paraguay (and, from 2001, those of the Gran Chaco, the Argentine Northwest and
      Patagonia), and the low priority, almost all maintenance: about 575 events without sources and about 700 sources
      without a reading link. Each new round can uncover gaps that did not count before (completing a series makes it a
      topic): rounds go on until each package's report shows nothing but decided gaps.
- [ ] **The contemporary era outside Europe, the United States and Argentina.** The seven packages from November 10,
      2026 cover ideas, science, wars and Argentina; still missing are the 20th-century political history of Brazil,
      Mexico, Chile and the rest of Latin America, China after Mao, independent India, Africa after decolonization and
      Southeast Asia, with their own sources.
- [ ] **More reading links for the contemporary era.** 302 of the 629 new sources have no link: many are still under
      copyright (Perón's texts enter the public domain in 2045) and several sites (PNAS, the Royal Society, the IPCC,
      the Kennedy Library, mises.org, oll.libertyfund.org) return 403 to the checker even though they open in a
      browser. It would take accepting DOIs and official sites that reject programs, checking them by hand, and finding
      the rulings in the cases against kirchnerismo in an official copy that responds.
- [ ] **Ongoing court cases.** As of November 10, 2026: the Cuadernos oral trial still has no verdict, and it's unclear
      whether the Hotesur-Los Sauces and Memorandum with Iran trials have started. Check them every so often and update
      their events.
- [ ] **What was left out of the contemporary topics**: Saint-Simon, Fourier, Owen, Bebel, Zetkin, Kollontai,
      Lumumba, Amílcar Cabral, Deng Xiaoping, Gödel, Wiener, Russell (only as an author), Pessoa, Brecht, Calvino, Eco,
      Onetti, Carlos Fuentes, Clarice Lispector and Galeano. Hawaii has no region (Pearl Harbor falls outside all of
      them).
- [ ] **Religions, cultures and languages for the world regions.** The 46 regions in `regiones-del-mundo.json`
      (Siberia, Japan, Africa, the Americas, Oceania…) have a summary, eras and population, but not those three layers:
      religion, culture or language mode leaves them hatched. Families will need to be added (Shinto, traditional
      African religions, Bantu languages, Austronesian…).
- [ ] **Curated estimates outside Europe and the Near East.** HYDE's per-country series cover everything, but the share
      of world population that also has a specialist estimate for its region (Russell, Urlanis, Butzer, DellaPergola,
      the Han censuses) goes from a quarter in year 1 to almost nothing in BC times and after 1600. Candidates:
      McEvedy and Jones (1978) for the whole world, Durand
      for China and India, Scheidel for the Roman Empire, Livi-Bacci for the Americas. Also without a curated estimate:
      Bohemia, the Balkans, Wallachia and Moldavia, the Baltic and Sicily (Russell and Urlanis give them grouped).
- [ ] **Population by polygon.** The series are for whole countries: a region smaller than its countries (the Rus',
      Mesoamerica, the Andes) gets the population of the full countries, and 24 regions (Siberia, Tibet, southern
      India, Patagonia…) have no series of their own. With the HYDE grids, the population inside each polygon could be
      summed (see 0.4).
- [ ] **Land left without a region** (0.4%): the tip of Chukotka east of the 180th meridian, Svalbard, Hawaii, the
      Malvinas, the Azores and other remote islands, and coastal strips the curated polygons don't reach. The
      per-country detail is in the coverage report.
- [ ] **Medieval sources without a place of writing.** 18 sources (Beowulf, the Poetic Edda, the Song of Roland, the
      Kuzari…) don't appear on the map because their place is unknown; enter the one proposed in the literature, with
      `aprox` and low confidence, or leave them as they are.
- [ ] **More reading links.** 104 checked links for 69 sources; still missing are Spanish translations and texts from
      sites like Fordham's Medieval Sourcebook or the Corpus Thomisticum.
- [ ] **Argentina up to 1912: what is still pending.** No legal link yet: the land laws of 1882-1885, Alberdi's
      Sistema económico y rentístico, Barros's Fronteras y territorios federales and much of the copyrighted
      historiography. No entry for lack of verifiable data: the colonial hospitals of Santiago del Estero and Mendoza,
      the Unitarian violence of 1829 (Rauch) and Quiroga's after La Ciudadela, the River Plate deputies at Cádiz,
      Eduardo Wilde's works, Miron Burgin as a person and Di Meglio's book on the Mazorca. To be checked against the
      text: Lynch's figure (some 2,000 deaths between 1829 and 1852), the casualties at Obligado according to each
      side, the phrase “Quiera el pueblo votar” in the 1912 manifesto, Mitre's and Sarmiento's letters about the
      Chacho, and the year of the Instituto Rosas (1938 or 1941). Several academic works still lack their main
      criticism with its author. Four sources still have no place of writing (the Requerimiento, the Democrates alter,
      Luis Ramírez's letter and Luis de la Cruz's diary). The English of these packages is machine translation and is
      worth reviewing.
- [ ] **Holy Land: what was left out.** Sinai goes with Egypt. Lebanon, Syria, Transjordan, Arabia, the Maghreb and
      Cyprus only have the HYDE, Gapminder and UN per-country series, with no curated estimate. Armenia has layers up
      to 1920: after that, the Turkish part is painted by Anatolia and the Republic of Armenia has no layers. 24
      sources without a place of writing (the New Testament, the Chronicle of Michael the Syrian, bin Laden's
      fatwas…). The digitized scrolls of the Israel Museum (dss.collections.imj.org.il) weren't responding on November
      10, 2026 and their links were removed. The videos in which jihadist groups claim attacks aren't linked, on
      purpose: the events say who claimed them and how, with their Wikipedia article.
- [ ] **The Celts: what was left out.** No link because the sites weren't answering the checker on November 11, 2026:
      LacusCurtius (almost every ancient author has a Perseus, Latin Library or Wikisource link, but not all), Hesperia
      (the Celtiberian and Lusitanian inscriptions), RIIG (the Coligny calendar), the Biblioteca Virtual Cervantes (The
      Siege of Numantia) and legislation.gov.uk (the Welsh acts of 1535, 1993 and 2005). No verified open copy: Lebor
      Gabála, Sanas Cormaic, the Bern scholia, the Senchas Már, the Cáin Adomnáin, the laws of Hywel, the Book of
      Leinster and the Würzburg glosses. No entry for lack of a checked source: the Celts of Silesia, the Noric
      inscriptions, Panóias, Uley, Hayling Island, Corent, Monte Bibele, modern estimates of pre-Roman population by
      author (Beloch, McEvedy and Jones, Millett) and the death toll of Galba's massacre. 18 sources without a place of
      writing (the Mabinogi, the Book of Taliesin, the Senchas Már…). Layers: Islam shows as majority in Anatolia and
      Galatia from 1071 although conversion was gradual; painting the Gallo of Upper Brittany needs its own subregion;
      Egypt, the Levant and the Maghreb have stretches with two majority entries at once. The English of these packages
      is machine translation.

### Storage and downloads

The full plan, with thresholds and where each thing is hosted, is in [docs/en/storage.md](docs/en/storage.md).
Each step is done when its threshold is crossed, not before.

- [ ] **Read packages on a separate thread** when the encyclopedia passes 10 MB or takes more than 1 s to open (the
      app logs it at startup: "Enciclopedia: N elementos… en X ms"), with a compact in-memory index.
- [ ] **Tiles by era and macroregion, download manager and capped cache** (autoload `Descargas`: priority queue, two
      requests at a time, nothing while the timeline is moving, reading in `WorkerThreadPool`, 500 MB cache with
      "Clear cache" in Settings). Needed with 0.4 or once past 50 MB.
- [ ] **Permanent mirrors** of each data version on Internet Archive and Zenodo, with both addresses in the updater's
      manifest.
- [ ] **The reading links left without a copy.** 20 of the 739 not on archive.org have no copy on the Wayback
      Machine (10 from Gutenberg, 4 from penelope.uchicago.edu, 2 from eur-lex): `python3
      tools/enciclopedia/enlaces.py --guardar` asks it to archive them, one every 15 s; on November 11, 2026 it archived
      12 and then throttled the requests. The availability API sometimes misses a copy that exists: running it again
      finds more. `--comprobar`, which lists dead originals, hasn't been run yet either.
- [ ] **Religion by country today** (Pew Research Center, 2010 and 2020) as one more series in the "Current country"
      block, and with it the religion layers of the world regions in the present era.

### Open data at scale (0.4)

- [ ] **Pleiades: what's left.** 91 of the encyclopedia's 438 places are joined to a Pleiades place; the rest don't
      have the identifier in Wikidata or are modern. When ancient places are added, `tools/pleiades/enlazar.py` has to
      be run again (`validar.py` warns if the join names a place that no longer exists, but not if a new one is
      missing). The data is read on the main thread the first time it's needed (some 150 to 270 ms
      when zooming into the map or searching for the first time): move it to a thread along with the packages, when
      that step is done. Pleiades' descriptions are in English. Left out are the 8,800 places without a location, the
      1,400 without dates and those that aren't a point (rivers, mountains, islands, regions, peoples, roads): rivers
      and roads could go in as lines in 0.5.
- [ ] **People from Wikidata.** With place and date of birth and death.
- [ ] **HYDE population grids.** HYDE's per-country series is already in (via Our World in Data, see **Done**). The
      5-arc-minute grid is still missing, with its low and high scenarios, to sum the population inside each polygon,
      give uncertainty ranges and fill a density mode on the map. On November 10, 2026 the Utrecht University server
      (geo.public.data.uu.nl) asked to solve an anti-bot check and the HYDE 3.2 deposit at DANS wasn't responding: it
      has to be downloaded by hand from a browser and left in `raw_data/`.
- [ ] **Vassalage.** Cliopatria's vassalage and dependency relations.

### Movement (0.5)

- [ ] **Movement on the map.** Migrations, trade routes, military campaigns and the spread of religions as animated
      arrows and particles.

### 3D view (0.6)

- [ ] **3D view.** Real relief, water with its own shader, clouds and effects, with the same information as the 2D map.
      Chosen in Settings. Heads-up: since 0.3.4, on Mac it renders with Compatibility (OpenGL), which lacks several
      Forward+ effects (SDFGI and VoxelGI global illumination, volumetric fog, SSR reflections). The view has to be
      designed to look good without them, or Macs that can handle it pick "Advanced" under **Rendering engine**.

### Version 1.0

- [ ] **Downloadable and web versions.**
- [ ] **Guide for adding packages.** So other people can add encyclopedia packages.
- [ ] **Review by specialists.** Of the data, by field and era.

## Done

### November 11, 2026: the first two rounds of gaps

- [x] With `huecos.py` and its procedure, each batch went through a writer, a reviewer who did not write it and a
      corrector before being applied. The reviews found reversed battle results, wrong dates and coordinates (some from
      Wikidata errors, such as the younger Roca born in Córdoba, Spain), layers that painted a disputed thesis as fact
      and one-sided omissions, and all were corrected.
- [x] New entries: the presidents, vice presidents and Buenos Aires governors missing between those present, the 1963,
      2007 and 2011 elections, the Paraguayan War battle by battle, the viceroyalty and the wars of independence (Junín,
      the Quito campaign, Cotagaita, Guayabos), the Platine War; the missing US presidents and Soviet leaders, the wars
      in Indochina, Greece, Bangladesh and Afghanistan, the 1953 coup in Iran; works by Marx, Engels, Lenin and Ayn
      Rand; medieval and Holy Land battles and councils (Fulford, Sluys, Lyon I, Vienne, Ajnadayn, Akroinon, Hunayn),
      the twentieth-century Holy Land conflicts with each side's account, and the Roman governors of Britain with
      Tacitus's citations checked against the Latin.
- [x] Region layers: every era, religion, culture and language that was cut short in Europe, the Near East, Asia,
      Mesoamerica, the Andes and the Río de la Plata, up to today and with their minorities; all of Nubia; fixes to old
      anachronistic entries (Canaanite from 3500 BC, Quechua from 1000 BC); nine new families.
- [x] `consultar.py texto` fetches the full article, to compare two languages; `aplicar` extends a layer that continues
      an identical one instead of duplicating it.

### November 11, 2026: gaps in what has been researched

- [x] **`tools/enciclopedia/huecos.py`**: what is missing inside what each topic has already researched. Each package
      has its scope in `tools/enciclopedia/huecos/alcances.json` (years, regions, core, axes and depth in Wikipedias,
      inferred from the data and checked by hand) and eight detectors search inside it: eras and layers cut short,
      stretches with no events, references, and with `--red` (Wikidata through QLever, with a cache outside git) series
      of offices, successions, parts of a whole, works by authors who have an entry and candidates from the place and
      period, as notable as what the topic already has. What is not filled stays in `decisiones.json` with its reason,
      and a decision can cover a whole group (a series, a whole, an author, an axis). `aplicar` adds what was built
      with the compact format to an existing package, with `parches.json` for entries that already exist
      (`construir.py --escribir` would replace the whole package). The procedure in rounds, with the writer's and
      reviewer's briefs and when to stop, is in [docs/en/gaps.md](docs/en/gaps.md). First mechanical fixes: the
      `autor_id` of Bialet Massé's report and of *Against Apion*, and four works missing from their author's entry.
      Without the network it runs in under a second; the first networked run can take half an hour because QLever
      throttles rapid requests.

### November 11, 2026: the Celts, from their pre-Indo-European roots to their end

- [x] **Nine new packages** with 447 sources (249 primary), 420 people, 432 events, 131 places and 7 regions (the
      encyclopedia goes from 4724 to 6161 entries) and 193 reading links that answered 200, checked against Wikipedia
      and Wikidata with the compact format and with a review of each topic for factual errors, bias and gaps. Almost
      everything known about the ancient Celts comes from Greeks and Romans who were their enemies, from archaeology and
      from Irish and Welsh texts written by monks centuries later: each entry says which source its claims come from,
      and on disputed matters it first says what the documents and archaeology show and then who interprets it how,
      without the victors' barbarian or Celtomaniac romanticism. Each modern work carries its thesis and the criticism
      it received.
      - `celtas-origenes-y-prehistoria`: the first farmers and the megaliths (Stonehenge and Newgrange, which aren't
        Celtic), steppe ancestry, Bell Beaker, the Bronze Age, Hallstatt and its princely seats (Hochdorf, Vix, the
        Heuneburg, the Glauberg) and La Tène; the hypotheses on the origin of the Celtic languages (Gimbutas, Renfrew,
        Mallory, Anthony, "Celtic from the West", Sims-Williams) and the genetic studies, with their archaeological
        critique; the oldest Celtic writing (the Lepontic of Castelletto Ticino, 6th century BC); earlier or neighboring
        peoples and languages (Tartessian, Iberian, Aquitanian, Etruscan, Raetic, Ligurian).
      - `galos-y-galia`: the Celts of Italy according to Polybius and Livy (with what is legend), Massalia, the Arverni,
        Narbonensis, the Cimbri and Teutones, the Gallic War campaign by campaign with about 90 people, Caesar's figures
        as criticized testimony (Henige, Rambaud, Raaflaub, Roymans), Gallic society according to Caesar and to
        archaeology, wine for slaves, Roman Gaul and its revolts, the Claudian tablet and the end of Gaulish.
      - `celtas-del-danubio-y-galacia`: the Boii, Noricum, the Scordisci and Eravisci, the invasion of 280-277 BC and
        Delphi (the pious story apart from the plausible), the kingdom of Tylis, the Galatians, Pergamon and its
        statues, Deiotarus, Paul's letter, the Galatian that Jerome still heard, Hellenistic mercenaries and the theft
        of the Manching gold.
      - `celtas-de-hispania`: Celtiberians, Vaccaei, Vettones, Lusitanians, Gallaeci, Astures and Cantabri with the
        debate on their Celticity, their Iberian neighbors, Segeda, Numantia, Viriathus, Sertorius, the Cantabrian
        Wars, the Botorrita bronzes and the hospitality tokens, Schulten and the myth of Numantia.
      - `celtas-de-britania-e-irlanda`: the Iron Age of the islands, the Roman conquest with each British leader
        (Caratacus, Cartimandua, Boudica, Calgacus), the Picts and the debate on their language, post-Roman Britain with
        Gildas and Arthur as a debate, Ireland (Tara, Emain Macha, ogham, Palladius and Patrick, the laws, the Táin and
        whether it is "a window on the Iron Age") and Wales (the Gododdin, Taliesin, the Mabinogi, Hywel Dda).
      - `religion-celta`: how it formed (what came before, what was inherited according to Indo-European comparison
        with its critiques, what came from contact), the gods with their inscriptions, the druids in every ancient text
        and in modern readings, human sacrifice and the heads with the archaeology for each side, the Coligny calendar
        and the festivals (Samhain and Halloween according to each author), the Irish mythology written by monks and
        the debate between nativists and anti-nativists, Christianization and what really survived.
      - `celtas-en-las-fuentes-antiguas`: how others saw them, from Hecataeus to Jerome: each author with what they
        saw, what they copied and what they wanted, each work with its passages, the images of the defeated Gaul, and
        whether the Celts wrote (Caesar's druidic rule and the inscriptions that did survive).
      - `celtas-legado-e-historiografia`: place names and words of Celtic origin, the Celtic languages up to today's
        censuses, the modern invention of "the Celtic" (Lhuyd, Pezron, Ossian, Iolo Morganwg, neo-druidism), political
        uses (Napoleon III, Ambiorix, Boudica, Galician Celticism, Vichy, Mitterrand), Asterix, the historiography and
        the "Celtosceptic" debate, and the Welsh colony in Chubut.
      - `mundo-celta`: seven subregions (Galatia, Celtiberia, Gallaecia, Cisalpine Gaul, Armorica, Caledonia and
        Noricum) with eras, layers and demography.
- [x] Culture, language and religion layers from the Neolithic in the twelve regions where Celts or their
      predecessors lived (France, Iberia, Britain, Ireland, Germany, Bohemia, Hungary, Romania, the Balkans, Italy,
      Anatolia and Poland), with 42 new families and the prehistoric eras; corrections to what was there (Latin wasn't
      the majority language in Iberia from 218 BC or in Italy from 700 BC, southern Germany was Celtic, Aquitanian
      apart from Basque), each with its source. Demography: Frier, Scheidel, Harper and Alcock, and the ancient figures
      (Caesar, Polybius, Plutarch, Pliny, Livy) as testimony with their critique.
- [x] Review of the existing entries for the period: the Gallic War was about Italy and had been written "in Rome",
      Clontarf had the sides reversed, Geoffrey of Monmouth was at a university that didn't exist, Columbanus in Bobbio
      instead of Luxeuil; Anatolia no longer has two majority religions at once. About 45 entries gained what the
      topics found (passages on the Celts, the Welsh colony in Rawson, Fontana and immigration).
- [x] The compact-format builder accepts bracketed coordinates and places with spaces in "activo".
- [x] The English of the new texts is machine translation; the titles of works published in English are the
      originals.

### November 11, 2026: the wheel, the timeline and touchscreens

- [x] Fixed: **with the mouse over a panel, the wheel zoomed the map** once the panel couldn't scroll any further (at
      the end, Godot passes the wheel upward even past a control that stops the mouse,
      `mouse_force_pass_scroll_events`, and it ended up on the map). Now each panel keeps the wheel and, on top of
      that, the map ignores it (and trackpad gestures) while the mouse is over a panel; `+` and `-` still zoom in and
      out.
- [x] **The timeline moves without changing its scale.** A click picks the year; dragging with the left button (or
      the right one, Shift + wheel, the horizontal wheel or two fingers on the trackpad) moves along the period;
      dragging the year line moves the year, as before; the wheel alone zooms in or out. The cursor shows what the
      drag will do.
- [x] **Touchscreens** (tablets and computers with a touchscreen): one finger moves the map and taps places and marks
      (with a wider margin than the mouse, since the finger covers what it touches), two fingers zoom in or out and
      move the map keeping the place between them underneath, a double tap zooms in, the timeline zooms with two
      fingers, and panels scroll with your finger even when the touch starts on a button (which doesn't get pressed).
      The bubble doesn't stay stuck where you tapped. The welcome screen explains it and suggests making the interface
      bigger in Settings → Size. The automated test checks it with real events, sent the way Godot sends them (the
      mouse it emulates with the first finger, then the touch; that part alone runs in a minute with
      `godot --headless --path . -- --prueba_entrada`); it still has to be tried on a real touchscreen.

### November 11, 2026: reading links that don't get lost

- [x] **Archived copies of the reading links.** `tools/enciclopedia/enlaces.py` looks up on the Wayback Machine the
      copy of every `leer` link and saves it in `data/enciclopedia/archivo.json`: 719 of the 739 links not on
      archive.org have a copy. A source's entry shows a «Copy» button next to each one, in case the original doesn't
      open, and `validar.py` warns how many don't have one. The copies live apart, not as an `archivo` field in each
      `leer` (what the storage plan said): that way the tool doesn't rewrite the packages edited by hand or with the
      editor. It's run by hand before each release.

### November 11, 2026: the ancient places of Pleiades (0.4)

- [x] **27,279 ancient places from [Pleiades](https://pleiades.stoa.org)** on the map (CC BY 3.0): settlements,
      villas, fortifications, sanctuaries, tombs, ports, road stations and bridges, public buildings, mines and
      archaeological sites, each one while it is attested (from 3000 BC to today, mostly from 500 BC to AD 500).
      `tools/pleiades/pleiades.py` downloads the daily dump and writes `data/pleiades/lugares.json` (1.5 MB, one row per
      place). It's only read when zooming into the map or searching. The dots are a MultiMesh filtered by year in a
      shader (a single draw call for all of them) and show up from zoom 1.3, small so they aren't mistaken for the
      encyclopedia's cities; settlement names from 4.5, and all names from 7. Each place has an entry: category,
      years, and live (through the same queue as Wikipedia) its description, its ancient names in each language and
      the Wikipedia summary if Pleiades links one. They can be searched from the bar, there's a switch in the legend
      and credit in Settings and in [Data and licenses](docs/en/data.md). Tested with Vulkan and with OpenGL.
- [x] **Pleiades and the encyclopedia, joined.** `tools/pleiades/enlazar.py` looks up in Wikidata the Pleiades
      identifier (P1584) of each encyclopedia place, from its Wikipedia article, and accepts it if the point is within
      25 km (`data/pleiades/enciclopedia.json`; the packages aren't touched). 91 were joined (León with the camp of
      *Legio VII Gemina*, Mecca with *Macoraba*, Medina with *Iathrippa*): their Pleiades dot is no longer drawn on top
      of the city, and the city's entry adds Pleiades' ancient names.

### November 11, 2026: places with dates and Wikipedia in a queue

- [x] **Modern places no longer show up in every era.** A place without `fundacion` was shown from 3400 BC (Omaha
      Beach on the map of 1350 BC). The fourteen that were like that now have a verified year: buildings and
      institutions, their opening (Once station, 1857; the Comodoro Py courts, c. 1993, when the federal courts moved
      into the former highway agency building); sites and natural places, the event that made them known (Martín
      García, 1516; the Falklands/Malvinas, 1764, the first settlement, since the first sighting is disputed; the Casa
      del Acuerdo, 1852; Omaha, 1944); Rosario, c. 1724, and Loreto, c. 1632. `validar.py` now requires the date for
      libraries, universities, laboratories, institutions and historic sites, the app's editor warns about it, and the
      rule is in the schema. Ancient cities of unknown origin (the Holy Land, Thebes, Heliopolis) stay undated, on
      purpose.
- [x] **Wikipedia requests go through a queue.** The app requested the summary and image of every entry it opened,
      all at once and even after the entry had been closed, and with many in a row Godot's DNS queue ran out (the
      automated test left some 5,100 “Out of resolver queries” warnings). Now `wiki.gd` makes four requests at a
      time, serves the entry being viewed first, drops those of old entries, shares a request when two ask for the
      same thing, and doesn't remember a connection failure (it retries when the entry is reopened). Full test: 0
      warnings.

### November 11, 2026: exported builds, with their typefaces

- [x] Fixed: **exported builds showed Godot's generic typeface** instead of Cinzel and EB Garamond. `TemaUI` read the
      raw `.ttf` with `FileAccess`, and the raw `.ttf` doesn't ship in an export: only its imported version does. From
      source it didn't show, because the file is on disk there. It now loads the imported resource (and reads the
      `.ttf` only if it hasn't been imported yet). Checked with an exported `.pck` opened from a folder without the
      project.

### November 11, 2026: local edits no longer silently hide what's new

- [x] **Notice when local edits hide a new version of a package.** In the exported version, what the encyclopedia
      editor saves is a copy of the package that overrides the bundled one and the one from data updates. Now, when
      the first copy is saved, its base (what was underneath) is saved next to it; if a data update or a new app later
      brings another version of that package, on startup (or when the install finishes) a notice says so and offers
      "Bring in what's new" or "Discard my changes"; the cross leaves it for next time.
- [x] **Bringing in what's new is a three-way merge per item**: for each source, person, event, place or region, what
      the copy changed stays and the rest comes from the new version, in its order; what the copy added goes at the
      end and what the copy deleted stays deleted. If an item changed on both sides the copy's wins, and the notice
      says which ones. Copies saved before this take what is underneath now as their base.
- [x] The automatic test checks the merge and, in exported mode, the base, the detection, bringing in what's new and
      discarding.

### November 11, 2026: religions, cultures, languages and population in the editor

- [x] **The encyclopedia editor covers the whole region.** Besides the main data, the area and the eras, it now edits
      religions, cultures and languages (from, until, name, family, weight and note; the family is picked from a
      dropdown with the ones in `familias.json` for that layer) and the population (year, figure, minimum and maximum,
      source, "ancient testimony" and note). Figures can be typed with dots or spaces as thousands separators.
- [x] **The Our World in Data figures are left alone.** `tools/enciclopedia/poblacion.py` writes them: the editor
      doesn't show them (it says how many there are), keeps them in place and, if the curated estimates change, warns
      that it has to be run again. A new figure is sorted by year and has no empty keys.
- [x] **The editor validates like `validar.py`**: "from" is required, the family must exist in its layer, the weight
      must be majority, significant or minority, and a population needs a whole number above zero and a source. It
      warns if the figure falls outside the range between the minimum and the maximum.
- [x] The automatic test checks those errors and adds a curated figure to a region with an Our World in Data series.
      To review the editor without a screen, `tools/captura.sh` accepts `--editar=region:polonia --desplazar=1200`.

### November 11, 2026: sharp coastlines up close

- [x] **The distance to the coast comes from the polygons** (`tools/pipeline/costa.py`, G channel of `relieve.png`).
      It used to be computed from the pixel mask, with integer distances, and up close the coast and the nautical
      chart lines on the water were staircases. Now the sign comes from the even-odd rule at the exact center of each
      pixel, the distance is the Euclidean distance to the Natural Earth segments (exact up to 2 px from the coast and
      propagated with jump flooding up to 32 px; against brute force, mean error 0.06 px) and the antimeridian cuts
      don't count as coastline. It takes a minute; `python3 costa.py` rewrites only that channel, and `p1_base.py`
      uses it.
- [x] **Nothing is lost for being smaller than a pixel.** With the exact distance, a strip of land narrower than a
      pixel (the Curonian Spit, Hel, the Outer Banks, the Venice Lido) came out dotted or disappeared. Each segment
      measures the width of the land behind it and, if it is under 1.5 px, the land is thickened to that width; the
      3158 islands that fit in a 1.5 px square become a disc of that diameter. Narrow water (fjords, the Bosporus) is
      not widened: it shows as a coastline, and the Bosporus, which used to be closed, now shows.
- [x] **Up close, the coastline is thin.** The shader had minimum widths to hide the steps (a 0.3 texel edge, a 0.45
      coastline and 0.35 waves): at zoom 10 the coast was about 11 screen pixels wide and blurry. Now they are 0.1,
      0.16 and 0.14; from afar nothing changes, because there the term proportional to the zoom wins.
- [x] `relieve.png` goes from 15.5 to 16.7 MB (it is saved with compression level 9; with the old level it was 17.6).
      Like all of `data/`, it reaches installed copies as a data update.

### November 11, 2026: Argentina from its Indigenous peoples to the Sáenz Peña law

- [x] **Seven new packages** with 382 sources, 420 people, 549 events and 110 places (the encyclopedia goes from 3175
      to 4636 items) and 222 reading links that returned 200, checked against Wikipedia and Wikidata with the compact
      format. Each topic was written by one agent and corrected by another, an adversarial reviewer that looked for
      factual errors, bias and gaps (193 corrections). Wikipedia was read critically: disputed events first say what
      the documents show and then who interprets them how, without siding with Mitre's liberal history or with the
      Rosista, Peronist or left-wing revisionism.
      - `pueblos-originarios-del-cono-sur`: archaeology and each people with its language and fate; the Collas and the
        Qullasuyu; Inca rule in the Northwest and Cuyo with the chroniclers who recorded it (Betanzos, Cieza,
        Sarmiento de Gamboa and the Toledan thesis of Inca “tyranny”, Guamán Poma, Garcilaso as a counterpoint); the
        Calchaquí wars and the deportation of the Quilmes; the southern frontier from the malones to the Conquest of
        the Desert, with the official figures of 1879 and what happened to the prisoners; Tierra del Fuego and the Chaco.
      - `rio-de-la-plata-colonial`: exploration, foundations, governorates and audiencias, the law of the Indies and
        the debate on the conquest (Montesinos, Vitoria, Las Casas, Sepúlveda, Valladolid), the Black Legend and the
        White Legend with works from both sides (De Bry, Juderías, Carbia, Hanke, Powell, Keen, Roca Barea,
        Villacañas), the demographic collapse with its estimates, the Jesuits, the University of Córdoba, smuggling
        and the inland customs, the slave trade and the first hospitals.
      - `virreinato-e-independencia`: the twelve viceroys with their terms, the Bourbon reforms, the British
        invasions, the crisis of 1808, the Cortes and the Constitution of Cádiz (“la Pepa”) and its repeal, May 1810
        with its minutes and its legends, the Plan de Operaciones and its controversy, the juntas, triumvirates and
        Supreme Directors, the Assembly of Year XIII, the Congress of Tucumán, Artigas and the campaigns of San Martín
        and Belgrano.
      - `guerras-civiles-y-organizacion-nacional`: the year 1820 and the caudillos, Rivadavia, the war with Brazil,
        the García convention by which the national government gave up the Banda Oriental, the founding of Uruguay,
        Dorrego's execution, the Ferré-Roxas y Patrón polemic and the Federal Pact (the provinces did not want to pay
        the Buenos Aires customs to trade on the Paraná), and from Caseros to Pavón with the Constitution of 1853.
      - `rosas-y-la-confederacion`: Rosas and the sum of public power, the Sociedad Popular Restauradora and the
        Mazorca with its leaders, its victims, the terror of 1840 and 1842, the confiscations and the trial and
        execution of the mazorqueros in 1853; the figures of the Tablas de sangre and their criticism; the blockades
        and Obligado with the reports and the treaties of 1849-1850; the Generation of '37; the causes of Caseros and
        the trial of Rosas (1857-1861).
      - `argentina-1862-1912`: every president with his term, the Paraguayan War with its causes, the secret treaty,
        the Paraguayan losses and the opposition at home, the montoneras, the liberal state, the Generation of '80
        with its writings, the social question and the electoral reform.
      - `historiografia-argentina`: Mitre and López and their polemic, Saldías and Quesada, the New Historical School,
        nationalist and left-wing revisionism, and later academic historiography, each work with what it argues and its
        main criticism.
- [x] Culture, language and religion layers for the Río de la Plata (which had three spans), the Argentine Northwest,
      Patagonia and the Gran Chaco (which had none), from the first settlement to 2000, with 13 new families.
- [x] Critical review of what was already there: 19 fixes to existing entries (the names with “es:” left by the
      builder, Juárez Celman and Roca as brothers-in-law of sisters rather than brothers-in-law, the misquoted
      declaration of independence, the Liminar Manifesto quote, the Charrúas outside the Pampas…), and others from
      what the topics found: the Conquest of the Desert now has sources and official figures, the May Revolution
      tells the cabildos from the 22nd to the 25th, Facundo is a primary source, the Tragic Week, the Patagonia
      Rebelde and Yrigoyen's entry say under which government the repressions happened, and the Sáenz Peña law no
      longer says it ended all fraud.
- [x] The English of the new texts was machine-translated (Claude Haiku, in batches with key checks): Google
      Translate refuses automated queries.

### November 10, 2026: the contemporary era, in seven packages

- [x] **Seven new packages** with 629 sources, 510 people, 440 events and 86 places (the encyclopedia goes from 1510
      to 3175 items), checked against Wikipedia and Wikidata with the same method as the medieval and Holy Land
      packages, and 376 reading links that returned 200:
      - `pensamiento-economico`: from Smith and Alberdi to the full Austrian school (Menger, Böhm-Bawerk, Mises,
        Hayek, Rothbard, Kirzner, Hoppe, Huerta de Soto), Keynes and Keynesianism, Chicago and Friedman,
        libertarianism (Rand, Nozick, *For a New Liberty*), Bretton Woods, Mont Pelerin, ECLAC and Prebisch, and
        Mises's lectures in Buenos Aires (1959).
      - `ideas-politicas`: socialism and communism from Marx to Mao and Che, anarchism from Proudhon to the CNT, the
        Zionism that was missing (Altneuland, Borochov, the Law of Return) and the Bund, fascism and Nazism as
        historical documents, Arendt and Popper, decolonization, civil rights, feminism, environmentalism, Kaczynski's
        manifesto, Fukuyama and Laclau.
      - `argentina-contemporanea`: from Law 1420 to Milei, with the complete Peronist doctrine (The Organized
        Community, the twenty truths, Conducción política, the 1949 Constitution), anti-Peronism, the dictatorship,
        Nunca más and the Trial of the Juntas, Malvinas with resolutions 2065 and 502, the national censuses from 1869
        to 2022, and the cases against kirchnerismo (Vialidad, final since June 10, 2025, Cuadernos, Hotesur, the
        Memorandum, Ciccone, Once, the Ruta del dinero K, López's bags) with the position of those convicted and the
        rulings that weren't convictions; $LIBRA, with the dismissal of October 23, 2026.
      - `ciencia-y-tecnologia`: the publications that opened up technologies, from Planck and Einstein to Turing,
        Shannon, the transistor, DNA, ARPANET, the web, the transformer, AlphaFold and CRISPR, with their Nobel Prizes.
      - `cultura-libre-y-hackers`: GNU and its manifesto, Gates's letter (1976, earlier than GNU: it wasn't a reply),
        the GPL, Linux, the Halloween documents, cypherpunks and Bitcoin, WikiLeaks and Assange, Manning, Snowden,
        Anonymous, Aaron Swartz and Sci-Hub.
      - `guerras-y-orden-mundial`: ultimatums and declarations of war from 1914 to 2022, the treaties and charters of
        the international order (Versailles, the UN, the Universal Declaration, NATO, Maastricht, Paris), the Cold War
        and the wars after it, with the state of Ukraine as of November 10, 2026.
      - `letras-y-pensamiento-del-siglo-xx`: the novels and essays that shaped the century, with the Nobel Prizes in
        Literature, Argentine and Latin American literature, philosophy and the social sciences.
- [x] Fixed: the Río de la Plata polygon left out the Buenos Aires waterfront and La Plata (the Casa Rosada and Plaza
      de Mayo didn't fall in any region); Patagonia now includes the Malvinas Islands, which had no region.
- [x] The app opens the 3263 encyclopedia items (3.8 MB) in 150 to 230 ms.

### November 10, 2026: each country's demographics and the storage plan

- [x] **"Current country" in the "Data" tab**: for any point on the map from 1800 on, the present-day country that
      contains it and its Our World in Data series (current borders): population, life expectancy, children per woman,
      under-5 mortality, median age, urban population, GDP per capita (Maddison), extreme poverty, literacy, years of
      schooling and foreign-born population. Each row shows the latest data published up to the chosen year; clicking
      it opens its chart, and the tooltip gives the definition, the world value and the source. 232 countries, 0.9 MB
      (`data/demografia/paises.json`, from `tools/demografia/series.py`).
- [x] **Country of each map unit**: `tools/pipeline/p4_paises.py` rasterizes the Natural Earth countries over the units
      and assigns each one to the country covering most of its land (229 countries; 782 of 58,076 units have no
      country: ice, disputed areas, coastal edges).
- [x] **Lazy loading**: the per-country series are read the first time the "Data" tab is opened (29 ms), not at
      startup. And at startup the app says how much the encyclopedia weighs and how long it takes (with the
      contemporary era, 3.8 MB in 150 to 230 ms).
- [x] **Population of the regions by decade** in the 20th century and so far in the 21st (previously, every 25 years).
- [x] **`GraficoSerie` for any indicator**: linear or logarithmic scale, with its unit in the tooltip; with
      yearly series it doesn't draw a point for every year.
- [x] **Storage and download plan** ([docs/en/storage.md](docs/en/storage.md)): how much each layer
      weighs (it's not terabytes: TellMAP stores entries and links to the texts), where it's hosted (GitHub releases,
      mirrored on Internet Archive and Zenodo; Google Drive won't work for the app to download from), the rules that
      keep the app from stuttering (nothing downloads while the timeline is moving, a priority queue, a capped cache,
      reading on another thread) and in what order it gets done.
- [x] New vocabulary for the contemporary era: genres `economia`, `politica`, `manifiesto`, `discurso`,
      `tecnologia` and `periodismo`; events `judicial`; places `laboratorio`, `institucion` and `sitio-historico`.
- [x] The automated test opens the "Data" tab for Buenos Aires in 2000 and taps each indicator.

### November 10, 2026: version 0.3.4, it shows up on Mac

- [x] **Tested on an Intel Mac** (MacBook Pro 2017, Intel Iris Plus 640, macOS 13.7.8): with 0.3.2 the window stayed
      dark. Forward+ on MoltenVK started without errors (which is why `fallback_to_opengl3` didn't kick in; it only
      acts if Vulkan fails to start) but drew only the background and the rings of some markers; the data and the
      interface were fine (`--verificar` and `--diagnostico`). Turning off Metal argument buffers changed nothing.
      With Compatibility it renders fully with both drivers (Apple's OpenGL 4.1 and ANGLE over Metal): 145 frames per
      second on "ultra" quality at 2880×1548, 0.65 to 1.1 GB of memory and 2.8 s to load the data.
      `--rendering-driver metal` doesn't exist on that Mac.
- [x] **Compatibility on macOS** (`renderer/rendering_method.macos` in `project.godot`). The app is 2D and uses
      nothing specific to Forward+. It's still a single universal `.app`: the problem depends on the GPU and its
      driver, not the CPU, and splitting Intel from Apple Silicon would only save size.
- [x] **Rendering engine in Settings**: Automatic, Compatible (OpenGL) or Advanced (Vulkan). It's saved in
      `user://motor.cfg`, which Godot reads at startup (`application/config/project_settings_override`) and which
      doesn't touch the signed macOS bundle. When reopening with a different engine, `AvisoGraficos` asks whether it
      looks right and, if nobody answers within 20 s, it switches back to the previous one on its own
      (`scripts/nucleo/motor.gd`). Settings shows the engine in use and the graphics card, and the app writes both to
      the log at startup.
- [x] **The log is written right away** (`application/run/flush_stdout_on_print`): on the Mac, `godot.log` stayed
      empty even after the app had been open for minutes.
- [x] **`verificar-macos` checks that it renders**: it opens the app with a window, takes a screenshot with
      `--comprobar_dibujo` (exits with 1 if it came out nearly flat) and, if it fails, removes the zip from the
      release, as in the other steps. The broken Mac screenshot had a single color; the good ones, between 170 and 200.
- [x] "Restart now" when running from source reopens the project with its `--path`, which Godot doesn't return among
      the arguments.

### November 10, 2026: version 0.3.3, asks before updating

- [x] **The app asks before updating itself.** On opening, if there's a new version or new data, a banner at the top
      center offers it with "Update" and "Not now", and nothing downloads until you say yes. "Not now" (or the X)
      changes nothing and the banner shows up again next time; with "Update", the same banner shows the progress and,
      when it's done, the usual notice remains. "Check now", in Settings, still installs without asking.
      `--preguntar-y-salir=si|no` answers the banner from the command line, and `probar.py` checks that "Not now"
      doesn't download or touch anything (neither data nor executable).
- [x] Fixed: **0.3.2 was announced as 0.3.1.** `version.yml` published the 0.3.2 manifest, but `datos.yml`,
      triggered by the same push, overwrote it two seconds later with one built earlier. The manifest was fixed by
      hand and both workflows now share the `concurrency` group `actualizaciones`.

### November 10, 2026: version 0.3.2, for macOS too

- [x] **Version 0.3.1 published** on GitHub (the first one that updates itself), with the fixed release
      `actualizaciones` and its manifest.
- [x] **macOS version**: universal `TellMAP.app` (Intel and Apple Silicon), ad hoc signed and not notarized.
      It's exported from Linux with the "macOS" preset in `export_presets.cfg` (which requires `import_etc2_astc` in
      `project.godot`; that changes nothing on Linux or Windows because there are no GPU-compressed textures), and
      the `verificar-macos` job in `version.yml` checks the signature and `--verificar` on a GitHub Mac; if it fails,
      it removes the zip from the release. The app doesn't replace itself on macOS (the data does) and "Restart now"
      reopens the bundle with `OS.create_instance`.
- [x] Fixed: **the map tooltip got stuck over the panel**. It only updated on movements that reached the map: when
      moving quickly onto the panel it stayed visible with the last place, covering the text, and when changing the
      year with the mouse over the panel it showed up again. Now it turns off as soon as the mouse moves onto the
      interface, it doesn't overlap the panel when the cursor is on the map right next to it, and the automated test
      checks it.
- [x] Fixed: **the side panel was sometimes taller than the window**, extending below the timeline with the end of
      the text out of reach. It opened by animating `position`, and Godot uses that to recompute all four offsets with
      the size at that moment: if the content was still being built, that height stayed fixed. Now it slides using
      only its horizontal offsets, and the automated test checks that it ends up inside the window.
- [x] Fixed: **religions, cultures and languages "since forever"**. With `"desde": null` the app painted the map
      from 3400 BC: the Balkans with Roman religion in the Neolithic. The 45 entries like that (43 in
      `edad-media.json` and 2 in `tierra-santa.json`) now have the date from which there's a record (the Roman
      conquest, the first mention, the arrival) and a note explaining it; `validar.py` rejects an empty `desde` in
      those layers.

### November 10, 2026: automatic updates

- [x] **The exported version updates itself** ([docs/en/updates.md](docs/en/updates.md)). On opening
      it checks a manifest on GitHub; a new version of the app is downloaded, verified (sha256) and replaces the
      executable, and it opens next time or with "Restart now" (Linux: it's renamed over the old one; Windows: the old
      one becomes `.viejo`). A notice at the top center and an "Updates" section in Settings, with the checkbox to
      turn it off.
- [x] **Data-only updates**: if the data changes and the code doesn't, the app downloads only the files that changed
      (`.gz` with their sha256 in the name) and installs them in the user folder by group (`mapa`, `enciclopedia`),
      where they override the built-in ones (`Datos.ruta()`); the new encyclopedia shows up right away. Each data
      version requires a minimum app version, and downloaded data is discarded automatically if the app ships newer
      data.
- [x] **Publishing**: `tools/actualizacion/publicar.py` (stamps `data/version.json`, builds the manifest and the
      `.gz` files); `version.yml` publishes the manifest with each app version, and `datos.yml`, which is new,
      publishes data only on every push to main that touches `data/`, after running the full test with the code of
      the latest published app.
- [x] **End-to-end test**: `tools/actualizacion/probar.py`, in `pruebas.yml`. It passed from source and with an
      exported Linux executable: it downloads only the group that changed, rejects tampered files and executables,
      replaces itself and starts up again.

### November 10, 2026: the whole world in regions, with its population

- [x] **The missing regions**, with eras, religions, cultures and languages: Armenia (the Armenian highlands) and
      Cilicia (a child of Anatolia) in `tierra-santa.json`; Finland, Sardinia and Corsica, and the Pontic steppe in
      `edad-media.json`. 14 new families (Tengrism, Scythian religion, Armenian, Sardinian, Hurro-Urartian
      languages…).
- [x] **`regiones-del-mundo.json` package**: 46 regions that complete the map (Siberia and the Russian Far East, the
      Caucasus, Central Asia, Tibet, Japan, Korea, Southeast Asia, South India, Africa by region, the Americas outside
      Mesoamerica, the Andes and the Río de la Plata, Oceania), with summary and eras. The polygons come from Natural
      Earth's country borders: each shared border is simplified only once for both sides, and the one bordering a
      curated region snaps to its vertices, so they don't overlap; coastlines can bulge out over the sea but never cut
      into land. Together, the 88 regions cover 99.6% of the land surface (previously, 16%).
- [x] **Population of every region since 10,000 BC**: `tools/enciclopedia/poblacion.py` adds up Our World in Data's
      per-country series (HYDE 3.3 up to 1799, Gapminder v7 up to 1949 and the UN from 1950 on) according to the
      assignment in `poblacion_regiones.json`, at 37 dates. Curated estimates take precedence; for islands that were
      settled late, model values before settlement are dropped (HYDE had people in Iceland before 874). 64 regions
      have their own series and 24 are counted within another one; only Saint Helena and the Falklands are left
      without a region.
- [x] **Coverage report** (`docs/es/cobertura.md`), generated by `tools/enciclopedia/cobertura.py` from the map units
      and the population extract: land covered, what share of the world population has a series and which curated
      estimate applies in each era, one row per region with its layers and items, and what's missing. `validar.py`
      warns if the report or the series are out of date.
- [x] Fixed: the `francia` polygon had the Pyrenees inverted and left out Gascony, Béarn and the Landes; the `arabia`
      one had the border with Jordan backwards and spilled into Jordan. The validator now rejects polygons with
      repeated vertices or self-intersecting edges.

### November 10, 2026: the Holy Land, from Antiquity to today

- [x] **`tierra-santa.json` package**: 7 new regions (the Holy Land, Lebanon, Syria and Transjordan, children of the
      Levant, plus Arabia, the Maghreb and Cyprus) with eras, religions, cultures and languages from prehistory to
      today; 176 sources, 198 people, 172 events and 75 places. Scriptures (Torah, Tanakh, Septuagint, Vulgate, New
      Testament, the Quran and its oldest manuscripts, Bukhari, the Dead Sea Scrolls with the War Scroll, Mishnah and
      Talmud); the first Islamic expansion from the Hijra to Poitiers and the sieges of Constantinople, with the first
      Christian reactions (Doctrina Jacobi, Sebeos, Sophronius, Pseudo-Methodius, the Pact of Umar); the Crusades
      from every side (the Byzantine appeal at Piacenza, Clermont, the Latin chroniclers, the Hebrew chronicles of
      1096, Armenians and Syrians, Usama ibn Munqidh, al-Sulami and the first call to jihad, Saladin); how Europe
      thought about Islam (Peter the Venerable, Riccoldo, Dubois, Manuel II, Cusa, Pius II, Luther, Tasso, Voltaire,
      Lessing, Gibbon, Renan and al-Afghani's reply); the Ottomans from Marj Dabiq to Vienna; the Kabbalah of Safed;
      Zionism and Arab nationalism; the Mandate with the Peel report; the Arab-Israeli wars; the 1988 Hamas Charter
      and its 2017 document; the Islamism of Qutb, Azzam and Bin Laden; claimed attacks, including those on the AMIA
      and the Israeli embassy in Buenos Aires; and dialogue, from Nostra aetate to Regensburg and "A Common Word".
- [x] **Checked against Wikipedia and Wikidata** with the same method as the medieval package; three ancient dates
      were kept (Hillel, Yohanan ben Zakkai, Judah ha-Nasi) where Wikidata contradicts Wikipedia. All 95 reading links
      returned 200: Wikisource in Hebrew, Arabic, Spanish, Greek, Latin, Italian, French, German and English, Project
      Gutenberg, Yale's Avalon Project, Fordham's Medieval Sourcebook, Sefaria, the Holy See and the full Peel report
      on UNISPAL and Internet Archive. Each link says whether it's in the public domain.
- [x] **Demographics of the Holy Land** from DellaPergola (2001), the Mandate censuses (1922 and 1931), the 1945
      Village Statistics and the Israeli and Palestinian statistics offices (2023).
- [x] **New families** in `familias.json`: 14, among them Samaritanism, the Druze, the Alawites, Ismailism, the
      Maronites, Oriental Orthodoxy, the Bahá'í Faith, pre-Islamic Arabian religion and Ibadism; the Philistines and
      the Berbers; South Arabian, the Berber languages and Yiddish.
- [x] **Items from other packages enriched**: the 1099 capture of Jerusalem and Hattin have a full summary and
      sources; Clermont and the conquest of Syria, sources; nine authors already loaded (Bernard, Halevi, Maimonides,
      Nachmanides, Cusa, Urban II, Frederick II, Innocent III, Josephus) get their new works.

### November 10, 2026: medieval Europe, with an emphasis on philosophy

- [x] **`edad-media.json` package**: 15 new regions (the Iberian Peninsula, France, Britain, Ireland, Germany and the
      Low Countries, Scandinavia, Iceland, Poland, Bohemia, Hungary, the Balkans, Wallachia and Moldavia, the Baltic,
      Rus' and Sicily) with eras, religions, cultures and languages from Antiquity to today; 173 sources, 215 people,
      125 events and 120 places, from the sack of Rome to 1500. Philosophy is covered in full: from Augustine and
      Boethius to Eriugena, Anselm, Abelard, Chartres and Saint Victor; al-Andalus and Jewish philosophy (Ibn Gabirol,
      Avempace, Averroes, Maimonides, Crescas); the Toledo translators; the scholasticism of Paris and Oxford with the
      condemnations of 1270 and 1277; Scotus, Ockham, Buridan and Oresme; mysticism (Eckhart, Porete, Julian);
      Byzantium (Photius, Psellos, Palamas, Plethon) and humanism up to Ficino and Pico. As a bonus: chronicles, sagas,
      law, science, rulers, battles, councils, universities and monasteries.
- [x] **Checked against Wikipedia and Wikidata**: each article was resolved on en.wikipedia (redirects and
      disambiguations), the Spanish title and the Wikidata id come from its sitelinks, the coordinates of places and
      events from P625, and life dates were cross-checked with P569/P570 (six of our own dates were kept where
      Wikidata contradicts Wikipedia, such as Ockham's death in 1347). All 104 reading links (Wikisource in Latin,
      Spanish, Italian, Icelandic, German and Russian, and Project Gutenberg) returned 200.
- [x] **Demographics with sources**: Russell (1972) for Iberia, France, Italy, Rus', Poland and Hungary (500-1450)
      and Urlanis (1941) for Britain, Ireland, Scandinavia and the German area (1000-1500), with notes where the two
      series differ or where the figure groups territories together.
- [x] **New families** in `familias.json`: 66, among them Arianism, Catharism, Hussitism, Protestantism and the
      pre-Christian religions of Europe; Germanic, Slavic, Celtic, Andalusi and Jewish cultures; Germanic, Celtic,
      Slavic, Baltic and Uralic languages, Basque and Hebrew.
- [x] Fixed: the `italia` polygon left out Naples and Amalfi; Italy gets its medieval demographics.
- [x] Fixed: an era with no start or no end (`"desde"` or `"hasta"`: `null`, which the schema allows) broke the
      timeline and the panel when selecting a place. Open-ended periods are now shown as "since 1808" or "until 432"
      (`Enciclopedia.rango_de`), and the automated test selects Paris, Dublin and Kyiv to cover it.
- [x] The automated test opens all 919 encyclopedia items in the editor and they come out identical.

### November 7, 2026: progressive encyclopedia (0.3)

- [x] **Encyclopedia editor inside the app** (Settings, or "Edit this entry" on each entry): forms for sources,
      people, events, places and regions, coordinates with a click on the map, validation on save (year 0, ranges,
      ids and references, closed fields) and the same JSON format: a package read and written back comes out
      identical, so the diff shows only what changed. On save, the map and the entries update on their own.
- [x] **Drafts from Wikipedia and Wikidata** (`tools/enciclopedia/borradores.py`): for the most looked-up places
      without an entry, the capital, the key people (the entity's office holders and the best known figures of its
      time), the dated events and the Wikipedia article by section, in the schema's format. Tested with the Ottoman
      Empire: 8 people (Suleiman, Mehmed II, Osman I…), 10 events, 5 capitals and 19 sections.
- [x] **AI-extended entries** (`tools/enciclopedia/redactar.py`): Claude writes the history section by section,
      citing the draft's numbered sources; paragraphs without a valid citation are discarded, years and figures that
      aren't in the cited material are flagged, and the links it suggests are checked. The region displays it with
      citations that lead to each reference.
- [x] **Human review**: the editor opens each draft, computes its study area from the Cliopatria territory, shows the
      verification warnings and only approves it with "I checked every fact…"; the items move to a package with the
      review date and note. `validar.py` won't let an AI entry be published without review and, with
      `--borradores`, also validates the drafts.
- [x] **Questionable data reviewed:**
  - Butzer (1976) estimates 2.9 million for Egypt around 1250 BC from carrying capacity (3 to 3.5 by his urban
    method; Kemp, 4 to 5): corrected, and his series for 3000, 2500, 1800 and 150 BC added, per Snape's summary;
  - Han censuses checked against the Chinese text: the one from year 2 with its two readings (59,594,978 from the
    Hanshu, 57,671,400 by commandery) and the one from 140 with 9,698,630 households and 49,150,220 people;
  - names: "Hashemite Arab Federation" (1415-1439) is Arab Iraq, "Michoacán" (1305-1533) the Purépecha Empire,
    "Wihtgar" the kingdom of the Isle of Wight and "Great Yuan" is Dayuan, which linked to the Yuan dynasty
    (`data/mapa/correcciones.json` stores the corrected links and the reason why);
  - the 33 states that Cliopatria includes twice ("X" and "(X)", same Wikidata) are merged on load: one name, one
    color and no internal border.
- [x] Fixed: the population chart draws the uncertainty band in segments (with an estimate that had no range it
      couldn't be triangulated) and "Part of" shows the name in Spanish.
- [x] The automated test opens all 271 encyclopedia items in the editor and checks they don't change, saves, approves
      a draft and tests the click on the map; the walkthrough adds five editor scenarios (548 controls).
- [x] **The editor also saves in the exported version**: since the packages are inside the executable, it saves
      copies in the user folder that override the built-in ones.
- [x] **Version 0.3.0 exported** for Windows and Linux, with the data inside the executable (a single file), and
      published on GitHub (`version.yml` exported and uploaded the zips).

### November 6, 2026: progressive encyclopedia (0.3)

- [x] **Queue of lookups without an entry** in Settings: how many places were looked up without an entry, the most
      looked-up ones (each one takes you to the place and the year), copy the queue as JSON and open its folder.
      Settings now scrolls.
- [x] Fixed before it shipped: releasing focus from buttons at the moment of pressing made Godot cancel the click.
      The interface walkthrough now presses and releases on different frames, like a person, and catches it.

### November 6, 2026: map (0.2)

- [x] **Clustered markers.** Markers that overlap on screen are grouped into a circle with their count and a colored
      dot per type; clicking zooms the camera in until they separate, and those sharing the exact same point spread
      out in a spiral up close. Clustering uses a grid with neighbors, linear in the number of markers.
- [x] **Sharp borders up close.** With less than one texel per pixel, the unit at each point comes from a bilinear
      vote of the four neighboring texels, and the lines (borders, provinces, selection, mouse) are drawn with a fixed
      on-screen width from the distance to the edge: smooth curves instead of raster stair-steps. From far away it
      still uses the usual method, with a transition between the two.
- [x] **Keyboard shortcuts**: 1 to 5 for the modes, / or Ctrl+F to search, G to go to a year, + and - to zoom, [ and
      ] for the tabs, Backspace to go back from an entry and F1 for help, which now lists them and scrolls so it fits
      in short windows.
- [x] **Everything usable without a mouse.** All buttons, the legend and the dialogs can be navigated with Tab, with
      a focus outline in the theme's color; with the mouse, focus is released automatically, so the spacebar still
      plays.
      The panel scrolls to follow focus.
- [x] **"High contrast" theme**: white text on black (21:1) and yellow accents.
- [x] **Export ready.** `export_presets.cfg` (Linux and Windows, with the `data/*` filter) and the `version.yml`
      workflow. Fixed along the way: the `.gdignore` in `data/mapa` left **out** all the map data on export (the
      `.pck` weighed 1.5 MB); now the relief and the terrain use the `keep` importer and the `.pck` (27 MB) runs the
      full automated test. New `--verificar` option to check an executable.
- [x] `tmap.py revisar` no longer crashes now and then: it was letting the script reload itself while running.

### November 6, 2026: clickable religions, cultures and languages (0.2)

- [x] **`familias` section in the encyclopedia** (`data/enciclopedia/paquetes/familias.json`): 33 religions,
      18 cultures and 29 languages, with name, parent family (Sunni Islam → Islam → Abrahamic religions), fixed color
      and Wikipedia article checked against the API. Languages now have a `familia` too. The validator checks layer,
      parents without cycles, colors and that every family used exists; [ESQUEMA.en.md](data/enciclopedia/ESQUEMA.en.md)
      documents it.
- [x] **Duplicate families merged.** Greek polytheism, Roman polytheism and Egypt's "Greek and Roman religion" fall
      under "Greco-Roman religion", and the legend shows the family name, not each region's.
- [x] **Religion, culture and language entry.** Parent family and the ones it includes, where it is in the selected
      year and with what weight, bars per region along the timeline (click to go to the year), notes, sources from
      those regions and eras, and the Wikipedia summary. While it's open, the map switches to that mode and
      highlights its areas.
- [x] **Clickable legend.** Hovering highlights the family on the map; clicking opens its entry. With many families
      it shows the most widespread ones and a button to see the rest.
- [x] **Clickable Data tab.** The place's religion, culture and language in rows with their color; each row opens its
      entry.
- [x] **Map click by mode.** In religion, culture or language, the panel opens the Data tab with the family at that
      point marked and a button to its entry, and the map highlights that family.
- [x] **Search** for religions, cultures and languages.
- [x] **Clickable timeline.** Source and event marks show their name (nearby ones, together) and open their entry
      with a click, besides taking you to the year.
- [x] **Political entity entry.** From the Summary tab, the Data link or search: area in the selected year, territory
      over time (chart with click to go to the year), maximum extent, places, events and sources from its territory
      while it belonged to it, links to Wikidata and Seshat, and Wikipedia. While it's open, the political map
      highlights it.
- [x] **Population chart** with the value, range and source of each estimate on hover.
- [x] Notes with BC dates no longer end in "a. C..".
- [x] **Walkthrough of the whole interface** (`scripts/nucleo/recorrido.gd`, `tmap.py recorrido` and inside the
      automated test): a real click on 401 controls in 17 scenarios; it fails if any of them errors out or does
      nothing. While it runs, links don't open the browser (they all go through `Estado.abrir_url`) and there are no
      animations.
- [x] **Regions with each era's actual outline.** In the layer modes, inside the region's polygon, whatever belongs
      to a Cliopatria entity that year is painted solid and the rest hatched in the same color: Egypt in 1350 BC looks
      like the Nile valley and not like a rectangle. Cliopatria was chosen over Natural Earth because modern borders
      (Egypt's are almost straight) say nothing about the era.
- [x] Faster in the layer modes: map values are stored according to which family applies in each region, so playing
      through years or returning to the mode doesn't recompute them.
- [x] The mode buttons at the top follow the mode even when it changes from somewhere else (an entry, the bridge).
- [x] Fixed: entries with `"hasta": null` (Egypt since the year 1000) caused an error in the layer modes. The
      automated test now goes through all 80 family entries, the legend and the click by mode, also in 1500.

### November 6, 2026: GitHub and landing page

- [x] **Project landing page** in `docs/index.html`, published with GitHub Pages from `main/docs`, with the app's
      look (Marble and Bronze, Cinzel and EB Garamond, real screenshots).
- [x] **Continuous integration**: on every push and pull request, it validates the encyclopedia, compiles the scripts
      and runs the automated test (`.github/workflows/pruebas.yml`).
- [x] Issue forms (bug, idea, data), pull request template and contribution guide.
- [x] `tools/github/organizar.py`: labels, milestones, one issue per task, board, Pages, security and the 0.1 release.

### November 6, 2026: logs and leaks

- [x] **Logs in `.godot/registros/`** for every run of the app and the editor, with traces, and `tmap.py registros`
      to read them. On close, the app records the nodes left unfreed and which script they come from.
- [x] **No leaks on close.** Godot reported hundreds of unfreed objects ("RIDs were leaked"). The causes: Wikipedia
      text that got lost if the panel changed while the image was downloading, the population chart being created
      even when it wasn't shown, and a reference cycle in the bridge. Now the full test and a windowed session close
      without a single warning.

### November 6, 2026: tools for working

- [x] **Bridge** (`addons/tellmap_puente`, `tools/godot/tmap.py`): drive the app and the editor from the terminal or
      with an agent. It covers year, camera, selection, clicks, screenshots, errors with traces, reloading shaders and
      the encyclopedia, and GDScript. In the editor it adds a "Bridge" panel with buttons for the automated test and
      validation.
- [x] **Startup that imports on its own.** A freshly downloaded clone, or one with new classes, no longer fails with
      "Parse error": the app imports the project and reopens itself.
- [x] `tmap.py revisar` (compiles all the scripts without opening the app) and `tmap.py doc` (the exact API of the
      installed Godot version).
- [x] [Contribution guide](docs/en/contributing.md) and this log.

### November 6, 2026: version 0.1

- [x] 2D world map with the Miller projection, shaded relief, rivers, smoothed coastlines and nautical chart lines on
      the water.
- [x] Political borders from 3400 BC to 2024 from Cliopatria: 58,076 units, 1,001,996 changes of ownership and about
      3 ms per year.
- [x] Curved names that follow the shape of the territory, in Spanish (1587 entities), and that fade out as you zoom
      in.
- [x] Timeline with playback, speeds, global and local eras, events and sources.
- [x] Side panel with five tabs (Summary, History, Sources, People and events, Data) and entries for source, person,
      event, place and region.
- [x] Live Wikipedia summaries, Spanish first, and cached.
- [x] Initial encyclopedia: an ancient Egypt pilot and a sample of eleven regions (15 regions, 76 sources, 55 people,
      78 events, 47 places), with its validator.
- [x] Religion, culture and language modes (where there's data), estimated population with a chart, and ancient
      testimonies kept separate.
- [x] Three visual themes (Marble and Bronze, Illuminated Parchment, Ink and Brass) and four graphics quality levels.
- [x] Search, settings, welcome screen and help.
- [x] Automated test (`--prueba`) and headless screenshots (`tools/captura.sh`).
- [x] README in Spanish and English, plan, data and licenses, and the answer about Grokipedia (it has no official API).
