# Cómo trabajar en TellMAP

Guía corta para quien colabore con el código, sea una persona o un agente de IA. Qué es el proyecto y cómo está hecho:
[el README](../../README.md) y [el plan](plan.md). Formato de la enciclopedia: [ESQUEMA.md](../../data/enciclopedia/ESQUEMA.md).

## Convenciones

- Código, comentarios, commits y documentación en español; los textos para el usuario, en rioplatense.
- La interfaz se arma por código (`scripts/interfaz/`), no en escenas del editor. Los temas son paletas en `tema.gd`.
- No existe el año 0: los años negativos son a. C. Usar `Fechas` (`scripts/nucleo/fechas.gd`) para mostrar y sumar.
- Para anclar un Control que ya está en el árbol, usar `set_anchors_and_offsets_preset()`: `set_anchors_preset()`
  conserva el rectángulo y deja controles de tamaño cero.
- `data/mapa/` lo genera `tools/pipeline/` (Python): no se edita a mano. La enciclopedia se valida con
  `python3 tools/enciclopedia/validar.py`, y lo que no está seguro se marca en vez de inventarlo.
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
- Detalle del puente: [tools/godot/README.md](../../tools/godot/README.md).

## Git

- Se trabaja en una rama; el merge y el push los hace Bautista.
- Las capturas para revisar van a una carpeta temporal, no al repo. Las del README van en `docs/assets/`.
