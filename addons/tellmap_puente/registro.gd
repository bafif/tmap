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
