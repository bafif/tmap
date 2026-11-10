class_name Datos
## De dónde se lee cada archivo de data/ y cómo se instala una actualización que trae solo datos.
##
## Los datos (data/mapa y data/enciclopedia) van dentro del ejecutable. Una actualización de datos guarda en
## user://datos/<versión>/ los grupos que cambiaron (un grupo es cada carpeta de data/): si cambió un archivo de un
## grupo, el grupo entero se lee de ahí y tapa al de adentro. Así una carpeta local nunca mezcla archivos de dos
## versiones, y los paquetes que se agregan o se borran se ven al listar la carpeta. `ruta()` traduce cada ruta.
##
## data/version.json lo escribe tools/actualizacion/publicar.py antes de exportar: {"datos": <fecha del commit en
## segundos>}. Desde el código fuente no existe: los datos son los del repo y nada los tapa. Qué archivos trae el
## ejecutable y su sha256 se calcula al instalar una actualización (no se confía en un sello que pudo quedar viejo).
## Detalle: docs/es/actualizaciones.md.

const RAIZ := "res://data/"
const DIR_LOCAL := "user://datos/"
const ACTIVO := "user://datos/activo.json"

## Grupo → carpeta local que lo reemplaza, con «/» al final. Vacío: todo se lee de adentro del ejecutable.
static var grupos := {}
## Versión de los datos que se están leyendo (fecha del commit, en segundos); 0 si no se sabe.
static var version := 0
static var _incluida := {}
static var _activo := {}
## rel → sha256 de lo que trae el ejecutable (se calcula la primera vez que hace falta).
static var _adentro := {}


## La versión de los datos que vienen dentro del ejecutable.
static func incluida() -> Dictionary:
	if _incluida.is_empty():
		var d: Variant = null
		if FileAccess.file_exists(RAIZ + "version.json"):
			d = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "version.json"))
		_incluida = d if d is Dictionary and d.has("datos") else {"datos": 0}
	return _incluida


## Los archivos de data/ que trae el ejecutable (o el repo), con su sha256: rel → sha256.
static func adentro() -> Dictionary:
	if _adentro.is_empty():
		for g in DirAccess.get_directories_at(RAIZ):
			_listar(RAIZ, g, _adentro)
	return _adentro


static func _listar(raiz: String, rel: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(raiz + rel):
		if not f.ends_with(".import") and not f.ends_with(".remap"):
			out[rel + "/" + f] = FileAccess.get_sha256(raiz + rel + "/" + f)
	for d in DirAccess.get_directories_at(raiz + rel):
		_listar(raiz, rel + "/" + d, out)


## Lee user://datos/activo.json y, si es más nuevo que lo de adentro y sirve para esta versión de la app, lo usa.
## Con `limpiar` (al abrir la app) borra lo que no se usa: versiones viejas y descargas a medias.
static func activar(version_app: String, limpiar := false) -> void:
	grupos.clear()
	_activo = {}
	version = int(incluida().get("datos", 0))
	var a: Variant = null
	if FileAccess.file_exists(ACTIVO):
		a = JSON.parse_string(FileAccess.get_file_as_string(ACTIVO))
	var sirve := a is Dictionary and int(a.get("datos", 0)) > version \
		and comparar(version_app, str(a.get("app_minima", "0"))) >= 0
	if sirve:
		for g in a.get("grupos", []):
			sirve = sirve and DirAccess.dir_exists_absolute(str(a["carpeta"]) + str(g))
	if sirve:
		_activo = a
		version = int(a["datos"])
		for g in a["grupos"]:
			grupos[str(g)] = "%s%s/" % [a["carpeta"], g]
	if limpiar and DirAccess.dir_exists_absolute(DIR_LOCAL):
		var queda := str(_activo.get("carpeta", "")).trim_suffix("/").get_file()
		for d in DirAccess.get_directories_at(DIR_LOCAL):
			if d != queda:
				borrar_carpeta(DIR_LOCAL + d)
		if _activo.is_empty():
			DirAccess.remove_absolute(ACTIVO)


## La ruta de donde leer `r` (una ruta res://data/…, de archivo o de carpeta).
static func ruta(r: String) -> String:
	if grupos.is_empty() or not r.begins_with(RAIZ):
		return r
	var resto := r.trim_prefix(RAIZ)
	var g := resto.get_slice("/", 0)
	if not grupos.has(g) or not resto.begins_with(g + "/"):
		return r
	return grupos[g] + resto.trim_prefix(g + "/")


## El sha256 del archivo `rel` (relativo a data/) que se lee hoy, o "" si no se sabe.
static func sha_actual(rel: String) -> String:
	var g := rel.get_slice("/", 0)
	if grupos.has(g):
		var info: Variant = _activo.get("archivos", {}).get(rel)
		return str(info["sha256"]) if info is Dictionary else ""
	return str(adentro().get(rel, ""))


## Los grupos de `archivos` (la lista completa de una versión nueva: rel → {"sha256", …}) que no son iguales a los
## de adentro del ejecutable: esos van a la carpeta local.
static func grupos_distintos(archivos: Dictionary) -> Array:
	var propios := adentro()
	var todos := {}
	for rel in archivos.keys() + propios.keys():
		todos[str(rel).get_slice("/", 0)] = true
	var out: Array = []
	for g in todos.keys():
		var a := _del_grupo(propios, g)
		var n := {}
		for rel in archivos:
			if str(rel).get_slice("/", 0) == g:
				n[rel] = str(archivos[rel]["sha256"])
		if a != n:
			out.append(g)
	out.sort()
	return out


## Lo que hay que bajar para pasar a `archivos`: lo que cambió respecto de lo que se lee hoy.
static func que_bajar(archivos: Dictionary) -> Array:
	var distintos := grupos_distintos(archivos)
	var out: Array = []
	for rel in archivos:
		if str(rel).get_slice("/", 0) in distintos and sha_actual(rel) != str(archivos[rel]["sha256"]):
			out.append(rel)
	out.sort()
	return out


## Instala la versión `nueva` (la sección «datos» del manifiesto) con los archivos ya bajados y verificados en
## `bajados` (rel → archivo local). Lo que no cambió se copia de lo que se lee hoy. Devuelve "" o el error; si falla,
## sigue valiendo lo de antes. No cambia lo que se está leyendo: eso lo hace `activar()`.
static func instalar(nueva: Dictionary, bajados: Dictionary) -> String:
	var archivos: Dictionary = nueva["archivos"]
	var distintos := grupos_distintos(archivos)
	var carpeta := "%s%d/" % [DIR_LOCAL, int(nueva["version"])]
	if carpeta == str(_activo.get("carpeta", "")):
		return "Esa versión de los datos ya está instalada."
	borrar_carpeta(carpeta)
	for g in distintos:
		DirAccess.make_dir_recursive_absolute(carpeta + g)
	for rel in archivos:
		if not str(rel).get_slice("/", 0) in distintos:
			continue
		var destino: String = carpeta + rel
		DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
		var err := OK
		if bajados.has(rel):
			err = DirAccess.rename_absolute(bajados[rel], destino)
		else:
			err = DirAccess.copy_absolute(ruta(RAIZ + rel), destino)
		if err != OK or FileAccess.get_sha256(destino) != str(archivos[rel]["sha256"]):
			borrar_carpeta(carpeta)
			return "No se pudo instalar %s (%s)." % [rel, error_string(err) if err != OK else "no coincide su sha256"]
	var activo := {"datos": int(nueva["version"]), "app_minima": str(nueva.get("app_minima", "0")), "carpeta": carpeta,
		"grupos": distintos, "archivos": archivos}
	var tmp := ACTIVO + ".nuevo"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		borrar_carpeta(carpeta)
		return "No se pudo escribir %s (%s)." % [tmp, error_string(FileAccess.get_open_error())]
	f.store_string(JSON.stringify(activo, "  "))
	f.close()
	# rename_absolute reemplaza el archivo anterior de una vez: si la app se corta acá, vale uno o el otro.
	var err := DirAccess.rename_absolute(tmp, ACTIVO)
	return "" if err == OK else "No se pudo activar la versión nueva (%s)." % error_string(err)


## Compara versiones «1.2.3»: -1, 0 o 1.
static func comparar(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


## La fecha de una versión de los datos, para mostrarla («10/11/2026»), o "" si no se sabe.
static func fecha(segundos: int) -> String:
	if segundos <= 0:
		return ""
	var d := Time.get_date_dict_from_unix_time(segundos)
	return "%d/%d/%d" % [d["day"], d["month"], d["year"]]


static func _del_grupo(lista: Dictionary, g: String) -> Dictionary:
	var out := {}
	for rel in lista:
		if str(rel).get_slice("/", 0) == g:
			var v: Variant = lista[rel]
			out[rel] = str(v["sha256"]) if v is Dictionary else str(v)
	return out


static func borrar_carpeta(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		borrar_carpeta(dir.path_join(d))
	DirAccess.remove_absolute(dir)
