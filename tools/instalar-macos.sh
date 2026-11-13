#!/bin/bash
# Instala (o actualiza) TellMAP en macOS. Se corre pegando en la Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/bafif/tmap/main/tools/instalar-macos.sh | bash
#
# Elige solo la versión para Intel o para Apple Silicon, la baja de la última versión de GitHub, la pone en
# Aplicaciones y la abre. Lo que baja curl no queda en cuarentena, así que macOS la abre a la primera, sin pasar por
# Privacidad y seguridad (la app tiene firma ad hoc y no está notarizada por Apple; ver docs/es/instalar.md).
#
# Variables opcionales, para probar:
#   TELLMAP_VERSION=v0.3.6     una versión en particular en vez de la última (sirve también para las preliminares)
#   TELLMAP_DESTINO=/carpeta   dónde dejar TellMAP.app (por defecto /Applications, o ~/Applications si no se puede)
#   TELLMAP_NO_ABRIR=1         no abrir la app al terminar
#   TELLMAP_ARQ=arm64|x86_64   forzar la arquitectura
#
# Todo va dentro de main, que se llama en la última línea: si la descarga del script se corta a la mitad, no corre nada.

set -euo pipefail

REPO="bafif/tmap"

main() {
	local es=0
	case "$(defaults read -g AppleLocale 2>/dev/null || echo "${LANG:-}")" in es*) es=1 ;; esac
	decir() { if [ "$es" = 1 ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
	fallar() { decir "Error: $1" "Error: $2" >&2; exit 1; }

	[ "$(uname -s)" = "Darwin" ] || fallar "este instalador es para macOS." "this installer is for macOS."

	# hw.optional.arm64 vale 1 en Apple Silicon aunque la Terminal corra con Rosetta (ahí uname -m dice x86_64).
	local arq="${TELLMAP_ARQ:-}"
	if [ -z "$arq" ]; then
		if [ "$(sysctl -in hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then arq="arm64"; else arq="x86_64"; fi
	fi
	local nombre_arq="Intel"
	[ "$arq" = "arm64" ] && nombre_arq="Apple Silicon"

	# La última versión: GitHub redirige /releases/latest a /releases/tag/<etiqueta>.
	local etiqueta="${TELLMAP_VERSION:-}"
	if [ -z "$etiqueta" ]; then
		etiqueta="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
		etiqueta="${etiqueta##*/}"
	fi
	case "$etiqueta" in v[0-9]*) ;; *) fallar "no se pudo saber cuál es la última versión ($etiqueta)." \
		"couldn't find out the latest version ($etiqueta)." ;; esac

	local archivo="TellMAP-$etiqueta-macos-$arq.zip"
	local url="https://github.com/$REPO/releases/download/$etiqueta/$archivo"

	# Global, no local: el trap corre al salir, cuando main ya terminó.
	TEMPORAL="$(mktemp -d)"
	trap 'rm -rf "$TEMPORAL"' EXIT
	local temporal="$TEMPORAL"

	# Hasta la 0.3.5 había un solo zip universal (Intel y Apple Silicon juntos).
	if ! curl -fsSI -o /dev/null "$url" 2>/dev/null; then
		archivo="TellMAP-$etiqueta-macos-universal.zip"
		url="https://github.com/$REPO/releases/download/$etiqueta/$archivo"
	fi

	decir "Bajando TellMAP $etiqueta para Mac con $nombre_arq…" "Downloading TellMAP $etiqueta for $nombre_arq Macs…"
	curl -fL --progress-bar -o "$temporal/$archivo" "$url" \
		|| fallar "no se pudo bajar $url" "couldn't download $url"
	ditto -x -k "$temporal/$archivo" "$temporal/zip"
	local app="$temporal/zip/TellMAP.app"
	[ -d "$app" ] || fallar "el zip no trae TellMAP.app." "the zip doesn't contain TellMAP.app."
	codesign --verify --deep --strict "$app" 2>/dev/null \
		|| fallar "la firma de TellMAP.app no es válida." "TellMAP.app's signature isn't valid."

	# La versión mínima de macOS que pide el ejecutable, para avisar claro en vez de que la app no abra.
	local minima actual
	minima="$(plutil -extract "LSMinimumSystemVersionByArchitecture.$arq" raw -o - "$app/Contents/Info.plist" 2>/dev/null \
		|| plutil -extract LSMinimumSystemVersion raw -o - "$app/Contents/Info.plist" 2>/dev/null || echo 0)"
	actual="$(sw_vers -productVersion)"
	if [ "$(printf '%s\n%s\n' "$minima" "$actual" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)" != "$minima" ]; then
		fallar "TellMAP necesita macOS $minima o más nuevo, y esta Mac tiene $actual." \
			"TellMAP needs macOS $minima or newer, and this Mac has $actual."
	fi

	local destino="${TELLMAP_DESTINO:-}"
	if [ -z "$destino" ]; then
		destino="/Applications"
		[ -w "$destino" ] || destino="$HOME/Applications"
	fi
	mkdir -p "$destino"

	if pgrep -x TellMAP >/dev/null 2>&1; then
		decir "Cerrando TellMAP…" "Closing TellMAP…"
		pkill -x TellMAP || true
		local i
		for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x TellMAP >/dev/null 2>&1 || break; sleep 1; done
	fi

	rm -rf "$destino/TellMAP.app"
	ditto "$app" "$destino/TellMAP.app"
	# Por si acaso: que nada de lo copiado quede en cuarentena.
	xattr -dr com.apple.quarantine "$destino/TellMAP.app" 2>/dev/null || true

	decir "TellMAP $etiqueta quedó instalada en $destino/TellMAP.app" "TellMAP $etiqueta is installed in $destino/TellMAP.app"
	if [ -z "${TELLMAP_NO_ABRIR:-}" ]; then
		open "$destino/TellMAP.app"
	fi
}

main "$@"
