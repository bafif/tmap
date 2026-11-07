# La enciclopedia

La enciclopedia de TellMAP no se escribe de una vez: se completa por etapas, empezando por donde más se usa, y cada
dato dice de dónde salió.

## Qué hay hoy

- **Fronteras y entidades** de todo el mundo (Cliopatria): cada entidad trae su artículo de Wikipedia y su id de
  Wikidata.
- **Resúmenes de Wikipedia en vivo**, en español primero y en inglés si no hay, guardados en caché por 30 días.
- **Dos paquetes curados** en `data/enciclopedia/paquetes/`:
  - `egipto.json`, el piloto: 4 regiones (con 18 eras para Egipto), 37 fuentes, 18 personas, 24 hechos y 14 lugares.
  - `mundo.json`, una muestra de once regiones (Mesopotamia, Levante, Anatolia, Grecia, Italia, Persia, China, India,
    Mesoamérica, Andes y Río de la Plata).
- El formato está en [ESQUEMA.md](../../data/enciclopedia/ESQUEMA.md) y se valida con
  `python3 tools/enciclopedia/validar.py`.
- **Un editor dentro de la app** para cargar y corregir todo eso sin tocar JSON (ver [más abajo](#el-editor)).

## ¿Y Grokipedia?

A noviembre de 2026, **Grokipedia no tiene una API oficial**. Lo que hay son clientes no oficiales que leen el sitio
(por ejemplo, paquetes de PyPI o servicios que lo replican) y al menos un sitio con nombre parecido que dice ofrecer una
API y no es de xAI. Además, su contenido estuvo congelado entre marzo y septiembre de 2026 y buena parte se derivó de
Wikipedia.

Por eso TellMAP no depende de Grokipedia: usa Wikipedia (API pública y estable, CC BY-SA), Wikidata (datos
estructurados, CC0) y, para las fichas largas, IA que redacta *a partir de fuentes citadas*. El estilo de ficha de
Grokipedia (un artículo largo, ordenado y legible) es la referencia de forma, no de contenido.

## Cuatro niveles de ficha

| Nivel | Qué es | Estado |
|---|---|---|
| 0 | Datos de Cliopatria: nombre, años y territorio | Todo el mundo |
| 1 | Resumen de Wikipedia en vivo | Todo lo que tenga artículo |
| 2 | Ficha curada: eras, fuentes primarias y secundarias, personas, hechos, población, religión, cultura e idioma | Egipto y la muestra mundial |
| 3 | Ficha extendida «estilo enciclopedia»: historia completa por secciones, redactada con IA desde fuentes citadas y revisada | Herramientas listas (0.3); se publican a medida que se revisan |

## Cómo se completa

1. **Qué falta lo dice el uso.** La app anota en `user://pendientes.json` lo que se abre y no tiene ficha curada: la
   entidad, su Wikidata, el lugar, los años consultados y cuántas veces. No sale de la computadora. En Ajustes →
   Enciclopedia se ven los más consultados y se puede copiar la cola. (En Linux, `user://` es
   `~/.local/share/godot/app_userdata/TellMAP/`.)
2. **Borrador automático.** `python3 tools/enciclopedia/borradores.py` toma las entradas más consultadas (`-n 3` por
   defecto; `--cola` para una cola copiada, `--wikidata Q12560` para una entidad puntual) y junta:
   - de Wikidata, la capital con sus coordenadas, las personas clave (quienes ocuparon sus cargos y las más conocidas
     de su época) con fechas y lugares de nacimiento y muerte, y los hechos fechados en los que participó;
   - de Wikipedia, el resumen y el artículo completo por secciones, en español o, si no hay, en inglés;
   - de Cliopatria, los años de la entidad.

   Lo deja en `data/enciclopedia/paquetes/borradores/`, con el formato del esquema y marcado «sin revisar».
3. **Redacción con IA, con citas obligatorias.** `python3 tools/enciclopedia/redactar.py <borrador>` le pasa a Claude
   las fuentes del borrador numeradas (cada sección del artículo y la ficha de Wikidata) y le pide la historia por
   secciones, citando en cada párrafo de qué fuente sale. Después, sin confiar en el modelo, descarta los párrafos sin
   cita válida, marca para revisar los años y cifras que no aparecen en las fuentes que citan, y comprueba uno por uno
   los enlaces de lectura que propone. Necesita el SDK (`pip install anthropic`) y una credencial de la API; cada
   ficha cuesta del orden de 0,15 a 0,40 USD con el modelo por defecto.
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
se mandan esos archivos. Las regiones se editan en sus datos principales, su área y sus
eras; religiones, culturas, idiomas y demografía todavía se cargan a mano en el JSON.

## Reglas editoriales

- **Nada inventado.** Si una fecha es incierta se marca `aprox` y se baja la `confianza`; si un dato no tiene fuente,
  no se carga.
- **Fuentes primarias primero**, en ediciones de dominio público o de acceso abierto cuando existan.
- **Dos coordenadas por texto**: dónde y cuándo se escribió, y de qué lugar y época trata.
- **Estimaciones con su autor y su rango.** Las cifras de autores antiguos son testimonios, no estimaciones.
- **Más de una tradición.** Las eras de cada región usan su propia periodización; la periodización europea aparece
  solo como referencia global y se dice que es orientativa.
- **Licencias claras.** Lo que se deriva de Wikipedia hereda CC BY-SA 4.0 y se atribuye.
