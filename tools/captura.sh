#!/usr/bin/env bash
# Saca una captura de TellMAP sin monitor (Linux, con el compositor cage en modo headless).
# Uso: tools/captura.sh salida.png [--anio=-1350] [--lon=31 --lat=29 --zoom=1.2] [--seleccionar] [--pestana=2]
#                                  [--ficha=fuente:gran-himno-a-aton] [--ajustes] [--tema=pergamino] [--modo=religion]
# Requiere: godot (4.7) y cage. Respeta TMPDIR para la carpeta temporal del compositor.
set -euo pipefail
raiz="$(cd "$(dirname "$0")/.." && pwd)"
salida="$(realpath -m "$1")"
shift
runtime="$(mktemp -d)"
trap 'rm -rf "$runtime"' EXIT
export XDG_RUNTIME_DIR="$runtime" WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1
export WLR_RENDERER="${WLR_RENDERER:-gles2}" WLR_RENDER_DRM_DEVICE="${WLR_RENDER_DRM_DEVICE:-/dev/dri/renderD128}"
timeout 150 cage -- godot --path "$raiz" --display-driver wayland ${GODOT_ARGS:-} -- --captura="$salida" "$@"
