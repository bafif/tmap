# Progreso de TellMAP

[English](PROGRESO.en.md)

Lo que falta, por bloque y en orden de prioridad, y los hitos de cada versión con la decisión que tomaron y por qué.
Cada tarea pendiente tiene su issue en GitHub, que crea `tools/github/organizar.py`. La visión por versiones está en
[la hoja de ruta del plan](docs/es/plan.md#hoja-de-ruta).

## Por hacer

### Mapa, rendimiento y distribución (0.2)

- [ ] **Probar en otros equipos.** Está probado en Linux, con Vulkan y con OpenGL, y en una Mac con Intel. Falta un
      Windows de verdad (el `.exe` pasa `--verificar` y la prueba completa con wine), una Mac con Apple Silicon (en la
      integración continua, `verificar-macos` saca una captura y comprueba que no salga lisa, pero nadie la miró en
      una de verdad), una Mac con Radeon, una notebook con gráficos integrados y una pantalla táctil (una notebook o
      una tablet con Windows o Linux: para Android o iPad no hay versión). Antes de cada versión, en una Mac con Intel:
      `TellMAP.app/Contents/MacOS/TellMAP -- --captura=x.png --comprobar_dibujo` (los runners de GitHub no tienen esa
      GPU).
- [ ] **Que la app de macOS también se actualice sola.** En macOS solo se actualizan los datos; con una versión nueva
      de la app, el aviso lleva a la página de descarga. Cambiar el ejecutable de adentro de `TellMAP.app` invalida su
      firma: hay que bajar el `.app` entero (un zip), reemplazarlo de una vez y reabrir.
- [ ] **Firmar y notarizar la versión de macOS** con una cuenta de Apple Developer (99 USD por año), para que se
      abra con doble clic sin pasar por Privacidad y seguridad.
- [ ] **Ver andar el `.dmg` de macOS.** `verificar-macos` arma con `hdiutil` un `.dmg` con `TellMAP.app` y un acceso
      a Aplicaciones, después de comprobar la app, y lo suma a la versión (si ese paso falla, la versión queda con el
      zip). Falta abrirlo en una Mac y, si anda, ofrecerlo en el README como forma de instalar. Instalar en
      Aplicaciones evita la *App Translocation* (macOS corre las apps en cuarentena desde una copia de solo lectura),
      que importa para que la app de macOS se actualice sola. Un `.pkg` no hace falta: la app no instala nada fuera
      del paquete y, sin notarizar, Gatekeeper lo frena igual.

### Enciclopedia progresiva (0.3)

- [ ] **Primera corrida real de `redactar.py`.** La verificación (citas, cifras, enlaces) está probada con una
      respuesta guardada; falta correrlo contra la API sobre un borrador real y revisar el resultado en el editor.
      Necesita una credencial de la API, que paga quien lo corre.

### Contenido de la enciclopedia

Lo cubierto y lo que falta, región por región, está en [el informe de cobertura](docs/es/cobertura.md).

- [ ] **La época contemporánea fuera de Europa, los Estados Unidos y la Argentina.** Faltan la historia política del
      siglo XX de Brasil, México, Chile y el resto de América Latina, China después de Mao, la India independiente,
      África después de la descolonización y el sudeste asiático, con sus fuentes propias.
- [ ] **Más enlaces de lectura para lo contemporáneo.** 302 de las 629 fuentes contemporáneas no tienen enlace:
      muchas tienen derechos vigentes (los textos de Perón entran en dominio público en 2045) y varios sitios (PNAS, la
      Royal Society, el IPCC, la Biblioteca Kennedy, mises.org, oll.libertyfund.org) le responden 403 al verificador
      aunque abren en un navegador. Habría que aceptar los DOI y los sitios oficiales que rechazan programas,
      comprobándolos a mano, y buscar las sentencias de las causas contra el kirchnerismo en una copia oficial que
      responda.
- [ ] **Causas judiciales en curso.** Los hechos dicen el estado a noviembre de 2026: el juicio oral de Cuadernos sin
      sentencia, y sin confirmar si empezaron los de Hotesur-Los Sauces y el Memorándum con Irán. Hay que revisarlos
      cada tanto y actualizar sus hechos.
- [ ] **Lo que quedó afuera de los temas contemporáneos**: Saint-Simon, Fourier, Owen, Bebel, Zetkin, Kollontai,
      Lumumba, Amílcar Cabral, Deng Xiaoping, Gödel, Wiener, Russell (solo como autor), Pessoa, Brecht, Calvino, Eco,
      Onetti, Carlos Fuentes, Clarice Lispector y Galeano. Hawái no tiene región (Pearl Harbor queda fuera de todas).
- [ ] **Religiones, culturas e idiomas de las regiones del mundo.** Las 46 regiones de `regiones-del-mundo.json`
      (Siberia, Japón, África, las Américas, Oceanía…) tienen resumen, eras y población, pero no esas tres capas:
      el modo de religión, cultura o idioma las deja rayadas. Faltan familias (sintoísmo, religiones tradicionales
      africanas, lenguas bantúes, austronesias…).
- [ ] **Estimaciones curadas fuera de Europa y el Cercano Oriente.** Las series por país de HYDE cubren todo, pero
      la parte de la población mundial que tiene además una estimación de especialistas para su región (Russell,
      Urlanis, Butzer, DellaPergola, los censos Han) va de un tercio en el año 1 a casi nada antes de Cristo y después
      de 1600. Candidatos: McEvedy y Jones (1978) para todo el mundo, Durand para China e India, Scheidel para el
      Imperio romano, Livi-Bacci para América. Sin estimación curada siguen también Bohemia, los Balcanes, Valaquia y
      Moldavia, el Báltico y Sicilia (Russell y Urlanis las dan agrupadas).
- [ ] **Población por polígono.** Las series son de países enteros: una región más chica que sus países (la Rus,
      Mesoamérica, los Andes) recibe la población de los países completos, y las regiones que están dentro de otra
      (Siberia, el Tíbet, el sur de la India, la Patagonia…) no tienen serie propia. Con las grillas de HYDE se podría
      sumar la población dentro de cada polígono (ver 0.4).
- [ ] **Tierra que queda sin región** (0,4 %): el extremo de Chukotka al este del meridiano 180, Svalbard, Hawái, las
      Azores y otras islas alejadas, y franjas costeras que los polígonos curados no alcanzan. El detalle por país
      está en el informe de cobertura.
- [ ] **Fuentes medievales sin lugar de escritura.** 18 fuentes (Beowulf, la Edda poética, el Cantar de Roldán, el
      Cuzarí…) no aparecen en el mapa porque su lugar es desconocido; cargar el que proponga la bibliografía, con
      `aprox` y confianza baja, o dejarlas así.
- [ ] **Más enlaces de lectura.** En lo medieval faltan traducciones en español y textos de sitios como el Medieval
      Sourcebook de Fordham o el Corpus Thomisticum.
- [ ] **La Argentina hasta 1912: lo que quedó pendiente.** Sin enlace legal: las leyes de tierras de 1882-1885, el
      Sistema económico y rentístico de Alberdi, Fronteras y territorios federales de Barros y buena parte de la
      historiografía con derechos vigentes. Sin ficha por falta de datos verificables: los hospitales coloniales de
      Santiago del Estero y Mendoza, la violencia unitaria de 1829 (Rauch) y la de Quiroga después de La Ciudadela, los
      diputados rioplatenses en Cádiz, las obras de Eduardo Wilde, Miron Burgin como persona y el libro de Di Meglio
      sobre la Mazorca. Por confirmar en el texto: la cifra de Lynch (unas 2000 muertes entre 1829 y 1852), las bajas
      de Obligado según cada parte, la frase «Quiera el pueblo votar» del manifiesto de 1912, las cartas de Mitre y de
      Sarmiento sobre el Chacho y el año del Instituto Rosas (1938 o 1941). Varias obras académicas todavía no dicen su
      crítica principal con autor. Cuatro fuentes siguen sin lugar de escritura (el Requerimiento, el Demócrates alter,
      la carta de Luis Ramírez y el diario de Luis de la Cruz). El inglés de estos paquetes es traducción automática:
      conviene revisarlo.
- [ ] **Tierra Santa: lo que quedó afuera.** El Sinaí va con Egipto. Líbano, Siria, Transjordania, Arabia, el Magreb y
      Chipre tienen solo la serie por país de HYDE, Gapminder y la ONU, sin estimación curada. Armenia tiene capas
      hasta 1920: después, la parte turca la pinta Anatolia y la república de Armenia queda sin capas. 24 fuentes sin
      lugar de escritura (el Nuevo Testamento, la Crónica de Miguel el Sirio, las fatuas de Bin Laden…). Los rollos
      digitalizados del Museo de Israel (dss.collections.imj.org.il) no responden y no tienen enlace. Los videos con
      que grupos yihadistas reivindican atentados no se enlazan, a propósito: los hechos dicen quién los reivindicó y
      cómo, con su artículo de Wikipedia.
- [ ] **Los celtas: lo que quedó afuera.** Sin enlace porque los sitios no le responden al verificador: LacusCurtius
      (casi todos los autores antiguos tienen enlace de Perseus, The Latin Library o Wikisource, pero no todos),
      Hesperia (las inscripciones celtibéricas y lusitanas), RIIG (el calendario de Coligny), la Biblioteca Virtual
      Cervantes (El cerco de Numancia) y legislation.gov.uk (las leyes galesas de 1535, 1993 y 2005). Sin copia
      abierta verificada: Lebor Gabála, Sanas Cormaic, los escolios de Berna, el Senchas Már, la Cáin Adomnáin, las
      leyes de Hywel, el Libro de Leinster y las glosas de Würzburgo. Sin ficha por falta de fuente comprobada: los
      celtas de Silesia, las inscripciones nóricas, Panóias, Uley, Hayling Island, Corent, Monte Bibele, las
      estimaciones modernas de población prerromana por autor (Beloch, McEvedy y Jones, Millett) y la cifra de muertos
      de la matanza de Galba. 18 fuentes sin lugar de escritura (el Mabinogi, el Libro de Taliesin, el Senchas Már…).
      Capas: el islam figura mayoritario en Anatolia y Galacia desde 1071 aunque la conversión fue gradual; pintar el
      galó de la Alta Bretaña pide una subregión propia; Egipto, el Levante y el Magreb tienen tramos con dos entradas
      mayoritarias a la vez. El inglés de estos paquetes es traducción automática.
- [ ] **Personas y fuentes en el centro de su ciudad.** En Buenos Aires siguen en un mismo punto unas 250 personas y
      240 fuentes (y cientos en Londres, París y Roma), además de unos 430 hechos sin un sitio único. Donde se sepa con
      seguridad, las personas podrían ir a su institución (una universidad, un diario) y las fuentes al lugar donde se
      escribieron; mientras tanto, la lista del grupo las muestra.

### Almacenamiento y descargas

El plan, con umbrales y dónde se aloja cada cosa, está en [Almacenamiento y descargas](docs/es/almacenamiento.md).
Cada paso se hace cuando se cruza su umbral, no antes.

- [ ] **Leer los paquetes en un hilo aparte** cuando la enciclopedia pase los 10 MB o tarde más de 1 s en abrir (la
      app lo dice al arrancar: «Enciclopedia: N elementos… en X ms»), con un índice compacto en memoria.
- [ ] **Teselas por época y macrorregión, administrador de descargas y caché con tope** (autoload `Descargas`: cola
      con prioridades, dos pedidos a la vez, nada mientras se mueve la línea de tiempo, lectura en
      `WorkerThreadPool`, caché de 500 MB con «Vaciar caché» en Ajustes). Hace falta con la 0.4 o al pasar los 50 MB.
- [ ] **Espejos permanentes** de cada versión de datos en Internet Archive y Zenodo, con las dos direcciones en el
      manifiesto del actualizador.
- [ ] **Los enlaces de lectura que quedaron sin copia.** Algunos enlaces (de Gutenberg, penelope.uchicago.edu,
      eur-lex…) no tienen copia en la Wayback Machine; `validar.py` dice cuántos. `python3
      tools/enciclopedia/enlaces.py --guardar` le pide que los archive, de a uno cada 15 s, y la Wayback Machine frena
      los pedidos después de unos pocos. La API de disponibilidad a veces no devuelve una copia que existe: volver a
      correrla encuentra más. Falta correr `--comprobar`, que lista los originales caídos.
- [ ] **Religión por país hoy** (Pew Research Center, 2010 y 2020) como serie más del bloque «País actual», y con eso
      las capas de religión de las regiones del mundo en la época actual.

### Datos abiertos a escala (0.4)

- [ ] **Pleiades: lo que falta.** Una parte de los lugares de la enciclopedia está unida a uno de Pleiades; el resto
      no tiene el identificador en Wikidata o es moderno. Cuando se suman lugares antiguos, hay que volver a correr
      `tools/pleiades/enlazar.py` (`validar.py` avisa si la unión nombra un lugar que ya no existe, pero no si falta
      uno nuevo). Los datos se leen en el hilo principal la primera vez que hacen falta (unos 150 a 270 ms al
      acercarse al mapa o al buscar por primera vez): pasarlos a un hilo con los paquetes, cuando se haga ese paso.
      Las descripciones de Pleiades están en inglés. Quedan afuera los 8800 lugares sin ubicación, los 1400 sin fechas
      y los que no son un punto (ríos, montes, islas, regiones, pueblos, rutas): los ríos y las rutas podrían ir como
      líneas en la 0.5.
- [ ] **Personas de Wikidata.** Con lugar y fecha de nacimiento y muerte.
- [ ] **Grillas de población de HYDE.** La serie por país de HYDE ya está (vía Our World in Data). Falta la grilla de
      5 minutos de arco, con sus escenarios bajo y alto, para sumar la población dentro de cada polígono, dar rangos
      de incertidumbre y poblar un modo de densidad en el mapa. El servidor de la Universidad de Utrecht
      (geo.public.data.uu.nl) pide resolver una verificación anti-bots y el depósito de HYDE 3.2 en DANS no responde:
      hay que bajarla a mano desde un navegador y dejarla en `raw_data/`.
- [ ] **Vasallaje.** Las relaciones de vasallaje y dependencia de Cliopatria.

### Movimiento (0.5)

- [ ] **Movimiento en el mapa.** Migraciones, rutas comerciales, campañas militares y difusión de religiones como
      flechas animadas y partículas.

### Vista 3D (0.6)

- [ ] **Vista 3D.** Relieve real, agua con shader propio, nubes y efectos, con la misma información del mapa 2D. Se
      elige en Ajustes. En Mac se dibuja con Compatibility (OpenGL), que no tiene varios efectos de Forward+
      (iluminación global SDFGI y VoxelGI, niebla volumétrica, reflejos SSR): la vista tiene que verse bien sin ellos,
      o las Mac que puedan eligen «Avanzado» en **Motor de dibujo**.

### Versión 1.0

- [ ] **Versiones descargables y web.** Las descargables ya están; falta la versión para el navegador.
- [ ] **Guía para sumar paquetes.** Para que otras personas sumen paquetes de la enciclopedia.
- [ ] **Revisión por especialistas.** De los datos, por área y época.

## Hecho

### La enciclopedia

Los paquetes nuevos llegan a las copias instaladas como actualización de datos, sin esperar una versión de la app. Qué
trae cada uno está en [la enciclopedia](docs/es/enciclopedia.md#qué-hay-hoy).

- **Los hechos, en el sitio donde pasaron**: 209 hechos que estaban en el centro de su ciudad van al lugar preciso,
  con las coordenadas de su artículo en Wikipedia: el Fuerte o la Casa Rosada para virreyes y presidentes, el Congreso
  de su época para las leyes, el tribunal para los juicios, el campo para las batallas. Lo que no tiene un sitio único
  (una elección, una epidemia, una guerra) sigue en la ciudad.
- **Los celtas, de sus raíces preindoeuropeas a su fin**: nueve paquetes, con capas de cultura, idioma y religión
  desde el Neolítico en las doce regiones donde vivieron celtas o sus antecesores. Casi todo lo que se sabe de ellos
  viene de griegos y romanos que fueron sus enemigos, de la arqueología y de textos escritos por monjes siglos
  después: cada ficha dice de qué fuente sale lo que afirma, y las cifras antiguas van como testimonio con su crítica.
- **La Argentina de los pueblos originarios a la ley Sáenz Peña**: siete paquetes, con todos los virreyes y
  presidentes. En lo disputado, cada ficha dice primero lo que muestran los documentos y después quién lo interpreta
  cómo, sin adherir a la historia liberal mitrista ni a ningún revisionismo; cada obra historiográfica lleva su tesis
  y su crítica principal.
- **La época contemporánea, en siete paquetes temáticos** (pensamiento económico, ideas políticas, la Argentina desde
  1880, ciencia y tecnología, cultura libre, guerras y orden mundial, letras y pensamiento del siglo XX). Los temas
  disputados dicen quién sostiene qué y su crítica principal; los fallos, el tribunal, qué resolvió y si está firme.
- **El mundo entero en regiones, con su población**: 46 regiones armadas con las fronteras de los países de Natural
  Earth completan el mapa (88 regiones sobre el 99,6 % de la tierra firme). Cada frontera compartida se simplifica una
  sola vez para los dos lados, así las regiones no se superponen. La población de cada región desde el 10 000 a. C.
  suma la serie por país de Our World in Data, y las estimaciones curadas de especialistas mandan sobre ella.
- **Tierra Santa, de la Antigüedad a hoy**: escrituras, la primera expansión islámica, las cruzadas desde todos los
  lados, el sionismo y el nacionalismo árabe, y los documentos modernos.
- **La Europa medieval, con énfasis en la filosofía**: de Agustín y Boecio al humanismo, con al-Ándalus, la filosofía
  judía y Bizancio.
- **Verificado contra Wikipedia y Wikidata**: desde la Europa medieval, cada paquete resuelve sus artículos en
  Wikipedia, toma de Wikidata los ids, las coordenadas y los títulos en español, y cruza las fechas de vida; donde
  Wikidata contradice a Wikipedia queda la fecha mejor respaldada. Solo entran enlaces de lectura que responden.
- **Familias de religiones, culturas e idiomas** (`familias.json`), con jerarquía y color fijo, para que la misma
  religión tenga siempre el mismo color y la leyenda agrupe por familia.

### Próxima versión

- **Nada en el mapa antes de tiempo**: una persona cuyo `activo` tiene `desde` y `hasta` aparece en su lugar de
  actividad solo esos años; antes, donde nació, y después, donde murió. Los hechos aparecen en su año, y «Ver en el
  mapa» y el buscador llevan a un año y un punto donde se ve. Así el mapa no muestra a nadie donde todavía no estaba.
- **27 279 lugares antiguos de [Pleiades](https://pleiades.stoa.org)** (0.4), cada uno mientras está atestiguado y
  con su ficha. Se leen recién al acercarse al mapa o al buscar, y se dibujan como un MultiMesh filtrado por año en
  un shader, en una sola llamada de dibujo.
- **Pleiades unido a la enciclopedia** por el identificador de Pleiades en Wikidata (P1584), si el punto queda a
  menos de 25 km. La unión va en `data/pleiades/enciclopedia.json` y no en los paquetes, que se editan a mano o con el
  editor.
- **Copias archivadas de los enlaces de lectura**: cada enlace tiene al lado un botón «Copia» que lleva a la Wayback
  Machine. Las copias van en `data/enciclopedia/archivo.json` y no en cada `leer`, para que `enlaces.py` no reescriba
  los paquetes.
- **Los lugares modernos tienen fecha**: bibliotecas, universidades, laboratorios, instituciones y sitios históricos
  llevan `fundacion` (el validador y el editor lo exigen), porque sin ella aparecían en todas las épocas.
- **Los pedidos a Wikipedia van en cola**: cuatro a la vez, primero el de la ficha que se mira y sin los de fichas ya
  cerradas, porque muchos pedidos juntos agotaban la cola de DNS de Godot.
- **La rueda, la línea de tiempo y las pantallas táctiles**: la rueda sobre una ventana ya no mueve el mapa; la línea
  de tiempo se recorre arrastrando sin cambiar la escala; con el dedo se mueve, se acerca y se tocan lugares, con más
  margen que el mouse. La prueba automática manda los eventos táctiles como los manda Godot.
- **Un `.dmg` para macOS** en cada versión, además del zip.
- **La lista de un grupo de marcadores**: el clic en un grupo abre en el panel la lista de sus hechos, personas y
  fuentes, cada uno con su ficha, y un botón para acercar el mapa hasta separarlos; volver desde una ficha regresa a
  la lista.

### 0.3.5 (11 de noviembre de 2026)

- **En español y en inglés.** La app elige según el idioma del equipo y se cambia en Ajustes. La enciclopedia se
  traduce en una capa aparte por paquete, con el hash del texto español, para que los paquetes sigan siendo uno solo
  y una traducción vieja se detecte sola. La página del proyecto, los documentos y las plantillas de GitHub también
  van en los dos idiomas, y la integración continua falla si falta un texto o un documento par.
- **Costas nítidas de cerca**: la distancia a la costa sale de los polígonos de Natural Earth y no de la máscara de
  píxeles, que de cerca daba escalones. La tierra más angosta que 1,5 px se engruesa hasta ese ancho, para que istmos
  e islas chicas no desaparezcan; el agua angosta no se ensancha.
- **El editor cubre la región entera**: religiones, culturas, idiomas y población, con la misma validación que
  `validar.py`. Las cifras de Our World in Data no se muestran ni se tocan: las escribe `poblacion.py`.
- **Aviso cuando lo editado tapa una versión nueva de un paquete**: la copia editada guarda su base, y si llega otra
  versión del paquete se ofrece pasarle lo nuevo (una mezcla de tres vías por elemento) o descartar los cambios, para
  que una copia vieja no tape en silencio lo que trae una actualización.
- Arreglado: las versiones exportadas salían con la tipografía genérica de Godot.

### 0.3.4 (10 de noviembre de 2026)

- **macOS dibuja con Compatibility (OpenGL).** En una Mac con Intel, Forward+ sobre MoltenVK no dibujaba el mapa, y
  la app es 2D y no usa nada propio de Forward+. Sigue siendo un solo `.app` universal: el problema depende de la GPU,
  no de la CPU.
- **Motor de dibujo en Ajustes** (Automático, Compatible u Avanzado), guardado en `user://motor.cfg` para no tocar el
  paquete firmado de macOS. Si nadie confirma en 20 s que se ve bien, vuelve solo al anterior.
- **`verificar-macos` comprueba que dibuja**: abre la app en una Mac de GitHub y, si la captura sale casi lisa, saca
  el zip de la versión.
- **«País actual» en la pestaña «Datos»**: desde 1800, las series de Our World in Data del país de hoy que contiene el
  punto (población, esperanza de vida, PIB per cápita, escolaridad…). Se leen al abrir la pestaña, no al arrancar.
- **[Plan de almacenamiento y descargas](docs/es/almacenamiento.md)**: versiones de GitHub como lugar principal,
  Internet Archive y Zenodo como espejos, y nada que se baje mientras se mueve la línea de tiempo.

### 0.3.3 (10 de noviembre de 2026)

- **La app pregunta antes de actualizarse** («Actualizar» o «Ahora no»), para que nada se baje sin permiso.
  «Buscar ahora», en Ajustes, instala sin preguntar, porque ya es un pedido.
- Los dos workflows que publican el manifiesto comparten un grupo de `concurrency`, para que uno no pise al otro.

### 0.3.2 (10 de noviembre de 2026)

- **Versión para macOS**: un `TellMAP.app` universal, con firma ad hoc y sin notarizar, exportado desde Linux y
  comprobado en una Mac de GitHub antes de quedar en la versión. En macOS se actualizan solos los datos, no la app,
  porque cambiar el ejecutable invalida la firma.
- **Nada «desde siempre»**: las religiones, culturas e idiomas de una región exigen `desde`, con la fecha desde la que
  hay registro, porque un `null` pintaba el mapa desde 3400 a. C.
- Arreglados el globo del mapa que quedaba encima del panel y el panel que a veces quedaba más largo que la ventana;
  la prueba automática comprueba los dos.

### 0.3.1 (10 de noviembre de 2026)

- **[Actualizaciones automáticas](docs/es/actualizaciones.md)**: una versión nueva de la app se baja, se verifica con
  sha256 y reemplaza al ejecutable. Si solo cambiaron los datos, se baja nada más lo que cambió, sin reinstalar.
- **Los datos se publican solos**: cada push a `main` que toca `data/` publica una versión de datos si la prueba
  completa pasa con el código de la última app publicada; si no pasa, esos datos esperan a la próxima versión.
- **Informe de cobertura** que se genera a partir de los datos y que `validar.py` avisa cuando quedó viejo.
- **El validador rechaza polígonos con vértices repetidos o lados que se cruzan**, que con la regla par-impar dejan
  afuera pedazos de la región.

### 0.3.0 (7 de noviembre de 2026)

Trae lo planeado para la 0.2, que no tuvo versión propia, y la enciclopedia progresiva.

- **Editor de la enciclopedia dentro de la app**, con formularios, coordenadas con un clic en el mapa y validación
  al guardar. Escribe el mismo JSON (un paquete leído y vuelto a escribir sale idéntico), para que el diff muestre
  solo lo cambiado; en la versión exportada guarda copias en la carpeta del usuario.
- **Cola de consultas sin ficha**, que queda en la computadora, y **borradores desde Wikipedia y Wikidata** para lo
  más consultado (`borradores.py`).
- **Fichas extendidas con IA** (`redactar.py`), sin confiar en el modelo: se descartan los párrafos sin cita válida,
  se marcan los años y cifras que no están en lo citado y se comprueban los enlaces. Ninguna pasa el validador sin
  revisión humana.
- **Datos dudosos revisados**: la población de Egipto según Butzer, los censos Han y los enlaces equivocados de
  Cliopatria, que se corrigen en `data/mapa/correcciones.json` con su porqué. Los 33 estados que Cliopatria trae dos
  veces se unifican al cargar.
- **Todo lo que se ve se puede tocar**: fichas de religión, cultura, idioma y entidad política, leyenda, pestaña
  Datos y línea de tiempo.
- **Regiones con el contorno real de cada época**: en los modos de capa, dentro del polígono se pinta pleno lo que
  ese año pertenece a una entidad de Cliopatria y rayado el resto. Cliopatria y no Natural Earth, porque las fronteras
  modernas no dicen nada de la época.
- **Fronteras nítidas de cerca**, **marcadores agrupados**, **atajos de teclado**, **todo usable sin mouse** y un
  tema de **alto contraste**.
- **Recorrido de toda la interfaz**: la prueba automática hace clic de verdad en cada control y falla si alguno da
  error o no hace nada.
- **Ejecutables de un solo archivo** para Linux y Windows, con los datos adentro, que `version.yml` exporta y publica.

### 0.1.0 (6 de noviembre de 2026)

- Mapa 2D con proyección de Miller, relieve, ríos y costas, y fronteras de 3400 a. C. a 2024 desde Cliopatria: 58 076
  unidades y un millón de cambios de dueño, en unos 3 ms por año.
- Nombres curvos que siguen la forma del territorio, línea de tiempo con eras, hechos y fuentes, y panel lateral con
  cinco pestañas.
- Resúmenes de Wikipedia en vivo y enciclopedia inicial: el piloto del antiguo Egipto y una muestra de once regiones.
- Tres temas visuales y cuatro niveles de calidad gráfica.
- Prueba automática, capturas sin monitor, registros de cada corrida y [el puente](tools/godot/README.md) para
  manejar la app y el editor desde la terminal.
- Página del proyecto en GitHub Pages e integración continua en cada push.
