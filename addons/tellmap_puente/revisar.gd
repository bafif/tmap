extends SceneTree
## Compila todos los scripts del proyecto sin abrir la app y lista los que fallan.
## Uso: godot --headless --path . -s res://addons/tellmap_puente/revisar.gd   (o tools/godot/tmap.py revisar)

const Registro := preload("res://addons/tellmap_puente/registro.gd")
const CARPETAS: Array[String] = ["res://scripts", "res://addons"]


func _initialize() -> void:
	# Si un error interno corta esta función, Godot no termina solo: este reloj lo cierra igual.
	create_timer(240.0).timeout.connect(_vencido)
	var reg := Registro.new()
	OS.add_logger(reg)
	var rutas: Array[String] = []
	for c in CARPETAS:
		_juntar(c, rutas)
	# Este mismo script ya compiló (está corriendo); volver a cargarlo con CACHE_MODE_IGNORE mientras se ejecuta hace
	# que Godot 4.7.2 se caiga a veces (señal 11).
	rutas.erase(get_script().resource_path)
	var malos := 0
	for ruta in rutas:
		var marca := reg.marca()
		# Sin «as GDScript»: en el binario oficial de Godot 4.7.2 esa conversión, dentro de un script de -s, da
		# «Internal script error! Opcode: 31» y la función se corta.
		var s: Resource = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not s.has_method("can_instantiate") or not s.call("can_instantiate"):
			malos += 1
			print("MAL  ", ruta)
			for e in reg.desde(marca, ["script", "error"]):
				print("     línea %s: %s" % [e.get("linea"), e.get("texto")])
	print("%d scripts, %d con errores" % [rutas.size(), malos])
	OS.remove_logger(reg)
	quit(1 if malos else 0)


func _vencido() -> void:
	print("revisar: no terminó en 4 minutos (¿un error interno de Godot?)")
	quit(2)


func _juntar(dir: String, rutas: Array[String]) -> void:
	if FileAccess.file_exists(dir.path_join(".gdignore")):
		return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			rutas.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_juntar(dir.path_join(d), rutas)
