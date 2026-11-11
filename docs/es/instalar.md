# Instalar

[English](../en/install.md)

## Bajar la versión de tu sistema

TellMAP no se instala: se baja el zip de tu sistema desde la
[última versión](https://github.com/bafif/tmap/releases/latest), se descomprime y se abre. Los datos van dentro del
ejecutable.

| Sistema | Archivo | Qué se abre |
|---|---|---|
| Linux (x86_64) | `TellMAP-<versión>-linux-x86_64.zip` | `TellMAP.x86_64` |
| Windows (x86_64) | `TellMAP-<versión>-windows-x86_64.zip` | `TellMAP.exe` |
| macOS (Intel y Apple Silicon) | `TellMAP-<versión>-macos-universal.zip` | `TellMAP.app` |

Lo que guarda la app (los ajustes, la caché de Wikipedia, lo que editás con el editor de la enciclopedia y los datos
que bajan las actualizaciones) queda en la carpeta del usuario: `~/.local/share/godot/app_userdata/TellMAP/` en Linux
y `%APPDATA%\Godot\app_userdata\TellMAP\` en Windows. Para desinstalarla, se borra la carpeta de la app y, si querés,
la carpeta del usuario.

## macOS: la primera vez

La versión de macOS tiene una firma ad hoc y no está notarizada por Apple. La primera vez, macOS dice que no puede
comprobarla: se abre igual desde **Configuración del Sistema → Privacidad y seguridad**, o en la Terminal con
`xattr -dr com.apple.quarantine TellMAP.app`.

En macOS los datos se actualizan solos, pero la app no: cuando hay una versión nueva, el aviso lleva a la página de
descarga.

## Si se ve en negro o con fallas

En **Ajustes → Motor de dibujo** se elige cómo dibuja la app. «Automático», el de entrada, usa Vulkan en Linux y
Windows (OpenGL si no hay Vulkan) y OpenGL en macOS; «Compatible (OpenGL)» anda en casi cualquier computadora y es el
que conviene si se ve en negro, con manchas o sin mapa. Al reabrir con otro motor, la app pregunta si se ve bien; si
nadie contesta en 20 segundos, vuelve al anterior.

Si ni siquiera se ve Ajustes, abrí la app con `--rendering-method gl_compatibility`.

## Actualizaciones

Al abrir, la app busca en GitHub si hay algo nuevo y pregunta antes de bajarlo. Se apaga en **Ajustes →
Actualizaciones**. Cómo funciona: [Actualizaciones automáticas](actualizaciones.md).

## Desde el código

Hace falta [Godot 4.7](https://godotengine.org/download), que es libre y pesa unos 100 MB:

```bash
git clone https://github.com/bafif/tmap.git
godot --path tmap            # o abrí la carpeta desde el editor de Godot
```

La primera vez, la app importa el proyecto sola y se vuelve a abrir. Esa copia no busca actualizaciones: se actualiza
con `git pull`.

Los datos del mapa ya vienen generados en `data/mapa/`. Para regenerarlos desde las fuentes originales, o con otra
versión de Cliopatria, está [el pipeline de datos](../../tools/pipeline/README.md). Para probar y ver los cambios:
[Cómo trabajar en TellMAP](contribuir.md).
