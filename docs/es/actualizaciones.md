# Actualizaciones automáticas

[English](../en/updates.md)

La versión descargada de TellMAP se actualiza sola. Hay dos clases de actualización:

- **De la app**: código nuevo. Se baja el ejecutable nuevo, que reemplaza al que está corriendo y se abre la próxima
  vez (o con «Reiniciar ahora»). Trae adentro los datos de su momento.
- **Solo de datos**: más fuentes, personas, hechos, regiones o un mapa corregido, sin cambiar el código. Se bajan
  nada más los archivos que cambiaron; la app no se reinstala. La enciclopedia nueva se ve enseguida; un mapa nuevo,
  al volver a abrir.

Desde el código fuente (`godot --path .` o el editor) no se busca nada: esa copia se actualiza con `git pull`.

## Qué ve quien usa la app

Al abrir, si la casilla de **Ajustes → Actualizaciones** está marcada (lo está de entrada), TellMAP consulta el
manifiesto en GitHub. Si hay algo nuevo, lo ofrece en un cartel arriba al centro («Hay una actualización: TellMAP
0.3.3 y datos del 12/11/2026. ¿La instalo?») con **Actualizar** y **Ahora no**, y no baja nada hasta que le dicen que
sí. Con «Ahora no» (o la cruz) no cambia nada y la app sigue como estaba; el cartel vuelve a salir la próxima vez que
se abra. Con «Actualizar» lo baja, comprueba su sha256, lo instala y avisa en el mismo lugar cuando terminó. Si el
ejecutable no se puede reemplazar (por ejemplo, porque está en una carpeta sin permiso de escritura), no pregunta: el
aviso lleva a la página de descarga. En Ajustes están el estado, «Buscar ahora» (que instala sin preguntar, porque ya
es un pedido) y la casilla para apagarlo. La consulta no manda nada del usuario: es un pedido a GitHub, como abrir la
página del proyecto.

## Cómo funciona

- **El manifiesto** es `actualizacion.json`, un archivo de la versión fija `actualizaciones` del repo en GitHub
  (marcada como prerelease para que nunca sea «la última»). Dice la última versión de la app, con un `.gz` del
  ejecutable por plataforma, y la última versión de los datos, con cada archivo de `data/`: sha256, tamaño y la
  dirección de su `.gz`. Cada `.gz` lleva el sha256 en el nombre y se sube una sola vez: una versión de datos sube
  nada más los archivos que cambiaron y reutiliza las direcciones de los demás.
- **La versión de los datos** es la fecha del commit, en segundos. `tools/actualizacion/publicar.py sellar` la
  escribe en `data/version.json` antes de exportar (ese archivo no va al repo). Qué archivos trae el ejecutable lo
  calcula la app al instalar una actualización (el sha256 de cada uno), y con eso decide qué bajar.
- **Los datos bajados** quedan en la carpeta del usuario, en `datos/<versión>/`, por grupo (`mapa`,
  `enciclopedia`): si cambió un archivo de un grupo, el grupo entero se lee de ahí y tapa al de adentro, así nunca se
  mezclan dos versiones. `datos/activo.json` dice cuál vale; se reemplaza de una vez al terminar de instalar, así que
  si algo se corta sigue valiendo lo anterior. `Datos.ruta()` (`scripts/nucleo/datos.gd`) traduce cada ruta de
  `res://data/`. Lo que se edita con el editor de la enciclopedia en la versión exportada sigue yendo a
  `enciclopedia/` y tapa a los dos. Por eso, al guardar la primera copia de un paquete se guarda al lado su base (lo
  que había debajo, en `enciclopedia_base/`): si después una actualización de datos o una app nueva traen otra
  versión de ese paquete, al abrir (o al terminar de instalar) un cartel lo avisa y ofrece pasarle lo nuevo a la
  copia (una mezcla de tres vías por elemento: queda lo que cambió la copia y lo demás sale de lo nuevo; si un
  elemento cambió en los dos lados, queda el de la copia y el cartel lo dice) o descartarla (`Edicion.tapadas()` y
  `AvisoCopias`). La traducción al inglés de la enciclopedia (`enciclopedia/traducciones/en/`) es
  parte del grupo `enciclopedia`: una traducción nueva o corregida llega como cualquier otra actualización de datos.
- **Compatibilidad**: una versión de datos dice qué versión de la app necesita como mínimo (`app_minima`, la última
  publicada cuando se armó). Una app más vieja no la instala: primero se actualiza la app. Y los datos bajados solo
  valen si son más nuevos que los que trae el ejecutable: al instalar una app nueva, si trae datos más nuevos, la
  carpeta de datos vieja se borra sola.
- **El ejecutable**: se baja a la carpeta del usuario, se comprueba, se escribe junto al actual como `.nuevo` y se
  renombra encima. En Linux el proceso que corre sigue con el archivo viejo; en Windows, que no deja pisar un
  ejecutable abierto, el viejo se renombra a `.viejo` y se borra la próxima vez.
- **macOS**: la app no se reemplaza sola. El ejecutable vive dentro de `TellMAP.app`, firmado (ad hoc), y cambiarlo
  invalidaría la firma: el manifiesto no trae una entrada `macos-*` y la app avisa que hay una versión nueva con la
  página de descarga. Los datos sí se actualizan solos, porque van a la carpeta del usuario.

## Publicar

- **Una versión de la app**: se publica la versión `vX.Y.Z` en GitHub, con `config/version` de
  `project.godot` igual a `X.Y.Z` (si no coinciden, el workflow falla: la app se creería vieja para siempre).
  `version.yml` exporta, sella los datos, sube los `.gz` y el manifiesto nuevo.
- **Solo datos**: alcanza con llevar los cambios de `data/` a `main`. `datos.yml` se fija si cambiaron respecto de
  lo publicado, valida la enciclopedia, corre la prueba automática completa **con el código de la última versión
  publicada de la app** y los datos nuevos, y si pasa publica una versión `datos-AAAAMMDD-HHMMSS` y el manifiesto
  nuevo. Si la prueba falla es porque los datos necesitan código nuevo: van con la próxima versión de la app. También
  se puede correr a mano desde la pestaña Actions.
- Los dos workflows suben `actualizacion.json` y comparten el grupo de `concurrency` `actualizaciones`, así que nunca
  corren a la vez: si no, un push que toca `data/` y publica una versión podría pisar el manifiesto nuevo con uno
  armado antes.

## Probar

`python3 tools/actualizacion/probar.py` arma una versión publicada falsa, la sirve en `127.0.0.1` y corre la app con
`-- --actualizaciones=<url>` y una carpeta de usuario aparte: comprueba que al abrir ofrezca lo nuevo y que «Ahora
no» no baje ni cambie nada, que con «Actualizar» baje e instale datos nuevos, que la app los lea, que al día no
pregunte nada, que rechace un archivo adulterado y que no deje restos. Con `--ejecutable build/linux/TellMAP.x86_64`
(un ejecutable exportado después de `publicar.py sellar`) prueba además que «Ahora no» deje el ejecutable como
estaba, que la app se reemplace sola y que vuelva a arrancar.

Banderas de la app para probar a mano: `--actualizaciones=<url del manifiesto>` prende el actualizador aunque se
corra desde el código fuente, `--actualizar-y-salir` busca, instala y sale (0 si salió bien, 1 si no),
`--preguntar-y-salir=si|no` hace lo mismo que al abrir y contesta el cartel con «Actualizar» o «Ahora no», y
`--ejecutable=<ruta>` elige qué ejecutable reemplazar (también desde el código fuente: sirve un archivo cualquiera).
