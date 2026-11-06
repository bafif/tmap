extends RefCounted
## Servidor del puente: TCP en 127.0.0.1, un pedido JSON por línea y una respuesta JSON por línea.
## Lo usan el plugin del editor (editor.gd) y la app (juego.gd). Cada pedido lleva el token de la sesión, que se
## guarda con el puerto en res://.godot/puente/<rol>-<pid>.json: solo lo leen quienes ya pueden leer el repo.
## Pedido: {"token": "...", "cmd": "captura", "args": {...}}  Respuesta: {"ok": true, "r": ..., "errores": [...]}
## Documentación: tools/godot/README.md.

signal atendido(comando: String, ok: bool, ms: int)

const DIR_SESIONES := "res://.godot/puente"
const PUERTO_BASE := 47800
const PUERTOS := 40
const MAX_PEDIDO := 4 * 1024 * 1024

var rol := ""
var puerto := 0
var token := ""
var raiz: Node
var registro: Logger
var ultimo_pedido_ms := 0
var _srv := TCPServer.new()
var _clientes: Array[Dictionary] = []
var _comandos := {}
var _ruta_sesion := ""


func registrar(nombre: String, f: Callable, ayuda: String) -> void:
	_comandos[nombre] = {"f": f, "ayuda": ayuda}


func iniciar(p_rol: String, p_raiz: Node, extra := {}) -> bool:
	rol = p_rol
	raiz = p_raiz
	_registrar_comunes()
	for i in PUERTOS:
		if _srv.listen(PUERTO_BASE + i, "127.0.0.1") == OK:
			puerto = PUERTO_BASE + i
			break
	if puerto == 0:
		push_warning("Puente: no hay puertos libres entre %d y %d." % [PUERTO_BASE, PUERTO_BASE + PUERTOS - 1])
		return false
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	var datos := {
		"rol": rol, "pid": OS.get_process_id(), "puerto": puerto, "token": token,
		"usuario": OS.get_environment("USER"), "proyecto": ProjectSettings.globalize_path("res://"),
		"godot": Engine.get_version_info()["string"], "desde": int(Time.get_unix_time_from_system()),
	}
	datos.merge(extra)
	var dir := ProjectSettings.globalize_path(DIR_SESIONES)
	DirAccess.make_dir_recursive_absolute(dir)
	_ruta_sesion = dir.path_join("%s-%d.json" % [rol, OS.get_process_id()])
	var f := FileAccess.open(_ruta_sesion, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(datos, "\t"))
		f.close()
	ultimo_pedido_ms = Time.get_ticks_msec()
	return true


func detener() -> void:
	for c in _clientes:
		(c["peer"] as StreamPeerTCP).disconnect_from_host()
	_clientes.clear()
	_srv.stop()
	if _ruta_sesion != "" and FileAccess.file_exists(_ruta_sesion):
		DirAccess.remove_absolute(_ruta_sesion)


## Se llama en cada _process: acepta conexiones y atiende las líneas completas que llegaron.
func sondear() -> void:
	while _srv.is_connection_available():
		var nuevo := _srv.take_connection()
		nuevo.set_no_delay(true)
		_clientes.append({"peer": nuevo, "buf": PackedByteArray()})
	for c in _clientes.duplicate():
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clientes.erase(c)
			continue
		var n := peer.get_available_bytes()
		if n <= 0:
			continue
		var r := peer.get_partial_data(n)
		if r[0] != OK:
			continue
		var buf: PackedByteArray = c["buf"]
		buf.append_array(r[1])
		if buf.size() > MAX_PEDIDO:
			peer.disconnect_from_host()
			_clientes.erase(c)
			continue
		var i := buf.find(10)
		while i >= 0:
			_atender(peer, buf.slice(0, i).get_string_from_utf8())
			buf = buf.slice(i + 1)
			i = buf.find(10)
		c["buf"] = buf


func _atender(peer: StreamPeerTCP, linea: String) -> void:
	var t0 := Time.get_ticks_msec()
	var pedido: Variant = JSON.parse_string(linea)
	var resp := {}
	var nombre := ""
	if not pedido is Dictionary:
		resp = {"ok": false, "error": "el pedido no es un objeto JSON"}
	elif str(pedido.get("token", "")) != token:
		resp = {"ok": false, "error": "token incorrecto"}
	else:
		nombre = str(pedido.get("cmd", ""))
		ultimo_pedido_ms = t0
		if not _comandos.has(nombre):
			resp = {"ok": false, "error": "no existe el comando «%s»; probá «ayuda»" % nombre}
		else:
			var args: Dictionary = pedido["args"] if pedido.get("args") is Dictionary else {}
			var marca: int = registro.call("marca") if registro else 0
			var r: Variant = await (_comandos[nombre]["f"] as Callable).call(args)
			if r is Dictionary and r.has("_error"):
				resp = {"ok": false, "error": r["_error"]}
			else:
				resp = {"ok": true, "r": a_json(r)}
			if registro:
				var nuevos: Array = registro.call("desde", marca, ["error", "script", "shader"])
				if not nuevos.is_empty():
					resp["errores"] = a_json(nuevos)
		atendido.emit(nombre, resp["ok"], Time.get_ticks_msec() - t0)
	resp["ms"] = Time.get_ticks_msec() - t0
	if pedido is Dictionary and pedido.has("id"):
		resp["id"] = pedido["id"]
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.put_data((JSON.stringify(resp) + "\n").to_utf8_buffer())


static func error(texto: String) -> Dictionary:
	return {"_error": texto}


## Convierte cualquier Variant en algo que JSON pueda representar.
static func a_json(v: Variant, prof := 0) -> Variant:
	if prof > 14:
		return str(v)
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return v
		TYPE_FLOAT:
			return null if is_nan(v) or is_inf(v) else v
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(v)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [v.x, v.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [v.x, v.y, v.z]
		TYPE_RECT2, TYPE_RECT2I:
			return [v.position.x, v.position.y, v.size.x, v.size.y]
		TYPE_COLOR:
			return "#" + (v as Color).to_html()
		TYPE_DICTIONARY:
			var d := {}
			for k: Variant in v:
				d[str(k)] = a_json(v[k], prof + 1)
			return d
		TYPE_ARRAY:
			var a := []
			for x: Variant in (v as Array).slice(0, 5000):
				a.append(a_json(x, prof + 1))
			return a
		TYPE_OBJECT:
			if not is_instance_valid(v):
				return "<objeto liberado>"
			if v is Node:
				return "<%s %s>" % [v.get_class(), v.get_path() if v.is_inside_tree() else v.name]
			if v is Resource and v.resource_path != "":
				return "<%s %s>" % [v.get_class(), v.resource_path]
			return "<%s#%d>" % [v.get_class(), v.get_instance_id()]
	if typeof(v) >= TYPE_PACKED_BYTE_ARRAY:
		return a_json(Array(v).slice(0, 5000), prof + 1)
	return var_to_str(v)


# ---------------------------------------------------------------------------------------------------------------
# Comandos comunes al editor y a la app


func _registrar_comunes() -> void:
	registrar("ayuda", _ayuda, "lista los comandos")
	registrar("ping", func(_a: Dictionary) -> Dictionary: return {"rol": rol, "pid": OS.get_process_id()},
			"responde si el puente está vivo")
	registrar("errores", _errores, "errores y avisos capturados {desde, todos, limpiar}")
	registrar("eval", _eval, "ejecuta GDScript {codigo}; una sola línea se evalúa como expresión; «raiz» es el nodo base")
	registrar("arbol", _arbol, "árbol de nodos {ruta=/root, profundidad=8, todos=false} con rectángulos en píxeles de ventana")
	registrar("nodo", _nodo_cmd, "lee o cambia un nodo {ruta, prop, valor} o llama un método {ruta, llamar, args}")
	registrar("captura", _captura, "captura de la ventana {ancho, region=[x,y,w,h], formato=png|jpg}; devuelve base64")
	registrar("esperar", _esperar, "espera {frames} o {segundos}")


func _ayuda(_a: Dictionary) -> Dictionary:
	var out := {}
	for k: String in _comandos:
		out[k] = _comandos[k]["ayuda"]
	return out


func _errores(a: Dictionary) -> Dictionary:
	if registro == null:
		return error("no hay registro de errores")
	var tipos: Array = [] if a.get("todos", false) else ["error", "aviso", "script", "shader", "printerr"]
	var items: Array = registro.call("desde", int(a.get("desde", 0)), tipos)
	var siguiente: int = registro.call("marca")
	if a.get("limpiar", false):
		registro.call("limpiar")
	return {"items": items, "siguiente": siguiente}


func _eval(a: Dictionary) -> Variant:
	var codigo := str(a.get("codigo", "")).strip_edges()
	if codigo == "":
		return error("falta «codigo»")
	var problemas: Array = []
	var script: GDScript = null
	if not codigo.contains("\n") and str(a.get("modo", "auto")) != "bloque":
		script = _compilar("return " + codigo, [])
	if script == null:
		script = _compilar(codigo, problemas)
	if script == null:
		return error("no compila: " + "; ".join(problemas))
	var o: Object = script.new()
	o.set("raiz", raiz)
	return await o.call("correr")


func _compilar(cuerpo: String, problemas: Array) -> GDScript:
	var fuente := "extends RefCounted\nvar raiz: Node\nfunc correr() -> Variant:\n"
	for l in cuerpo.split("\n"):
		fuente += "\t" + l + "\n"
	fuente += "\treturn null\n"
	var s := GDScript.new()
	s.source_code = fuente
	if registro:
		registro.call("empezar_desvio")
	var err := s.reload()
	var capt: Array = registro.call("terminar_desvio") if registro else []
	if err != OK:
		for e: Dictionary in capt:
			problemas.append("línea %d: %s" % [int(e.get("linea", 0)) - 3, e.get("texto", "")])
		if problemas.is_empty():
			problemas.append(error_string(err))
		return null
	return s


func _nodo_por_ruta(ruta: String) -> Node:
	var arbol := raiz.get_tree()
	if ruta.begins_with("/"):
		return arbol.root.get_node_or_null(ruta)
	var base: Node = arbol.current_scene if arbol.current_scene else arbol.root
	return base.get_node_or_null(ruta)


func _arbol(a: Dictionary) -> Variant:
	var n := _nodo_por_ruta(str(a.get("ruta", "/root")))
	if n == null:
		return error("no existe el nodo %s" % a.get("ruta"))
	var t := raiz.get_tree().root.get_final_transform()
	return _a_dic(n, int(a.get("profundidad", 8)), bool(a.get("todos", false)), t, [0])


func _a_dic(n: Node, prof: int, todos: bool, t: Transform2D, cuenta: Array) -> Dictionary:
	cuenta[0] += 1
	var d := {"nombre": str(n.name), "clase": n.get_class()}
	var sc: Script = n.get_script()
	if sc and sc.resource_path != "":
		d["script"] = sc.resource_path.get_file()
	if n is Control:
		var r := (n as Control).get_global_rect()
		d["rect"] = a_json(Rect2(t * r.position, r.size * t.get_scale()).abs())
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		d["oculto"] = true
	var texto: Variant = n.get("text")
	if texto is String and texto != "":
		d["texto"] = (texto as String).left(80)
	var hijos := []
	for c in n.get_children():
		if not todos and c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		hijos.append(c)
	if not hijos.is_empty():
		if prof <= 0 or cuenta[0] > 2500:
			d["hijos_omitidos"] = hijos.size()
		else:
			d["hijos"] = hijos.map(func(c: Node) -> Dictionary: return _a_dic(c, prof - 1, todos, t, cuenta))
	return d


func _nodo_cmd(a: Dictionary) -> Variant:
	var n := _nodo_por_ruta(str(a.get("ruta", "")))
	if n == null:
		return error("no existe el nodo %s" % a.get("ruta"))
	if a.has("llamar"):
		return await n.callv(str(a["llamar"]), a.get("args", []))
	if a.has("prop"):
		if a.has("valor"):
			var v: Variant = a["valor"]
			if v is String and a.get("var", false):
				v = str_to_var(v)
			n.set(str(a["prop"]), v)
		return n.get(str(a["prop"]))
	var props := {}
	for p in n.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[p["name"]] = n.get(p["name"])
	return {"clase": n.get_class(), "propiedades": props}


func _captura(a: Dictionary) -> Variant:
	# En modo de bajo consumo Godot solo redibuja si algo cambió: se apaga un momento para asegurar un cuadro nuevo.
	var bajo := OS.low_processor_usage_mode
	OS.low_processor_usage_mode = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	OS.low_processor_usage_mode = bajo
	var tex := raiz.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return error("no hay imagen: ¿corre con --headless?")
	if a.get("region") is Array and (a["region"] as Array).size() == 4:
		var g: Array = a["region"]
		img = img.get_region(Rect2i(int(g[0]), int(g[1]), int(g[2]), int(g[3])))
	var ancho := int(a.get("ancho", 0))
	if ancho > 0 and ancho < img.get_width():
		img.resize(ancho, int(round(img.get_height() * float(ancho) / img.get_width())), Image.INTERPOLATE_LANCZOS)
	var jpg := str(a.get("formato", "png")) == "jpg"
	var buf := img.save_jpg_to_buffer(float(a.get("calidad", 0.85))) if jpg else img.save_png_to_buffer()
	return {"ancho": img.get_width(), "alto": img.get_height(), "formato": "jpg" if jpg else "png",
			"base64": Marshalls.raw_to_base64(buf)}


func _esperar(a: Dictionary) -> Dictionary:
	if a.has("segundos"):
		await raiz.get_tree().create_timer(float(a["segundos"])).timeout
	else:
		for i in int(a.get("frames", 1)):
			await raiz.get_tree().process_frame
	return {}
