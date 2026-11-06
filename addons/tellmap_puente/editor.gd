@tool
extends EditorPlugin
## Puente del editor: deja que tools/godot/tmap.py (o un agente) maneje este editor: reescanear archivos, correr y
## parar la app, abrir un archivo en una línea, leer ajustes, ver los errores, sacar capturas y ejecutar GDScript
## con acceso a EditorInterface. El panel «Puente» muestra cada pedido y tiene botones para las tareas de siempre.
## Ver tools/godot/README.md.

const Servidor := preload("res://addons/tellmap_puente/servidor.gd")
const Registro := preload("res://addons/tellmap_puente/registro.gd")
const AUTO_RECARGA := "text_editor/behavior/files/auto_reload_scripts_on_external_change"

var _srv: Servidor
var _registro: Registro
var _dock: EditorDock
var _estado: Label
var _bitacora: RichTextLabel
var _hilo: Thread


func _enter_tree() -> void:
	_registro = Registro.new()
	OS.add_logger(_registro)
	_registro.abrir_archivo("editor")
	_srv = Servidor.new()
	_srv.registro = _registro
	_srv.registrar("estado", _estado_cmd, "proyecto, escena abierta, si la app está corriendo")
	_srv.registrar("escanear", _escanear, "reescanea los archivos (después de cambiarlos desde afuera)")
	_srv.registrar("jugar", _jugar, "corre la app {escena}; sin escena, la principal")
	_srv.registrar("parar", _parar, "para la app que corre desde el editor")
	_srv.registrar("abrir", _abrir, "abre {ruta, linea} en el editor (scripts, escenas u otros archivos)")
	_srv.registrar("ajuste_editor", _ajuste_editor, "lee o cambia un ajuste del editor {clave, valor}")
	_srv.registrar("recargar_plugin", _recargar_plugin, "apaga y prende este plugin para tomar sus cambios")
	_srv.atendido.connect(_al_atender)
	_armar_panel()
	if _srv.iniciar("editor", EditorInterface.get_base_control()):
		_estado.text = "Escuchando en 127.0.0.1:%d" % _srv.puerto
	else:
		_estado.text = "Sin puerto libre: el puente del editor está apagado."


func _exit_tree() -> void:
	if _hilo and _hilo.is_started():
		_hilo.wait_to_finish()
	if _srv:
		_srv.detener()
	if _registro:
		OS.remove_logger(_registro)
		_registro.cerrar_archivo()
	_srv = null
	_registro = null
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()


func _process(_d: float) -> void:
	if _srv:
		_srv.sondear()


# ---------------------------------------------------------------------------------------------------------------
# Panel


func _armar_panel() -> void:
	_dock = EditorDock.new()
	_dock.title = "Puente"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_BL
	var caja := VBoxContainer.new()
	_dock.add_child(caja)
	_estado = Label.new()
	caja.add_child(_estado)
	var auto := CheckBox.new()
	auto.text = "Recargar sin preguntar los scripts cambiados afuera"
	auto.tooltip_text = "Ajuste del editor «%s». Sirve cuando otro programa edita los archivos." % AUTO_RECARGA
	auto.button_pressed = EditorInterface.get_editor_settings().get_setting(AUTO_RECARGA)
	auto.toggled.connect(func(v: bool) -> void: EditorInterface.get_editor_settings().set_setting(AUTO_RECARGA, v))
	caja.add_child(auto)
	var fila := HBoxContainer.new()
	caja.add_child(fila)
	for d: Array in [["Prueba automática", _prueba], ["Validar enciclopedia", _validar], ["Limpiar", _limpiar]]:
		var b := Button.new()
		b.text = d[0]
		b.pressed.connect(d[1])
		fila.add_child(b)
	_bitacora = RichTextLabel.new()
	_bitacora.scroll_following = true
	_bitacora.selection_enabled = true
	_bitacora.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bitacora.custom_minimum_size.y = 160
	caja.add_child(_bitacora)
	add_dock(_dock)


func _anotar(texto: String) -> void:
	var hora := Time.get_time_string_from_system()
	_bitacora.append_text("[color=#888]%s[/color] %s\n" % [hora, texto])


func _al_atender(comando: String, ok: bool, ms: int) -> void:
	if comando in ["ping", "errores"]:
		return
	_anotar("%s%s [color=#888](%d ms)[/color]" % ["" if ok else "[color=#e66]✗[/color] ", comando, ms])


func _limpiar() -> void:
	_bitacora.clear()


func _prueba() -> void:
	_tarea("Prueba automática", OS.get_executable_path(),
			["--headless", "--path", ProjectSettings.globalize_path("res://"), "--", "--prueba"])


func _validar() -> void:
	_tarea("Validar enciclopedia", "python3",
			[ProjectSettings.globalize_path("res://tools/enciclopedia/validar.py")])


## Corre un programa en otro hilo para no trabar el editor y muestra el final de su salida.
func _tarea(nombre: String, programa: String, args: Array) -> void:
	if _hilo and _hilo.is_alive():
		_anotar("[color=#e6a]Ya hay una tarea corriendo.[/color]")
		return
	if _hilo:
		_hilo.wait_to_finish()
	_anotar("%s: corriendo…" % nombre)
	_hilo = Thread.new()
	_hilo.start(func() -> void:
		var salida := []
		var codigo := OS.execute(programa, PackedStringArray(args), salida, true)
		_fin_tarea.call_deferred(nombre, codigo, "\n".join(salida)))


func _fin_tarea(nombre: String, codigo: int, salida: String) -> void:
	var lineas := salida.strip_edges().split("\n")
	var cola := "\n".join(lineas.slice(maxi(0, lineas.size() - 8)))
	var color := "#7c7" if codigo == 0 else "#e66"
	_anotar("[color=%s]%s: %s[/color]\n%s" % [color, nombre, "bien" if codigo == 0 else "falló (%d)" % codigo, cola])


# ---------------------------------------------------------------------------------------------------------------
# Comandos


func _estado_cmd(_a: Dictionary) -> Dictionary:
	var raiz := EditorInterface.get_edited_scene_root()
	return {
		"proyecto": ProjectSettings.globalize_path("res://"), "godot": Engine.get_version_info()["string"],
		"escena": raiz.scene_file_path if raiz else "", "abiertas": EditorInterface.get_open_scenes(),
		"jugando": EditorInterface.is_playing_scene(), "escena_jugando": EditorInterface.get_playing_scene(),
		"auto_recarga": EditorInterface.get_editor_settings().get_setting(AUTO_RECARGA),
	}


func _escanear(_a: Dictionary) -> Dictionary:
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	await get_tree().process_frame
	while fs.is_scanning():
		await get_tree().process_frame
	return {}


func _jugar(a: Dictionary) -> Dictionary:
	if a.has("escena"):
		EditorInterface.play_custom_scene(str(a["escena"]))
	else:
		EditorInterface.play_main_scene()
	return {"jugando": true}


func _parar(_a: Dictionary) -> Dictionary:
	EditorInterface.stop_playing_scene()
	return {}


func _abrir(a: Dictionary) -> Variant:
	var ruta := str(a.get("ruta", ""))
	if not ruta.begins_with("res://"):
		ruta = "res://" + ruta.trim_prefix("/")
	if not FileAccess.file_exists(ruta):
		return Servidor.error("no existe %s" % ruta)
	if ruta.get_extension() in ["gd", "gdshader"]:
		EditorInterface.edit_resource(load(ruta))
		if ruta.ends_with(".gd"):
			EditorInterface.edit_script(load(ruta), int(a.get("linea", 1)), int(a.get("columna", 0)))
	elif ruta.get_extension() in ["tscn", "scn"]:
		EditorInterface.open_scene_from_path(ruta)
	else:
		EditorInterface.select_file(ruta)
	return {"abierto": ruta}


func _ajuste_editor(a: Dictionary) -> Variant:
	var es := EditorInterface.get_editor_settings()
	var clave := str(a.get("clave", ""))
	if not es.has_setting(clave):
		return Servidor.error("no existe el ajuste del editor «%s»" % clave)
	if a.has("valor"):
		es.set_setting(clave, a["valor"])
	return {clave: es.get_setting(clave)}


func _recargar_plugin(_a: Dictionary) -> Dictionary:
	var nombre := "tellmap_puente"
	(func() -> void:
		EditorInterface.set_plugin_enabled(nombre, false)
		EditorInterface.set_plugin_enabled(nombre, true)).call_deferred()
	return {"recargando": true}
