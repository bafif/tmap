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
- [ ] **Probar en otros equipos.** Windows y una notebook con gráficos integrados. El modo OpenGL
      (`--rendering-method gl_compatibility`) ya se probó en la GTX 1050 Ti: se ve igual que con Vulkan.
- [ ] **Publicar la primera versión con ejecutables.** Crear la versión 0.2 en GitHub: el workflow
      `version.yml` exporta Linux y Windows, comprueba el de Linux con `--verificar` y sube los zip. No se pudo probar
      acá porque no hay plantillas de exportación instaladas; el `.pck` sí se exportó y pasó la prueba completa.

### Enciclopedia progresiva (0.3)

- [ ] **Editor de la enciclopedia dentro de Godot**, para cargar fuentes, personas, hechos y lugares con
      formularios, poner coordenadas con un clic en el mapa y validar al guardar, sin tocar JSON.

- [ ] **Borradores desde Wikipedia y Wikidata.** Automáticos, para lo más consultado.
- [ ] **Fichas extendidas con IA.** Que citen sus fuentes, siempre con revisión humana antes de publicarse.
- [ ] **Revisar los datos dudosos:**
  - la cifra de Butzer para Egipto en 1250 a. C., reconstruida desde resúmenes;
  - los censos Han de 2 y 140 d. C., cargados de memoria;
  - nombres poco seguros: Gran Yuan, Federación Árabe Hachemita, Wihtgar, Michoacán como Imperio tarasco;
  - unos 35 pares de nombres duplicados para la misma entidad, con y sin paréntesis.

### Datos abiertos a escala (0.4)

- [ ] **Lugares de Pleiades.** Los lugares antiguos de [Pleiades](https://pleiades.stoa.org).
- [ ] **Personas de Wikidata.** Con lugar y fecha de nacimiento y muerte.
- [ ] **Población de HYDE.** Estimaciones por grilla para todo el mundo.
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
