#!/bin/bash
# Prueba TellMAP en una Mac tal como la instala la gente y deja un informe. Se corre pegando en la Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/bafif/tmap/main/tools/probar-macos.sh | bash
#
# 1. Instala la última versión con tools/instalar-macos.sh, que elige la de Intel o la de Apple Silicon.
# 2. Comprueba que sea esa versión, que el ejecutable sea del procesador de esta Mac, la firma ad hoc, que no quede en
#    cuarentena y que arranque con todos sus datos (--verificar).
# 3. La abre con la ventana de verdad, saca una captura y comprueba que no salga casi lisa. Los runners de GitHub no
#    tienen placa de video, así que esto solo se comprueba en una Mac: con Forward+, una Intel Iris Plus 640 dejaba la
#    ventana en negro sin ningún error.
# 4. Baja el .dmg de la versión, lo verifica y lo monta: tiene que traer la misma TellMAP.app que el zip, firmada, y un
#    acceso a Aplicaciones, y la app tiene que abrir y dibujar desde el disco.
# 5. Deja el informe, las capturas, los registros de la app y el .dmg en una carpeta del escritorio, y abre la captura y
#    el .dmg para mirarlos a ojo. Si algo falla, el informe y las capturas van en un issue.
#
# Variables opcionales:
#   TELLMAP_VERSION=v0.3.6     una versión en particular en vez de la última (sirve también para las preliminares)
#   TELLMAP_INFORME=/carpeta   dónde dejar el informe (por defecto, una carpeta nueva en el escritorio)
#   TELLMAP_NO_ABRIR=1         no abrir la captura ni el .dmg al terminar
#
# Sale con 1 si algo falló. Todo va dentro de main, que se llama en la última línea: si la descarga del script se
# corta a la mitad, no corre nada.

set -euo pipefail

REPO="bafif/tmap"
# El registro de la app exportada; se renombra en la apertura siguiente, así que se copia después de cada una.
REGISTRO="$HOME/Library/Application Support/Godot/app_userdata/TellMAP/logs/godot.log"
CARPETA=""
INFORME="/dev/null"
TEMPORAL=""
MONTAJE=""
DMG=""
FALLAS=0

linea() { printf '%s\n' "$1" | tee -a "$INFORME"; }
bien() { linea "bien:  $1"; }
mal() {
	linea "FALLA: $1"
	FALLAS=$((FALLAS + 1))
}

limpiar() {
	if [ -n "$MONTAJE" ]; then
		hdiutil detach "$MONTAJE" -quiet 2>/dev/null || hdiutil detach "$MONTAJE" -force -quiet 2>/dev/null || true
	fi
	if [ -n "$TEMPORAL" ]; then rm -rf "$TEMPORAL"; fi
}

guardar_registro() {
	if [ -f "$REGISTRO" ]; then cp "$REGISTRO" "$CARPETA/$1"; fi
}

# Corre un comando con un límite de segundos (macOS no trae timeout) y devuelve 124 si se pasó.
con_limite() {
	local segundos="$1" i=0 pid estado=0
	shift
	"$@" </dev/null &
	pid=$!
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$i" -ge "$segundos" ]; then
			kill "$pid" 2>/dev/null || true
			sleep 3
			kill -9 "$pid" 2>/dev/null || true
			wait "$pid" 2>/dev/null || true
			return 124
		fi
		sleep 1
		i=$((i + 1))
	done
	wait "$pid" || estado=$?
	return "$estado"
}

# Abre la app con la ventana de verdad, saca una captura y mira que no salga casi lisa (--comprobar_dibujo sale con 1).
revisar_dibujo() {
	local app="$1" captura="$2" salida="$3" que="$4" estado=0 motor medida
	con_limite 240 "$app/Contents/MacOS/TellMAP" -- --captura="$captura" --comprobar_dibujo --diagnostico \
		>"$salida" 2>&1 || estado=$?
	motor="$(grep -o 'gráficos: .*' "$salida" | head -1 || true)"
	medida="$(grep -o 'Dibujo .*' "$salida" | head -1 || true)"
	if [ "$estado" = 124 ]; then
		mal "${que}: no sacó la captura en cuatro minutos"
	elif [ ! -f "$captura" ]; then
		mal "${que}: se cerró (${estado}) sin sacar la captura"
	elif [ "$estado" = 0 ]; then
		bien "${que} dibuja (${motor:-sin motor en la salida}; ${medida})"
	else
		mal "${que}: la captura salió casi lisa (${motor:-sin motor en la salida}; ${medida})"
	fi
}

terminar() {
	linea ""
	if [ "$FALLAS" = 0 ]; then
		linea "Todo bien."
	else
		linea "Fallas: ${FALLAS}. Ver arriba y los archivos de la carpeta."
	fi
	linea "Informe, capturas y registros en ${CARPETA}"
	if [ -z "${TELLMAP_NO_ABRIR:-}" ]; then
		if [ -f "$CARPETA/captura.png" ]; then open "$CARPETA/captura.png"; fi
		if [ -n "$DMG" ] && [ -f "$DMG" ]; then
			open "$DMG"
			echo "Se abrió el .dmg en el Finder: tiene que verse TellMAP, con su ícono, y el acceso a Aplicaciones."
		fi
	fi
	if [ "$FALLAS" = 0 ]; then exit 0; fi
	exit 1
}

main() {
	[ "$(uname -s)" = "Darwin" ] || { echo "Esta prueba es para macOS." >&2; exit 1; }

	# hw.optional.arm64 vale 1 en Apple Silicon aunque la Terminal corra con Rosetta.
	local arq="x86_64"
	if [ "$(sysctl -in hw.optional.arm64 2>/dev/null || echo 0)" = "1" ]; then arq="arm64"; fi

	local etiqueta="${TELLMAP_VERSION:-}"
	if [ -z "$etiqueta" ]; then
		etiqueta="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest")"
		etiqueta="${etiqueta##*/}"
	fi
	case "${etiqueta}" in
		v[0-9]*) ;;
		*) echo "No se pudo saber cuál es la última versión (${etiqueta})." >&2; exit 1 ;;
	esac

	CARPETA="${TELLMAP_INFORME:-$HOME/Desktop/TellMAP-prueba-${etiqueta}-$(date +%Y%m%d-%H%M%S)}"
	mkdir -p "$CARPETA"
	INFORME="$CARPETA/informe.txt"
	TEMPORAL="$(mktemp -d)"
	trap limpiar EXIT

	local video
	video="$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/ {print $2}' |
		paste -s -d ',' - || true)"
	linea "TellMAP ${etiqueta} en macOS, $(date '+%Y-%m-%d %H:%M')"
	linea "Mac: $(sysctl -n hw.model) ($(sysctl -n machdep.cpu.brand_string)), macOS $(sw_vers -productVersion), ${arq}"
	linea "Video: ${video:-desconocido}"
	linea ""

	# El instalador de al lado si se corre desde una copia del repo; si no, el de GitHub.
	local instalador="$TEMPORAL/instalar-macos.sh"
	if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/instalar-macos.sh" ]; then
		instalador="$(dirname "${BASH_SOURCE[0]}")/instalar-macos.sh"
	elif ! curl -fsSL -o "$instalador" "https://raw.githubusercontent.com/${REPO}/main/tools/instalar-macos.sh"; then
		mal "no se pudo bajar el instalador"
		terminar
	fi

	local destino="/Applications"
	[ -w "$destino" ] || destino="$HOME/Applications"
	local app="$destino/TellMAP.app"
	echo "Instalando TellMAP ${etiqueta}…"
	if TELLMAP_VERSION="$etiqueta" TELLMAP_DESTINO="$destino" TELLMAP_NO_ABRIR=1 bash "$instalador" \
		>"$CARPETA/instalacion.txt" 2>&1 </dev/null; then
		bien "se instaló con tools/instalar-macos.sh en ${app}"
	else
		mal "el instalador falló (ver instalacion.txt)"
		terminar
	fi

	local version archs
	version="$(plutil -extract CFBundleShortVersionString raw -o - "$app/Contents/Info.plist" 2>/dev/null || echo '?')"
	case "${etiqueta#v}" in
		"$version" | "$version"-*) bien "es la ${version}" ;;
		*) mal "la app dice ser la ${version} y se pidió la ${etiqueta}" ;;
	esac
	archs="$(lipo -archs "$app/Contents/MacOS/TellMAP" 2>/dev/null || echo '?')"
	case " ${archs} " in
		*" ${arq} "*) bien "el ejecutable es para ${archs}" ;;
		*) mal "el ejecutable es para ${archs} y esta Mac es ${arq}" ;;
	esac
	if codesign --verify --deep --strict "$app" 2>"$TEMPORAL/firma.txt"; then
		bien "la firma ad hoc vale"
	else
		mal "la firma no vale: $(head -1 "$TEMPORAL/firma.txt")"
	fi
	if xattr -p com.apple.quarantine "$app" >/dev/null 2>&1; then
		mal "quedó en cuarentena"
	else
		bien "no quedó en cuarentena"
	fi

	echo "Abriendo TellMAP sin ventana (--verificar)…"
	if con_limite 300 "$app/Contents/MacOS/TellMAP" --headless -- --verificar >"$CARPETA/verificar.txt" 2>&1 &&
		grep -q "TellMAP bien" "$CARPETA/verificar.txt"; then
		bien "arranca con todos sus datos ($(grep -o 'TellMAP bien.*' "$CARPETA/verificar.txt" | head -1))"
	else
		mal "--verificar no terminó bien (ver verificar.txt)"
	fi
	guardar_registro registro-verificar.log

	echo "Abriendo TellMAP con su ventana para sacar una captura…"
	revisar_dibujo "$app" "$CARPETA/captura.png" "$CARPETA/salida-app.txt" "la app instalada"
	guardar_registro registro-app.log

	DMG="$CARPETA/TellMAP-${etiqueta}-macos-${arq}.dmg"
	echo "Bajando el .dmg…"
	local url_dmg="https://github.com/${REPO}/releases/download/${etiqueta}/TellMAP-${etiqueta}-macos-${arq}.dmg"
	if ! curl -fsSL -o "$DMG" "$url_dmg"; then
		linea "aviso: ${etiqueta} no tiene .dmg para ${arq}"
		rm -f "$DMG"
		DMG=""
		terminar
	fi
	if hdiutil verify "$DMG" >"$TEMPORAL/verificar-dmg.txt" 2>&1; then
		bien "el .dmg pasa hdiutil verify"
	else
		mal "el .dmg no pasa hdiutil verify: $(tail -1 "$TEMPORAL/verificar-dmg.txt")"
	fi
	MONTAJE="$TEMPORAL/disco"
	mkdir -p "$MONTAJE"
	if ! hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MONTAJE" "$DMG" >"$TEMPORAL/montar.txt" 2>&1; then
		mal "el .dmg no se monta: $(tail -1 "$TEMPORAL/montar.txt")"
		MONTAJE=""
		terminar
	fi
	bien "el .dmg se monta"
	if [ "$(readlink "$MONTAJE/Applications" || true)" = "/Applications" ]; then
		bien "trae el acceso a Aplicaciones"
	else
		mal "no trae el acceso a Aplicaciones"
	fi
	if [ ! -d "$MONTAJE/TellMAP.app" ]; then
		mal "no trae TellMAP.app"
	else
		if diff -rq "$MONTAJE/TellMAP.app" "$app" >"$TEMPORAL/diferencias.txt" 2>&1; then
			bien "su TellMAP.app es igual a la del zip"
		else
			mal "su TellMAP.app no es igual a la del zip: $(head -1 "$TEMPORAL/diferencias.txt")"
		fi
		if codesign --verify --deep --strict "$MONTAJE/TellMAP.app" 2>/dev/null; then
			bien "la firma de la app del .dmg vale"
		else
			mal "la firma de la app del .dmg no vale"
		fi
		echo "Abriendo TellMAP desde el .dmg…"
		revisar_dibujo "$MONTAJE/TellMAP.app" "$CARPETA/captura-dmg.png" "$CARPETA/salida-dmg.txt" \
			"la app abierta desde el .dmg"
		guardar_registro registro-dmg.log
	fi
	hdiutil detach "$MONTAJE" -quiet 2>/dev/null || hdiutil detach "$MONTAJE" -force -quiet 2>/dev/null || true
	MONTAJE=""

	terminar
}

main "$@"
