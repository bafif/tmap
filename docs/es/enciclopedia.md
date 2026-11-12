# La enciclopedia

[English](../en/encyclopedia.md)

La enciclopedia de TellMAP no se escribe de una vez: se completa por etapas, empezando por donde más se usa, y cada
dato dice de dónde salió.

## Qué hay hoy

- **Fronteras y entidades** de todo el mundo (Cliopatria): cada entidad trae su artículo de Wikipedia y su id de
  Wikidata.
- **Resúmenes de Wikipedia en vivo**, en el idioma de la app (o el que se elija en Ajustes) y en el otro si no hay
  artículo, guardados en caché por 30 días.
- **Paquetes** en `data/enciclopedia/paquetes/`, más `familias.json` con las familias de religiones, culturas e
  idiomas. Sus regiones cubren el 99,6 % de la tierra firme, y cada una tiene población estimada desde el 10 000 a. C.
  o se cuenta dentro de otra. Cuántas fichas hay y qué falta está en [Cobertura de la enciclopedia](cobertura.md), que
  se genera solo:
  - `egipto`, el piloto: el antiguo Egipto, con sus eras de la unificación a la época moderna.
  - `mundo`, una muestra de once regiones (Mesopotamia, Levante, Anatolia, Grecia, Italia, Persia, China, India,
    Mesoamérica, Andes y Río de la Plata).
  - `edad-media`, la Europa medieval del saqueo de Roma a 1500, con énfasis en la historia de la filosofía, y sus
    regiones, de la península ibérica a la Rus, con eras, religiones, culturas e idiomas desde la Antigüedad. La
    demografía sigue a Russell (1972) y a Urlanis (1941).
  - `tierra-santa`, de la Antigüedad a hoy, con las regiones del Levante, Arabia, el Magreb, Chipre, Armenia y
    Cilicia: las escrituras, la primera expansión islámica, las cruzadas desde todos los lados, el pensamiento de
    judíos, cristianos y musulmanes y los documentos modernos. La demografía sigue a DellaPergola (2001) y a los
    censos del Mandato.
  - `regiones-del-mundo`, las 46 regiones que completan el mapa (de Siberia y Japón a África, las Américas y
    Oceanía), armadas con las fronteras de los países actuales de Natural Earth: resumen, eras y población, todavía
    sin religiones, culturas ni idiomas.
  - La época contemporánea, en siete paquetes temáticos: `pensamiento-economico`, `ideas-politicas`,
    `argentina-contemporanea` (de 1880 a hoy), `ciencia-y-tecnologia`, `cultura-libre-y-hackers`,
    `guerras-y-orden-mundial` y `letras-y-pensamiento-del-siglo-xx`.
  - La Argentina hasta 1912, en siete paquetes: `pueblos-originarios-del-cono-sur`, `rio-de-la-plata-colonial`,
    `virreinato-e-independencia`, `guerras-civiles-y-organizacion-nacional`, `rosas-y-la-confederacion`,
    `argentina-1862-1912` e `historiografia-argentina`.
  - Los celtas, en nueve paquetes: `celtas-origenes-y-prehistoria`, `galos-y-galia`, `celtas-del-danubio-y-galacia`,
    `celtas-de-hispania`, `celtas-de-britania-e-irlanda`, `religion-celta`, `celtas-en-las-fuentes-antiguas`,
    `celtas-legado-e-historiografia` y `mundo-celta`, con siete subregiones.

  Desde `edad-media`, cada paquete está verificado contra Wikipedia y Wikidata (títulos, ids, coordenadas y fechas de
  vida), y sus enlaces de lectura respondieron al comprobarlos.
- **Series por país desde 1800** (población, esperanza de vida, fecundidad, economía, educación) en la pestaña
  «Datos», para el país actual de cada punto: `data/demografia/`, de `tools/demografia/series.py`.
- **Población de todas las regiones**: `tools/enciclopedia/poblacion.py` suma, para cada región, la serie por país de
  Our World in Data (HYDE 3.3, Gapminder y la ONU), según la asignación de `tools/enciclopedia/poblacion_regiones.json`.
  Las estimaciones curadas de especialistas mandan: en los años que cubren no se agrega nada.
  `tools/enciclopedia/cobertura.py` rehace el informe de cobertura y `validar.py` avisa si quedó viejo.
- El formato está en [ESQUEMA.md](../../data/enciclopedia/ESQUEMA.md) y se valida con
  `python3 tools/enciclopedia/validar.py`. Para escribir muchas fichas de una vez hay un [formato
  compacto](../../tools/enciclopedia/compacto/FORMATO.md) de texto que `tools/enciclopedia/compacto/construir.py`
  convierte en paquetes verificados contra Wikipedia y Wikidata.
- **La enciclopedia en inglés**: cada paquete tiene su traducción en `data/enciclopedia/traducciones/en/`, una capa
  aparte que se arma con `tools/traduccion/enciclopedia.py`
  ([el esquema](../../data/enciclopedia/ESQUEMA.md#traducciones)).
  Con la app en inglés se leen esos textos; lo que todavía no está traducido se ve en español.
- **Un editor dentro de la app** para cargar y corregir todo eso sin tocar JSON (ver [más abajo](#el-editor)).

## ¿Y Grokipedia?

TellMAP no usa Grokipedia: a noviembre de 2026 no tiene una API oficial (solo hay clientes no oficiales que leen el
sitio) y buena parte de su contenido se deriva de Wikipedia. Usa Wikipedia (API pública y estable, CC BY-SA), Wikidata
(datos estructurados, CC0) y, para las fichas largas, IA que redacta *a partir de fuentes citadas*.

## Cuatro niveles de ficha

| Nivel | Qué es | Estado |
|---|---|---|
| 0 | Datos de Cliopatria: nombre, años y territorio | Todo el mundo |
| 1 | Resumen de Wikipedia en vivo | Todo lo que tenga artículo |
| 2 | Ficha curada: eras, fuentes primarias y secundarias, personas, hechos, población, religión, cultura e idioma | Las regiones y los temas de los paquetes |
| 3 | Ficha extendida «estilo enciclopedia»: historia completa por secciones, redactada con IA desde fuentes citadas y revisada | Las herramientas están; todavía no hay fichas publicadas |

## Cómo se completa

1. **Qué falta lo dice el uso.** La app anota en `user://pendientes.json` lo que se abre y no tiene ficha curada: la
   entidad, su Wikidata, el lugar, los años consultados y cuántas veces. No sale de la computadora. En Ajustes →
   Enciclopedia se ven los más consultados y se puede copiar la cola. (En Linux, `user://` es
   `~/.local/share/godot/app_userdata/TellMAP/` en la versión instalada y `~/.local/share/TellMAP-codigo/` desde el
   código; `borradores.py` lee por defecto la de la instalada.)
2. **Borrador automático.** `python3 tools/enciclopedia/borradores.py` toma las entradas más consultadas (`-n 3` por
   defecto; `--cola` para una cola copiada, `--wikidata Q12560` para una entidad puntual) y junta:
   - de Wikidata, la capital con sus coordenadas, las personas clave (quienes ocuparon sus cargos y las más conocidas
     de su época) con fechas y lugares de nacimiento y muerte, y los hechos fechados en los que participó;
   - de Wikipedia, el resumen y el artículo completo por secciones, en español o, si no hay, en inglés;
   - de Cliopatria, los años de la entidad.

   Lo deja en `data/enciclopedia/paquetes/borradores/`, con el formato del esquema y marcado «sin revisar».
3. **Redacción con IA, con citas obligatorias.** `python3 tools/enciclopedia/redactar.py <borrador>` le pasa a un
   modelo de Anthropic las fuentes del borrador numeradas (cada sección del artículo y la ficha de Wikidata) y le pide
   la historia por secciones, citando en cada párrafo de qué fuente sale. Después, sin confiar en el modelo, descarta
   los párrafos sin cita válida, marca para revisar los años y cifras que no aparecen en las fuentes que citan, y
   comprueba uno por uno los enlaces de lectura que propone. Necesita el SDK de Anthropic (`pip install anthropic`) y
   una credencial de su API; cada ficha cuesta del orden de 0,15 a 0,40 USD con el modelo por defecto.
4. **Revisión humana.** En la app, Ajustes → «Abrir el editor de la enciclopedia» → Borradores: se calcula el área de
   estudio con el territorio de Cliopatria, se abre y corrige cada elemento, se lee la ficha extendida con los avisos
   de la verificación y, cuando todo está bien, se marca «Revisé cada dato y cada sección contra sus fuentes» y se
   aprueba. Recién ahí los elementos pasan a un paquete, con la fecha y la nota de la revisión. Una ficha redactada
   con IA sin revisión no pasa el validador.
5. **De a poco y a mano.** Se corre en lotes chicos, cuando hace falta, nunca de forma desatendida: así el costo queda
   controlado y la calidad también.

## El editor

Desde Ajustes → «Abrir el editor de la enciclopedia», o con «Editar esta ficha» en cualquier ficha de fuente, persona,
hecho, lugar o región:

- **Formularios** para cada sección, con los campos del esquema: los años se escriben «-1274» o «1274 a. C.», las
  listas de ids separadas por comas, y los enlaces de lectura y las eras como filas que se agregan y se quitan.
- **Coordenadas con un clic**: «Elegir en el mapa» y el próximo clic en el mapa las pone; «Ver» lleva el mapa a ellas.
- **Validación al guardar**: años sin año 0, coordenadas en rango, ids y referencias que existan, campos cerrados. Los
  errores frenan el guardado; los avisos (una fuente sin lugar de escritura, por ejemplo) solo se muestran.
- **El mismo formato**: guarda en el JSON del paquete de cada elemento, o en el que se elija para uno nuevo, sin cambiar
  nada más del archivo. Al guardar, el mapa y las fichas se actualizan solos.

Desde el código fuente (con Godot) escribe en los archivos del proyecto. En una versión exportada, donde los paquetes
van dentro del ejecutable, guarda copias en la carpeta del usuario (`user://enciclopedia/`; en Windows,
`%APPDATA%\Godot\app_userdata\TellMAP\enciclopedia\`) que tapan a los de adentro: para sumar esos cambios al proyecto,
se mandan esos archivos. Las regiones se editan en sus datos principales, su área, sus
eras, sus religiones, culturas e idiomas (la familia se elige entre las de `familias.json`) y su población. Las cifras
de población de Our World in Data no se muestran ni se tocan: las escribe `tools/enciclopedia/poblacion.py`, que hay
que volver a correr cuando cambian las estimaciones curadas (el editor lo avisa).

## Reglas editoriales

- **Nada inventado.** Si una fecha es incierta se marca `aprox` y se baja la `confianza`; si un dato no tiene fuente,
  no se carga.
- **Fuentes primarias primero**, en ediciones de dominio público o de acceso abierto cuando existan.
- **Dos coordenadas por texto**: dónde y cuándo se escribió, y de qué lugar y época trata.
- **Estimaciones con su autor y su rango.** Las cifras de autores antiguos son testimonios, no estimaciones.
- **Más de una tradición.** Las eras de cada región usan su propia periodización; la periodización europea aparece
  solo como referencia global y se dice que es orientativa.
- **Licencias claras.** Lo que se deriva de Wikipedia hereda CC BY-SA 4.0 y se atribuye.
