extends Node
## Va primero entre los autoloads y no usa ningún class_name.
##
## Godot conoce los class_name del proyecto (Fechas, Proyeccion, TemaUI…) por un registro que arma al importarlo
## (.godot/global_script_class_cache.cfg). En un clon recién bajado ese registro no existe, y después de traer una
## clase nueva le falta: en los dos casos ningún script compila. Si pasa eso, este nodo importa el proyecto una vez y
## vuelve a abrir la app con los mismos argumentos. En el editor y en las versiones exportadas no hace nada.

const REGISTRO := "res://.godot/global_script_class_cache.cfg"
const CARPETAS: Array[String] = ["res://scripts", "res://addons"]


func _init() -> void:
	if not OS.has_feature("editor") or Engine.is_editor_hint():
		return
	var faltan := _clases_sin_registrar()
	if faltan.is_empty():
		return
	var raiz := ProjectSettings.globalize_path("res://")
	if OS.get_environment("TELLMAP_IMPORTADO") == "1":
		printerr("TellMAP: después de importar siguen sin registrar %s. Abrí el proyecto una vez en el editor: godot -e --path %s"
				% [", ".join(faltan), raiz])
		return
	print("TellMAP: importando el proyecto (la primera vez o con clases nuevas, como %s); tarda unos segundos…"
			% ", ".join(faltan.slice(0, 3)))
	var godot := OS.get_executable_path()
	OS.execute(godot, PackedStringArray(["--headless", "--path", raiz, "--import"]))
	OS.set_environment("TELLMAP_IMPORTADO", "1")
	OS.create_process(godot, _argumentos(raiz))
	# Sin esto, los autoloads que siguen intentan compilar y llenan la salida de errores que ya no importan.
	OS.kill(OS.get_process_id())


## Los mismos argumentos con los que se abrió la app, con la ruta del proyecto explícita. Godot no devuelve los que
## ya consumió (--path, --headless…): --headless se recupera mirando el servidor de pantalla.
func _argumentos(raiz: String) -> PackedStringArray:
	var out := PackedStringArray(["--path", raiz])
	if DisplayServer.get_name() == "headless":
		out.append("--headless")
	var motor := OS.get_cmdline_args()
	var usuario := OS.get_cmdline_user_args()
	var i := 0
	while i < motor.size():
		var a := motor[i]
		if a == "--path":
			i += 2
			continue
		if a in usuario or a == "--" or a == "++":
			break
		out.append(a)
		i += 1
	if not usuario.is_empty():
		out.append("--")
		out.append_array(usuario)
	return out


func _clases_sin_registrar() -> PackedStringArray:
	var registradas := {}
	var cfg := ConfigFile.new()
	if cfg.load(REGISTRO) == OK:
		for c: Variant in cfg.get_value("", "list", []):
			if c is Dictionary:
				registradas[str(c.get("class", ""))] = true
	var re := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)")
	var faltan := PackedStringArray()
	for carpeta in CARPETAS:
		_buscar(carpeta, re, registradas, faltan)
	return faltan


func _buscar(dir: String, re: RegEx, registradas: Dictionary, faltan: PackedStringArray) -> void:
	if not DirAccess.dir_exists_absolute(dir) or FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var m := re.search(FileAccess.get_file_as_string(dir.path_join(f)))
			if m and not registradas.has(m.get_string(1)):
				faltan.append(m.get_string(1))
	for d in DirAccess.get_directories_at(dir):
		_buscar(dir.path_join(d), re, registradas, faltan)
