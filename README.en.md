<p align="center">
  <img src="docs/assets/portada.png" alt="TellMAP in 1350 BCE: Egypt selected, with the side panel listing the sources written there at that time, such as the Amarna letters and the Great Hymn to the Aten" width="100%">
</p>

<p align="center">
  <strong>World history on a living map, with its sources at hand.</strong><br>
  Slide the timeline and watch borders shift, cities rise and the texts written in each place appear.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-1E5A44" alt="AGPL-3.0 license"></a>
  <img src="https://img.shields.io/badge/status-in%20development-D42F06" alt="Status: in development">
  <a href="https://github.com/bafif/tmap/actions/workflows/pruebas.yml"><img src="https://github.com/bafif/tmap/actions/workflows/pruebas.yml/badge.svg" alt="Tests"></a>
  <a href="https://bafif.github.io/tmap/"><img src="https://img.shields.io/badge/site-bafif.github.io%2Ftmap-C9A04A" alt="Project site"></a>
  <img src="https://img.shields.io/badge/Godot-4.7-478CBF" alt="Godot 4.7">
  <img src="https://img.shields.io/badge/data-open-8E6B2E" alt="Open data">
  <a href="README.md"><img src="https://img.shields.io/badge/leer%20en-español-555" alt="Leer en español"></a>
</p>

---

## Why it exists

History is usually studied in chapters: one book for Egypt, another for Rome, an atlas on the side. The sources,
which are what we actually know, end up in a bibliography almost nobody opens. That makes it hard to see that
everything happened at once in one world, and that every claim rests on a text someone wrote somewhere, at some time.

I am building TellMAP to study history the other way around: starting from the map and from the sources. A *tell* is
the mound left by centuries of cities built one on top of another, each layer an era. TellMAP does the same with the
world: pick a place, dig through its layers, and in each one find who ruled it, who lived there, what happened and
what was written.

## A library ordered in space and time

Every text has **two coordinates**: where and when it was written, and which place and period it is about. Go to Egypt
in 1350 BCE and you will find the *Great Hymn to the Aten*, written at Amarna at that very moment, alongside
Herodotus, who told the story nine centuries later, and the 20th-century Egyptologists who studied it from London or
Chicago.

| You… | You see… |
|---|---|
| **Slide the timeline** | The borders of 1,637 political entities, from 3400 BCE to 2024, moving year by year |
| **Click a place** | A panel sliding in from the right: who ruled that spot in each century, its eras, estimated population, religion and language |
| **Open the Sources tab** | What was written *there and then* (primary sources) and what was written *about* that place and time (studies), with links to read them |
| **Let time run** | Thinkers appearing while they live, events flashing at their date, cities founded and abandoned |

<p align="center">
  <img src="docs/assets/temas.png" alt="The same place in the three themes: Marble & Bronze showing sources, Illuminated Parchment showing the history of the place, and Ink & Brass showing people and events" width="100%">
</p>

Three interface themes (Marble & Bronze, Illuminated Parchment, Ink & Brass) and four graphics quality levels, so it
runs well from an old laptop to a gaming PC.

<p align="center">
  <img src="docs/assets/mundo.png" alt="The world in 117 CE: the Roman Empire at its greatest extent, the Parthians, the Kushan Empire, the Xianbei and the Han dynasty" width="100%">
</p>

## What makes it different

- **Borders with a backbone.** It uses [Cliopatria](https://github.com/Seshat-Global-History-Databank/cliopatria), the
  geospatial dataset of the Seshat Global History Databank: 13,400 expert-reviewed records. The map is split into
  58,000 units that follow those real borders instead of a grid that approximates them.
- **Sources first.** Every entry tells primary from secondary sources, states how certain its date is, and links to
  full texts on Wikisource, Perseus, Project Gutenberg or the Internet Archive when they are in the public domain.
- **Nothing made up.** Ancient figures are published estimates with their author and uncertainty range. What is not
  known is said to be unknown.
- **The look of grand-strategy maps.** Hillshaded relief, rivers, nautical-chart coastlines, names that curve across
  the land, and three interface themes: Marble & Bronze, Illuminated Parchment, and Ink & Brass.
- **Built to grow step by step.** The encyclopedia is readable JSON, organized in packages, edited with forms inside
  the app. Today it ships a full pilot on ancient Egypt, medieval Europe with its philosophy, the Holy Land from
  Antiquity to today, and regions covering the rest of the world with their estimated population; the rest is filled
  in stages, and [a report generated from the data](docs/es/cobertura.md) (in Spanish) says what is covered and what
  is not. It grows most-consulted first, with drafts from Wikipedia and Wikidata and AI that always cites its sources and goes through
  human review.
- **No accounts, no telemetry.** It runs on your computer. The only things that go online are the Wikipedia lookup when
  you open an entry, which is cached, and the [update](docs/es/actualizaciones.md) check on GitHub when the app opens,
  which sends nothing about you and can be turned off in Settings.
- **Updates itself.** The downloaded version installs new releases; when only the data changed (more sources, people,
  events or regions) it downloads just the changed files, without reinstalling the program.

## Try it

The simplest way is to download the [latest release](https://github.com/bafif/tmap/releases/latest) for Linux,
Windows or macOS: unzip it and open it, nothing to install. The macOS build is not notarized by Apple: the first time,
macOS says it cannot check it; open it anyway from **System Settings → Privacy & Security**, or in the Terminal with
`xattr -dr com.apple.quarantine TellMAP.app`. If it shows a black window or glitches on some computer, choose
«Compatible (OpenGL)» under **Ajustes (the gear icon) → Motor de dibujo**; if not even the settings show up, start
it with `--rendering-method gl_compatibility`.

To run it from the source you need [Godot 4.7](https://godotengine.org/download) (free, about 100 MB).

```bash
git clone https://github.com/bafif/tmap.git
godot --path tmap            # or open the folder from the Godot editor
```

To check everything works, `godot --headless --path tmap -- --prueba` walks through the app on its own and reports
any error; `tools/captura.sh` takes screenshots without a monitor, and [the bridge](tools/godot/README.md) (in Spanish)
lets you drive the app and the editor from the terminal or with an AI agent. The map data is already generated in `data/mapa/`. To rebuild it from the original sources, or with another Cliopatria
release, follow [the data pipeline](tools/pipeline/README.md) (in Spanish).

## Status

Version 0.1: the first one that works end to end. The detailed log of what is done and what is pending is in
[PROGRESO.md](PROGRESO.md) (in Spanish).

- [x] 2D world map with relief, rivers, coastlines and Miller projection
- [x] Political borders from 3400 BCE to 2024, with names that follow the shape of each territory
- [x] Timeline with playback, global and local eras, events and sources
- [x] Side panel: summary, history of the place, sources, people and events, data
- [x] Live Wikipedia summaries, Spanish first
- [x] Pilot encyclopedia on ancient Egypt and a sample of eleven regions
- [x] Medieval Europe package: 15 regions, 173 sources (with an emphasis on philosophy), 215 people, 125 events and
      120 places, checked against Wikipedia and Wikidata
- [x] Regions for the whole world (88, over 99.6% of the land), with estimated population from 10,000 BCE (HYDE,
      Gapminder and the UN, via Our World in Data) and a coverage report generated from the data
- [x] Holy Land package: 7 regions, 176 sources (scriptures, crusade chronicles from every side, Jewish, Christian
      and Muslim thought, modern documents), 198 people, 172 events and 75 places, checked the same way
- [x] Religion, culture and language map modes (where data exists), with each period's real outline
- [x] Pages for every religion, culture, language and polity; clickable legend, timeline and charts
- [x] Grouped markers, keyboard shortcuts and four visual themes (one high-contrast)
- [x] Four graphics quality levels and an automated test that clicks every control
- [ ] 3D view with relief, water and effects
- [ ] Progressive encyclopedia filling with AI and human review
- [ ] Animated migrations, routes and movements of peoples
- [x] Downloadable builds for Linux, Windows and macOS, exported automatically when a GitHub release is published
- [ ] Browser build

## Documentation (in Spanish)

| | |
|---|---|
| [Project plan](docs/es/plan.md) | Architecture, technical decisions and phased roadmap |
| [Data and licenses](docs/es/datos.md) | Where each piece of data comes from, how it is processed and its license |
| [The encyclopedia](docs/es/enciclopedia.md) | How it grows, Wikipedia and Grokipedia, AI and editorial rules |
| [Coverage](docs/es/cobertura.md) | Which regions, periods and data are covered and what is missing, generated from the data |
| [Entry schema](data/enciclopedia/ESQUEMA.md) | The format of sources, people, events, places and regions |
| [Data pipeline](tools/pipeline/README.md) | How the map and borders are generated |

## Author

Made by **Bautista D. Fiori**. If you want to use it for teaching, add sources from your field or help with the code,
get in touch.

[LinkedIn](https://www.linkedin.com/in/b-d-fiori/) · [GitHub](https://github.com/bafif)

## License

The code is [AGPL-3.0-or-later](LICENSE): you may use, modify and share it; if you offer a modified version over a
network, you must offer its source code too. The data keeps its own licenses, detailed in
[Data and licenses](docs/es/datos.md): Cliopatria (CC BY 4.0), Natural Earth and NASA (public domain), Wikipedia
(CC BY-SA 4.0), population from Our World in Data (CC BY 4.0), and the Cinzel and EB Garamond typefaces (SIL Open Font License).
