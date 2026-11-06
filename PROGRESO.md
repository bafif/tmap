# Progreso de TellMAP

Bitácora de lo que está hecho y lo que falta. Cada tarea pendiente tiene su issue en GitHub y está en el tablero
del proyecto; `tools/github/organizar.py` crea los que falten. Se actualiza con cada cambio: lo terminado pasa a **Hecho** con su
fecha y lo nuevo que aparece se suma a **Por hacer**, en su bloque. Cada bloque está ordenado por prioridad, de arriba
hacia abajo. La visión general por versiones está en [la hoja de ruta del plan](docs/es/plan.md#hoja-de-ruta).

## Por hacer

### Ahora: que todo lo que se ve se pueda tocar (0.2)

La interfaz ya se ve completa, pero varias cosas son solo información. La meta del bloque: todo lo que se ve responde
a un clic y lleva a algo útil.

- [ ] **Línea de tiempo tocable.** Las marcas de fuentes y hechos muestran su nombre al pasar el mouse y abren su
      ficha con un clic. Hoy solo llevan al año.
- [ ] **Ficha de la entidad política.** Al tocar el nombre de un reino o imperio: sus fechas, su territorio a lo
      largo del tiempo (resaltado en el mapa), los lugares y las fuentes de su época, y su resumen de Wikipedia.
- [ ] **Gráfico de población.** El valor, el año y la fuente de cada estimación al pasar el mouse.
- [ ] **Recorrido de toda la interfaz con el puente.** Una prueba automática que hace clic en cada control visible y
      falla si alguno no hace nada o da error.

Datos que necesita este bloque:

- [ ] **Regiones con contorno más fino.** En los modos de capa, Egipto y otras regiones se ven como rectángulos.
      Hay que pasar a contornos reales (Natural Earth o los de Cliopatria).

### Mapa, rendimiento y distribución (0.2)

- [ ] **Bordes nítidos de cerca.** Bordes con campo de distancia, para que no se vean los píxeles con mucho zoom.
- [ ] **Agrupar marcadores.** Los que caen en el mismo lugar se juntan en uno con un número, que se abre al acercarse.
- [ ] **Teclado y accesibilidad.** Atajos completos, tamaño de letra, contraste y todo usable sin mouse.
- [ ] **Probar en otros equipos.** Windows, una notebook con gráficos integrados y el modo OpenGL.
- [ ] **Ejecutables para Linux y Windows.** Exportarlos con el filtro `data/*` y publicarlos en las releases de GitHub.

### Enciclopedia progresiva (0.3)

- [ ] **Editor de la enciclopedia dentro de Godot**, para cargar fuentes, personas, hechos y lugares con
      formularios, poner coordenadas con un clic en el mapa y validar al guardar, sin tocar JSON.
- [ ] **Cola de consultas sin ficha.** Verla y exportarla (hoy se guarda en `user://pendientes.json`).
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
