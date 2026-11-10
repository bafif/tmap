# El puente: manejar TellMAP y el editor desde afuera

[English](README.en.md)

`addons/tellmap_puente/` deja que un programa (la terminal, una prueba o un agente de IA) maneje la app mientras corre
y el editor de Godot mientras está abierto. `tools/godot/tmap.py` es el cliente: Python sin dependencias.

## Para qué sirve

- **Ver lo que se cambia sin tocar el mouse**: abrir la app, ir a un año y a un lugar, abrir una pestaña y sacar una
  captura, en un segundo y sin reiniciar.
- **Probar la interfaz como una persona**: clics, teclas, arrastres y texto, en píxeles de la ventana (los mismos de
  las capturas y de `arbol`).
- **Iterar rápido**: `shader` vuelve a leer los shaders del disco y `recargar` vuelve a leer la enciclopedia, sin
  cerrar la app.
- **Diagnosticar**: `errores` devuelve los errores y avisos del motor con su traza; cada respuesta trae además los
  errores que aparecieron durante ese pedido. `arbol` muestra los nodos con su rectángulo en pantalla y `eval`
  ejecuta GDScript dentro de la app.
- **Trabajar con el editor abierto**: reescanear archivos cambiados desde afuera, correr y parar la app, abrir un
  script en una línea.

## Uso

```bash
tools/godot/tmap.py lanzar                       # abre la app con el puente (sin pantalla usa cage)
tools/godot/tmap.py anio anio=-1350
tools/godot/tmap.py ir lon=31 lat=27.6 zoom=1.2
tools/godot/tmap.py seleccionar lon=31 lat=27.6
tools/godot/tmap.py pestana n=2
tools/godot/tmap.py captura egipto.png ancho=1200
tools/godot/tmap.py eval 'Enciclopedia.fuentes.size()'
tools/godot/tmap.py ayuda                        # todos los comandos de la app
tools/godot/tmap.py cerrar
```

Con el editor abierto, `--a editor` habla con el editor en vez de la app (`estado`, `escanear`, `jugar`, `parar`,
`abrir ruta=scripts/principal.gd linea=40`, `ajuste_editor`, `recargar_plugin`, más los comunes). Para hablar con el
editor de otra copia del proyecto: `--proyecto /ruta/al/proyecto`.

Además: `tmap.py revisar` compila todos los scripts sin abrir la app, `tmap.py prueba` corre la prueba automática y
`tmap.py doc Clase.metodo` (o `doc ?texto`) muestra la API exacta de la versión de Godot instalada; la primera vez
la genera en `~/.cache/tellmap/`.

`tmap.py recorrido` (con la app abierta) hace clic de verdad en cada botón visible y en los gráficos tocables, en 17
escenarios (cada pestaña de un lugar, cada tipo de ficha, modo de capa, ajustes, ayuda y búsqueda), y devuelve
cuántos tocó y cuáles no hicieron nada; `solo="ficha de familia"` corre un escenario suelto. Mientras corre, los
enlaces no abren el navegador. La prueba automática lo incluye y falla si un clic da error o no hace nada.

## Registros

Cada vez que corre la app (o el editor, con el plugin) se guarda un registro en `.godot/registros/`: mensajes,
errores y avisos con su traza de GDScript, y al cerrar, los nodos que quedaron sin liberar con su script. Se guardan
los últimos 15 de cada uno.

```bash
tools/godot/tmap.py registros               # el último de la app
tools/godot/tmap.py registros --errores     # solo errores y avisos
tools/godot/tmap.py registros editor -n 200 # el último del editor
tools/godot/tmap.py registros --lista
```

## En el editor

El plugin viene activado (Proyecto → Configuración del proyecto → Plugins → «Puente TellMAP»). Agrega el panel
**Puente**, que muestra cada pedido que llega y tiene botones para correr la prueba automática y validar la
enciclopedia. La casilla «Recargar sin preguntar los scripts cambiados afuera» evita el aviso del editor cada vez que
otro programa edita un archivo.

## Cómo funciona y por qué es seguro

- La app enciende el puente solo en compilaciones de depuración y solo si se abre con `-- --puente` o desde el
  editor. En una versión exportada no hace nada.
- Cada puente escucha en `127.0.0.1`, en el primer puerto libre desde el 47800, y guarda su puerto y un token
  aleatorio en `.godot/puente/<rol>-<pid>.json`. Todo pedido sin ese token se rechaza.
- Ese archivo solo lo pueden leer quienes ya pueden leer y modificar el repo (y por lo tanto ya podrían cambiar el
  código). El puente no le da acceso a nadie más.
- Protocolo: una línea JSON por pedido, `{"token", "cmd", "args"}`, y una por respuesta,
  `{"ok", "r" | "error", "errores", "ms"}`. Cualquier lenguaje con sockets puede hablarle.
- Las apps abiertas con `lanzar` se cierran solas tras 15 minutos sin pedidos.
