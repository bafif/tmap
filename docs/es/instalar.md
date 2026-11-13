# Instalar

[English](../en/install.md)

## Bajar la versión de tu sistema

En Linux y Windows, TellMAP no se instala: se baja el zip de tu sistema desde la
[última versión](https://github.com/bafif/tmap/releases/latest), se descomprime y se abre. Los datos van dentro del
ejecutable. En macOS conviene el instalador ([abajo](#macos)).

| Sistema | Archivo | Qué se abre |
|---|---|---|
| Linux (x86_64) | `TellMAP-<versión>-linux-x86_64.zip` | `TellMAP.x86_64` |
| Windows (x86_64) | `TellMAP-<versión>-windows-x86_64.zip` | `TellMAP.exe` |
| macOS con Apple Silicon (M1, M2…) | `TellMAP-<versión>-macos-arm64.dmg` (o `.zip`) | `TellMAP.app` |
| macOS con Intel | `TellMAP-<versión>-macos-x86_64.dmg` (o `.zip`) | `TellMAP.app` |

Lo que guarda la app (los ajustes, la caché de Wikipedia, lo que editás con el editor de la enciclopedia y los datos
que bajan las actualizaciones) queda en la carpeta del usuario: `~/.local/share/godot/app_userdata/TellMAP/` en Linux
`%APPDATA%\Godot\app_userdata\TellMAP\` en Windows y `~/Library/Application Support/Godot/app_userdata/TellMAP/` en
macOS. Para desinstalarla, se borra la carpeta de la app y, si querés,
la carpeta del usuario.

## macOS

Se abre la Terminal (Aplicaciones → Utilidades → Terminal), se pega esto y se aprieta Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/bafif/tmap/main/tools/instalar-macos.sh | bash
```

El instalador ([`tools/instalar-macos.sh`](../../tools/instalar-macos.sh)) se fija si la Mac es Intel o Apple Silicon,
baja esa versión de la última de GitHub, comprueba la firma, la deja en `/Applications` (o en `~/Applications` si no
se puede escribir ahí) y la abre. Anda en cualquier Mac con macOS 11 o más nuevo, y la app se abre a la primera.

### Por qué un instalador y no el doble clic

La app tiene una firma ad hoc y no está notarizada por Apple (eso pide una cuenta de Apple Developer, de 99 USD por
año). Lo que baja el navegador queda marcado «en cuarentena», y macOS no abre una app en cuarentena sin notarizar:
dice «"TellMAP" no se puede abrir porque Apple no puede revisar si contiene software malicioso». Lo que baja `curl`
desde la Terminal no queda en cuarentena, así que macOS la abre sin preguntar.

Si bajaste el `.dmg` o el `.zip` con el navegador, la primera vez hay que abrirla desde **Configuración del Sistema →
Privacidad y seguridad**, más abajo, con «Abrir igualmente», o sacarle la cuarentena en la Terminal con
`xattr -dr com.apple.quarantine /Applications/TellMAP.app`.

### Actualizar

En macOS los datos se actualizan solos, pero la app no: cuando hay una versión nueva, el aviso lleva a la página de
la versión, y para instalarla se vuelve a correr el mismo comando.

## Si se ve en negro o con fallas

En **Ajustes → Motor de dibujo** se elige cómo dibuja la app. «Automático», el de entrada, usa Vulkan en Linux y
Windows (OpenGL si no hay Vulkan) y OpenGL en macOS; «Compatible (OpenGL)» anda en casi cualquier computadora y es el
que conviene si se ve en negro, con manchas o sin mapa. Al reabrir con otro motor, la app pregunta si se ve bien; si
nadie contesta en 20 segundos, vuelve al anterior.

Si ni siquiera se ve Ajustes, abrí la app con `--rendering-method gl_compatibility`.

## Actualizaciones

Al abrir, y después cada hora, la app busca en GitHub si hay algo nuevo y pregunta antes de bajarlo. Se apaga en
**Ajustes → Actualizaciones**. Cómo funciona: [Actualizaciones automáticas](actualizaciones.md).

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
