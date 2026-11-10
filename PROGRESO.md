# Progreso de TellMAP

Bitácora de lo que está hecho y lo que falta. Cada tarea pendiente tiene su issue en GitHub y está en el tablero
del proyecto; `tools/github/organizar.py` crea los que falten. Se actualiza con cada cambio: lo terminado pasa a **Hecho** con su
fecha y lo nuevo que aparece se suma a **Por hacer**, en su bloque. Cada bloque está ordenado por prioridad, de arriba
hacia abajo. La visión general por versiones está en [la hoja de ruta del plan](docs/es/plan.md#hoja-de-ruta).

## Por hacer

### Ahora: que todo lo que se ve se pueda tocar (0.2)

La interfaz ya se ve completa, pero varias cosas son solo información. La meta del bloque: todo lo que se ve responde
a un clic y lleva a algo útil.

Bloque terminado el 6 de noviembre de 2026 (ver **Hecho**).

### Mapa, rendimiento y distribución (0.2)

- [ ] **Costas nítidas de muy cerca.** Con zoom 5 o más, la costa y las líneas de carta náutica del agua todavía
      muestran escalones: la distancia a la costa de `relieve.png` se calculó desde una máscara de píxeles. Hay que
      generarla en el pipeline desde los polígonos de Natural Earth, con resolución por debajo del píxel.
- [ ] **Probar en otros equipos.** Windows y una notebook con gráficos integrados. El `.exe` de la 0.3.0 ya pasó
      `--verificar` y la prueba completa con wine; falta un Windows de verdad. El modo OpenGL
      (`--rendering-method gl_compatibility`) ya se probó en la GTX 1050 Ti: se ve igual que con Vulkan.
- [ ] **Publicar la versión 0.3.0 con ejecutables.** Los zips de Windows y Linux ya están exportados con las
      plantillas oficiales de Godot 4.7.2, con los datos dentro del ejecutable, y pasaron la prueba completa (Linux
      nativo, Windows con wine). Falta crear la versión v0.3.0 en GitHub y subirlos; al publicarla, el workflow
      `version.yml` los vuelve a exportar y los reemplaza (va a ser su primera corrida). Los zips de `build/` son de
      antes del actualizador: los que valen son los que exporta el workflow, que además crea la versión fija
      `actualizaciones` con el primer manifiesto. Desde ahí, las apps instaladas se actualizan solas.
- [ ] **Aviso cuando una actualización de datos queda tapada por lo editado.** En la versión exportada, un paquete
      editado con el editor de la enciclopedia queda en una copia local que tapa al de adentro y también al de una
      actualización de datos. Hay que avisarlo al instalar y ofrecer descartar la copia o pasarle lo nuevo.

### Enciclopedia progresiva (0.3)

Lo que pedía la hoja de ruta quedó hecho el 7 de noviembre de 2026 (ver **Hecho**). Quedan dos tareas que surgieron al
hacerlo:

- [ ] **Primera corrida real de `redactar.py`.** La verificación (citas, cifras, enlaces) se probó con una respuesta
      guardada; falta correrlo contra la API con una credencial, sobre un borrador real, y revisar el resultado en el
      editor. Lo decide y lo paga quien lo corre.
- [ ] **Religiones, culturas, idiomas y demografía en el editor.** Hoy el editor cubre los datos principales, el área y
      las eras de las regiones; esas cuatro listas todavía se cargan a mano en el JSON.

### Contenido de la enciclopedia

El universo cubierto y el que falta, región por región, está en [docs/es/cobertura.md](docs/es/cobertura.md), que
genera `tools/enciclopedia/cobertura.py` (y `validar.py` avisa si quedó viejo).

- [ ] **Religiones, culturas e idiomas de las regiones del mundo.** Las 46 regiones de `regiones-del-mundo.json`
      (Siberia, Japón, África, las Américas, Oceanía…) tienen resumen, eras y población, pero no esas tres capas:
      el modo de religión, cultura o idioma las deja rayadas. Habrá que sumar familias (sintoísmo, religiones
      tradicionales africanas, lenguas bantúes, austronesias…).
- [ ] **Estimaciones curadas fuera de Europa y el Cercano Oriente.** Las series por país de HYDE cubren todo, pero
      la parte de la población mundial que tiene además una estimación de especialistas para su región (Russell,
      Urlanis, Butzer, DellaPergola, los censos Han) va de un cuarto en el año 1 a casi nada antes de Cristo y
      después de 1600. Candidatos: McEvedy y Jones (1978) para todo el mundo, Durand
      para China e India, Scheidel para el Imperio romano, Livi-Bacci para América. Sin estimación curada siguen
      también Bohemia, los Balcanes, Valaquia y Moldavia, el Báltico y Sicilia (Russell y Urlanis las dan agrupadas).
- [ ] **Población por polígono.** Las series son de países enteros: una región más chica que sus países (la Rus,
      Mesoamérica, los Andes) recibe la población de los países completos, y 24 regiones (Siberia, el Tíbet, el sur
      de la India, la Patagonia…) no tienen serie propia. Con las grillas de HYDE se podría sumar la población dentro
      de cada polígono (ver 0.4).
- [ ] **Tierra que queda sin región** (0,4 %): el extremo de Chukotka al este del meridiano 180, Svalbard, Hawái, las
      Malvinas, las Azores y otras islas alejadas, y franjas costeras que los polígonos curados no alcanzan. El
      detalle por país está en el informe de cobertura.
- [ ] **Fuentes medievales sin lugar de escritura.** 18 fuentes (Beowulf, la Edda poética, el Cantar de Roldán, el
      Cuzarí…) no aparecen en el mapa porque su lugar es desconocido; cargar el que proponga la bibliografía, con
      `aprox` y confianza baja, o dejarlas así.
- [ ] **Más enlaces de lectura.** 104 enlaces comprobados para 69 fuentes; faltan traducciones en español y textos de
      sitios como el Medieval Sourcebook de Fordham o el Corpus Thomisticum.
- [ ] **Tierra Santa: lo que quedó afuera.** El Sinaí va con Egipto. Líbano, Siria, Transjordania, Arabia, el Magreb y
      Chipre tienen solo la serie por país de HYDE, Gapminder y la ONU, sin estimación curada. Armenia tiene capas
      hasta 1920: después, la parte turca la pinta Anatolia y la república de Armenia queda sin capas. 24 fuentes sin
      lugar de escritura (el Nuevo Testamento, la Crónica de Miguel el Sirio, las fatuas de Bin Laden…). Los rollos
      digitalizados del Museo de Israel (dss.collections.imj.org.il) no respondían el 10/11/2026 y sus enlaces se
      sacaron. Los videos con que grupos yihadistas reivindican atentados no se enlazan, a propósito: los hechos
      dicen quién los reivindicó y cómo, con su artículo de Wikipedia.

### Datos abiertos a escala (0.4)

- [ ] **Lugares de Pleiades.** Los lugares antiguos de [Pleiades](https://pleiades.stoa.org).
- [ ] **Personas de Wikidata.** Con lugar y fecha de nacimiento y muerte.
- [ ] **Grillas de población de HYDE.** La serie por país de HYDE ya está (vía Our World in Data, ver **Hecho**).
      Falta la grilla de 5 minutos de arco, con sus escenarios bajo y alto, para sumar la población dentro de cada
      polígono, dar rangos de incertidumbre y poblar un modo de densidad en el mapa. El 10/11/2026 el servidor de la
      Universidad de Utrecht (geo.public.data.uu.nl) pedía resolver una verificación anti-bots y el depósito de HYDE
      3.2 en DANS no respondía: hay que bajarla a mano desde un navegador y dejarla en `raw_data/`.
- [ ] **Vasallaje.** Las relaciones de vasallaje y dependencia de Cliopatria.

### Movimiento (0.5)

- [ ] **Movimiento en el mapa.** Migraciones, rutas comerciales, campañas militares y difusión de religiones como
      flechas animadas y partículas.

### Vista 3D (0.6)

- [ ] **Vista 3D.** Relieve real, agua con shader propio, nubes y efectos, con la misma información del mapa 2D. Se
      elige en Ajustes.

### Versión 1.0

- [ ] **Versiones descargables y web.**
- [ ] **Guía para sumar paquetes.** Para que otras personas sumen paquetes de la enciclopedia.
- [ ] **Revisión por especialistas.** De los datos, por área y época.

## Hecho

### 10 de noviembre de 2026: actualizaciones automáticas

- [x] **La versión exportada se actualiza sola** ([docs/es/actualizaciones.md](docs/es/actualizaciones.md)). Al abrir
      consulta un manifiesto en GitHub; una versión nueva de la app se baja, se verifica (sha256) y reemplaza al
      ejecutable, y se abre la próxima vez o con «Reiniciar ahora» (Linux: se renombra encima; Windows: el viejo pasa
      a `.viejo`). Aviso arriba al centro y sección «Actualizaciones» en Ajustes, con la casilla para apagarlo.
- [x] **Actualizaciones solo de datos**: si cambian los datos y no el código, la app baja nada más los archivos que
      cambiaron (`.gz` con su sha256 en el nombre) y los instala en la carpeta del usuario por grupo (`mapa`,
      `enciclopedia`), que tapan a los de adentro (`Datos.ruta()`); la enciclopedia nueva se ve enseguida. Cada
      versión de datos pide una versión mínima de la app, y los datos bajados se descartan solos si la app trae unos
      más nuevos.
- [x] **Publicación**: `tools/actualizacion/publicar.py` (sella `data/version.json`, arma el manifiesto y los `.gz`);
      `version.yml` publica el manifiesto con cada versión de la app y `datos.yml`, nuevo, publica solo datos en cada
      push a master que toque `data/`, después de correr la prueba completa con el código de la última app publicada.
- [x] **Prueba de punta a punta**: `tools/actualizacion/probar.py`, en `pruebas.yml`. Pasó desde el código fuente y
      con un ejecutable de Linux exportado: baja solo el grupo que cambió, rechaza archivos y ejecutables adulterados,
      se reemplaza a sí mismo y vuelve a arrancar.

### 10 de noviembre de 2026: el mundo entero en regiones, con su población

- [x] **Las regiones que faltaban**, con eras, religiones, culturas e idiomas: Armenia (la meseta armenia) y Cilicia
      (hija de Anatolia) en `tierra-santa.json`; Finlandia, Cerdeña y Córcega y la estepa póntica en
      `edad-media.json`. 14 familias nuevas (tengrismo, religión escita, armenio, sardo, lenguas hurrito-urarteas…).
- [x] **Paquete `regiones-del-mundo.json`**: 46 regiones que completan el mapa (Siberia y el Lejano Oriente ruso, el
      Cáucaso, Asia central, el Tíbet, Japón, Corea, el sudeste asiático, el sur de la India, África por regiones, las
      Américas fuera de Mesoamérica, los Andes y el Río de la Plata, Oceanía), con resumen y eras. Los polígonos salen
      de las fronteras de los países de Natural Earth: cada frontera compartida se simplifica una sola vez para los dos
      lados y la que linda con una región curada se pega a sus vértices, así que no se superponen; las costas pueden
      abultarse sobre el mar pero no recortar tierra. Entre todas, las 88 regiones cubren el 99,6 % de la tierra firme
      (antes, el 16 %).
- [x] **Población de todas las regiones desde el 10 000 a. C.**: `tools/enciclopedia/poblacion.py` suma la serie por
      país de Our World in Data (HYDE 3.3 hasta 1799, Gapminder v7 hasta 1949 y la ONU desde 1950) según la
      asignación de `poblacion_regiones.json`, en 37 fechas. Las estimaciones curadas mandan; en las islas que se
      poblaron tarde se omiten los valores de modelo anteriores al poblamiento (HYDE daba gente en Islandia antes de
      874). 64 regiones tienen serie propia y 24 se cuentan dentro de otra; solo Santa Elena y las Malvinas quedan sin
      región.
- [x] **Informe de cobertura** (`docs/es/cobertura.md`), generado por `tools/enciclopedia/cobertura.py` con las
      unidades del mapa y el extracto de población: tierra cubierta, qué parte de la población mundial tiene serie y
      cuál estimación curada en cada época, una fila por región con sus capas y elementos, y lo que falta. `validar.py`
      avisa si el informe o las series quedaron viejos.
- [x] Arreglado: el polígono de `francia` tenía los Pirineos invertidos y dejaba afuera Gascuña, el Bearne y las Landas;
      el de `arabia` tenía la frontera con Jordania al revés y se metía en Jordania. El validador ahora rechaza los
      polígonos con vértices repetidos o lados que se cruzan.

### 10 de noviembre de 2026: Tierra Santa, de la Antigüedad a hoy

- [x] **Paquete `tierra-santa.json`**: 7 regiones nuevas (Tierra Santa, Líbano, Siria y Transjordania, hijas del
      Levante, más Arabia, el Magreb y Chipre) con eras, religiones, culturas e idiomas de la prehistoria a hoy; 176
      fuentes, 198 personas, 172 hechos y 75 lugares. Escrituras (Torá, Tanaj, Septuaginta, Vulgata, Nuevo
      Testamento, Corán y sus manuscritos más antiguos, Bujari, manuscritos del mar Muerto con el Rollo de la guerra,
      Mishná y Talmud); la primera expansión islámica de la hégira a Poitiers y los asedios de Constantinopla, con las
      primeras reacciones cristianas (Doctrina Jacobi, Sebeos, Sofronio, el Pseudo-Metodio, el Pacto de Omar); las
      cruzadas desde todos los lados (el pedido bizantino en Piacenza, Clermont, los cronistas latinos, las crónicas
      hebreas de 1096, armenios y sirios, Usama ibn Munqidh, al-Sulami y el primer llamado al yihad, Saladino);
      cómo pensó Europa al islam (Pedro el Venerable, Riccoldo, Dubois, Manuel II, Cusa, Pío II, Lutero, Tasso,
      Voltaire, Lessing, Gibbon, Renan y la respuesta de al-Afgani); los otomanos de Marj Dabiq a Viena; la cábala de
      Safed; el sionismo y el nacionalismo árabe; el Mandato con el informe Peel; las guerras árabe-israelíes; la
      Carta de Hamás de 1988 y su documento de 2017; el islamismo de Qutb, Azzam y Bin Laden; los atentados
      reivindicados, también los de la AMIA y la embajada de Israel en Buenos Aires; y el diálogo, de Nostra aetate a
      Ratisbona y «Una palabra común».
- [x] **Verificado contra Wikipedia y Wikidata** con el mismo método que el paquete medieval; se dejaron tres fechas
      antiguas (Hilel, Yojanán ben Zakai, Judá ha-Nasí) donde Wikidata contradice a Wikipedia. Los 95 enlaces de
      lectura respondieron 200: Wikisource en hebreo, árabe, castellano, griego, latín, italiano, francés, alemán e
      inglés, Proyecto Gutenberg, el Proyecto Avalon de Yale, el Medieval Sourcebook de Fordham, Sefaria, la Santa
      Sede y el informe Peel completo en UNISPAL e Internet Archive. Cada enlace dice si es de dominio público.
- [x] **Demografía de Tierra Santa** de DellaPergola (2001), los censos del Mandato (1922 y 1931), las Village
      Statistics de 1945 y las oficinas de estadística israelí y palestina (2023).
- [x] **Familias nuevas** en `familias.json`: 14, entre ellas el samaritanismo, los drusos, los alauitas, el
      ismailismo, los maronitas, la ortodoxia oriental, la fe bahá'í, la religión árabe preislámica y el ibadismo; los
      filisteos y los bereberes; el sudarábigo, las lenguas bereberes y el ídish.
- [x] **Elementos de otros paquetes enriquecidos**: la toma de Jerusalén de 1099 y Hattin tienen resumen completo y
      fuentes; Clermont y la conquista de Siria, fuentes; nueve autores ya cargados (Bernardo, Halevi, Maimónides,
      Najmánides, Cusa, Urbano II, Federico II, Inocencio III, Josefo) suman sus obras nuevas.

### 10 de noviembre de 2026: la Europa medieval, con énfasis en la filosofía

- [x] **Paquete `edad-media.json`**: 15 regiones nuevas (Península ibérica, Francia, Britania, Irlanda, Alemania y
      los Países Bajos, Escandinavia, Islandia, Polonia, Bohemia, Hungría, Balcanes, Valaquia y Moldavia, el Báltico,
      la Rus y Sicilia) con eras, religiones, culturas e idiomas desde la Antigüedad hasta hoy; 173 fuentes, 215
      personas, 125 hechos y 120 lugares, del saqueo de Roma a 1500. La filosofía va completa: de Agustín y Boecio a
      Eriúgena, Anselmo, Abelardo, Chartres y San Víctor; al-Ándalus y la filosofía judía (Ibn Gabirol, Avempace,
      Averroes, Maimónides, Crescas); los traductores de Toledo; la escolástica de París y Oxford con las condenas de
      1270 y 1277; Escoto, Ockham, Buridán y Oresme; la mística (Eckhart, Porete, Juliana); Bizancio (Focio, Pselo,
      Palamás, Pletón) y el humanismo hasta Ficino y Pico. De yapa: crónicas, sagas, derecho, ciencia, gobernantes,
      batallas, concilios, universidades y monasterios.
- [x] **Verificado contra Wikipedia y Wikidata**: cada artículo se resolvió en en.wikipedia (redirecciones y
      desambiguaciones), el título en español y el id de Wikidata salen de sus sitelinks, las coordenadas de lugares y
      hechos de P625, y las fechas de vida se cruzaron con P569/P570 (se dejaron seis fechas propias donde Wikidata
      contradice a Wikipedia, como la muerte de Ockham en 1347). Los 104 enlaces de lectura (Wikisource en latín,
      español, italiano, islandés, alemán y ruso, y Proyecto Gutenberg) respondieron 200.
- [x] **Demografía con fuente**: Russell (1972) para Iberia, Francia, Italia, Rus, Polonia y Hungría (500-1450) y
      Urlanis (1941) para Britania, Irlanda, Escandinavia y el área alemana (1000-1500), con notas cuando las dos
      series difieren o cuando la cifra agrupa territorios.
- [x] **Familias nuevas** en `familias.json`: 66, entre ellas el arrianismo, el catarismo, el husitismo, el
      protestantismo y las religiones precristianas de Europa; culturas germánicas, eslavas, celtas, andalusí, judías;
      lenguas germánicas, celtas, eslavas, bálticas, urálicas, el euskera y el hebreo.
- [x] Arreglado: el polígono de `italia` dejaba afuera a Nápoles y Amalfi; Italia suma su demografía medieval.
- [x] Arreglado: una era sin comienzo o sin final (`"desde"` o `"hasta"`: `null`, que el esquema permite) rompía la
      línea de tiempo y el panel al seleccionar un lugar. Ahora los períodos abiertos se muestran como «desde 1808» o
      «hasta 432» (`Enciclopedia.rango_de`), y la prueba automática selecciona París, Dublín y Kiev para cubrirlo.
- [x] La prueba automática abre los 919 elementos de la enciclopedia en el editor y salen idénticos.

### 7 de noviembre de 2026: enciclopedia progresiva (0.3)

- [x] **Editor de la enciclopedia dentro de la app** (Ajustes, o «Editar esta ficha» en cada ficha): formularios para
      fuentes, personas, hechos, lugares y regiones, coordenadas con un clic en el mapa, validación al guardar (año 0,
      rangos, ids y referencias, campos cerrados) y el mismo formato JSON: un paquete leído y vuelto a escribir sale
      idéntico, así el diff muestra solo lo cambiado. Al guardar, el mapa y las fichas se actualizan solos.
- [x] **Borradores desde Wikipedia y Wikidata** (`tools/enciclopedia/borradores.py`): para lo más consultado sin
      ficha, la capital, las personas clave (cargos de la entidad y las más conocidas de su época), los hechos fechados
      y el artículo de Wikipedia por secciones, en el formato del esquema. Probado con el Imperio otomano: 8 personas
      (Solimán, Mehmed II, Osmán I…), 10 hechos, 5 capitales y 19 secciones.
- [x] **Fichas extendidas con IA** (`tools/enciclopedia/redactar.py`): Claude redacta la historia por secciones citando
      las fuentes numeradas del borrador; se descartan los párrafos sin cita válida, se marcan los años y cifras que no
      están en lo citado y se comprueban los enlaces que propone. La región la muestra con citas que llevan a cada
      referencia.
- [x] **Revisión humana**: el editor abre cada borrador, calcula su área de estudio con el territorio de Cliopatria,
      muestra los avisos de la verificación y solo lo aprueba con «Revisé cada dato…»; los elementos pasan a un paquete
      con la fecha y la nota de la revisión. `validar.py` no deja publicar una ficha de IA sin revisión y, con
      `--borradores`, valida también los borradores.
- [x] **Datos dudosos revisados:**
  - Butzer (1976) estima 2,9 millones para Egipto hacia 1250 a. C. por capacidad de carga (3 a 3,5 por su método
    urbano; Kemp, 4 a 5): corregido y sumada su serie de 3000, 2500, 1800 y 150 a. C., según el resumen de Snape;
  - censos Han comprobados con el texto chino: el del año 2 con sus dos lecturas (59 594 978 del Hanshu, 57 671 400
    por comandancias) y el del 140 con 9 698 630 hogares y 49 150 220 personas;
  - nombres: «Hashemite Arab Federation» (1415-1439) es el Irak árabe, «Michoacán» (1305-1533) el Imperio purépecha,
    «Wihtgar» el reino de la isla de Wight y «Great Yuan» es Dayuan, que enlazaba a la dinastía Yuan
    (`data/mapa/correcciones.json` guarda los enlaces corregidos y el porqué);
  - los 33 estados que Cliopatria trae dos veces («X» y «(X)», mismo Wikidata) se unifican al cargar: un nombre, un
    color y sin frontera interna.
- [x] Arreglado: el gráfico de población dibuja la banda de incertidumbre por tramos (con una estimación sin rango no
      se podía triangular) y «Parte de» muestra el nombre en español.
- [x] La prueba automática abre los 271 elementos de la enciclopedia en el editor y comprueba que no cambian, guarda,
      aprueba un borrador y prueba el clic en el mapa; el recorrido suma cinco escenarios del editor (548 controles).
- [x] **El editor también guarda en la versión exportada**: como los paquetes van dentro del ejecutable, guarda copias
      en la carpeta del usuario que tapan a los de adentro.
- [x] **Versión 0.3.0 exportada** para Windows y Linux, con los datos dentro del ejecutable (un solo archivo).

### 6 de noviembre de 2026: enciclopedia progresiva (0.3)

- [x] **Cola de consultas sin ficha** en Ajustes: cuántos lugares se consultaron sin ficha, los más consultados
      (cada uno lleva al lugar y al año), copiar la cola en JSON y abrir su carpeta. Ajustes ahora tiene scroll.
- [x] Arreglado antes de publicarse: al soltar el foco de los botones en el momento de apretar, Godot cancelaba el
      clic. El recorrido de la interfaz ahora aprieta y suelta en cuadros distintos, como una persona, y lo detecta.

### 6 de noviembre de 2026: mapa (0.2)

- [x] **Marcadores agrupados.** Los que se pisan en pantalla se juntan en un círculo con su número y un punto de
      color por tipo; el clic acerca la cámara hasta separarlos, y los que comparten el punto exacto se abren en
      espiral de cerca. El agrupamiento usa una grilla con vecinos, lineal en la cantidad de marcadores.
- [x] **Fronteras nítidas de cerca.** Con menos de un texel por píxel, la unidad de cada punto sale de un voto
      bilineal de los cuatro texels vecinos y las líneas (fronteras, provincias, selección, mouse) se trazan con grosor
      fijo en pantalla desde la distancia al borde: curvas suaves en vez de escalones del ráster. De lejos sigue el
      método de siempre, con una transición entre los dos.
- [x] **Atajos de teclado**: 1 a 5 para los modos, / o Ctrl+F para buscar, G para ir a un año, + y - para el
      zoom, [ y ] para las pestañas, Retroceso para volver de una ficha y F1 para la ayuda, que ahora los lista y
      tiene scroll para entrar en ventanas bajas.
- [x] **Todo usable sin mouse.** Todos los botones, la leyenda y los diálogos se recorren con Tab, con un
      recuadro de foco del color del tema; con el mouse el foco se suelta solo, así la barra espaciadora sigue
      reproduciendo. El panel se desplaza siguiendo al foco.
- [x] **Tema «Alto contraste»**: texto blanco sobre negro (21:1) y acentos amarillos.
- [x] **Exportación lista.** `export_presets.cfg` (Linux y Windows, con el filtro `data/*`) y el workflow
      `version.yml`. Arreglado de paso: el `.gdignore` de `data/mapa` dejaba **afuera** todos los datos del mapa al
      exportar (el `.pck` pesaba 1,5 MB); ahora el relieve y el terreno usan el importador `keep` y el `.pck` (27 MB)
      corre la prueba automática completa. Nueva opción `--verificar` para comprobar un ejecutable.
- [x] `tmap.py revisar` ya no se cae a veces: dejaba que el script se recargara a sí mismo mientras corría.

### 6 de noviembre de 2026: religiones, culturas e idiomas tocables (0.2)

- [x] **Sección `familias` en la enciclopedia** (`data/enciclopedia/paquetes/familias.json`): 33 religiones,
      18 culturas y 29 idiomas, con nombre, familia mayor (islam sunita → islam → religiones abrahámicas), color fijo y
      artículo de Wikipedia comprobado contra la API. Los idiomas ahora también tienen `familia`. El validador revisa
      capa, padres sin ciclos, colores y que toda familia usada exista; [ESQUEMA.md](data/enciclopedia/ESQUEMA.md)
      lo documenta.
- [x] **Familias repetidas unificadas.** El politeísmo griego, el romano y la «Religión griega y romana» de Egipto
      quedan bajo «Religión grecorromana», y la leyenda muestra el nombre de la familia, no el de cada región.
- [x] **Ficha de religión, cultura e idioma.** Familia mayor y las que incluye, dónde está en el año elegido y con
      qué peso, barras por región sobre la línea de tiempo (con clic para ir al año), notas, fuentes de esas regiones
      y épocas, y resumen de Wikipedia. Mientras está abierta, el mapa pasa a ese modo y resalta sus áreas.
- [x] **Leyenda tocable.** Pasar el mouse resalta la familia en el mapa; el clic abre su ficha. Con muchas familias
      muestra las más extendidas y un botón para ver el resto.
- [x] **Pestaña Datos tocable.** Religión, cultura e idioma del lugar en filas con su color; cada fila abre su ficha.
- [x] **Clic en el mapa según el modo.** En religión, cultura o idioma, el panel abre la pestaña Datos con la
      familia de ese punto marcada y un botón a su ficha, y el mapa resalta esa familia.
- [x] **Búsqueda** de religiones, culturas e idiomas.
- [x] **Línea de tiempo tocable.** Las marcas de fuentes y hechos muestran su nombre (las cercanas, juntas) y abren
      su ficha con un clic, además de llevar al año.
- [x] **Ficha de la entidad política.** Desde la pestaña Resumen, el enlace de Datos o la búsqueda: superficie en el
      año elegido, territorio a lo largo del tiempo (gráfico con clic para ir al año), máxima extensión, lugares,
      hechos y fuentes de su territorio mientras le pertenecía, enlaces a Wikidata y Seshat, y Wikipedia. Mientras
      está abierta, el mapa político la resalta.
- [x] **Gráfico de población** con el valor, el rango y la fuente de cada estimación al pasar el mouse.
- [x] Las notas con fechas antes de Cristo ya no terminan en «a. C..».
- [x] **Recorrido de toda la interfaz** (`scripts/nucleo/recorrido.gd`, `tmap.py recorrido` y dentro de la
      prueba automática): clic real en 401 controles en 17 escenarios; falla si alguno da error o no hace nada.
      Mientras corre, los enlaces no abren el navegador (todos pasan por `Estado.abrir_url`) y no hay animaciones.
- [x] **Regiones con el contorno real de cada época.** En los modos de capa, dentro del polígono de la región se
      pinta pleno lo que ese año pertenece a una entidad de Cliopatria y rayado del mismo color el resto: el Egipto de
      1350 a. C. se ve como el valle del Nilo y no como un rectángulo. Se eligió Cliopatria y no Natural Earth porque
      las fronteras modernas (las de Egipto son casi rectas) no dicen nada de la época.
- [x] Más rápido en los modos de capa: los valores del mapa se guardan según qué familia rige en cada región, así
      que reproducir años o volver al modo no los recalcula.
- [x] Los botones de modo de arriba siguen al modo aunque cambie desde otro lado (una ficha, el puente).
- [x] Arreglado: las entradas con `"hasta": null` (Egipto desde el año 1000) daban error en los modos de capa.
      La prueba automática ahora pasa por las 80 fichas de familias, la leyenda y el clic según el modo, también
      en 1500.

### 6 de noviembre de 2026: GitHub y landing

- [x] **Landing del proyecto** en `docs/index.html`, publicada con GitHub Pages desde `master/docs`, con la estética
      de la app (Mármol y bronce, Cinzel y EB Garamond, capturas reales).
- [x] **Integración continua**: en cada push y pull request, valida la enciclopedia, compila los scripts y corre la
      prueba automática (`.github/workflows/pruebas.yml`).
- [x] Formularios de issues (error, idea, dato), plantilla de pull request y guía de colaboración.
- [x] `tools/github/organizar.py`: etiquetas, versiones, un issue por tarea, tablero, Pages, seguridad y release 0.1.

### 6 de noviembre de 2026: registros y fugas

- [x] **Registros en `.godot/registros/`** de cada corrida de la app y del editor, con trazas, y `tmap.py registros`
      para leerlos. Al cerrar, la app anota los nodos que quedaron sin liberar y de qué script vienen.
- [x] **Sin fugas al cerrar.** Godot reportaba cientos de objetos sin liberar («RIDs were leaked»). Las causas: el
      texto de Wikipedia que se perdía si el panel cambiaba mientras bajaba la imagen, el gráfico de población que se
      creaba aunque no se mostrara y un ciclo de referencias en el puente. Ahora la prueba completa y una sesión con
      ventana cierran sin ningún aviso.

### 6 de noviembre de 2026: herramientas para trabajar

- [x] **Puente** (`addons/tellmap_puente`, `tools/godot/tmap.py`): manejar la app y el editor desde la terminal o
      con un agente. Incluye año, cámara, selección, clics, capturas, errores con traza, recarga de shaders y
      enciclopedia, y GDScript. En el editor suma un panel «Puente» con botones para la prueba automática y la
      validación.
- [x] **Arranque que importa solo.** Un clon recién bajado, o uno con clases nuevas, ya no falla con «Parse error»:
      la app importa el proyecto y se vuelve a abrir.
- [x] `tmap.py revisar` (compila todos los scripts sin abrir la app) y `tmap.py doc` (la API exacta de la versión de
      Godot instalada).
- [x] [Guía para colaborar](docs/es/contribuir.md) y esta bitácora.

### 6 de noviembre de 2026: versión 0.1

- [x] Mapa 2D del mundo con proyección de Miller, relieve sombreado, ríos, costas suavizadas y líneas de carta
      náutica en el agua.
- [x] Fronteras políticas de 3400 a. C. a 2024 desde Cliopatria: 58 076 unidades, 1 001 996 cambios de dueño y unos
      3 ms por año.
- [x] Nombres curvos que siguen la forma del territorio, en español (1587 entidades), y que se apagan al acercarse.
- [x] Línea de tiempo con reproducción, velocidades, eras globales y locales, hechos y fuentes.
- [x] Panel lateral con cinco pestañas (Resumen, Historia, Fuentes, Gente y hechos, Datos) y fichas de fuente,
      persona, hecho, lugar y región.
- [x] Resúmenes de Wikipedia en vivo, primero en español y guardados en caché.
- [x] Enciclopedia inicial: piloto del antiguo Egipto y muestra de once regiones (15 regiones, 76 fuentes,
      55 personas, 78 hechos, 47 lugares), con su validador.
- [x] Modos de religión, cultura e idioma (donde hay datos), población estimada con gráfico y testimonios antiguos
      aparte.
- [x] Tres temas visuales (Mármol y bronce, Pergamino iluminado, Tinta y latón) y cuatro niveles de calidad gráfica.
- [x] Búsqueda, ajustes, pantalla de bienvenida y ayuda.
- [x] Prueba automática (`--prueba`) y capturas sin monitor (`tools/captura.sh`).
- [x] README en español e inglés, plan, datos y licencias, y la respuesta sobre Grokipedia (no tiene API oficial).
