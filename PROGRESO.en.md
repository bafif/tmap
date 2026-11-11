# TellMAP progress

[Español](PROGRESO.md)

What's left, by block and in order of priority, and the milestones of each version with the decision behind them and
why. Every pending task has its GitHub issue, created by `tools/github/organizar.py`. The overall view by version is in
[the plan's roadmap](docs/en/plan.md#roadmap).

## To do

### Map, performance and distribution (0.2)

- [ ] **Test on other machines.** It's tested on Linux, with Vulkan and with OpenGL, and on an Intel Mac. Still
      missing: a real Windows machine (the `.exe` passes `--verificar` and the full test under wine), a Mac with Apple
      Silicon (in continuous integration, `verificar-macos` takes a screenshot and checks it isn't flat, but nobody has
      looked at the app on a real one), a Mac with Radeon, a laptop with integrated graphics and a touchscreen (a
      laptop or a tablet running Windows or Linux: there's no Android or iPad version). Before each release, on an
      Intel Mac: `TellMAP.app/Contents/MacOS/TellMAP -- --captura=x.png --comprobar_dibujo` (GitHub's runners don't
      have that GPU).
- [ ] **Make the macOS app update itself too.** On macOS only the data updates; for a new app version, the notice
      leads to the download page. Changing the executable inside `TellMAP.app` invalidates its signature: the whole
      `.app` has to be downloaded (a zip), swapped in one go and reopened.
- [ ] **Sign and notarize the macOS version** with an Apple Developer account (99 USD a year), so it opens with a
      double click without going through Privacy & Security.
- [ ] **See the macOS `.dmg` working.** `verificar-macos` builds with `hdiutil` a `.dmg` with `TellMAP.app` and a
      shortcut to Applications, after checking the app, and adds it to the release (if that step fails, the release
      keeps the zip). It still has to be opened on a Mac and, if it works, offered in the README as a way to install.
      Installing into Applications avoids *App Translocation* (macOS runs quarantined apps from a read-only copy),
      which matters for the macOS app to update itself. A `.pkg` isn't needed: the app installs nothing outside the
      bundle and, without notarization, Gatekeeper blocks it anyway.

### Progressive encyclopedia (0.3)

- [ ] **First real run of `redactar.py`.** The verification (citations, figures, links) is tested with a saved
      response; it still has to run against the API on a real draft, and the result has to be reviewed in the editor.
      It needs an API credential, paid for by whoever runs it.

### Encyclopedia content

What's covered and what's missing, region by region, is in [the coverage report](docs/en/coverage.md).

- [ ] **The contemporary era outside Europe, the United States and Argentina.** Still missing are the 20th-century
      political history of Brazil, Mexico, Chile and the rest of Latin America, China after Mao, independent India,
      Africa after decolonization and Southeast Asia, with their own sources.
- [ ] **More reading links for the contemporary era.** 302 of the 629 contemporary sources have no link: many are
      still under copyright (Perón's texts enter the public domain in 2045) and several sites (PNAS, the Royal Society,
      the IPCC, the Kennedy Library, mises.org, oll.libertyfund.org) return 403 to the checker even though they open
      in a browser. It would take accepting DOIs and official sites that reject programs, checking them by hand, and
      finding the rulings in the cases against kirchnerismo in an official copy that responds.
- [ ] **Ongoing court cases.** The events give the state as of November 2026: the Cuadernos oral trial without a
      verdict, and unconfirmed whether the Hotesur-Los Sauces and Memorandum with Iran trials have started. They need
      checking every so often, with their events updated.
- [ ] **What was left out of the contemporary topics**: Saint-Simon, Fourier, Owen, Bebel, Zetkin, Kollontai,
      Lumumba, Amílcar Cabral, Deng Xiaoping, Gödel, Wiener, Russell (only as an author), Pessoa, Brecht, Calvino, Eco,
      Onetti, Carlos Fuentes and Clarice Lispector (Galeano now has an entry). Hawaii has no region (Pearl Harbor falls
      outside all of them).
- [ ] **Religions, cultures and languages for the world regions.** The 33 non-American regions in
      `regiones-del-mundo.json` (Siberia, Japan, Africa, Oceania…) have a summary, eras and population, but not those
      three layers: religion, culture or language mode leaves them hatched. Families are missing (Shinto, traditional
      African religions, Bantu languages, Austronesian…).
- [ ] **Indigenous peoples of the Americas: what is left to confirm.** Figures the reviewers could not check against
      the text were left attributed and with medium confidence: those tortured and killed at the Maní auto-da-fé (about
      4,500 and 158, according to Clendinnen), the “more than forty thousand” people of one day of the siege of
      Tenochtitlan in Cortés's third letter, the skulls of the Huey Tzompantli (INAH's and Wikipedia's figures differ),
      the half million Indians taken out of Nicaragua (Radell), Cook's and Dobyns's figures for Peru in 1520, the 47-67 %
      of the carbon in Koch et al. (2019), the deaths from the 1733 smallpox in Greenland, the Powhatan population and
      the colonial dead of King Philip's War, Mabila and Awa'uq. Also to be confirmed: the 1570 law issued at Évora,
      Pedro Claver's final vows (1622), the Colegio del Príncipe (1619 or 1620), Antonio Ricardo's arrival in Lima
      (1580 or 1581), Santillán's tasa (1558 or 1559), the Juzgado General de Indios (1585 or 1591-1592) and whether
      Vivar attributes the killing of the 1541 hostages to Inés Suárez. Lewy (2004) could not be read (Commentary
      returns 403). No legal reading link although they are in the public domain: Staden, Carvajal, Acuña, Antonil,
      Nóbrega, Sandoval, Mariño de Lobera, Góngora Marmolejo, Otermín's autos and the Acoma trial. The 280 links in
      these packages have no archived copy yet. On the map, El Tajín falls in Aridoamerica and La
      Venta, Izapa and Chiapa de Corzo in the Maya area, because the polygons are approximate; the Columbus monument is
      still at its old site in Buenos Aires. The English is machine translation and should be reviewed.
- [ ] **The full test with the whole encyclopedia.** With the Indigenous peoples of the Americas it has not yet run end
      to end, in Spanish or in English: it gets as far as the keyboard shortcuts (every entry, the families, legend,
      timeline, charts and markers), and the editor step, which piled up a whole section's forms until it went over
      3.8 GB, now waits one frame every 50 items, but it still has to be seen finishing.
- [ ] **Curated estimates outside Europe and the Near East.** HYDE's per-country series cover everything, but the share
      of world population that also has a specialist estimate for its region (Russell, Urlanis, Butzer, DellaPergola,
      the Han censuses) goes from a third in year 1 to almost nothing in BC times and after 1600. Candidates: McEvedy
      and Jones (1978) for the whole world, Durand for China and India, Scheidel for the Roman Empire, Livi-Bacci for
      the Americas. Also without a curated estimate: Bohemia, the Balkans, Wallachia and Moldavia, the Baltic and
      Sicily (Russell and Urlanis give them grouped).
- [ ] **Population by polygon.** The series are for whole countries: a region smaller than its countries (the Rus',
      Mesoamerica, the Andes) gets the population of the full countries, and the regions that sit inside another
      (Siberia, Tibet, southern India, Patagonia…) have no series of their own. With the HYDE grids, the population
      inside each polygon could be summed (see 0.4).
- [ ] **Land left without a region** (0.4%): the tip of Chukotka east of the 180th meridian, Svalbard, Hawaii, the
      Azores and other remote islands, and coastal strips the curated polygons don't reach. The per-country detail is
      in the coverage report.
- [ ] **Medieval sources without a place of writing.** 18 sources (Beowulf, the Poetic Edda, the Song of Roland, the
      Kuzari…) don't appear on the map because their place is unknown; enter the one proposed in the literature, with
      `aprox` and low confidence, or leave them as they are.
- [ ] **More reading links.** For the medieval sources, Spanish translations and texts from sites like Fordham's
      Medieval Sourcebook or the Corpus Thomisticum are still missing.
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
      fatwas…). The Israel Museum's digitized scrolls (dss.collections.imj.org.il) don't respond and have no link. The
      videos in which jihadist groups claim attacks aren't linked, on purpose: the events say who claimed them and how,
      with their Wikipedia article.
- [ ] **The Celts: what was left out.** No link because the sites don't answer the checker: LacusCurtius (almost every
      ancient author has a Perseus, Latin Library or Wikisource link, but not all), Hesperia (the Celtiberian and
      Lusitanian inscriptions), RIIG (the Coligny calendar), the Biblioteca Virtual Cervantes (The Siege of Numantia)
      and legislation.gov.uk (the Welsh acts of 1535, 1993 and 2005). No verified open copy: Lebor Gabála, Sanas
      Cormaic, the Bern scholia, the Senchas Már, the Cáin Adomnáin, the laws of Hywel, the Book of Leinster and the
      Würzburg glosses. No entry for lack of a checked source: the Celts of Silesia, the Noric inscriptions, Panóias,
      Uley, Hayling Island, Corent, Monte Bibele, modern estimates of pre-Roman population by author (Beloch, McEvedy
      and Jones, Millett) and the death toll of Galba's massacre. 18 sources without a place of writing (the Mabinogi,
      the Book of Taliesin, the Senchas Már…). Layers: Islam shows as majority in Anatolia and Galatia from 1071
      although conversion was gradual; painting the Gallo of Upper Brittany needs its own subregion; Egypt, the Levant
      and the Maghreb have stretches with two majority entries at once. The English of these packages is machine
      translation.
- [ ] **People and sources at the center of their city.** In Buenos Aires about 250 people and 240 sources still
      share one point (and hundreds in London, Paris and Rome), plus some 430 events with no single site. Where it is
      known for sure, people could go to their institution (a university, a newspaper) and sources to the place where
      they were written; meanwhile, the group list shows them.

### Storage and downloads

The plan, with thresholds and where each thing is hosted, is in [Storage and downloads](docs/en/storage.md). Each step
is done when its threshold is crossed, not before.

- [ ] **Read packages on a separate thread** when the encyclopedia passes 10 MB or takes more than 1 s to open (the
      app logs it at startup: "Enciclopedia: N elementos… en X ms"), with a compact in-memory index. It is already
      over 10 MB (10.1 MB, 8,911 items in 43 packages), although it opens in about 400 ms.
- [ ] **Tiles by era and macroregion, download manager and capped cache** (autoload `Descargas`: priority queue, two
      requests at a time, nothing while the timeline is moving, reading in `WorkerThreadPool`, 500 MB cache with
      "Clear cache" in Settings). Needed with 0.4 or once past 50 MB.
- [ ] **Permanent mirrors** of each data version on Internet Archive and Zenodo, with both addresses in the updater's
      manifest.
- [ ] **The reading links left without a copy.** Some links (from Gutenberg, penelope.uchicago.edu, eur-lex…) have no
      copy on the Wayback Machine; `validar.py` says how many. `python3 tools/enciclopedia/enlaces.py --guardar` asks
      it to archive them, one every 15 s, and the Wayback Machine throttles the requests after a few. The
      availability API sometimes misses a copy that exists: running it again finds more. `--comprobar`, which lists
      dead originals, still has to be run.
- [ ] **Religion by country today** (Pew Research Center, 2010 and 2020) as one more series in the "Current country"
      block, and with it the religion layers of the world regions in the present era.

### Open data at scale (0.4)

- [ ] **Pleiades: what's left.** Part of the encyclopedia's places are joined to a Pleiades place; the rest don't have
      the identifier in Wikidata or are modern. When ancient places are added, `tools/pleiades/enlazar.py` has to be
      run again (`validar.py` warns if the join names a place that no longer exists, but not if a new one is missing).
      The data is read on the main thread the first time it's needed (some 150 to 270 ms when zooming into the map or
      searching for the first time): move it to a thread along with the packages, when that step is done. Pleiades'
      descriptions are in English. Left out are the 8,800 places without a location, the 1,400 without dates and
      those that aren't a point (rivers, mountains, islands, regions, peoples, roads): rivers and roads could go in as
      lines in 0.5.
- [ ] **People from Wikidata.** With place and date of birth and death.
- [ ] **HYDE population grids.** HYDE's per-country series is already in (via Our World in Data). The 5-arc-minute
      grid is still missing, with its low and high scenarios, to sum the population inside each polygon, give
      uncertainty ranges and fill a density mode on the map. The Utrecht University server (geo.public.data.uu.nl)
      asks to solve an anti-bot check and the HYDE 3.2 deposit at DANS doesn't respond: it has to be downloaded by
      hand from a browser and left in `raw_data/`.
- [ ] **Vassalage.** Cliopatria's vassalage and dependency relations.

### Movement (0.5)

- [ ] **Movement on the map.** Migrations, trade routes, military campaigns and the spread of religions as animated
      arrows and particles.

### 3D view (0.6)

- [ ] **3D view.** Real relief, water with its own shader, clouds and effects, with the same information as the 2D map.
      Chosen in Settings. On Mac it renders with Compatibility (OpenGL), which lacks several Forward+ effects (SDFGI
      and VoxelGI global illumination, volumetric fog, SSR reflections): the view has to look good without them, or
      Macs that can handle it pick "Advanced" under **Rendering engine**.

### Version 1.0

- [ ] **Downloadable and web versions.** The downloadable ones are done; the browser version is still missing.
- [ ] **Guide for adding packages.** So other people can add encyclopedia packages.
- [ ] **Review by specialists.** Of the data, by field and era.

## Done

### The encyclopedia

New packages reach installed copies as data updates, without waiting for an app version. What each one covers is in
[the encyclopedia](docs/en/encyclopedia.md#whats-there-today).

- **The Indigenous peoples of the Americas and their colonization**: fourteen packages, from the peopling of the
  continent to the independence of each area (and at least to the end of the 18th century where colonial rule went
  on), with neither Black Legend nor White Legend. Disputed matters first
  say what the documents and archaeology show and then who interprets them how; the sweeping theses (“Spain brought
  civilization”, “it was a genocide”) come with their authors and their criticism. Where there is a record, they cover
  war, sacrifice and slavery among Indigenous peoples, the civilizing work of each power (and whether its laws were
  enforced) and its documented abuses; myths that the documents refute have an entry that says so. North America is
  divided into its ten culture areas, the Maya area and Brazilian Amazonia are added, and every American region has
  culture, language and religion layers. The American entries that were already there follow the same criteria
  (Mesoamerica is also defined by sacrifice, the viceroyalty eras tell the demographic collapse, and the Cry of
  Dolores was given in the name of Ferdinand VII).
- **Events at the site where they happened**: 209 events that sat at the center of their city move to the precise
  place, with the coordinates of its Wikipedia article: the Fort or the Casa Rosada for viceroys and presidents, the
  Congress building of the time for laws, the court for trials, the field for battles. What has no single site (an
  election, an epidemic, a war) stays in the city.
- **The Celts, from their pre-Indo-European roots to their end**: nine packages, with culture, language and religion
  layers from the Neolithic on in the twelve regions where Celts or their forerunners lived. Almost everything known
  about them comes from Greeks and Romans who were their enemies, from archaeology and from texts written by monks
  centuries later: each entry says which source its claims come from, and ancient figures go in as testimony with
  their criticism.
- **Argentina from its Indigenous peoples to the Sáenz Peña law**: seven packages, with every viceroy and president.
  On disputed matters, each entry first says what the documents show and then who reads them how, without siding with
  Mitre's liberal history or any revisionism; each work of historiography carries its thesis and its main criticism.
- **The contemporary era, in seven thematic packages** (economic thought, political ideas, Argentina since 1880,
  science and technology, free culture, wars and world order, 20th-century letters and thought). Disputed topics say
  who holds what and the main criticism; rulings give the court, what it decided and whether it's final.
- **The whole world in regions, with its population**: 46 regions built from Natural Earth's country borders complete
  the map (88 regions over 99.6% of the land). Each shared border is simplified once for both sides, so regions don't
  overlap. The population of each region since 10,000 BC adds up Our World in Data's per-country series, and curated
  specialist estimates take precedence over it.
- **The Holy Land, from Antiquity to today**: scriptures, the first Islamic expansion, the Crusades from every side,
  Zionism and Arab nationalism, and modern documents.
- **Medieval Europe, with an emphasis on philosophy**: from Augustine and Boethius to humanism, with al-Andalus, Jewish
  philosophy and Byzantium.
- **Checked against Wikipedia and Wikidata**: since medieval Europe, each package resolves its Wikipedia articles,
  takes ids, coordinates and Spanish titles from Wikidata, and cross-checks lifespans; where Wikidata contradicts
  Wikipedia, the better-supported date stays. Only reading links that respond go in.
- **Families of religions, cultures and languages** (`familias.json`), with a hierarchy and a fixed color, so the same
  religion always has the same color and the legend groups by family.

### Next version

- **The editor test no longer piles up forms**: it waits one frame every 50 items, because what is taken out of the
  scene is only freed at the end of the frame, and with the whole encyclopedia a single section went over 3.8 GB.

- **Nothing on the map before its time**: a person whose `activo` has `desde` and `hasta` shows up at their place of
  activity only in those years; before, where they were born, and after, where they died. Events appear in their own
  year, and the map button and the search take you to a year and a point where they can be seen. So the map never
  shows anyone where they had not arrived yet.
- **Updates in plain sight**: the banner that offers them sits above everything, the check repeats every hour while
  the app is open, and if the startup check fails, a notice says so; every result goes to the log. From source,
  `user://` is a different folder, so tests don't change the installed TellMAP's settings.
- **27,279 ancient places from [Pleiades](https://pleiades.stoa.org)** (0.4), each one while it's attested and with
  its own entry. They're read only when zooming into the map or searching, and drawn as a MultiMesh filtered by year
  in a shader, in a single draw call.
- **Pleiades joined to the encyclopedia** through the Pleiades identifier in Wikidata (P1584), if the point is less
  than 25 km away. The join goes in `data/pleiades/enciclopedia.json` and not in the packages, which are edited by hand
  or in the editor.
- **Archived copies of reading links**: each link has a "Copy" button next to it that leads to the Wayback Machine.
  The copies go in `data/enciclopedia/archivo.json` and not in each `leer`, so `enlaces.py` doesn't rewrite packages.
- **Modern places have a date**: libraries, universities, laboratories, institutions and historic sites carry
  `fundacion` (the validator and the editor require it), because without it they showed up in every era.
- **Wikipedia requests are queued**: four at a time, the entry being viewed first and none for entries already
  closed, because many requests at once exhausted Godot's DNS queue.
- **The wheel, the timeline and touchscreens**: the wheel over a window no longer moves the map; the timeline is
  scrolled by dragging without changing its scale; a finger moves the map, zooms and taps places, with a wider margin
  than the mouse. The automatic test sends touch events the way Godot sends them.
- **A `.dmg` for macOS** in every release, alongside the zip.
- **The list of a marker group**: clicking a group opens in the panel the list of its events, people and sources,
  each with its card, and a button that zooms the map in until they separate; going back from a card returns to the
  list.

### 0.3.5 (November 11, 2026)

- **In Spanish and English.** The app picks the computer's language and it can be changed in Settings. The
  encyclopedia is translated in a separate layer per package, with the hash of the Spanish text, so packages stay a
  single source and an outdated translation is detected on its own. The project page, the documents and the GitHub
  templates are in both languages too, and continuous integration fails if a text or a paired document is missing.
- **Sharp coastlines up close**: the distance to the coast comes from Natural Earth's polygons rather than the pixel
  mask, which made staircases up close. Land narrower than 1.5 px is thickened to that width so isthmuses and small
  islands don't disappear; narrow water isn't widened.
- **The editor covers the whole region**: religions, cultures, languages and population, with the same validation as
  `validar.py`. Our World in Data figures aren't shown or touched: `poblacion.py` writes them.
- **A notice when local edits hide a new version of a package**: the edited copy keeps its base, and if another
  version of the package arrives, it offers to bring the new one in (a three-way merge per item) or discard the
  changes, so an old copy doesn't silently hide what an update brings.
- Fixed: exported builds came out with Godot's generic typeface.

### 0.3.4 (November 10, 2026)

- **macOS renders with Compatibility (OpenGL).** On an Intel Mac, Forward+ over MoltenVK didn't draw the map, and the
  app is 2D and uses nothing specific to Forward+. It's still a single universal `.app`: the problem depends on the
  GPU, not the CPU.
- **Rendering engine in Settings** (Automatic, Compatible or Advanced), saved in `user://motor.cfg` so the signed macOS
  bundle isn't touched. If nobody confirms within 20 s that it looks right, it switches back on its own.
- **`verificar-macos` checks that it draws**: it opens the app on a GitHub Mac and, if the screenshot is nearly flat,
  pulls the zip from the release.
- **"Current country" in the "Data" tab**: since 1800, the Our World in Data series for today's country containing
  the point (population, life expectancy, GDP per capita, schooling…). They're read when the tab opens, not at
  startup.
- **[Storage and downloads plan](docs/en/storage.md)**: GitHub releases as the main host, Internet Archive and Zenodo
  as mirrors, and nothing downloaded while the timeline is moving.

### 0.3.3 (November 10, 2026)

- **The app asks before updating** ("Update" or "Not now"), so nothing is downloaded without permission. "Check now",
  in Settings, installs without asking, since it's already a request.
- The two workflows that publish the manifest share a `concurrency` group, so one doesn't overwrite the other.

### 0.3.2 (November 10, 2026)

- **macOS version**: a universal `TellMAP.app`, ad hoc signed and not notarized, exported from Linux and checked on a
  GitHub Mac before it stays in the release. On macOS the data updates itself, not the app, because changing the
  executable invalidates the signature.
- **Nothing "since forever"**: a region's religions, cultures and languages require `desde`, with the date from which
  there's a record, because a `null` painted the map from 3400 BC.
- Fixed the map tooltip left on top of the panel and the panel that was sometimes taller than the window; the
  automatic test checks both.

### 0.3.1 (November 10, 2026)

- **[Automatic updates](docs/en/updates.md)**: a new app version is downloaded, verified with sha256 and replaces the
  executable. If only the data changed, only what changed is downloaded, without reinstalling.
- **Data publishes itself**: every push to `main` that touches `data/` publishes a data version if the full test
  passes with the code of the latest published app; if it doesn't, that data waits for the next app version.
- **Coverage report** generated from the data, which `validar.py` flags when it's out of date.
- **The validator rejects polygons with repeated vertices or crossing sides**, which with the even-odd rule leave
  pieces of the region out.

### 0.3.0 (November 7, 2026)

It brings what was planned for 0.2, which had no release of its own, and the progressive encyclopedia.

- **Encyclopedia editor inside the app**, with forms, coordinates with a click on the map and validation on save. It
  writes the same JSON (a package read and written back comes out identical), so the diff shows only what changed;
  in the exported build it saves copies in the user folder.
- **Queue of lookups without an entry**, which stays on the computer, and **drafts from Wikipedia and Wikidata** for
  what's looked up most (`borradores.py`).
- **Extended entries with AI** (`redactar.py`), without trusting the model: paragraphs without a valid citation are
  dropped, years and figures not in the cited text are flagged and links are checked. None passes the validator
  without human review.
- **Doubtful data reviewed**: Egypt's population according to Butzer, the Han censuses and Cliopatria's wrong links,
  which are corrected in `data/mapa/correcciones.json` with the reason. The 33 states Cliopatria lists twice are
  merged on load.
- **Everything you see can be clicked**: entries for religions, cultures, languages and polities, the legend, the
  Data tab and the timeline.
- **Regions with the real outline of each era**: in layer modes, inside the polygon, what belongs to a Cliopatria
  entity that year is painted solid and the rest hatched. Cliopatria rather than Natural Earth, because modern borders
  say nothing about the era.
- **Sharp borders up close**, **clustered markers**, **keyboard shortcuts**, **everything usable without a mouse** and
  a **high contrast** theme.
- **Walkthrough of the whole interface**: the automatic test really clicks every control and fails if any gives an
  error or does nothing.
- **Single-file executables** for Linux and Windows, with the data inside, exported and published by `version.yml`.

### 0.1.0 (November 6, 2026)

- 2D map with the Miller projection, relief, rivers and coasts, and borders from 3400 BC to 2024 from Cliopatria:
  58,076 units and a million changes of hands, at about 3 ms per year.
- Curved names that follow the shape of the territory, a timeline with eras, events and sources, and a side panel with
  five tabs.
- Live Wikipedia summaries and a starting encyclopedia: the ancient Egypt pilot and a sample of eleven regions.
- Three visual themes and four graphics quality levels.
- Automatic test, screenshots without a monitor, logs of every run and [the bridge](tools/godot/README.en.md) to drive
  the app and the editor from the terminal.
- Project page on GitHub Pages and continuous integration on every push.
