extends Node
## Actualizaciones automáticas de la versión exportada (docs/es/actualizaciones.md).
##
## Al abrir, si el ajuste «actualizar_solo» está prendido, lee un manifiesto publicado en GitHub. Si hay algo nuevo
## para instalar, lo ofrece con un cartel («Actualizar» o «Ahora no») y no baja nada hasta que le dicen que sí. «Ahora
## no» no cambia nada: se vuelve a ofrecer la próxima vez que se abra la app. Una versión nueva de la app se baja, se
## verifica (sha256) y reemplaza al ejecutable que está corriendo: se abre la próxima vez (o con «Reiniciar ahora»).
## Si solo hay datos nuevos, baja nada más los archivos que cambiaron y los instala con `Datos.instalar()`: la
## enciclopedia nueva se ve enseguida y el mapa nuevo, al volver a abrir. «Buscar ahora», en Ajustes, instala sin
## preguntar: ya es un pedido.
##
## Desde el código fuente no hace nada (se actualiza con git). Para probarlo: `-- --actualizaciones=<url del
## manifiesto>` lo prende, `--actualizar-y-salir` busca, instala y sale (0 bien, 1 error), `--preguntar-y-salir=si|no`
## hace lo mismo que al abrir y contesta el cartel, y `--ejecutable=<ruta>` elige qué ejecutable reemplazar. Lo usa
## tools/actualizacion/probar.py.

## «oferta»: hay algo para instalar y se pregunta (aceptar() o posponer()); «app»: hay una versión nueva instalada o
## para bajar a mano; «datos»: datos nuevos ya visibles; «datos_mapa»: datos nuevos que se ven al volver a abrir.
signal aviso(tipo: String, texto: String)
signal estado_cambiado

const MANIFIESTO := "https://github.com/bafif/tmap/releases/download/actualizaciones/actualizacion.json"
const PAGINA := "https://github.com/bafif/tmap/releases/latest"
## Versión del formato del manifiesto que entiende esta app: uno más nuevo pide bajar la app a mano.
const FORMATO := 1
const BAJANDO := "user://datos/bajando/"
const GZ_APP := "user://actualizacion.gz"

## Si esta copia se actualiza sola: la versión exportada, o con --actualizaciones en la línea de comandos.
var habilitado := false
var url_manifiesto := MANIFIESTO
## El ejecutable que se reemplaza ("" desde el código fuente: ahí no se reemplaza nada).
var ruta_ejecutable := ""
var ocupado := false
## Lo último que pasó, para Ajustes.
var texto := ""
## Versión nueva ya instalada, que se abre al reiniciar.
var app_lista := ""
## Si lo instalado (la app o datos del mapa) recién se ve al volver a abrir.
var pide_reinicio := false
## Página para bajar a mano la versión nueva cuando no se puede reemplazar el ejecutable.
var pagina_nueva := ""
## El manifiesto de lo que se ofreció y todavía no se contestó ({} si no hay nada esperando respuesta).
var _ofrecido: Dictionary = {}
## Lo ofrecido, en palabras («TellMAP 0.3.3 y datos del 12/11/2026»).
var _novedad := ""


func _ready() -> void:
	var args := _argumentos()
	habilitado = OS.has_feature("template") or args.has("actualizaciones")
	url_manifiesto = str(args.get("actualizaciones", MANIFIESTO))
	ruta_ejecutable = str(args.get("ejecutable", OS.get_executable_path() if OS.has_feature("template") else ""))
	if not habilitado:
		return
	_borrar_viejo()
	Datos.activar(version_app(), true)
	if args.has("actualizar-y-salir"):
		Estado.carga_terminada.connect(_actualizar_y_salir, CONNECT_ONE_SHOT)
	elif args.has("preguntar-y-salir"):
		Estado.carga_terminada.connect(_preguntar_y_salir.bind(str(args["preguntar-y-salir"]) == "si"), CONNECT_ONE_SHOT)
	elif Estado.ajustes.get("actualizar_solo", true) and not ["prueba", "verificar", "captura", "puente"].any(func(a): return args.has(a)):
		Estado.carga_terminada.connect(func(): get_tree().create_timer(3.0).timeout.connect(buscar.bind(true)), CONNECT_ONE_SHOT)


static func version_app() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## Busca lo nuevo. Con `preguntar` (al abrir), si hay algo para instalar lo ofrece (aviso «oferta») y espera la
## respuesta: aceptar() o posponer(). Sin `preguntar` (o si lo nuevo no se puede instalar desde acá), lo instala.
## Devuelve "" si salió bien (aunque no hubiera nada) o el error.
func buscar(preguntar := false) -> String:
	if ocupado:
		return ""
	if not habilitado:
		return _fijar("Desde el código fuente, TellMAP se actualiza con git.")
	ocupado = true
	# Buscar a mano con un cartel abierto vale como «Actualizar»: el cartel se reemplaza por el aviso de lo instalado.
	_ofrecido = {}
	_fijar("Buscando actualizaciones…")
	var err := await _buscar(preguntar)
	return _terminar(err)


## «Actualizar» en el cartel: instala lo que se ofreció.
func aceptar() -> String:
	if ocupado or _ofrecido.is_empty():
		return ""
	var m := _ofrecido
	_ofrecido = {}
	ocupado = true
	_fijar("Actualizando: %s…" % _novedad)
	var err := await _instalar(m)
	return _terminar(err)


## «Ahora no» en el cartel: no se baja ni se cambia nada. Se vuelve a ofrecer la próxima vez que se abra TellMAP.
func posponer() -> void:
	if _ofrecido.is_empty():
		return
	_ofrecido = {}
	_fijar("Quedó para después: %s. Se vuelve a ofrecer la próxima vez que abras TellMAP, o ahora con «Buscar ahora»."
		% _novedad)


## Si hay una pregunta esperando respuesta (el cartel de «Actualizar» o «Ahora no»).
func hay_oferta() -> bool:
	return not _ofrecido.is_empty()


func _terminar(err: String) -> String:
	# Lo bajado a medias (si algo falló) no sirve para la próxima.
	Datos.borrar_carpeta(BAJANDO)
	DirAccess.remove_absolute(GZ_APP)
	ocupado = false
	if err != "":
		_fijar("No se pudo actualizar: %s" % err)
	estado_cambiado.emit()
	return err


func _buscar(preguntar: bool) -> String:
	var r := await _pedir(url_manifiesto)
	if r.has("error"):
		return "no se pudo leer el manifiesto (%s)." % r["error"]
	var m: Variant = JSON.parse_string((r["cuerpo"] as PackedByteArray).get_string_from_utf8())
	if not m is Dictionary:
		return "el manifiesto no es un JSON válido."
	if int(m.get("formato", 0)) > FORMATO:
		pagina_nueva = PAGINA
		aviso.emit("app", "Hay una versión nueva de TellMAP que hay que bajar a mano.")
		_fijar("Hay una versión nueva de TellMAP que hay que bajar a mano.")
		return ""
	if preguntar:
		var novedad := _que_hay(m)
		if novedad != "":
			_ofrecido = m
			_novedad = novedad
			_fijar("Hay una actualización: %s." % novedad)
			aviso.emit("oferta", "Hay una actualización: %s. ¿La instalo?" % novedad)
			return ""
	return await _instalar(m)


## Lo que se puede instalar desde acá, en palabras, o "" si no hay nada. Una versión de la app que hay que bajar a mano
## no se ofrece: _instalar() la avisa con el enlace a la descarga.
func _que_hay(m: Dictionary) -> String:
	var partes := PackedStringArray()
	var app: Dictionary = m.get("app", {})
	if _app_nueva(app) and _app_instalable(app):
		partes.append("TellMAP %s" % str(app["version"]))
	var datos: Dictionary = m.get("datos", {})
	if _datos_nuevos(datos):
		partes.append("datos del %s" % Datos.fecha(int(datos["version"])))
	return " y ".join(partes)


func _app_nueva(app: Dictionary) -> bool:
	var nueva := str(app.get("version", "0"))
	return Datos.comparar(nueva, version_app()) > 0 and nueva != app_lista


## Si el ejecutable se puede reemplazar desde acá: hay uno para esta plataforma y la carpeta se puede escribir.
func _app_instalable(app: Dictionary) -> bool:
	var plataforma := "%s-%s" % [OS.get_name().to_lower(), Engine.get_architecture_name()]
	return not app.get(plataforma, {}).is_empty() and ruta_ejecutable != "" \
		and _se_puede_escribir(ruta_ejecutable.get_base_dir())


func _datos_nuevos(datos: Dictionary) -> bool:
	return int(datos.get("version", 0)) > Datos.version \
		and Datos.comparar(version_app(), str(datos.get("app_minima", "0"))) >= 0


func _instalar(m: Dictionary) -> String:
	var app: Dictionary = m.get("app", {})
	var hecho: Array = []
	var nueva := str(app.get("version", "0"))
	if _app_nueva(app):
		var err := await _actualizar_app(app)
		if err != "":
			return err
		hecho.append("TellMAP %s quedó instalada: se abre la próxima vez." % nueva if app_lista == nueva else
			"Hay una versión nueva, TellMAP %s: bajala de su página." % nueva)
	var datos: Dictionary = m.get("datos", {})
	if _datos_nuevos(datos):
		var err := await _actualizar_datos(datos)
		if err != "":
			return err
		hecho.append(texto)
	if hecho.is_empty():
		_fijar("TellMAP está al día: versión %s%s." % [version_app(),
			", datos del %s" % Datos.fecha(Datos.version) if Datos.version > 0 else ""])
	else:
		_fijar(" ".join(hecho))
	return ""


func _actualizar_app(app: Dictionary) -> String:
	var nueva := str(app["version"])
	pagina_nueva = str(app.get("pagina", PAGINA))
	var plataforma := "%s-%s" % [OS.get_name().to_lower(), Engine.get_architecture_name()]
	var a: Dictionary = app.get(plataforma, {})
	var manual := "Hay una versión nueva, TellMAP %s: bajala de su página." % nueva
	if not _app_instalable(app):
		aviso.emit("app", manual)
		return ""
	_fijar("Bajando TellMAP %s…" % nueva)
	var gz := GZ_APP
	var r := await _pedir(str(a["url"]), gz)
	if r.has("error"):
		return "no se pudo bajar la versión %s (%s)." % [nueva, r["error"]]
	var bytes := _descomprimir(gz, a)
	DirAccess.remove_absolute(gz)
	if bytes.is_empty():
		return "la versión %s que se bajó no coincide con la publicada (sha256)." % nueva
	var exe := ruta_ejecutable
	var nuevo := exe + ".nuevo"
	var f := FileAccess.open(nuevo, FileAccess.WRITE)
	if f == null:
		aviso.emit("app", manual)
		return ""
	f.store_buffer(bytes)
	f.close()
	var err := OK
	if OS.get_name() == "Windows":
		# Windows no deja pisar un ejecutable abierto, pero sí renombrarlo: el viejo se borra al abrir el nuevo.
		DirAccess.remove_absolute(exe + ".viejo")
		err = DirAccess.rename_absolute(exe, exe + ".viejo")
		if err == OK:
			err = DirAccess.rename_absolute(nuevo, exe)
	else:
		FileAccess.set_unix_permissions(nuevo, FileAccess.get_unix_permissions(exe))
		# En Linux y macOS el proceso que corre sigue con el archivo viejo; el nombre pasa al nuevo de una vez.
		err = DirAccess.rename_absolute(nuevo, exe)
	if err != OK:
		DirAccess.remove_absolute(nuevo)
		return "no se pudo reemplazar el ejecutable (%s)." % error_string(err)
	app_lista = nueva
	pide_reinicio = true
	aviso.emit("app", "TellMAP %s quedó instalada: se abre la próxima vez." % nueva)
	return ""


func _actualizar_datos(datos: Dictionary) -> String:
	var archivos: Dictionary = datos.get("archivos", {})
	var faltan := Datos.que_bajar(archivos)
	var bajados := {}
	DirAccess.make_dir_recursive_absolute(BAJANDO)
	for i in faltan.size():
		var rel: String = faltan[i]
		var info: Dictionary = archivos[rel]
		_fijar("Bajando datos nuevos: %d de %d archivos…" % [i + 1, faltan.size()])
		var gz := BAJANDO + str(info["sha256"]) + ".gz"
		var r := await _pedir(str(info["url"]), gz)
		if r.has("error"):
			return "no se pudo bajar %s (%s)." % [rel, r["error"]]
		var bytes := _descomprimir(gz, info)
		DirAccess.remove_absolute(gz)
		if bytes.is_empty() and int(info.get("bytes", 0)) > 0:
			return "%s no coincide con lo publicado (sha256)." % rel
		var destino := BAJANDO + str(info["sha256"])
		var f := FileAccess.open(destino, FileAccess.WRITE)
		if f == null:
			return "no se pudo guardar %s (%s)." % [rel, error_string(FileAccess.get_open_error())]
		f.store_buffer(bytes)
		f.close()
		bajados[rel] = destino
	var err := Datos.instalar(datos, bajados)
	if err != "":
		return err
	var antes := Datos.grupos.duplicate()
	Datos.activar(version_app())
	var del_mapa: bool = Datos.grupos.get("mapa", "") != antes.get("mapa", "")
	var cuando := "se ven al volver a abrir TellMAP" if del_mapa else "ya están en el mapa"
	pide_reinicio = pide_reinicio or del_mapa
	if Estado.cargado:
		Enciclopedia.recargar()
	_fijar("Datos del %s instalados (%d archivo%s nuevo%s): %s." % [Datos.fecha(Datos.version), faltan.size(),
		"" if faltan.size() == 1 else "s", "" if faltan.size() == 1 else "s", cuando])
	aviso.emit("datos_mapa" if del_mapa else "datos", texto)
	return ""


## Vuelve a abrir la app con los mismos argumentos (la versión nueva, si se reemplazó el ejecutable).
func reiniciar() -> void:
	var exe := ruta_ejecutable if ruta_ejecutable != "" else OS.get_executable_path()
	var argumentos := OS.get_cmdline_args()
	if not OS.get_cmdline_user_args().is_empty():
		argumentos.append("--")
		argumentos.append_array(OS.get_cmdline_user_args())
	if OS.get_name() == "macOS" and exe == OS.get_executable_path():
		# En macOS el ejecutable vive dentro de TellMAP.app: create_instance vuelve a abrir el paquete entero.
		OS.create_instance(argumentos)
	else:
		OS.create_process(exe, argumentos)
	get_tree().quit()


## Descomprime un .gz bajado y comprueba los dos sha256 (el del .gz y el del archivo). Vacío si algo no coincide.
func _descomprimir(gz: String, info: Dictionary) -> PackedByteArray:
	if FileAccess.get_sha256(gz) != str(info.get("sha256_gz", "")):
		return PackedByteArray()
	var n := int(info.get("bytes", 0))
	var bytes := FileAccess.get_file_as_bytes(gz).decompress(n, FileAccess.COMPRESSION_GZIP) if n > 0 else PackedByteArray()
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	if bytes.size() != n or h.finish().hex_encode() != str(info.get("sha256", "")):
		return PackedByteArray()
	return bytes


## Un pedido HTTP: {"cuerpo": PackedByteArray} o {"error": texto}. Con `archivo`, lo guarda ahí.
func _pedir(url: String, archivo := "") -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 30.0 if archivo == "" else 3600.0
	# Sin gzip de transporte: lo bajado tiene que ser byte por byte lo publicado, para comparar su sha256.
	h.accept_gzip = archivo == ""
	h.download_file = archivo
	add_child(h)
	var err := h.request(url, PackedStringArray(["User-Agent: TellMAP/%s (+https://github.com/bafif/tmap)" % version_app()]))
	if err != OK:
		h.queue_free()
		return {"error": error_string(err)}
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return {"error": "sin conexión" if r[0] in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE] else
			"error %d de HTTPRequest" % r[0]}
	if r[1] != 200:
		return {"error": "HTTP %d" % r[1]}
	return {"cuerpo": r[3]}


func _se_puede_escribir(dir: String) -> bool:
	var prueba := dir.path_join(".tellmap-prueba-escritura")
	var f := FileAccess.open(prueba, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(prueba)
	return true


## El ejecutable viejo que dejó una actualización en Windows.
func _borrar_viejo() -> void:
	if ruta_ejecutable != "" and FileAccess.file_exists(ruta_ejecutable + ".viejo"):
		DirAccess.remove_absolute(ruta_ejecutable + ".viejo")


func _actualizar_y_salir() -> void:
	var err := await buscar()
	print("[actualizacion] %s" % (texto if err == "" else "ERROR: " + texto))
	get_tree().quit(0 if err == "" else 1)


## Lo mismo que al abrir, contestando el cartel con «Actualizar» (`si`) o «Ahora no».
func _preguntar_y_salir(si: bool) -> void:
	var err := await buscar(true)
	if err == "" and hay_oferta():
		print("[actualizacion] %s" % texto)
		if si:
			err = await aceptar()
		else:
			posponer()
	print("[actualizacion] %s" % (texto if err == "" else "ERROR: " + texto))
	get_tree().quit(0 if err == "" else 1)


func _fijar(t: String) -> String:
	texto = t
	estado_cambiado.emit()
	return ""


func _argumentos() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var partes := a.substr(2).split("=", true, 1)
			out[partes[0]] = partes[1] if partes.size() > 1 else "1"
	return out
