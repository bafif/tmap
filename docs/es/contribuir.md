# Cómo trabajar en TellMAP

[English](../en/contributing.md)

Guía corta para colaborar con el código. Qué es el proyecto y cómo está hecho: [el README](../../README.md) y
[el plan](plan.md). Formato de la enciclopedia: [ESQUEMA.md](../../data/enciclopedia/ESQUEMA.md).

## Convenciones

- Código, comentarios y commits en español. La documentación y los textos para el usuario, en español rioplatense y
  en inglés (ver [Idiomas](#idiomas)).
- La interfaz se arma por código (`scripts/interfaz/`), no en escenas del editor. Los temas son paletas en `tema.gd`.
- No existe el año 0: los años negativos son a. C. Usar `Fechas` (`scripts/nucleo/fechas.gd`) para mostrar y sumar.
- Para anclar un Control que ya está en el árbol, usar `set_anchors_and_offsets_preset()`: `set_anchors_preset()`
  conserva el rectángulo y deja controles de tamaño cero.
- `data/mapa/` lo genera `tools/pipeline/` (Python): no se edita a mano, salvo `nombres_es.json` y
  `correcciones.json`, que son revisiones a mano. La enciclopedia se edita con el editor de la app o a mano, se valida
  con `python3 tools/enciclopedia/validar.py`, y lo que no está seguro se marca en vez de inventarlo.
- Lo que el editor de la enciclopedia escribe pasa por `Edicion` (`scripts/nucleo/edicion.gd`): conserva el formato de
  los JSON y no escribe nada mientras corre el recorrido de la interfaz (`Estado.sin_escribir`).
- Una clase nueva con `class_name` no necesita abrir el editor: al arrancar, la app importa el proyecto sola si falta
  registrarla (`scripts/nucleo/arranque.gd`).
- Antes de usar una API de Godot que no está ya en el código, chequear la firma con `tools/godot/tmap.py doc`.

## Probar y ver los cambios

- `tools/godot/tmap.py revisar`: compila todos los scripts.
- `tools/godot/tmap.py prueba`: la prueba automática completa.
- `tools/godot/tmap.py lanzar`: abre la app con el puente (sin monitor usa `cage`). Después se usan `anio`, `ir`,
  `seleccionar`, `pestana`, `captura`, `eval`, `errores`, `shader`, `recargar`, `clic` y los demás comandos
  (`ayuda`). Al terminar, `cerrar`.
- Con el editor abierto: `tools/godot/tmap.py --proyecto <carpeta del editor> --a editor estado|escanear|jugar|abrir`.
- Después de cada prueba, leer `tools/godot/tmap.py registros --errores`: tiene que terminar en «ningún nodo suelto
  sin liberar».
- Detalle del puente: [tools/godot/README.md](../../tools/godot/README.md).
- Si se toca algo de cómo se dibuja: `tools/captura.sh x.png --comprobar_dibujo` (sale con 1 si la captura quedó casi
  lisa) y lo mismo con OpenGL, que es el motor de macOS: `GODOT_ARGS="--rendering-method gl_compatibility"
  tools/captura.sh x.png --comprobar_dibujo`. El motor que se elige en Ajustes va en `user://motor.cfg`
  (`scripts/nucleo/motor.gd`).
- Si se toca el actualizador (`scripts/nucleo/actualizador.gd`, `datos.gd`) o cómo se leen los datos:
  `python3 tools/actualizacion/probar.py`, y con un ejecutable exportado, `--ejecutable <ruta>`
  ([actualizaciones](actualizaciones.md)). Todo lo que lee `data/` pasa por `Datos.ruta()`.

## Idiomas

- La app sale en español o en inglés según el idioma del equipo (`scripts/nucleo/idioma.gd`) y se cambia en Ajustes o
  en la bienvenida; lo que se elige manda sobre la detección. `--idioma=es|en` lo fija para pruebas y capturas.
- Todo texto de la interfaz se escribe en español dentro de `tr()` (o `Idioma.t()` en funciones estáticas) y su inglés
  va en `traducciones/en.po`. `python3 tools/traduccion/interfaz.py actualizar` suma al catálogo los textos nuevos, y
  `revisar` (corre en el CI) falla si falta alguno, si no coinciden los marcadores o si hay un texto asignado a mano
  fuera de `tr()`. Los registros (`print`, `push_error`) quedan en español.
- La enciclopedia se traduce aparte, en una capa por paquete en `data/enciclopedia/traducciones/en/`
  ([el esquema](../../data/enciclopedia/ESQUEMA.md#traducciones)), con `tools/traduccion/enciclopedia.py`: `estado`
  cuenta lo traducido, lo que falta y lo viejo, `extraer` saca lo pendiente en lotes para traducir y `aplicar` lo
  vuelca en la capa. `tools/traduccion/probar.py` prueba la ida y vuelta.
- La prueba automática corre en los dos idiomas: `tools/godot/tmap.py prueba` y `tools/godot/tmap.py prueba --idioma
  en`.
- La página del proyecto (`docs/index.html`) tiene el español en el HTML y el inglés en su diccionario `EN`.
- Cada documento tiene su par en el otro idioma: `docs/es/` y `docs/en/`, y en el resto `X.md` y `X.en.md`, con un
  enlace al otro arriba de todo. `python3 tools/traduccion/documentos.py` (corre en el CI) falla si a un documento le
  falta su par o si un enlace relativo apunta a un archivo que no existe. Si se cambia uno, se cambia el otro en el
  mismo commit.

## Progreso

- Lo que queda pendiente va en «Por hacer» de [PROGRESO.md](../../PROGRESO.md), en su bloque y en orden de
  prioridad, con un título en negrita: `tools/github/organizar.py` crea un issue por cada uno y lo reconoce por ese
  título, así que no se cambia.
- Lo terminado sale de «Por hacer». Si es un hito, va a «Hecho», en la versión que lo trae (o en «La enciclopedia» si
  es contenido): qué se decidió y por qué, en una o dos frases, en presente y sin fecha ni relato de cómo se hizo.

## Git

- Los cambios se proponen con un pull request, con [su plantilla](../../.github/pull_request_template.md).
- Las capturas para revisar van a una carpeta temporal, no al repo. Las del README van en `docs/assets/`.
