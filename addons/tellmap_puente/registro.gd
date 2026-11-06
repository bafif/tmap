extends Logger
## Guarda en memoria los últimos errores y avisos del motor, con la traza de GDScript cuando la hay, para que el
## puente los devuelva (comando «errores» y campo «errores» de cada respuesta). Godot lo llama desde cualquier hilo.

const MAX := 500
const TIPOS: Array[String] = ["error", "aviso", "script", "shader"]

## Si es true, también guarda los print() comunes (por defecto solo errores, avisos y printerr()).
var guardar_mensajes := false

var _mutex := Mutex.new()
var _items: Array[Dictionary] = []
var _siguiente := 0
var _desvio: Array = []
var _desviando := false
var _archivo: FileAccess
var _escribiendo := false


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var traza := PackedStringArray()
	for bt in script_backtraces:
		for i in bt.get_frame_count():
			traza.append("%s:%d %s()" % [bt.get_frame_file(i), bt.get_frame_line(i), bt.get_frame_function(i)])
	_agregar({
		"tipo": TIPOS[error_type] if error_type >= 0 and error_type < TIPOS.size() else "error",
		"texto": rationale if rationale != "" else code,
		"archivo": file, "linea": line, "funcion": function, "traza": traza,
	})


func _log_message(message: String, error: bool) -> void:
	if error or guardar_mensajes:
		_agregar({"tipo": "printerr" if error else "mensaje", "texto": message.strip_edges()})


func _agregar(d: Dictionary) -> void:
	_mutex.lock()
	if _desviando:
		_desvio.append(d)
	else:
		d["i"] = _siguiente
		d["ms"] = Time.get_ticks_msec()
		_siguiente += 1
		_items.append(d)
		if _items.size() > MAX:
			_items.pop_front()
		if _archivo and not _escribiendo:
			_escribiendo = true
			_archivo.store_string(_linea(d))
			_archivo.flush()
			_escribiendo = false
	_mutex.unlock()


func _linea(d: Dictionary) -> String:
	var hora := Time.get_time_string_from_system()
	var t := "%s %s %s" % [hora, str(d["tipo"]).to_upper().rpad(8), d["texto"]]
	if d.get("archivo", "") != "":
		t += "  (%s:%s)" % [d["archivo"], d["linea"]]
	for x in d.get("traza", []):
		t += "\n        " + x
	return t + "\n"


## Además de guardar en memoria, escribe todo en res://.godot/registros/<rol>-<fecha>-<pid>.log (quedan los
## últimos «mantener» de cada rol). Devuelve la ruta. Lo usan la app y el editor en las compilaciones de desarrollo.
func abrir_archivo(rol: String, mantener := 15) -> String:
	var dir := ProjectSettings.globalize_path("res://.godot/registros")
	DirAccess.make_dir_recursive_absolute(dir)
	var viejos := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.begins_with(rol + "-"))
	viejos.sort()
	while viejos.size() >= mantener:
		DirAccess.remove_absolute(dir.path_join(viejos.pop_front()))
	var fecha := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var ruta := dir.path_join("%s-%s-%d.log" % [rol, fecha, OS.get_process_id()])
	_mutex.lock()
	_archivo = FileAccess.open(ruta, FileAccess.WRITE)
	_mutex.unlock()
	guardar_mensajes = true
	escribir("TellMAP %s · Godot %s · %s" % [ProjectSettings.get_setting("application/config/version", ""),
			Engine.get_version_info()["string"], " ".join(OS.get_cmdline_args() + OS.get_cmdline_user_args())])
	return ruta


func escribir(texto: String) -> void:
	_mutex.lock()
	if _archivo:
		_archivo.store_string(texto + "\n")
		_archivo.flush()
	_mutex.unlock()


func cerrar_archivo() -> void:
	_mutex.lock()
	_archivo = null
	_mutex.unlock()


## Índice del próximo registro: para pedir después solo lo nuevo.
func marca() -> int:
	_mutex.lock()
	var m := _siguiente
	_mutex.unlock()
	return m


func desde(i: int, tipos: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_mutex.lock()
	for d in _items:
		if d["i"] >= i and (tipos.is_empty() or d["tipo"] in tipos):
			out.append(d.duplicate())
	_mutex.unlock()
	return out


func limpiar() -> void:
	_mutex.lock()
	_items.clear()
	_mutex.unlock()


## Mientras dura el desvío, lo que llega no entra al registro: sirve para probar a compilar código sin ensuciarlo.
func empezar_desvio() -> void:
	_mutex.lock()
	_desvio = []
	_desviando = true
	_mutex.unlock()


func terminar_desvio() -> Array:
	_mutex.lock()
	_desviando = false
	var out := _desvio
	_desvio = []
	_mutex.unlock()
	return out
