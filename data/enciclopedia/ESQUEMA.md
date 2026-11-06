# Esquema de la enciclopedia de TellMAP

La enciclopedia vive en archivos JSON (UTF-8, sangría de 2 espacios) dentro de `data/enciclopedia/paquetes/`. Cada
paquete es un archivo independiente (`egipto.json`, `mundo.json`…) y el programa los junta al arrancar. Si dos
paquetes traen el mismo `id` en la misma sección, gana el primero en orden alfabético y se avisa en la consola.

Todo el texto va en **español** (rioplatense neutro, con tildes), breve y verificable. Nada inventado: si una fecha o un
dato no es seguro, se marca `"aprox": true` y `"confianza": "baja"`, o directamente se omite.

## Convenciones

- **Años:** enteros. Negativos = antes de Cristo. **No existe el año 0**: `-1` es el 1 a. C. y `1` es el 1 d. C.
  (la misma convención que Cliopatria).
- **Coordenadas:** `lon` y `lat` en grados decimales (WGS84). Ojo con el orden: en los polígonos va `[lon, lat]`.
- **Ids:** minúsculas, sin tildes, con guiones: `textos-de-las-piramides`, `herodoto`.
- **Wikipedia:** `{"es": "Título exacto del artículo en es.wikipedia", "en": "Exact title on en.wikipedia"}`. Solo
  títulos que existan; si no hay artículo en un idioma, se omite esa clave.
- **Enlaces de lectura (`leer`):** solo URLs comprobadas (que respondan 200), preferentemente de texto completo y
  dominio público o acceso abierto: Wikisource, Proyecto Gutenberg, Perseus, Internet Archive, ETCSL, LacusCurtius,
  Biblioteca Virtual Miguel de Cervantes, sitios universitarios. Nunca enlaces a copias piratas.

## Archivo de paquete

```json
{
  "paquete": "egipto",
  "descripcion": "Piloto: el antiguo Egipto, de la unificación a la conquista árabe",
  "regiones": [],
  "fuentes": [],
  "personas": [],
  "hechos": [],
  "lugares": []
}
```

### `regiones`

Una región es un área de estudio. Se dibuja con un polígono aproximado (10 a 40 vértices) y puede estar dentro de otra.

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
    {"desde": -3100, "hasta": 1600, "nombre": "Egipcio (luego copto)", "peso": "mayoritaria"}
  ]
}
```

- `peso`: `"mayoritaria"`, `"importante"` o `"minoritaria"`. El mapa pinta la mayoritaria.
- `familia` (religiones y culturas): agrupa para colorear. Valores sugeridos para religiones: `politeismo-egipcio`,
  `politeismo-mesopotamico`, `politeismo-griego`, `politeismo-romano`, `judaismo`, `cristianismo`,
  `cristianismo-copto`, `cristianismo-ortodoxo`, `catolicismo`, `protestantismo`, `islam-sunni`, `islam-chii`,
  `zoroastrismo`, `budismo`, `hinduismo`, `vedismo`, `jainismo`, `confucianismo`, `taoismo`, `religion-tradicional-china`,
  `religion-mesoamericana`, `religion-andina`, `religiones-originarias`. Para culturas: `egipcia`, `semitica`,
  `griega`, `latina`, `persa`, `arabe`, `turca`, `china`, `india`, `mesoamericana`, `andina`, `hispana`, `criolla`,
  `pueblos-originarios`, etc. Se pueden agregar otras con el mismo estilo.
- `demografia`: solo estimaciones publicadas, con su fuente real (por ejemplo McEvedy y Jones, *Atlas of World
  Population History*, 1978; Scheidel; Bagnall y Frier). Con `min` y `max` cuando la literatura da un rango. Si no
  hay fuente, no se pone. Las cifras que dan los autores antiguos (Diodoro, Josefo…) llevan
  `"tipo": "testimonio-antiguo"`: la app las muestra aparte y nunca las usa para estimar ni graficar.
- Cualquier entrada de `eras`, `demografia`, `religiones`, `culturas` o `idiomas` puede llevar una `nota` con la
  aclaración que haga falta (incertidumbre, debates).

### `fuentes`

El corazón del proyecto: textos ubicados en el espacio y el tiempo. Una fuente tiene **dos coordenadas**: dónde y cuándo
se escribió (`escrita`) y de qué lugar y época trata (`trata`). Un papiro egipcio está escrito y trata del mismo lugar y
tiempo; Heródoto escribió en el siglo V a. C. sobre un Egipto de siglos antes; un historiador del siglo XX escribió en
Londres sobre el Imperio Nuevo.

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

- `tipo`: `"primaria"` (producida en la época y el lugar que estudia: documentos, inscripciones, crónicas
  contemporáneas, literatura de la época) o `"secundaria"` (estudio posterior: historiadores antiguos que escriben
  sobre épocas anteriores, historiografía moderna, arqueología).
- `genero`: `religioso`, `historia`, `cronica`, `literatura`, `poesia`, `filosofia`, `legal`, `administrativo`,
  `epistolar`, `inscripcion`, `geografia`, `ciencia`, `medicina`, `sabiduria`, `viajes`, `ensayo`, `arqueologia`.
- `escrita.anio_hasta`: opcional, para textos compuestos a lo largo de un período.
- `autor_id`: el `id` de una persona si está en algún paquete; si no, `null` y solo el nombre en `autor`.
- `confianza`: qué tan segura es la datación (`alta`, `media`, `baja`).

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

- `activo` es opcional: dónde trabajó, si no es el lugar de nacimiento. El mapa lo muestra ahí mientras vive. Puede
  llevar `desde` y `hasta` (reinado o época de actividad conocida) para personas sin fechas de nacimiento o muerte:
  `"activo": {"lugar": "Amarna", "lon": 30.896, "lat": 27.645, "desde": -1352, "hasta": -1336, "aprox": true}`.
  Sin ningún año, la persona no aparece en el mapa ni en «personas vivas».
- Para personas antiguas con fechas inciertas, `aprox: true` y la mejor estimación académica.

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
  `tratado`, `construccion`, `exploracion`, `revolucion`.
- `fuentes`: ids de fuentes que lo documentan (pueden ser de otro paquete).

### `lugares`

Ciudades, templos y sitios que aparecen en el mapa cuando existen.

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

- `tipo`: `ciudad`, `capital`, `templo`, `puerto`, `sitio-arqueologico`, `biblioteca`, `universidad`.
- `abandono`: año en que deja de ser habitada o relevante; `null` si sigue.
- `importancia`: 1 (local) a 3 (de primer orden). Decide desde qué zoom se ve.
