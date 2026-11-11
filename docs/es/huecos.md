# Los huecos de lo investigado

[English](../en/gaps.md)

Cómo se recorre la enciclopedia para que ningún tema quede con huecos en el lugar y la época que ya cubre: si un tema
tiene a diez de los doce presidentes de su período, le faltan dos; si tiene la mitad de las batallas de una guerra,
las otras tan conocidas como esas también van; si una región tiene religiones hasta el 400 y desde el 900, falta lo
del medio. Sirve para personas y para agentes de IA.

## Qué es un hueco

Cada paquete es un tema investigado en un lugar y una época. Su **alcance**, en
[`tools/enciclopedia/huecos/alcances.json`](../../tools/enciclopedia/huecos/alcances.json), dice:

- `desde` y `hasta`: los años que cubre;
- `regiones`: dónde, y `nucleo`, las regiones donde pasa el tema y no solo se asoma (las más citadas hasta juntar el
  60 % de sus fichas, más las que el paquete define): los candidatos se buscan ahí;
- `hechos` y `ocupaciones`: los ejes, es decir, los tipos de hecho y los roles de persona que el tema trata con al
  menos tres fichas. En los temas de ideas, que no son de un lugar (la ciencia, el pensamiento económico, las
  letras), `ocupaciones` va vacío: las personas que les faltan salen por sus obras, sus cargos y sus sucesiones, no
  por dónde nacieron;
- `profundidad`: qué tan conocido es lo menos conocido que el tema incluye, medido en Wikipedias (el cuartil inferior
  de los sitelinks de Wikidata de sus hechos, fuentes y personas), y la mediana.

Un hueco es algo que cae **adentro** del alcance y es **al menos tan notable** como lo que el tema ya tiene, pero
falta. Lo que cae afuera no es un hueco sino una ampliación: va a «Por hacer» de [PROGRESO.md](../../PROGRESO.md).

El alcance y la profundidad se fijan una vez (`huecos.py alcances --fijar`, que los infiere de los datos y de la
descripción del paquete, y después se revisan a mano) y no se recalculan solos: si cada ronda bajara la vara, la
búsqueda no terminaría nunca. Para ir más hondo en un tema se cambian a mano, y eso es una decisión, no un efecto
secundario.

## Los detectores

`python3 tools/enciclopedia/huecos.py` (sin argumentos muestra la ayuda). Sin red, los detectores tardan menos de un
segundo:

| detector | qué encuentra | prioridad |
|---|---|---|
| `capas` | años investigados en que una región no tiene era, religión, cultura o idioma, ni los tiene una región que la contiene (es lo que la app muestra en su lugar) | alta si corta una capa ya empezada; media si falta al borde o falta la capa entera |
| `tramos` | tramos sin hechos ni fuentes del tema en una de sus regiones, entre tramos que sí tienen | media; baja si otros paquetes cubren ese tramo |
| `referencias` | autores con ficha sin `autor_id` y obras sin sincronizar (se arreglan solos), hechos sin fuentes o sin coordenadas, fuentes sin enlace de lectura o sin lugar de escritura | alta lo mecánico, baja el resto |

Con `--red` consultan Wikidata a través de [QLever](https://qlever.dev) (mucho más rápido que el servicio oficial) y la
API de Wikipedia, y guardan las respuestas en `tools/enciclopedia/huecos/cache/`, fuera de git. QLever frena los pedidos
seguidos, así que la primera corrida completa puede tardar media hora; las siguientes salen de la caché (`rm -r
tools/enciclopedia/huecos/cache` para consultar de nuevo):

| detector | qué encuentra | prioridad |
|---|---|---|
| `series` | titulares de un cargo (P39) entre el primero y el último que tmap tiene | alta con tres o más titulares presentes y la mitad de la serie; media con un cuarto; baja fuera de esa ventana pero dentro del alcance |
| `sucesiones` | eslabones que faltan en una cadena de hechos u obras (P155/P156) | alta entre dos que están; media al final de una cadena, dentro del alcance y de la profundidad |
| `partes` | partes (P361) de un conjunto que el tema ya tiene a medias, tan notables como el tema | alta si está la mitad; media si no |
| `obras` | obras (P50) de autores que ya tienen ficha, tan notables como las fuentes del tema | alta si superan la mediana del tema; media si no |
| `candidatos` | hechos de los ejes del tema (batallas, tratados, revoluciones, desastres, expediciones, concilios) y personas de sus ocupaciones, ubicados en sus regiones y sus años | media si superan la mediana del tema; baja si no |

`informe` muestra por defecto las prioridades alta y media (`--prioridad baja` para todo). Cada hueco tiene una
**clave** estable (`serie:Q12969145:Q254041`, `capa:levante:eras:1292:1515`…). Uno rellenado desaparece solo, porque
los detectores comparan por QID, por id y por años. Uno que no se va a rellenar se anota en
[`decisiones.json`](../../tools/enciclopedia/huecos/decisiones.json), con la fecha y el motivo:

    python3 tools/enciclopedia/huecos.py decidir <clave> descartado "no es del tema: …"
    python3 tools/enciclopedia/huecos.py decidir <clave> sin-datos "ninguna fuente da la fecha"
    python3 tools/enciclopedia/huecos.py decidir --archivo decisiones.json   # [{"clave", "decision", "motivo"}]

Una decisión vale para su clave y para las que empiezan con ella: `serie:Q123` descarta la serie entera y
`capa:nubia` todas las capas de Nubia; `candidato:<paquete>:personas`, todos los candidatos de personas de un paquete,
si ese eje no es del tema.

## Una ronda

Se trabaja por rondas lanzadas a mano, nunca de forma desatendida. Cada ronda ataca uno o varios paquetes enteros, no
huecos sueltos de todos lados, para que cada tema quede cerrado.

1. **Detectar.** `huecos.py informe --red [--paquete P]…` cuenta los huecos por paquete y detector, y
   `huecos.py lotes <carpeta> --red [--paquete P]…` escribe un `.md` y un `.json` por paquete. Si un paquete nuevo no
   tiene alcance fijado, `huecos.py alcances --fijar` lo infiere: se revisan los años y las regiones contra la
   descripción del paquete y se corrigen a mano antes de seguir.
2. **Lo mecánico.** `huecos.py arreglar --escribir` (el `autor_id` cuyo nombre coincide exacto con una sola persona, y
   las obras de cada autor) y `python3 tools/enciclopedia/validar.py`.
3. **Triar.** Quien coordina lee los lotes y descarta en bloque lo que no es del tema: una serie de cargos que tmap
   tiene por otro motivo (tres generales que están por la Segunda Guerra Mundial no hacen de la jefatura del Estado
   Mayor un tema), un candidato que cae en las regiones y los años pero no en el tema. Es el paso más barato y el que
   más ahorra: un descarte es una línea; una ficha mal elegida es un escritor, un revisor y una traducción.
4. **Rellenar.** Un escritor por lote; un lote de más de unos 60 huecos se parte por detector o por época. Escribe en
   el [formato compacto](../../tools/enciclopedia/compacto/FORMATO.md#rellenar-huecos-de-un-paquete-que-ya-existe) un
   tema `huecos-<paquete>` en una carpeta de trabajo fuera del repo, los cambios a fichas que ya existen en
   `parches.json` y lo que decide no rellenar en `decisiones.json`, y construye con `construir.py <carpeta> --tema
   huecos-<paquete>` hasta que el informe quede limpio. Ver [el encargo del escritor](#encargo-del-escritor).
5. **Revisar.** Un revisor adversarial por lote, que no es el que escribió: ver
   [el encargo del revisor](#encargo-del-revisor). El escritor, o quien coordina, aplica las correcciones y vuelve a
   construir.
6. **Aplicar.** `huecos.py aplicar <carpeta>/huecos-<paquete> <paquete> --escribir` y
   `huecos.py decidir --archivo <carpeta>/huecos-<paquete>/decisiones.json`; después `validar.py` y `cobertura.py`.
   Si dos lotes crearon el mismo id, `aplicar` no escribe nada: el segundo usa el id del primero y se reconstruye.
7. **Verificar.** Se vuelve a correr el informe de esos paquetes: lo atacado tiene que haber desaparecido. Lo nuevo
   que aparezca (el eslabón siguiente de una cadena recién completada, otra batalla de la guerra que se sumó) es la
   ronda siguiente.

Se para cuando no queda nada de prioridad alta ni media en los paquetes elegidos, cuando una ronda cierra menos de la
mitad de lo que atacó (algo anda mal: se mira antes de seguir), cuando se llega al presupuesto de la tarea o a las tres
rondas. Nunca queda una búsqueda abierta sin tope.

Al final de la tarea, no de cada ronda:

- **Inglés.** `python3 tools/traduccion/enciclopedia.py estado`, `extraer <carpeta>` en lotes, cada lote traducido
  por un modelo chico, y `aplicar <respuestas>`; después `python3 tools/traduccion/probar.py`.
- **Lugares y enlaces.** Si se sumaron lugares antiguos, `python3 tools/pleiades/enlazar.py` los une con Pleiades;
  los enlaces de lectura nuevos reciben su copia en la Wayback Machine con `python3 tools/enciclopedia/enlaces.py`.
- **Probar.** `validar.py`, `cobertura.py --comprobar`, `tools/godot/tmap.py prueba` y `prueba --idioma en`, y
  `tmap.py registros --errores`.
- **Anotar.** En PROGRESO.md y PROGRESO.en.md, lo hecho con la fecha; en «Por hacer», lo que quedó `sin-datos` y vale
  la pena volver a buscar, y lo de fuera del alcance que apareció.

## Criterio

- **Wikidata propone, no decide.** Un candidato es una pista: entra si es del tema y se puede verificar (en noviembre
  de 2026, Wikidata daba a Alexandra Kolontái muerta en Bahía Blanca, y por eso aparecía entre los candidatos de la
  Argentina de 1862 a 1912). Cada dato se confirma con `tools/enciclopedia/compacto/consultar.py resumen <título>` y
  el artículo; `construir.py` además compara las fechas con Wikidata y avisa si no coinciden. Si Wikidata, Wikipedia
  y la bibliografía no coinciden, manda la fuente primaria o la bibliografía especializada, no la versión que más se
  repite.
- **Documentos primero.** En los hechos disputados se dice primero lo que muestran los documentos y después,
  atribuido, quién lo interpreta cómo. Sin propaganda de ningún lado y sin tomar una historia oficial como verdad.
  Wikipedia se lee con mirada crítica, y lo que ya está en tmap tampoco es verdad por estar: si al rellenar aparece un
  error en una ficha vieja, se corrige con un parche.
- **Nada inventado.** Lo inseguro va con `aprox`, `confianza: baja` o una `nota`, o no va. Un hueco que no se puede
  rellenar con datos verificables queda `sin-datos`, con el motivo.
- **El mismo molde.** Un hueco se rellena como sus vecinos: si el paquete tiene un hecho por cada presidencia, el
  presidente que falta lleva el suyo; si las batallas de la guerra citan el parte de batalla, la que falta también.
- **Lo de yapa.** Lo que aparece al investigar y cae dentro del alcance entra; lo que cae afuera se anota en «Por
  hacer», no se pierde.

## Encargo del escritor

Quien coordina completa lo que va entre llaves.

> Rellenás los huecos de «{paquete}» en la enciclopedia de TellMAP ({repo}). La lista está en {lote}.md: cada hueco
> tiene su clave, su QID de Wikidata cuando lo hay y la razón por la que se lo considera hueco.
>
> Antes de escribir, leé `tools/enciclopedia/compacto/FORMATO.md` (cómo se escribe; sobre todo «Rellenar huecos de un
> paquete que ya existe»), `data/enciclopedia/ESQUEMA.md` (qué significa cada campo) y la sección «Criterio» de
> `docs/es/huecos.md`. Mirá cómo el paquete trata a los vecinos de cada hueco (el JSON en `data/enciclopedia/paquetes/`)
> y seguí el mismo molde. Verificá cada dato con `python3 tools/enciclopedia/compacto/consultar.py`.
>
> Trabajás solo en {carpeta}/huecos-{paquete}/, con `paquete: huecos-{paquete}` en meta.txt. Cada hueco termina de una
> de tres formas:
>
> 1. rellenado: su ficha en el formato compacto (personas.txt, hechos.txt, fuentes*.txt, lugares.txt, leer.txt,
>    familias.txt), usando los ids que ya existen cuando corresponda, sin redefinir ninguno;
> 2. arreglado en una ficha que ya existe: una entrada en parches.json (eras y capas de una región, las fuentes de un
>    hecho, un enlace de lectura, un dato corregido);
> 3. no rellenado: una entrada en decisiones.json, `descartado` (no es del tema) o `sin-datos` (no se puede
>    verificar), con el motivo en una oración.
>
> Ninguno queda sin respuesta. Construí con `python3 tools/enciclopedia/compacto/construir.py {carpeta} --tema
> huecos-{paquete}` hasta que informe.txt quede limpio o con avisos explicados. Nunca uses `--escribir` ni toques
> `data/`: lo aplica quien coordina.
>
> Al terminar, devolvé cuántos rellenaste, arreglaste y descartaste, los avisos que quedaron y por qué, y lo que
> encontraste fuera del alcance que valga la pena anotar.

## Encargo del revisor

> Revisás, sin haberlo escrito, lo que se va a sumar a «{paquete}» en la enciclopedia de TellMAP ({repo}): lo que hay
> en {carpeta}/huecos-{paquete}/ (salida.json, parches.json, decisiones.json), contra el lote {lote}.md y la sección
> «Criterio» de `docs/es/huecos.md`. Buscá:
>
> - errores de hecho: fechas, lugares, cargos, autorías, cifras; confirmalos con
>   `python3 tools/enciclopedia/compacto/consultar.py resumen <título>` y, si hace falta, con la fuente primaria;
> - sesgo de cualquier lado: adjetivos de opinión, una interpretación presentada como hecho, una sola versión de algo
>   disputado, propaganda o una historia oficial tomada como verdad;
> - huecos mal cerrados: descartes que sí eran del tema, `sin-datos` que se podían verificar, fichas que no siguen el
>   molde de sus vecinos;
> - enlaces de lectura que no son legales o no llevan al texto que dicen.
>
> No reescribas: devolvé una lista de correcciones concretas (id, campo, qué dice, qué tiene que decir y con qué
> fuente), de la más grave a la menos, o «sin observaciones».

## Costo

- Los detectores no gastan nada más que tiempo de red, y el triaje de quien coordina es barato. Lo caro son el
  escritor y el revisor, y por eso conviene descartar antes de escribir.
- Para escribir alcanza un modelo intermedio, porque `construir.py` verifica títulos, QID, fechas y enlaces. Para
  revisar, el más capaz en los temas disputados (política, religión, guerras recientes) y el intermedio en los demás.
  Para traducir, el más chico.
- Los lotes van en paralelo, de a cuatro o cinco. Si dos lotes pueden necesitar la misma persona u obra, se reparte
  de antemano quién la define.
- Antes de la primera ronda se mira el presupuesto disponible; después de la primera se mide cuánto costó y con eso se
  decide cuántas más entran.
