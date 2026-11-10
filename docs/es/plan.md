# Plan del proyecto

[English](../en/plan.md)

TellMAP es un atlas histórico interactivo para estudiar historia desde las fuentes. Este documento explica cómo está
hecho, por qué se tomaron las decisiones técnicas y qué sigue.

## La idea en una frase

Un mapa del mundo con una línea de tiempo de 3400 a. C. a hoy, donde cada lugar abre su historia (quién lo gobernó,
quién vivió ahí, qué pasó) y, sobre todo, sus **fuentes**: lo que se escribió ahí en cada época y lo que se escribió
después sobre ese lugar y esa época.

## Decisiones técnicas

### Motor: Godot 4

Se evaluaron tres caminos:

| Opción | A favor | En contra |
|---|---|---|
| **Godot 4** (elegida) | Libre (MIT), liviano, 2D y 3D de calidad, shaders propios, exporta a escritorio y web | Menos herramientas GIS listas que la web |
| Web (MapLibre, deck.gl) | Ecosistema GIS enorme, se comparte con un link | Lograr la estética de un juego de estrategia (agua, relieve, partículas, 3D) cuesta mucho más |
| Unity o Unreal | Gráficos de punta | Pesados, licencias comerciales, mucho más de lo que hace falta |

Godot alcanza para la calidad visual buscada (shaders, partículas, agua, 3D) y deja todo el proyecto libre. El cuello
de botella no es el motor sino los datos, y esos se preparan con Python fuera de Godot. Si algún día hace falta una
versión web, Godot exporta a WebAssembly; para algo más liviano se podría reusar el mismo pipeline de datos con un
visor web.

### La técnica del mapa

Es la técnica de los juegos de gran estrategia, adaptada a 5400 años:

1. **Unidades.** El mundo se divide en ~58 000 unidades (como las provincias de esos juegos). Una textura guarda,
   para cada píxel, el número de su unidad. Las unidades no son una grilla: se generan cortando celdas orgánicas por
   las fronteras reales de Cliopatria, así que dentro de una unidad la historia política es la misma.
2. **Historia como eventos.** Para cada unidad, el pipeline calcula sus cambios de dueño (año, unidad, antes,
   después): ~1 millón de eventos en total. Mover la línea de tiempo aplica esos eventos hacia adelante o hacia atrás;
   para saltos largos se parte de una de las 43 «fotos» completas guardadas cada ~20 000 eventos.
3. **Una tabla chica por año.** El estado de un año es una textura de 256 × 227 píxeles (un valor por unidad). El
   shader cruza la textura de unidades con esa tabla y con una paleta de colores. Cambiar de año solo actualiza esa
   tabla: no se redibuja ningún polígono.
4. **El shader** (`shaders/mapa.gdshader`) hace el resto: color del terreno, sombreado del relieve, ríos, costas
   suavizadas con un campo de distancia, líneas de carta náutica en el agua, color político que se atenúa al
   acercarse, fronteras con antialiasing, brillo interior de la frontera, selección, resaltado al pasar el mouse y
   grano de papel.
5. **Nombres curvos.** Para cada registro de Cliopatria, el pipeline calcula el eje principal y la curvatura de su
   territorio; la app dibuja el nombre letra por letra sobre esa curva, con una tipografía de campo de distancia que
   se escala sin perder nitidez.

### Proyección

Cilíndrica de Miller, recortada entre 83° N y 57° S (sin la Antártida). Se parece a los mapas que todos conocemos sin
inflar tanto las latitudes altas como Mercator. La fórmula está en `tools/pipeline/comun.py` y en
`scripts/nucleo/proyeccion.gd`; si se cambia, se regeneran los datos.

## Estructura del código

```
scripts/
  principal.gd          entrada: pantalla de carga, arma mapa e interfaz, capturas automáticas
  nucleo/               estado global, datos del mapa, enciclopedia, Wikipedia, proyección, fechas
  mapa/                 vista con cámara, capa de nombres, capa de marcadores
  interfaz/             tema, barra superior, línea de tiempo, panel lateral, leyenda, ajustes, bienvenida
shaders/                mapa y viñeta
data/mapa/              datos generados por el pipeline (Godot no los importa: .gdignore)
data/enciclopedia/      paquetes JSON de la enciclopedia y su esquema
tools/pipeline/         Python: base física, unidades y fronteras, Wikidata, vista previa
tools/enciclopedia/     validación de paquetes
raw_data/               fuentes originales (GEBCO, Natural Earth, Blue Marble)
legado/                 el primer intento con QGIS, como referencia
```

La interfaz se arma por código (no en escenas del editor) para que los temas visuales sean solo paletas y se puedan
cambiar en vivo.

## Opciones de calidad y vistas

- **Calidad** (Ajustes): baja, media, alta y ultra. Cambian la resolución de las texturas, el relieve, la cantidad de
  muestras de las fronteras, el brillo interior, las olas, el papel y el agua animada. «Baja» usa la cuarta parte de
  memoria de video.
- **Temas de interfaz:** Mármol y bronce, Pergamino iluminado, y Tinta y latón. Cada uno es un diccionario de colores
  en `scripts/interfaz/tema.gd`; agregar otro es copiar uno.
- **Vista 3D** (planificada): una malla con el relieve real (la elevación ya está en el pipeline), la misma textura
  política del 2D proyectada encima, agua con shader propio, nubes y partículas. Se va a elegir en Ajustes, con
  Forward+ (el proyecto ya está configurado así en Linux y Windows, con respaldo a OpenGL para equipos viejos; en
  Mac usa Compatibility desde la 0.3.4, y cada uno puede elegir el motor en Ajustes).

## Cómo se prueba

- `godot --headless --path . -- --prueba`: recorre la app sin intervención (saltos de año, modos, selección y
  pestañas en varios lugares del mundo, todas las fichas, búsquedas, calidades y temas) y escribe en la salida
  cualquier error de script. Termina con «TERMINADA sin cortes».
- `tools/captura.sh salida.png --anio=-1350 --lon=31 --lat=27.6 --zoom=1.2 --seleccionar --pestana=2`: saca una
  captura real sin monitor (con el compositor `cage`), útil para revisar la estética y para el README.
- `python3 tools/enciclopedia/validar.py`: valida los paquetes de la enciclopedia.
- `tools/godot/tmap.py`: el puente para manejar la app y el editor desde afuera (capturas, año, cámara, clics,
  errores, GDScript); ver [tools/godot/README.md](../../tools/godot/README.md). `tmap.py revisar` compila todos los
  scripts sin abrir la app.
- `python3 tools/pipeline/lamina.py ANIO x0 y0 x1 y1 salida.png`: lámina estática de alta calidad de cualquier año,
  sin Godot (por ejemplo, [el mundo en 117 d. C.](../assets/mundo_117.png)).

### Almacenamiento y descargas

TellMAP guarda fichas y enlaza los textos: lo que distribuye se mide en decenas o cientos de MB, no en terabytes. Lo
masivo (personas de Wikidata, grillas de población) se va a bajar por teselas de época y región, a pedido, con un
administrador de descargas que nunca baja nada mientras se mueve la línea de tiempo y una caché con tope. El plan,
los umbrales y dónde se aloja cada cosa (versiones de GitHub, con espejos en Internet Archive y Zenodo; Google Drive
no) están en [Almacenamiento y descargas](almacenamiento.md).

## Hoja de ruta

El detalle de cada paso, con lo hecho y lo que falta, está en [PROGRESO.md](../../PROGRESO.md).

| Fase | Qué incluye |
|---|---|
| **0.1** (esta) | Mapa 2D, fronteras de 3400 a. C. a 2024, línea de tiempo, panel lateral, enciclopedia piloto (Egipto) y muestra mundial, Wikipedia en vivo, temas y calidades |
| **0.2** | Probar en otros equipos (hasta ahora: Vulkan en una GTX 1050 Ti), bordes con campo de distancia para que no se vean los píxeles de cerca, agrupar marcadores superpuestos, exportar ejecutables (los datos de `data/` se incluyen con el filtro de exportación `data/*`), atajos de teclado y accesibilidad |
| **0.3** | Enciclopedia progresiva: cola de lo que se consulta sin ficha, borradores con Wikipedia y Wikidata, fichas extendidas con IA citando fuentes, revisión humana (ver [la enciclopedia](enciclopedia.md)) |
| **0.4** | Datos abiertos a gran escala: lugares antiguos de [Pleiades](https://pleiades.stoa.org), personas de Wikidata con lugares y fechas, población por grilla de HYDE, relaciones de vasallaje de Cliopatria |
| **0.5** | Movimiento: migraciones, rutas comerciales, campañas y difusión de religiones como flechas animadas y partículas |
| **0.6** | Vista 3D con relieve, agua y efectos |
| **1.0** | Versiones descargables y web, guía para sumar paquetes, revisión por especialistas |

## Rendimiento medido en el pipeline

- 58 076 unidades, 1 001 996 eventos, 43 fotos y 13 272 etiquetas.
- Datos del mapa en disco: ~24 MB (terreno 1,7 MB en WebP, relieve 14,7 MB, unidades 2 MB, política 6 MB).
- En memoria de video, con calidad alta: ~320 MB (terreno y relieve con mipmaps, unidades). Con calidad baja, ~110 MB.
