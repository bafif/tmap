# Progreso de TellMAP

[English](PROGRESO.en.md)

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

- [ ] **Probar en otros equipos.** Windows, una Mac con Apple Silicon y una notebook con gráficos integrados. El
      `.exe` de la 0.3.0 ya pasó `--verificar` y la prueba completa con wine; falta un Windows de verdad. La Mac con
      Intel ya se probó (ver la 0.3.4 en **Hecho**). En Apple Silicon, desde la 0.3.4, `verificar-macos` saca una
      captura y comprueba que no salga lisa, pero falta mirar la app en una de verdad; tampoco se probó una Mac con
      Radeon. Antes de cada versión, en la MacBook con Intel:
      `TellMAP.app/Contents/MacOS/TellMAP -- --captura=x.png --comprobar_dibujo` (el runner de GitHub no tiene esa
      GPU). El modo OpenGL ya se probó en la GTX 1050 Ti: se ve igual que con Vulkan.
- [ ] **Que la app de macOS también se actualice sola.** Hoy en macOS solo se actualizan los datos; para una
      versión nueva de la app, el aviso lleva a la página de descarga. Reemplazar el binario de adentro de
      `TellMAP.app` invalidaría su firma: hay que bajar el `.app` entero (un zip), cambiarlo de una vez y reabrir.
- [ ] **Firmar y notarizar la versión de macOS** con una cuenta de Apple Developer (99 USD por año), para que se
      abra con doble clic sin pasar por Privacidad y seguridad. Lo decide Bautista.
- [ ] **Ver andar el `.dmg` de macOS.** Desde el 11/11/2026, `verificar-macos` arma con `hdiutil` un `.dmg` con
      `TellMAP.app` y un acceso a Aplicaciones, después de comprobar la app, y lo suma a la versión (si ese paso falla,
      la versión queda con el zip). Abrirla desde Aplicaciones evita la *App Translocation* (macOS corre las apps en
      cuarentena desde una copia de solo lectura), que va a importar el día que la app de macOS se actualice sola.
      Falta verlo en la próxima versión publicada, abrirlo en la MacBook y, si anda, nombrarlo en el README como
      forma de instalar. Un instalador `.pkg` no hace falta: la app no instala nada fuera del paquete y sin notarizar
      Gatekeeper lo frena igual.

### Enciclopedia progresiva (0.3)

Lo que pedía la hoja de ruta quedó hecho el 7 de noviembre de 2026 (ver **Hecho**). Queda una tarea que surgió al
hacerlo:

- [ ] **Primera corrida real de `redactar.py`.** La verificación (citas, cifras, enlaces) se probó con una respuesta
      guardada; falta correrlo contra la API con una credencial, sobre un borrador real, y revisar el resultado en el
      editor. Lo decide y lo paga quien lo corre.

### Contenido de la enciclopedia

El universo cubierto y el que falta, región por región, está en [docs/es/cobertura.md](docs/es/cobertura.md), que
genera `tools/enciclopedia/cobertura.py` (y `validar.py` avisa si quedó viejo).

- [ ] **La época contemporánea fuera de Europa, los Estados Unidos y la Argentina.** Los siete paquetes del 10/11/2026
      cubren las ideas, la ciencia, las guerras y la Argentina; faltan la historia política del siglo XX de Brasil,
      México, Chile y el resto de América Latina, China después de Mao, la India independiente, África después de la
      descolonización y el sudeste asiático, con sus fuentes propias.
- [ ] **Más enlaces de lectura para lo contemporáneo.** 302 de las 629 fuentes nuevas no tienen enlace: muchas tienen
      derechos vigentes (los textos de Perón entran en dominio público en 2045) y varios sitios (PNAS, la Royal
      Society, el IPCC, la Biblioteca Kennedy, mises.org, oll.libertyfund.org) responden 403 al verificador aunque
      abren en un navegador. Habría que aceptar los DOI y los sitios oficiales que rechazan programas, comprobándolos
      a mano, y buscar las sentencias de las causas contra el kirchnerismo en una copia oficial que responda.
- [ ] **Causas judiciales en curso.** Al 10/11/2026: el juicio oral de Cuadernos sigue sin sentencia, y no está claro
      si empezaron los de Hotesur-Los Sauces y el Memorándum con Irán. Revisarlos cada tanto y actualizar sus hechos.
- [ ] **Lo que quedó afuera de los temas contemporáneos**: Saint-Simon, Fourier, Owen, Bebel, Zetkin, Kollontai,
      Lumumba, Amílcar Cabral, Deng Xiaoping, Gödel, Wiener, Russell (solo como autor), Pessoa, Brecht, Calvino, Eco,
      Onetti, Carlos Fuentes, Clarice Lispector y Galeano. Hawái no tiene región (Pearl Harbor queda fuera de todas).
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
      digitalizados del Museo de Israel (dss.collections.imj.org.il) no respondían el 10/11/2026 y sus enlaces se
      sacaron. Los videos con que grupos yihadistas reivindican atentados no se enlazan, a propósito: los hechos
      dicen quién los reivindicó y cómo, con su artículo de Wikipedia.
- [ ] **Los celtas: lo que quedó afuera.** Sin enlace porque los sitios no respondían al verificador el 11/11/2026:
      LacusCurtius (casi todos los autores antiguos tienen enlace de Perseus, The Latin Library o Wikisource, pero no
      todos), Hesperia (las inscripciones celtibéricas y lusitanas), RIIG (el calendario de Coligny), la Biblioteca
      Virtual Cervantes (El cerco de Numancia) y legislation.gov.uk (las leyes galesas de 1535, 1993 y 2005). Sin copia
      abierta verificada: Lebor Gabála, Sanas Cormaic, los escolios de Berna, el Senchas Már, la Cáin Adomnáin, las
      leyes de Hywel, el Libro de Leinster y las glosas de Würzburgo. Sin ficha por falta de fuente comprobada: los
      celtas de Silesia, las inscripciones nóricas, Panóias, Uley, Hayling Island, Corent, Monte Bibele, las
      estimaciones modernas de población prerromana por autor (Beloch, McEvedy y Jones, Millett) y la cifra de muertos
      de la matanza de Galba. 18 fuentes sin lugar de escritura (el Mabinogi, el Libro de Taliesin, el Senchas Már…).
      Capas: el islam figura mayoritario en Anatolia y Galacia desde 1071 aunque la conversión fue gradual; pintar el
      galó de la Alta Bretaña pide una subregión propia; Egipto, el Levante y el Magreb tienen tramos con dos entradas
      mayoritarias a la vez. El inglés de estos paquetes es traducción automática.

### Almacenamiento y descargas

El plan completo, con umbrales y dónde se aloja cada cosa, está en [docs/es/almacenamiento.md](docs/es/almacenamiento.md).
Cada paso se hace cuando se cruza su umbral, no antes.

- [ ] **Leer los paquetes en un hilo aparte** cuando la enciclopedia pase los 10 MB o tarde más de 1 s en abrir (la
      app lo dice al arrancar: «Enciclopedia: N elementos… en X ms»), con un índice compacto en memoria.
- [ ] **Teselas por época y macrorregión, administrador de descargas y caché con tope** (autoload `Descargas`: cola
      con prioridades, dos pedidos a la vez, nada mientras se mueve la línea de tiempo, lectura en
      `WorkerThreadPool`, caché de 500 MB con «Vaciar caché» en Ajustes). Hace falta con la 0.4 o al pasar los 50 MB.
- [ ] **Espejos permanentes** de cada versión de datos en Internet Archive y Zenodo, con las dos direcciones en el
      manifiesto del actualizador.
- [ ] **Los enlaces de lectura que quedaron sin copia.** 118 de los 739 que no están en archive.org no tienen copia en
      la Wayback Machine (41 de Gutenberg, 35 de Wikisource): `python3 tools/enciclopedia/enlaces.py --guardar` le
      pide que los archive, de a uno cada 15 s. El 11/11/2026 web.archive.org dejó de aceptar conexiones desde esta
      máquina después de unos pedidos en paralelo a su API CDX, así que queda para otra corrida. Tampoco se corrió
      todavía `--comprobar`, que lista los originales caídos.
- [ ] **Religión por país hoy** (Pew Research Center, 2010 y 2020) como serie más del bloque «País actual», y con eso
      las capas de religión de las regiones del mundo en la época actual.

### Datos abiertos a escala (0.4)

- [ ] **Pleiades: lo que falta.** 91 de los 438 lugares de la enciclopedia están unidos a uno de Pleiades; el resto
      no tiene el identificador en Wikidata o es moderno. Cuando se suman lugares antiguos, hay que volver a correr
      `tools/pleiades/enlazar.py` (`validar.py` avisa si la unión nombra un lugar que ya no existe, pero no si falta
      uno nuevo). Los datos se leen en el hilo principal la primera vez que hace falta (unos 150 a
      270 ms al acercarse al mapa o al buscar por primera vez): pasarlos a un hilo con los paquetes, cuando se haga ese
      paso. Las descripciones de Pleiades están en inglés. Quedan afuera los 8800 lugares sin ubicación, los 1400 sin
      fechas y los que no son un punto (ríos, montes, islas, regiones, pueblos, rutas): los ríos y las rutas podrían
      ir como líneas en la 0.5.
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
      elige en Ajustes. Ojo: desde la 0.3.4, en Mac se dibuja con Compatibility (OpenGL), que no tiene varios
      efectos de Forward+ (iluminación global SDFGI y VoxelGI, niebla volumétrica, reflejos SSR). Hay que diseñar la
      vista para que se vea bien sin ellos o que las Mac que puedan elijan «Avanzado» en **Motor de dibujo**.

### Versión 1.0

- [ ] **Versiones descargables y web.**
- [ ] **Guía para sumar paquetes.** Para que otras personas sumen paquetes de la enciclopedia.
- [ ] **Revisión por especialistas.** De los datos, por área y época.

## Hecho

### 11 de noviembre de 2026: los celtas, de sus raíces preindoeuropeas a su fin

- [x] **Nueve paquetes nuevos** con 447 fuentes (249 primarias), 420 personas, 432 hechos, 131 lugares y 7 regiones
      (la enciclopedia pasa de 4724 a 6161 elementos) y 193 enlaces de lectura que respondieron 200, verificados contra
      Wikipedia y Wikidata con el formato compacto y con una revisión que buscó errores de hecho, sesgo y faltantes en
      cada tema. Casi todo lo que se sabe de los
      celtas antiguos viene de griegos y romanos que fueron sus enemigos, de la arqueología y de textos irlandeses y
      galeses escritos por monjes siglos después: cada ficha dice de qué fuente sale lo que afirma, y en lo disputado
      dice primero lo que muestran los documentos y la arqueología y después quién lo interpreta cómo, sin el bárbaro
      de los vencedores ni el romanticismo celtómano. Cada obra moderna lleva su tesis y la crítica que recibió.
      - `celtas-origenes-y-prehistoria`: los primeros agricultores y el megalitismo (Stonehenge y Newgrange, que no son
        celtas), la ascendencia esteparia, el campaniforme, la Edad del Bronce, Hallstatt y sus principados (Hochdorf,
        Vix, la Heuneburg, el Glauberg) y La Tène; las hipótesis sobre el origen de las lenguas celtas (Gimbutas,
        Renfrew, Mallory, Anthony, «Celtic from the West», Sims-Williams) y los estudios genéticos, con su crítica
        arqueológica; la escritura celta más antigua (el lepóntico de Castelletto Ticino, siglo VI a. C.); los pueblos y
        lenguas anteriores o vecinos (tartesio, íbero, aquitano, etrusco, rético, ligur).
      - `galos-y-galia`: los celtas de Italia según Polibio y Livio (con lo que es leyenda), Masalia, los arvernos, la
        Narbonense, cimbrios y teutones, la guerra de las Galias campaña por campaña con unos 90 personajes, las cifras
        de César como testimonio criticado (Henige, Rambaud, Raaflaub, Roymans), la sociedad gala según César y según la
        arqueología, el vino a cambio de esclavos, la Galia romana y sus revueltas, la tabla claudiana y el fin del galo.
      - `celtas-del-danubio-y-galacia`: boyos, el Nórico, escordiscos y eraviscos, la invasión de 280-277 a. C. y
        Delfos (lo piadoso separado de lo verosímil), el reino de Tile, los gálatas, Pérgamo y sus estatuas, Deyótaro,
        la carta de Pablo, el gálata que todavía oyó Jerónimo, los mercenarios helenísticos y el robo del oro de Manching.
      - `celtas-de-hispania`: celtíberos, vacceos, vetones, lusitanos, galaicos, astures y cántabros con el debate de
        su celticidad, sus vecinos íberos, Segeda, Numancia, Viriato, Sertorio, las guerras cántabras, los bronces de
        Botorrita y las téseras de hospitalidad, Schulten y el mito de Numancia.
      - `celtas-de-britania-e-irlanda`: la Edad del Hierro de las islas, la conquista romana con cada jefe britano
        (Carataco, Cartimandua, Boudica, Calgaco), los pictos y el debate de su lengua, la Britania posromana con
        Gildas y Arturo como debate, Irlanda (Tara, Emain Macha, el ogam, Paladio y Patricio, las leyes, el Táin y la
        discusión de si es «una ventana a la Edad del Hierro») y Gales (el Gododdin, Taliesin, el Mabinogi, Hywel Dda).
      - `religion-celta`: cómo se formó (lo anterior, lo heredado según la comparación indoeuropea con sus críticas, lo
        tomado por contacto), los dioses con sus inscripciones, los druidas en todos los textos antiguos y en las
        lecturas modernas, el sacrificio humano y las cabezas con la arqueología de cada lado, el calendario de Coligny
        y las fiestas (Samain y Halloween según cada autor), la mitología irlandesa escrita por monjes y el debate entre
        nativistas y antinativistas, la cristianización y lo que sobrevivió de verdad.
      - `celtas-en-las-fuentes-antiguas`: cómo los vieron los demás, de Hecateo a Jerónimo: cada autor con lo que vio,
        lo que copió y lo que quería, cada obra con sus pasajes, las imágenes del galo vencido y si los celtas
        escribieron (la regla druídica de César y las inscripciones que sí quedaron).
      - `celtas-legado-e-historiografia`: topónimos y palabras de origen celta, las lenguas celtas hasta los censos de
        hoy, la invención moderna de «lo celta» (Lhuyd, Pezron, Ossian, Iolo Morganwg, el neodruidismo), los usos
        políticos (Napoleón III, Ambiórix, Boudica, el celtismo gallego, Vichy, Mitterrand), Astérix, la historiografía
        y el debate de los «celtoescépticos», y la colonia galesa del Chubut.
      - `mundo-celta`: siete subregiones (Galacia, Celtiberia, Galecia, Galia Cisalpina, Armórica, Caledonia y Nórico)
        con eras, capas y demografía.
- [x] Capas de cultura, idioma y religión desde el Neolítico en las doce regiones donde vivieron celtas o sus
      antecesores (Francia, Iberia, Britania, Irlanda, Alemania, Bohemia, Hungría, Rumania, los Balcanes, Italia,
      Anatolia y Polonia), con 42 familias nuevas y las eras prehistóricas; correcciones de lo que había (el latín no era
      mayoritario en Iberia desde 218 a. C. ni en Italia desde 700 a. C., el sur de Alemania era celta, el aquitano
      separado del vasco), cada una con su fuente. Demografía: Frier, Scheidel, Harper y Alcock, y las cifras antiguas
      (César, Polibio, Plutarco, Plinio, Livio) como testimonio con su crítica.
- [x] Revisión de las fichas existentes del período: la guerra de las Galias trataba de Italia y se había escrito «en
      Roma», Clontarf tenía los bandos al revés, Geoffrey de Monmouth estaba en una universidad que no existía, Columbano
      en Bobbio en vez de Luxeuil; Anatolia ya no tiene dos religiones mayoritarias a la vez. Unas 45 fichas sumaron lo
      que encontraron los temas (pasajes sobre los celtas, la colonia galesa en Rawson, Fontana y la inmigración).
- [x] El constructor del formato compacto acepta coordenadas entre corchetes y lugares con espacios en «activo».
- [x] El inglés de los textos nuevos es traducción automática; los títulos de las obras publicadas en inglés son los
      originales.

### 11 de noviembre de 2026: enlaces de lectura que no se pierden

- [x] **Copias archivadas de los enlaces de lectura.** `tools/enciclopedia/enlaces.py` busca en la Wayback Machine la
      copia de cada enlace `leer` y la guarda en `data/enciclopedia/archivo.json`: 621 de los 739 enlaces que no están
      en archive.org tienen copia. La ficha de una fuente muestra un botón «Copia» al lado de cada uno, por si el
      original no abre, y `validar.py` avisa cuántos no la tienen. Las copias van aparte y no como campo `archivo` en
      cada `leer` (lo que decía el plan de almacenamiento): así la herramienta no reescribe los paquetes que se
      editan a mano o con el editor. Se corre a mano antes de cada versión.

### 11 de noviembre de 2026: los lugares antiguos de Pleiades (0.4)

- [x] **27 279 lugares antiguos de [Pleiades](https://pleiades.stoa.org)** en el mapa (CC BY 3.0): asentamientos,
      villas, fortificaciones, santuarios, tumbas, puertos, estaciones y puentes, edificios públicos, minas y sitios
      arqueológicos, cada uno mientras está atestiguado (del 3000 a. C. a hoy, sobre todo del 500 a. C. al 500).
      `tools/pleiades/pleiades.py` baja el volcado diario y escribe `data/pleiades/lugares.json` (1,5 MB, una fila
      por lugar). Se leen recién al acercarse al mapa o al buscar. Los puntos son un MultiMesh filtrado por año en un
      shader (una sola llamada de dibujo para todos) y aparecen desde el zoom 1,3, chicos para no confundirse con las
      ciudades de la enciclopedia; los nombres de los asentamientos, desde el 4,5, y todos desde el 7. Cada lugar
      tiene ficha: categoría, años, y en vivo (por la misma cola que Wikipedia) su descripción, sus nombres antiguos
      en cada lengua y el resumen de Wikipedia si Pleiades lo enlaza. Se buscan desde la barra, hay interruptor en la
      leyenda y crédito en Ajustes y en [Datos y licencias](docs/es/datos.md). Probado con Vulkan y con OpenGL.
- [x] **Pleiades y la enciclopedia, unidos.** `tools/pleiades/enlazar.py` busca en Wikidata el identificador de
      Pleiades (P1584) de cada lugar de la enciclopedia, a partir de su artículo de Wikipedia, y lo acepta si el punto
      queda a menos de 25 km (`data/pleiades/enciclopedia.json`; los paquetes no se tocan). Quedaron 91 unidos (León
      con el campamento de la *Legio VII Gemina*, La Meca con *Macoraba*, Medina con *Iathrippa*): su punto de
      Pleiades ya no se dibuja encima de la ciudad, y la ficha de la ciudad suma los nombres antiguos de Pleiades.

### 11 de noviembre de 2026: lugares con fecha y Wikipedia en cola

- [x] **Los lugares modernos ya no aparecen en todas las épocas.** Un lugar sin `fundacion` se veía desde 3400 a. C.
      (la playa de Omaha en el mapa de 1350 a. C.). Los catorce que estaban así tienen su año, verificado: los
      edificios y las instituciones, el de su inauguración (Estación Once, 1857; los tribunales de Comodoro Py, c. 1993,
      cuando se mudaron los juzgados federales al edificio de Vialidad); los sitios y los lugares naturales, el del
      hecho que los hace conocidos (Martín García, 1516; Malvinas, 1764, la primera población, porque el primer
      avistaje está en disputa; la Casa del Acuerdo, 1852; Omaha, 1944); Rosario, c. 1724, y Loreto, c. 1632.
      `validar.py` exige ahora la fecha en bibliotecas, universidades, laboratorios, instituciones y sitios históricos,
      el editor de la app lo avisa y el criterio quedó en el esquema. Las ciudades antiguas de origen desconocido
      (Tierra Santa, Tebas, Heliópolis) siguen sin fecha, a propósito.
- [x] **Los pedidos a Wikipedia van en cola.** La app pedía el resumen y la imagen de cada ficha que se abría, todos a
      la vez y aunque la ficha ya se hubiera cerrado, y con muchas seguidas se agotaba la cola de DNS de Godot (la
      prueba automática dejaba unos 5100 avisos «Out of resolver queries»). Ahora `wiki.gd` hace cuatro pedidos a la
      vez, atiende primero el de la ficha que se está mirando, descarta los de fichas viejas, comparte el pedido si
      dos piden lo mismo y no recuerda un fallo de conexión (se vuelve a probar al reabrir la ficha). La prueba
      completa: 0 avisos.

### 11 de noviembre de 2026: las versiones exportadas, con sus tipografías

- [x] Arreglado: **las versiones exportadas salían con la tipografía genérica de Godot** en vez de Cinzel y EB
      Garamond. `TemaUI` leía el `.ttf` crudo con `FileAccess`, y en lo exportado el `.ttf` no viaja: solo su versión
      importada. Desde el código fuente no se notaba, porque ahí el archivo está en disco. Ahora carga el recurso
      importado (y lee el `.ttf` solo si todavía no se importó). Comprobado con un `.pck` exportado, abierto desde una
      carpeta sin el proyecto.

### 11 de noviembre de 2026: lo editado ya no tapa en silencio a lo nuevo

- [x] **Aviso cuando lo editado tapa una versión nueva de un paquete.** En la versión exportada, lo que guarda el
      editor de la enciclopedia es una copia del paquete que tapa al de adentro y al de las actualizaciones de datos.
      Ahora, al guardar la primera copia, se guarda al lado su base (lo que había debajo); si después una
      actualización de datos o una app nueva traen otra versión de ese paquete, al abrir (o al terminar de instalar)
      un cartel lo avisa y ofrece «Pasarle lo nuevo» o «Descartar mis cambios»; la cruz lo deja para la próxima vez.
- [x] **Pasarle lo nuevo es una mezcla de tres vías por elemento**: de cada fuente, persona, hecho, lugar o región
      queda lo que cambió la copia y lo demás sale de lo nuevo, con su orden; lo agregado en la copia va al final y lo
      que la copia borró sigue borrado. Si un elemento cambió en los dos lados queda el de la copia, y el cartel dice
      cuáles fueron. Las copias guardadas antes de esto toman como base lo que hay ahora debajo.
- [x] La prueba automática comprueba la mezcla y, en modo exportado, la base, la detección, el pase de lo nuevo y el
      descarte.

### 11 de noviembre de 2026: religiones, culturas, idiomas y población en el editor

- [x] **El editor de la enciclopedia cubre la región entera.** Además de los datos principales, el área y las eras,
      ahora edita religiones, culturas e idiomas (desde, hasta, nombre, familia, peso y nota; la familia se elige en
      un desplegable con las de `familias.json` de esa capa) y la población (año, cifra, mínimo y máximo, fuente,
      «testimonio antiguo» y nota). Las cifras se pueden escribir con puntos o espacios de miles.
- [x] **Las cifras de Our World in Data no se tocan.** Las escribe `tools/enciclopedia/poblacion.py`: el editor no
      las muestra (dice cuántas hay), las deja en su lugar y, si cambian las estimaciones curadas, avisa que hay que
      volver a correrlo. Una cifra nueva queda ordenada por año y sin claves vacías.
- [x] **La validación del editor es la de `validar.py`**: «desde» obligatorio, familia que exista en su capa, peso
      mayoritaria, importante o minoritaria, y en la población un entero mayor que cero y una fuente. Avisa si la
      cifra queda fuera del rango entre el mínimo y el máximo.
- [x] La prueba automática valida esos errores y agrega una cifra curada a una región con serie de Our World in Data.
      Para revisar el editor sin pantalla, `tools/captura.sh` acepta `--editar=region:polonia --desplazar=1200`.

### 11 de noviembre de 2026: costas nítidas de muy cerca

- [x] **La distancia a la costa sale de los polígonos** (`tools/pipeline/costa.py`, canal G de `relieve.png`). Antes
      se calculaba desde la máscara de píxeles, con distancias enteras, y de cerca la costa y las líneas de carta
      náutica del agua eran escaleras. Ahora el signo sale de la regla par-impar en el centro exacto de cada píxel, la
      distancia es la euclídea a los segmentos de Natural Earth (exacta hasta 2 px de la costa y propagada con *jump
      flooding* hasta 32 px; contra fuerza bruta, error medio de 0,06 px) y los cortes del antimeridiano no cuentan
      como costa. Tarda un minuto; `python3 costa.py` reescribe solo ese canal, y `p1_base.py` lo usa.
- [x] **Nada se pierde por ser más chico que un píxel.** Con la distancia exacta, una lengua de tierra más angosta que
      un píxel (el istmo de Curlandia, Hel, los Outer Banks, el Lido de Venecia) salía punteada o desaparecía. Cada
      tramo mide el ancho de la tierra hacia adentro y, si es menor que 1,5 px, se la engruesa hasta ese ancho; las
      3158 islas que entran en un cuadrado de 1,5 px son un disco de ese diámetro. El agua angosta (fiordos, el
      Bósforo) no se ensancha: se ve como una línea de costa, y el Bósforo, que antes quedaba cerrado, ahora se ve.
- [x] **De cerca, la costa es fina.** El shader tenía mínimos de ancho para disimular los escalones (borde de 0,3
      texel, línea de costa de 0,45 y olas de 0,35): con zoom 10 la costa medía unos 11 px de pantalla y se veía
      borrosa. Ahora son 0,1, 0,16 y 0,14; lejos no cambia nada, porque ahí manda el término proporcional al zoom.
- [x] `relieve.png` pasa de 15,5 a 16,7 MB (se guarda con compresión 9; con la de antes eran 17,6). Como todo `data/`,
      llega a las copias instaladas como actualización de datos.

### 11 de noviembre de 2026: la Argentina de los pueblos originarios a la ley Sáenz Peña

- [x] **Siete paquetes nuevos** con 382 fuentes, 420 personas, 549 hechos y 110 lugares (la enciclopedia pasa de 3175
      a 4636 elementos) y 222 enlaces de lectura que respondieron 200, verificados contra Wikipedia y Wikidata con el
      formato compacto. Cada tema lo escribió un agente y lo corrigió otro, un revisor adversarial que buscó errores
      de hecho, sesgo y faltantes (193 correcciones). Wikipedia se usó con mirada crítica: los hechos disputados dicen
      primero lo que muestran los documentos y después quién los interpreta cómo, sin adherir a la historia liberal
      mitrista ni al revisionismo rosista, peronista o de izquierda.
      - `pueblos-originarios-del-cono-sur`: arqueología y cada pueblo con su lengua y su destino; los collas y el
        Qullasuyu; el dominio inca en el noroeste y Cuyo con los cronistas que lo registraron (Betanzos, Cieza,
        Sarmiento de Gamboa y la tesis toledana de la «tiranía» inca, Guamán Poma, Garcilaso como contrapunto); las
        guerras calchaquíes y la desnaturalización de los quilmes; la frontera sur de los malones a la Conquista del
        Desierto, con las cifras oficiales de 1879 y lo que pasó con los prisioneros; Tierra del Fuego y el Chaco.
      - `rio-de-la-plata-colonial`: exploración, fundaciones, gobernaciones y audiencias, el derecho indiano y el
        debate sobre la conquista (Montesinos, Vitoria, Las Casas, Sepúlveda, Valladolid), la leyenda negra y la
        leyenda rosa con obras de los dos lados (De Bry, Juderías, Carbia, Hanke, Powell, Keen, Roca Barea,
        Villacañas), la caída demográfica con sus estimaciones, los jesuitas, la Universidad de Córdoba, el contrabando
        y la aduana seca, la trata de esclavos y los primeros hospitales.
      - `virreinato-e-independencia`: los doce virreyes con su mandato, las reformas borbónicas, las invasiones
        inglesas, la crisis de 1808, las Cortes y la Constitución de Cádiz («la Pepa») y su derogación, Mayo con sus
        actas y sus leyendas, el Plan de Operaciones y su polémica, las juntas, los triunviratos y los Directores
        Supremos, la Asamblea del Año XIII, el Congreso de Tucumán, Artigas y las campañas de San Martín y Belgrano.
      - `guerras-civiles-y-organizacion-nacional`: el año 20 y los caudillos, Rivadavia, la guerra con el Brasil, la
        convención García con la que el gobierno nacional resignaba la Banda Oriental, la fundación del Uruguay, el
        fusilamiento de Dorrego, la polémica Ferré-Roxas y Patrón y el Pacto Federal (las provincias no querían pagarle
        a la aduana porteña para comerciar por el Paraná), y de Caseros a Pavón con la Constitución de 1853.
      - `rosas-y-la-confederacion`: Rosas y la suma del poder público, la Sociedad Popular Restauradora y la Mazorca
        con sus jefes, sus víctimas, el terror de 1840 y 1842, las confiscaciones y el juicio y la ejecución de los
        mazorqueros en 1853; las cifras de las Tablas de sangre y su crítica; los bloqueos y Obligado con los partes y
        los tratados de 1849-1850; la Generación del 37; las causas de Caseros y el juicio a Rosas (1857-1861).
      - `argentina-1862-1912`: cada presidente con su mandato, la guerra del Paraguay con sus causas, el tratado
        secreto, las pérdidas paraguayas y la oposición interna, las montoneras, el Estado liberal, la Generación del
        80 con sus escritos, la cuestión social y la reforma electoral.
      - `historiografia-argentina`: Mitre y López y su polémica, Saldías y Quesada, la Nueva Escuela Histórica, el
        revisionismo nacionalista y el de izquierda, y la historiografía académica posterior, cada obra con lo que
        sostiene y su crítica principal.
- [x] Capas de cultura, idioma y religión del Río de la Plata (que tenía tres tramos), del noroeste argentino, la
      Patagonia y el Gran Chaco (que no tenían ninguna), del poblamiento a 2000, con 13 familias nuevas.
- [x] Revisión crítica de lo que ya estaba: 19 correcciones de fichas existentes (los nombres con «es:» que había dejado
      el constructor, Juárez Celman y Roca concuñados y no cuñados, la cita mal armada del acta de independencia, la
      del Manifiesto Liminar, los charrúas fuera de la pampa…), y otras a partir de lo que encontraron los temas: la
      Conquista del Desierto ahora tiene fuentes y cifras oficiales, la Semana de Mayo cuenta los cabildos del 22 al 25,
      el Facundo es fuente primaria, la Semana Trágica, la Patagonia rebelde y la ficha de Yrigoyen dicen bajo qué
      gobierno ocurrieron las represiones, y la ley Sáenz Peña ya no dice que terminó con todo fraude.
- [x] El inglés de los textos nuevos se tradujo en forma automática (Claude Haiku, en lotes con verificación de claves):
      Google Translate rechaza las consultas automáticas.

### 10 de noviembre de 2026: la época contemporánea, en siete paquetes

- [x] **Siete paquetes nuevos** con 629 fuentes, 510 personas, 440 hechos y 86 lugares (la enciclopedia pasa de 1510
      a 3175 elementos), verificados contra Wikipedia y Wikidata con el mismo método que los paquetes medievales y de
      Tierra Santa, y 376 enlaces de lectura que respondieron 200:
      - `pensamiento-economico`: de Smith y Alberdi a la escuela austríaca completa (Menger, Böhm-Bawerk, Mises,
        Hayek, Rothbard, Kirzner, Hoppe, Huerta de Soto), Keynes y el keynesianismo, Chicago y Friedman, el
        libertarismo (Rand, Nozick, *Por una nueva libertad*), Bretton Woods, Mont Pelerin, la CEPAL y Prebisch, y las
        conferencias de Mises en Buenos Aires (1959).
      - `ideas-politicas`: socialismo y comunismo de Marx a Mao y el Che, anarquismo de Proudhon a la CNT, el
        sionismo que faltaba (Altneuland, Borojov, la Ley del Retorno) y el Bund, fascismo y nazismo como documentos
        históricos, Arendt y Popper, descolonización, derechos civiles, feminismo, ecologismo, el manifiesto de
        Kaczynski, Fukuyama y Laclau.
      - `argentina-contemporanea`: de la Ley 1420 a Milei, con la doctrina peronista completa (la Comunidad
        organizada, las veinte verdades, Conducción política, la Constitución de 1949), el antiperonismo, la
        dictadura, el Nunca más y el Juicio a las Juntas, Malvinas con las resoluciones 2065 y 502, los censos
        nacionales de 1869 a 2022 y las causas contra el kirchnerismo (Vialidad firme desde el 10/6/2025, Cuadernos,
        Hotesur, el Memorándum, Ciccone, Once, la Ruta del dinero K, los bolsos de López) con la posición de los
        condenados y los fallos que no fueron condena; $LIBRA, con el sobreseimiento del 23/10/2026.
      - `ciencia-y-tecnologia`: las publicaciones que abrieron tecnologías, de Planck y Einstein a Turing, Shannon,
        el transistor, el ADN, ARPANET, la web, el transformer, AlphaFold y CRISPR, con sus premios Nobel.
      - `cultura-libre-y-hackers`: GNU y su manifiesto, la carta de Gates (1976, anterior a GNU: no fue una
        respuesta), la GPL, Linux, los documentos Halloween, cypherpunks y Bitcoin, WikiLeaks y Assange, Manning,
        Snowden, Anonymous, Aaron Swartz y Sci-Hub.
      - `guerras-y-orden-mundial`: ultimátums y declaraciones de guerra de 1914 a 2022, los tratados y cartas del
        orden internacional (Versalles, la ONU, la Declaración Universal, la OTAN, Maastricht, París), la Guerra Fría
        y las guerras posteriores, con el estado de Ucrania al 10/11/2026.
      - `letras-y-pensamiento-del-siglo-xx`: las novelas y ensayos que marcaron el siglo, con los premios Nobel de
        literatura, la literatura argentina y latinoamericana, la filosofía y las ciencias sociales.
- [x] Arreglado: el polígono del Río de la Plata dejaba afuera la costa porteña y La Plata (la Casa Rosada y la Plaza
      de Mayo no caían en ninguna región); la Patagonia ahora incluye las islas Malvinas, que no tenían región.
- [x] La app abre los 3263 elementos de la enciclopedia (3,8 MB) en 150 a 230 ms.

### 10 de noviembre de 2026: la demografía de cada país y el plan de almacenamiento

- [x] **«País actual» en la pestaña «Datos»**: para cualquier punto del mapa desde 1800, el país de hoy que lo
      contiene y sus series de Our World in Data (fronteras actuales): población, esperanza de vida, hijos por mujer,
      mortalidad antes de los 5 años, edad mediana, población urbana, PIB per cápita (Maddison), pobreza extrema,
      alfabetización, años de escolaridad y nacidos en otro país. Cada fila muestra el último dato publicado hasta el
      año elegido; al tocarla se abre su gráfico, y el tooltip da la definición, el valor del mundo y la fuente. 232
      países, 0,9 MB (`data/demografia/paises.json`, de `tools/demografia/series.py`).
- [x] **País de cada unidad del mapa**: `tools/pipeline/p4_paises.py` rasteriza los países de Natural Earth sobre
      las unidades y asigna cada una al que cubre la mayor parte de su tierra (229 países; 782 de 58 076 unidades
      quedan sin país: hielo, zonas en disputa, bordes costeros).
- [x] **Carga perezosa**: las series por país se leen al abrir por primera vez la pestaña «Datos» (29 ms), no al
      arrancar. Y la app dice al arrancar cuánto pesa y cuánto tarda la enciclopedia (con la época contemporánea,
      3,8 MB en 150 a 230 ms).
- [x] **Población de las regiones por década** en el siglo XX y lo que va del XXI (antes, cada 25 años).
- [x] **`GraficoSerie` para cualquier indicador**: escala lineal o logarítmica, con su unidad en el tooltip; con
      series anuales no dibuja un punto por año.
- [x] **Plan de almacenamiento y descargas** ([docs/es/almacenamiento.md](docs/es/almacenamiento.md)): cuánto pesa
      cada capa (no son terabytes: TellMAP guarda fichas y enlaza los textos), dónde se aloja (versiones de GitHub, con
      espejos en Internet Archive y Zenodo; Google Drive no sirve para que la app baje de ahí), las reglas para que la
      app no se trabe (nada se baja mientras se mueve la línea de tiempo, una cola con prioridades, caché con tope,
      lectura en otro hilo) y en qué orden se hace.
- [x] Vocabulario nuevo para la época contemporánea: géneros `economia`, `politica`, `manifiesto`, `discurso`,
      `tecnologia` y `periodismo`; hechos `judicial`; lugares `laboratorio`, `institucion` y `sitio-historico`.
- [x] La prueba automática abre la pestaña «Datos» de Buenos Aires en 2000 y toca cada indicador.

### 10 de noviembre de 2026: versión 0.3.4, en Mac se ve

- [x] **Probada en una Mac con Intel** (MacBook Pro 2017, Intel Iris Plus 640, macOS 13.7.8): con la 0.3.2 la
      ventana quedaba oscura. Forward+ sobre MoltenVK arrancaba sin errores (por eso no saltaba
      `fallback_to_opengl3`, que solo actúa si Vulkan no arranca) pero dibujaba nada más el fondo y los anillos de
      algunos marcadores; los datos y la interfaz estaban bien (`--verificar` y `--diagnostico`). Sacar los argument
      buffers de Metal no cambió nada. Con Compatibility se ve completa con los dos drivers (OpenGL 4.1 de Apple y
      ANGLE sobre Metal): 145 cuadros por segundo con calidad «ultra» en 2880×1548, 0,65 a 1,1 GB de memoria y 2,8 s
      para cargar los datos. `--rendering-driver metal` no existe en esa Mac.
- [x] **Compatibility en macOS** (`renderer/rendering_method.macos` en `project.godot`). La app es 2D y no usa nada
      propio de Forward+. Sigue siendo un solo `.app` universal: el problema depende de la GPU y su driver, no de la
      CPU, y separar Intel de Apple Silicon solo ahorraría tamaño.
- [x] **Motor de dibujo en Ajustes**: Automático, Compatible (OpenGL) o Avanzado (Vulkan). Se guarda en
      `user://motor.cfg`, que Godot lee al arrancar (`application/config/project_settings_override`) y que no toca
      el paquete firmado de macOS. Al reabrir con otro motor, `AvisoGraficos` pregunta si se ve bien y, si nadie
      contesta en 20 s, vuelve solo al anterior (`scripts/nucleo/motor.gd`). Ajustes muestra el motor en uso y la
      placa de video, y la app los anota en el registro al arrancar.
- [x] **El registro se escribe al momento** (`application/run/flush_stdout_on_print`): en la Mac, `godot.log` quedaba
      vacío aunque la app llevara minutos abierta.
- [x] **`verificar-macos` comprueba que dibuja**: abre la app con ventana, saca una captura con
      `--comprobar_dibujo` (sale con 1 si quedó casi lisa) y, si falla, saca el zip de la versión como en los otros
      pasos. La captura rota de la Mac tenía un solo color; las buenas, entre 170 y 200.
- [x] «Reiniciar ahora» desde el código fuente vuelve a abrir el proyecto con su `--path`, que Godot no devuelve entre
      los argumentos.

### 10 de noviembre de 2026: versión 0.3.3, pregunta antes de actualizar

- [x] **La app pregunta antes de actualizarse.** Al abrir, si hay una versión nueva o datos nuevos, un cartel arriba
      al centro lo ofrece con «Actualizar» y «Ahora no», y no baja nada hasta que le dicen que sí. «Ahora no» (o la
      cruz) no cambia nada y el cartel vuelve a salir la próxima vez; con «Actualizar», el mismo cartel muestra cómo
      va y al terminar queda el aviso de siempre. «Buscar ahora», en Ajustes, sigue instalando sin preguntar.
      `--preguntar-y-salir=si|no` contesta el cartel desde la línea de comandos, y `probar.py` comprueba que «Ahora
      no» no baje ni toque nada (datos ni ejecutable).
- [x] Arreglado: **la 0.3.2 quedó anunciada como 0.3.1.** `version.yml` publicó el manifiesto de la 0.3.2, pero
      `datos.yml`, lanzado por el mismo push, lo pisó dos segundos después con uno armado antes. El manifiesto se
      corrigió a mano y los dos workflows comparten ahora el grupo de `concurrency` `actualizaciones`.

### 10 de noviembre de 2026: versión 0.3.2, también para macOS

- [x] **Versión 0.3.1 publicada** en GitHub (la primera que se actualiza sola), con la versión fija
      `actualizaciones` y su manifiesto.
- [x] **Versión para macOS**: `TellMAP.app` universal (Intel y Apple Silicon), con firma ad hoc y sin notarizar.
      Se exporta desde Linux con el preset «macOS» de `export_presets.cfg` (pide `import_etc2_astc` en
      `project.godot`, que no cambia nada en Linux ni Windows porque no hay texturas comprimidas para la GPU), y el
      trabajo `verificar-macos` de `version.yml` comprueba en una Mac de GitHub la firma y `--verificar`; si falla,
      saca el zip de la versión. La app no se reemplaza sola en macOS (los datos sí) y «Reiniciar ahora» reabre el
      paquete con `OS.create_instance`.
- [x] Arreglado: **el globo del mapa quedaba clavado encima del panel**. Solo se actualizaba con los movimientos que
      llegaban al mapa: al pasar rápido al panel quedaba visible con el último lugar, tapando el texto, y al cambiar
      de año con el mouse sobre el panel volvía a aparecer. Ahora se apaga apenas el mouse pasa a la interfaz, no
      cruza el panel cuando el cursor está sobre el mapa al lado, y la prueba automática lo comprueba.
- [x] Arreglado: **el panel lateral a veces quedaba más largo que la ventana**, por debajo de la línea de tiempo y con
      el final del texto fuera de alcance. Se abría animando `position`, y Godot recalcula con eso los cuatro márgenes
      con el tamaño del momento: si el contenido todavía se estaba armando, ese alto quedaba fijo. Ahora se corre
      solo con sus márgenes horizontales, y la prueba automática comprueba que termine dentro de la ventana.
- [x] Arreglado: **religiones, culturas e idiomas «desde siempre»**. Con `"desde": null` la app pintaba el mapa desde
      3400 a. C.: los Balcanes con religión romana en el Neolítico. Las 45 entradas así (43 de `edad-media.json` y 2
      de `tierra-santa.json`) tienen ahora la fecha desde la que hay registro (la conquista romana, la primera
      mención, la llegada) y una nota que la explica; `validar.py` rechaza un `desde` vacío en esas capas.

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
      push a main que toque `data/`, después de correr la prueba completa con el código de la última app publicada.
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
- [x] **Versión 0.3.0 exportada** para Windows y Linux, con los datos dentro del ejecutable (un solo archivo), y
      publicada en GitHub (`version.yml` exportó y subió los zips).

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

- [x] **Landing del proyecto** en `docs/index.html`, publicada con GitHub Pages desde `main/docs`, con la estética
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
