# Almacenamiento y descargas: cómo crece TellMAP sin volverse inmanejable

TellMAP va a sumar muchísima información: la época contemporánea, personas de Wikidata, lugares de Pleiades, grillas
de población, libros, fallos, tratados. Esta página dice cuánto pesa eso de verdad, dónde se guarda cada cosa, cómo
la baja la app sin trabar la computadora de nadie y en qué orden se hace. Lo decidido el 10 de noviembre de 2026.

## La cuenta real: no son terabytes

TellMAP **no guarda los textos**: guarda la ficha de cada obra (título, autor, fechas, lugar, resumen propio) y enlaza
a dónde leerla (Wikisource, Proyecto Gutenberg, Internet Archive, el sitio oficial). Tampoco guarda Wikipedia: pide
el resumen de un artículo cuando alguien lo abre. Por eso lo que hay que distribuir es chico:

| Qué | Hoy | Al completarse | Notas |
|---|---|---|---|
| Mapa (terreno, relieve, unidades, fronteras) | 25 MB | 25-60 MB | Crece si se agrega la vista 3D o costas más finas |
| Enciclopedia curada (fichas) | 3,8 MB, 3263 elementos | 15-150 MB | ~1,5 KB por elemento: 10 000 elementos ≈ 15 MB (3 MB comprimidos) |
| Series por país (demografía, economía) | 0,9 MB | 2-5 MB | Our World in Data, un valor por año desde 1950 y por década antes |
| Personas de Wikidata con fecha y lugar (0.4) | — | 60-600 MB | ~1 a 10 millones de personas, ~60 bytes cada una en binario |
| Lugares de Pleiades (0.4) | — | ~5 MB | ~36 000 lugares antiguos |
| Grillas de población de HYDE (0.4) | — | 30 MB a 1 GB | A medio grado, ~30 MB comprimidos; a 5 minutos de arco, ~1 GB |
| Textos completos para leer sin conexión | — | lo que elija cada uno | Opcional: se bajan de a uno, a pedido |

Lo que sí pesa terabytes (escaneos de libros, volcados completos de Wikipedia, grillas de alta resolución de todos los
años) **no se distribuye**: queda en su sitio de origen y la app lo enlaza. El total que TellMAP aloja por sí mismo
va a estar entre decenas y unos pocos cientos de MB, y nadie tiene que bajarlo entero.

## Tres capas

1. **El núcleo, dentro del ejecutable** (hasta ~150 MB): la app, el mapa, la enciclopedia curada mientras entre en
   el umbral de abajo, las series por país y un **índice de todo** (id, tipo, años, coordenadas, título, en qué
   tesela está), para que la búsqueda y los marcadores funcionen sin conexión.
2. **Teselas por demanda**: lo masivo (personas de Wikidata, grillas, paquetes grandes) cortado por época y región,
   cada tesela de 50 a 500 KB comprimida. Se baja la primera vez que hace falta y queda en la carpeta del usuario.
3. **Lo externo, en vivo**: resúmenes de Wikipedia y enlaces de lectura. Se piden de a uno, cuando alguien toca algo,
   nunca en lote.

## Dónde alojar cada cosa

| Opción | Costo | Límites | Para qué sirve |
|---|---|---|---|
| **Versiones de GitHub** (lo que ya usa el actualizador) | Gratis en un repo público | 2 GB por archivo; GitHub no limita el total ni el tráfico de las versiones | **El lugar principal**: el ejecutable, los datos y las teselas, con su manifiesto y sha256 |
| **Internet Archive** | Gratis | Sin límite práctico; más lento | **Espejo permanente** de cada versión de datos y de los conjuntos grandes |
| **Zenodo** (CERN) | Gratis | 50 GB por registro | Publicar los conjuntos de datos con DOI, para que se puedan citar |
| Cloudflare R2 | 10 GB gratis por mes, sin cargo por tráfico; después, ~0,015 USD por GB y mes | Pide tarjeta | Solo si algún día hay muchas teselas chicas o mucho tráfico: lo decide Bautista |
| Google Drive | Gratis hasta la cuota de la cuenta | Corta las descargas de archivos populares («se superó la cuota de descarga»), pone una pantalla de aviso antes de bajar archivos grandes y depende de una cuenta personal | **No sirve para que la app baje de ahí.** Sí, como respaldo personal de `raw_data/` |

Decisión: **versiones de GitHub como fuente principal** (ya está integrado y probado: manifiesto, sha256, descargas
parciales por archivo), **Internet Archive y Zenodo como espejos permanentes**. Si GitHub dejara de responder, la app
prueba el espejo: el manifiesto lleva las dos direcciones de cada archivo.

### Cuando lo de afuera se cae

- **Enlaces de lectura**: cada `leer` suma un campo `archivo` con su copia en la Wayback Machine, que la app ofrece si
  el original no responde. Una herramienta (`tools/enciclopedia/enlaces.py`, por hacer) comprueba todos los enlaces y
  pide la copia a la Wayback Machine al cargar uno nuevo; se corre a mano antes de cada versión.
- **Wikipedia**: si no responde, la ficha propia sigue estando; el resumen de Wikipedia queda en caché la primera vez.
- **Datos de origen** (Our World in Data, Cliopatria, Natural Earth, HYDE): nunca se consultan en vivo. Se copian al
  repo o a una versión (las licencias lo permiten: CC BY y dominio público) y desde ahí se arma todo.

## Que la app no se trabe: reglas de descarga

El riesgo no es el tamaño total sino bajar o procesar mucho de golpe, por ejemplo mientras alguien arrastra la línea
de tiempo. Las reglas:

1. **Mover el año no baja nada.** Mientras la línea de tiempo se arrastra o se reproduce, la app usa solo lo que ya
   tiene en memoria. Las descargas salen de un gesto explícito: seleccionar un lugar, abrir una ficha o pedir
   «Bajar esta época» en Ajustes.
2. **Espera a que el año se quede quieto.** Recién 400 ms después del último cambio de año se puede adelantar la
   tesela de la región y la época que se están mirando, con la prioridad más baja.
3. **Un solo administrador de descargas** (autoload `Descargas`): una cola con prioridades (lo que se tocó, lo que
   se ve, lo adelantado), como mucho dos pedidos a la vez, cancelación de lo adelantado que ya no hace falta,
   reintentos con espera creciente, aviso de «sin conexión» en vez de error, y un tope por servidor (Wikipedia: un
   pedido por segundo).
4. **Nada pesado en el hilo principal.** Leer y preparar una tesela va en un hilo aparte (`WorkerThreadPool`); el
   resultado se integra en el hilo principal de a partes chicas por cuadro, para que la animación no se corte.
5. **Presupuesto de disco**: la caché de la carpeta del usuario tiene un tope (500 MB de entrada, se cambia en
   Ajustes entre 100 MB y 10 GB) y borra lo menos usado. Ajustes muestra cuánto ocupa y tiene «Vaciar caché».
6. **Presupuesto de memoria**: las teselas leídas viven en una lista con tope (64 MB de entrada); la menos usada se
   descarta y se vuelve a leer del disco si hace falta.
7. **Integridad**: cada archivo trae su sha256 en el manifiesto (como hoy el actualizador); uno que no coincide se
   descarta y se vuelve a pedir.
8. **Nunca bloquear**: si una tesela no baja, el panel dice «no se pudo bajar» con un botón para reintentar; el resto
   de la app sigue igual.

## Teselas: cómo se corta

- **Clave**: época × macrorregión. Épocas más finas donde hay más datos: de a 1000 años antes de 1000 a. C., de a un
  siglo hasta 1500, de a 25 años hasta 1900 y de a una década desde 1900. Macrorregiones: unas doce (Europa,
  Cercano Oriente, África del norte, África subsahariana, Asia central, Asia del sur, Asia oriental, sudeste
  asiático y Oceanía, Norteamérica, Mesoamérica y el Caribe, Sudamérica).
- Cada elemento va a la tesela de su año y lugar principales (la fuente, donde se escribió; la persona, donde vivió).
  El índice del núcleo dice en qué tesela está cada uno.
- Los paquetes temáticos siguen siendo la forma de **escribir** (JSON legible, con diff en git). Las teselas son la
  forma de **distribuir**: las arma un paso de la publicación (`tools/actualizacion/publicar.py`), no se editan.

## Orden de trabajo

| Paso | Cuándo | Qué |
|---|---|---|
| 0 | Hecho (10/11/2026) | Las series por país se leen recién al abrir la pestaña «Datos» (29 ms) y la app mide al arrancar cuánto pesa y cuánto tarda la enciclopedia (con la época contemporánea, 3,8 MB en 150 a 230 ms en la PC de desarrollo) |
| 1 | Cuando la enciclopedia pase los **10 MB** o tarde más de 1 s en abrir | Lectura de los paquetes en un hilo aparte mientras se ve la pantalla de carga; índice compacto en memoria |
| 2 | Con la 0.4 (personas de Wikidata, Pleiades) o al pasar los **50 MB** | Teselas, administrador de descargas, caché con tope y la sección de Ajustes; las teselas en las versiones de GitHub |
| 3 | Con las grillas de HYDE | Teselas raster por época, espejo en Internet Archive y Zenodo |
| 4 | Antes de la 1.0 | Campo `archivo` en los enlaces de lectura y `enlaces.py`; textos para leer sin conexión, de a uno |

Según la medición de hoy (de 40 a 110 ms por MB en esta PC, según esté el disco en caché; en una notebook vieja puede
ser el triple), todo lo que se cargó hasta ahora, incluida la época contemporánea, entra en la capa 1 sin cambiar
nada más.
