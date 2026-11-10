# Formato compacto para escribir temas de la enciclopedia

TellMAP es un atlas histórico (Godot) con una enciclopedia de **fichas**: fuentes (textos: libros, artículos,
manifiestos, leyes, fallos, discursos), personas, hechos y lugares, ubicados en el espacio y el tiempo. La app no
guarda los textos: guarda la ficha (título, autor, fechas, resumen propio) y **enlaza** a dónde leerlos. Esquema
completo: [data/enciclopedia/ESQUEMA.md](../../../data/enciclopedia/ESQUEMA.md).

Escribir cientos de fichas directamente en JSON es lento y propenso a errores. Este formato de texto, con una línea
o un bloque por elemento, se escribe rápido, y `construir.py` lo convierte en paquetes verificados. Así se armaron los
paquetes de la Edad Media, Tierra Santa y la época contemporánea. Cada tema vive en `<carpeta de temas>/<tema>/` (la
carpeta puede estar fuera del repo: lo que vale son los paquetes que salen) y se arma con:

    python3 tools/enciclopedia/compacto/construir.py <carpeta de temas> --tema <tema>

que resuelve cada artículo de Wikipedia (redirecciones, desambiguaciones, título en español y QID de Wikidata),
toma coordenadas y lugares de Wikidata, compara las fechas con Wikidata, comprueba que cada enlace de lectura
responda 200 y deja `temas/<tema>/informe.txt` con los avisos y `salida.json` con el paquete. **Se itera hasta que el
informe quede limpio** (o con avisos explicados). Con `--tema` no escribe en el repo; sin `--tema` y con `--escribir`
arma todos los temas juntos, resuelve las referencias entre ellos y escribe los paquetes en
`data/enciclopedia/paquetes/`.

## Reglas de contenido

- Todo en **español rioplatense neutro**, con tildes, breve, preciso y **verificable**. Nada inventado: si un dato no
  es seguro, se marca aproximado (`~`) y `c: media`/`baja`, o se omite. Ante la duda, `consultar.py resumen <título>`.
- **Neutralidad**: describir qué dice cada obra y qué pasó, sin adherir. En temas disputados (peronismo,
  kirchnerismo, sionismo, socialismo, libertarismo, guerras), decir quién sostiene qué y cuál es la crítica principal,
  en una oración. Los fallos judiciales: tribunal, fecha, qué resolvió, penas, instancias y si está firme; si la
  persona condenada lo denuncia como persecución, se dice.
- Resúmenes: 2 a 4 oraciones para fuentes (`r`) y 1 a 2 para `p` (por qué importa); 1 a 3 oraciones para personas,
  hechos y lugares. Sin adjetivos de opinión («brillante», «nefasto»).
- Hechos posteriores a 2024: confirmalos con `consultar.py resumen` (tu memoria puede estar vieja o equivocada).
- Ids: minúsculas, sin tildes, con guiones (`teoria-general-keynes`, `keynes`). Antes de crear uno, fijate si ya
  existe en otro paquete: si existe, **usá ese id** y no lo redefinas (el constructor avisa «ID QUE YA EXISTE»). Si
  varios temas se escriben a la vez, conviene repartir de antemano qué tema define cada figura u obra compartida.

## Archivos del tema

Todos UTF-8, con `#` para comentarios. Campos separados por ` | ` (nunca uses `|` dentro de un texto).

### `meta.txt`
    paquete: <nombre-del-paquete>
    descripcion: <una oración>

### `personas.txt`
    # id | nombre | nacimiento | muerte | activo | roles | artículo en inglés | resumen
    keynes | John Maynard Keynes | 1883 @wd | 1946 @wd | @cambridge 1909-1946 | economista | John Maynard Keynes | Economista británico...

- nacimiento/muerte: `año [lugar]`; vacío si vive o no se sabe. Lugar: `@wd` (lo toma de Wikidata: lo más
  cómodo), `@clave` (del nomenclátor), `@clave=Texto`, o `=Texto` (sin coordenadas).
- activo: `@clave año-año` (dónde trabajó y cuándo); vacío si basta con el nacimiento.
- `~` al final de un año = aproximado. Años negativos = a. C.

### `fuentes*.txt` (pueden ser varios: `fuentes1.txt`, `fuentes2.txt`…)
    ## teoria-general-keynes
    t: Teoría general de la ocupación, el interés y el dinero
    to: The General Theory of Employment, Interest and Money
    a: keynes                      (id de persona; o =Nombre si no tiene ficha)
    k: secundaria economia         (tipo: primaria|secundaria; género, ver abajo)
    e: 1936 @londres               (año o rango año-año, y lugar donde se escribió o publicó)
    tr: britania,norteamerica 1929-1936   (regiones de las que trata y años que abarca; "-" si es universal)
    io: Inglés
    so: Libro                      (opcional)
    r: Resumen...
    p: Por qué importa...
    w: The General Theory of Employment, Interest and Money   (artículo en inglés; `es:Título` si solo hay en español)
    c: alta

- tipo: `primaria` = documento de su época sobre su época (manifiesto, ley, fallo, discurso, carta, tratado, artículo
  científico original, libro de teoría escrito por su autor); `secundaria` = estudio posterior sobre otra época
  (historiografía). Casi todo lo de esta tanda es primaria.
- géneros: `religioso historia cronica literatura poesia filosofia legal administrativo epistolar inscripcion
  geografia ciencia medicina sabiduria viajes ensayo arqueologia economia politica manifiesto discurso tecnologia
  periodismo`. Fallos, leyes, tratados, resoluciones y constituciones: `legal`. Artículos científicos: `ciencia`.

### `hechos.txt`
    # id | título | años | lugar | tipo | fuentes | artículo en inglés | resumen | regiones extra
    conferencia-de-bretton-woods | Conferencia de Bretton Woods | 1944 | @bretton-woods | economico | acuerdos-de-bretton-woods | Bretton Woods Conference | Resumen... |

- años: `1944`, `1914-1918`, `1944~`. lugar: como en personas; `@=Texto` usa las coordenadas del propio artículo.
- tipo: `politico batalla fundacion religioso cultural cientifico economico desastre tratado construccion
  exploracion revolucion judicial`. Guerras enteras: `batalla` con rango de años; fallos: `judicial`.
- fuentes: ids separados por coma (de cualquier tema o paquete), o vacío.
- regiones extra (opcional): ids de regiones además de la que toca el punto (los `id` de las regiones de los paquetes).

### `lugares.txt`
    # id | nombre | fundación | abandono | tipo | importancia | artículo en inglés | resumen | [lon,lat si Wikidata no las tiene]
    bell-labs | Laboratorios Bell | 1925 | - | laboratorio | 2 | Bell Labs | Resumen...

- tipo: `ciudad capital templo puerto sitio-arqueologico biblioteca universidad laboratorio institucion sitio-historico`.
- importancia 1 (local) a 3 (primer orden). Solo lugares que importan por sí mismos (un laboratorio, una plaza, un
  tribunal, un centro clandestino); las ciudades donde algo se escribió van en el nomenclátor.

### `gaz.txt` (nomenclátor: puntos para `@clave`, no son fichas)
    # clave | nombre | artículo en inglés | [lon,lat si Wikidata no las tiene]
    londres | Londres | London
    cambridge | Cambridge | Cambridge

Los **lugares** de los paquetes ya sirven como `@clave` (`@roma`, `@paris`, `@jerusalen`, `@buenos-aires`…): antes
de agregar una clave, fijate si ya existe.

### `leer.txt` (dónde leer cada fuente; solo enlaces que respondan 200)
    # fuente | pg:<número>, ws:<lengua>:<título> o url:<https://...> | descripción | lengua | [dp si una url es de dominio público]
    manifiesto-gnu | url:https://www.gnu.org/gnu/manifesto.es.html | Texto en español en gnu.org | es |

Prioridad: dominio público o acceso abierto y **oficial** (Wikisource, Proyecto Gutenberg, Internet Archive, Avalon
Project de Yale, sitios de la ONU, gnu.org, arXiv, el sitio de la revista o del autor, el CIJ de la Corte Suprema
argentina, InfoLEG, el Boletín Oficial, mises.org para la escuela austríaca, marxists.org para el socialismo y el
anarquismo). Nunca copias piratas de libros con derechos: si no hay copia legal, la fuente queda sin enlace (la ficha
igual vale). `pg:` y `ws:` se marcan dominio público solos; con `url:` poné `dp` solo si lo es.

## Herramientas

`python3 tools/enciclopedia/compacto/consultar.py` (sin argumentos muestra la ayuda):
`resumen`, `buscar`, `titulos` (comprueba muchos títulos a la vez, separados por ` ;; `), `wd`, `url`, `ws`, `pg`.
