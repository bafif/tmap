# Esquema de la enciclopedia de TellMAP

La enciclopedia vive en archivos JSON (UTF-8, sangría de 2 espacios) dentro de `data/enciclopedia/paquetes/`. Cada
paquete es un archivo independiente (`egipto.json`, `mundo.json`…) y el programa los junta al arrancar. Si dos
paquetes traen el mismo `id` en la misma sección, gana el primero en orden alfabético y se avisa en la consola.

Se pueden editar a mano o con el editor de la app (Ajustes → «Abrir el editor de la enciclopedia», o «Editar esta
ficha» en cada ficha), que guarda con este mismo formato: un paquete leído y vuelto a escribir sale idéntico.

Todo el texto va en **español** (rioplatense neutro, con tildes), breve y verificable. Nada inventado: si una fecha o un
dato no es seguro, se marca `"aprox": true` y `"confianza": "baja"`, o directamente se omite. Las traducciones van
aparte, en otra carpeta: ver [Traducciones](#traducciones).

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
  "lugares": [],
  "familias": []
}
```

### `regiones`

Una región es un área de estudio. Se dibuja con un polígono aproximado (10 a 40 vértices; hasta 60 en las regiones
armadas con las fronteras de los países actuales) y puede estar dentro de otra. El polígono tiene que ser un anillo
simple, sin vértices repetidos ni lados que se crucen: con la regla par-impar que usa la app, un anillo que se cruza
deja afuera pedazos de la región. El validador lo controla.

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
    {"desde": -3100, "hasta": 1600, "nombre": "Egipcio (luego copto)", "familia": "egipcio", "peso": "mayoritaria"}
  ]
}
```

- `peso`: `"mayoritaria"`, `"importante"` o `"minoritaria"`. El mapa pinta la mayoritaria.
- En los modos de religión, cultura e idioma, el polígono marca el área de estudio. Dentro de él, el mapa pinta con
  el color pleno las zonas que ese año pertenecen a alguna entidad de Cliopatria y con un rayado del mismo color las
  demás (desiertos, zonas sin estado registrado): así se ve el contorno real de cada época, como el valle del Nilo en
  el Egipto antiguo, aunque el polígono sea aproximado.
- `desde` y `hasta` en eras, religiones, culturas e idiomas: `"hasta": null` quiere decir que sigue hasta hoy.
  En religiones, culturas e idiomas `desde` es obligatorio: la app lee un `null` como «desde siempre» (3400 a. C.) y
  así pinta el mapa. Si algo es anterior a lo documentado, va la fecha desde la que hay registro (la conquista, la
  primera mención, la llegada) y una `nota` que lo explique; `validar.py` rechaza el `null`.
- `familia` (obligatoria en religiones, culturas e idiomas): el `id` de una familia de la misma capa en la sección
  [`familias`](#familias). Agrupa para colorear el mapa, da el nombre de la leyenda y abre la ficha de la familia.
  El `nombre` de la entrada puede ser más preciso para esa región («Islam sunní (conquistadores y conversos)»).
- `demografia`: solo estimaciones publicadas, con su fuente real (por ejemplo McEvedy y Jones, *Atlas of World
  Population History*, 1978; Scheidel; Bagnall y Frier). Con `min` y `max` cuando la literatura da un rango. Si no
  hay fuente, no se pone. Las cifras que dan los autores antiguos (Diodoro, Josefo…) llevan
  `"tipo": "testimonio-antiguo"`: la app las muestra aparte y nunca las usa para estimar ni graficar.
  Las entradas cuya fuente termina en «vía Our World in Data» las escribe `tools/enciclopedia/poblacion.py` (la suma
  de los países que `tools/enciclopedia/poblacion_regiones.json` asigna a la región) y se reemplazan cada vez que se
  corre: no se editan a mano. Las estimaciones curadas mandan sobre ellas.
- Cualquier entrada de `eras`, `demografia`, `religiones`, `culturas` o `idiomas` puede llevar una `nota` con la
  aclaración que haga falta (incertidumbre, debates).
- `extendida` (opcional): la ficha extendida, la historia completa por secciones (el nivel 3 de
  [la enciclopedia](../../docs/es/enciclopedia.md)). Cada afirmación lleva en el texto la marca `[n]` de su fuente, y
  cada sección la lista en `citas`; cada `n` está en `referencias` con su URL. Si la redactó una IA, lleva `ia`
  (modelo y fecha) y no se publica sin `revision` (fecha y nota de quien la revisó): el validador lo exige.
- `origen` (opcional): de qué borrador salió la región, cuándo se generó y cuándo se revisó. Lo pone el editor al
  aprobar el borrador.

```json
"extendida": {
  "secciones": [
    {"titulo": "Orígenes", "texto": "El Estado otomano nació de un beylicato turco de Anatolia [1].", "citas": [1]}
  ],
  "referencias": [
    {"n": 1, "titulo": "Wikipedia (es), «Imperio otomano», Introducción", "url": "https://es.wikipedia.org/wiki/Imperio_otomano"}
  ],
  "ia": {"modelo": "claude-opus-5-5", "fecha": "2026-11-07"},
  "revision": {"fecha": "2026-11-08", "nota": "Revisada contra el artículo; corregida la fecha de Bursa."}
}
```

### `familias`

Las religiones, culturas e idiomas que usan las regiones, con su jerarquía. Hoy viven todas en `familias.json`.

```json
{
  "capa": "religiones",
  "id": "islam-sunni",
  "nombre": "Islam sunita",
  "padre": "islam",
  "color": "#3f8a4e",
  "nota": "Opcional: una aclaración (agrupaciones discutibles, incertidumbre).",
  "wikipedia": {"es": "Sunismo", "en": "Sunni Islam"}
}
```

- `capa`: `religiones`, `culturas` o `idiomas`. El `id` es único dentro de cada capa (`arabe` puede ser una cultura y
  un idioma).
- `padre`: la familia mayor, de la misma capa, o `null`. Así se arma la cadena islam sunita → islam → religiones
  abrahámicas. Una familia con hijas también puede usarse directo en una región (`cristianismo`).
- `color`: `#rrggbb`, fijo para que la misma religión tenga siempre el mismo color. Las hijas, parecido a su madre.
- La ficha de la familia muestra el resumen de Wikipedia, dónde está en cada año y con qué peso, las notas de las
  regiones y sus fuentes: no hace falta escribir un resumen propio.

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
  `epistolar`, `inscripcion`, `geografia`, `ciencia`, `medicina`, `sabiduria`, `viajes`, `ensayo`, `arqueologia`,
  `economia`, `politica`, `manifiesto`, `discurso`, `tecnologia`, `periodismo`. Leyes, fallos, tratados,
  resoluciones y constituciones van como `legal`; los artículos científicos, como `ciencia`.
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
  `tratado`, `construccion`, `exploracion`, `revolucion`, `judicial` (sentencias y fallos). Una guerra entera va como
  `batalla` con `anio_hasta`.
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

- `tipo`: `ciudad`, `capital`, `templo`, `puerto`, `sitio-arqueologico`, `biblioteca`, `universidad`,
  `laboratorio`, `institucion` (un congreso, un tribunal, una sede de gobierno o de un organismo), `sitio-historico`
  (una plaza, un campo de concentración, un centro clandestino, un campo de batalla).
- `abandono`: año en que deja de ser habitada o relevante; `null` si sigue.
- `importancia`: 1 (local) a 3 (de primer orden). Decide desde qué zoom se ve.

## Traducciones

Los paquetes no se traducen: la traducción de cada uno vive en `traducciones/<idioma>/<paquete>.json` (por ahora solo
`en`), con una entrada por texto. Con la app en inglés, cada texto traducido reemplaza al español al cargar el paquete;
lo que no tiene traducción se ve en español. El editor de la app trabaja siempre sobre el español.

```json
{
 "paquete": "egipto",
 "idioma": "en",
 "textos": {
  "regiones/egipto/eras.0.nombre": {"hash": "3f0c9a51e2", "texto": "Early Dynastic Period"},
  "familias/religiones:islam-sunni/nombre": {"hash": "9b7d20c4aa", "texto": "Sunni Islam"}
 }
}
```

- La clave es sección, id y campo. El campo es un camino con puntos y posiciones (`eras.0.nombre`, `escrita.lugar`,
  `roles.1`); en `familias` el id va con su capa.
- `hash`: el comienzo del sha256 del texto español que se tradujo. Si después cambia el español, la app sigue
  mostrando la traducción que había y la herramienta la cuenta como vieja para volver a traducirla. Lo mismo pasa si
  se inserta una entrada en medio de una lista (una era, por ejemplo): las que siguen cambian de posición.
- Se traducen los textos que se leen: en `regiones`, `nombre`, `resumen`, el `nombre`, el `resumen` y la `nota` de las
  eras, la `nota` de la demografía, el `nombre` y la `nota` de religiones, culturas e idiomas, y el `titulo` y el
  `texto` de las secciones de la ficha extendida; en `familias`, `nombre` y `nota`; en `fuentes`, `titulo`, `autor`,
  `escrita.lugar`, `idioma_original`, `soporte`, `resumen` y `por_que_importa`; en `personas`, `nombre`, `roles`,
  el `lugar` de `nacimiento`, `muerte` y `activo`, y `resumen`; en `hechos`, `titulo`, `lugar` y `resumen`; en
  `lugares`, `nombre` y `resumen`. Los nombres propios se traducen solo si tienen una forma propia en el otro idioma
  (Heródoto → Herodotus).
- No se traducen los ids ni los campos que son ids (`familia`, `padre`, `regiones`, `obras`, `fuentes`, `autor_id`),
  los valores cerrados (`peso`, `tipo`, `genero`, `confianza`, `capa`: la app los traduce sola), años, coordenadas,
  colores, `wikipedia` (ya trae `en`), `wikidata`, los enlaces de `leer`, las `fuente` de la demografía, las
  referencias de la ficha extendida, `titulo_original` ni lo que la app no muestra (`descripcion` del paquete, `ia`,
  `revision`, `origen`).
- Las capas se arman con `tools/traduccion/enciclopedia.py`: `estado` cuenta lo traducido, lo que falta y lo viejo,
  `extraer <carpeta>` saca lo pendiente en lotes JSON para traducir y `aplicar <respuestas>` vuelca las traducciones
  con su hash. No se editan a mano.

## Borradores

`paquetes/borradores/*.json` tiene el formato de un paquete y una sección más, `borrador`: el origen (la entidad de
Cliopatria, su Wikidata y cuántas veces se consultó), la fecha, el estado («sin revisar»), las fuentes y el artículo
de Wikipedia por secciones, sugerencias para quien revisa y, si se redactó con IA, `ia` con los avisos de la
verificación automática, lo que se descartó y las fuentes de lectura que propone. La app no carga los borradores: se
revisan y se aprueban en el editor, que pasa sus elementos a un paquete. Los arman `tools/enciclopedia/borradores.py`
y `tools/enciclopedia/redactar.py` (ver [la enciclopedia](../../docs/es/enciclopedia.md)).

`python3 tools/enciclopedia/validar.py --borradores` los valida junto con los paquetes; en un borrador, la falta de
área de estudio o de revisión es un aviso, no un error.
