extends SceneTree
## Compila todos los scripts del proyecto sin abrir la app y lista los que fallan.
## Uso: godot --headless --path . -s res://addons/tellmap_puente/revisar.gd   (o tools/godot/tmap.py revisar)

const Registro := preload("res://addons/tellmap_puente/registro.gd")
const CARPETAS: Array[String] = ["res://scripts", "res://addons"]


func _initialize() -> void:
	var reg := Registro.new()
	OS.add_logger(reg)
	var rutas: Array[String] = []
	for c in CARPETAS:
		_juntar(c, rutas)
	var malos := 0
	for ruta in rutas:
		var marca := reg.marca()
		var s := ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if s == null or not s.can_instantiate():
			malos += 1
			print("MAL  ", ruta)
			for e in reg.desde(marca, ["script", "error"]):
				print("     línea %s: %s" % [e.get("linea"), e.get("texto")])
	print("%d scripts, %d con errores" % [rutas.size(), malos])
	OS.remove_logger(reg)
	quit(1 if malos else 0)


func _juntar(dir: String, rutas: Array[String]) -> void:
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			rutas.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_juntar(dir.path_join(d), rutas)
