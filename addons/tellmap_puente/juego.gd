extends Node
## Puente de la app (autoload «Puente»): deja que tools/godot/tmap.py, un agente o una prueba manejen TellMAP mientras
## corre: año, modo, cámara, selección, pestañas, ajustes, clics y teclas, capturas, recarga de shaders y de la
## enciclopedia, y GDScript. Se enciende solo en compilaciones de depuración, cuando la app se abre con «-- --puente»
## o desde el editor; en una versión exportada no hace nada. Ver servidor.gd y tools/godot/README.md.

const Servidor := preload("res://addons/tellmap_puente/servidor.gd")
const Registro := preload("res://addons/tellmap_puente/registro.gd")

var servidor: Servidor
var registro: Registro
var _autocierre := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := _args()
	set_process(false)
	if not OS.is_debug_build():
		return
	registro = Registro.new()
	OS.add_logger(registro)
	if OS.has_feature("editor"):
		registro.abrir_archivo("juego")
	if not (args.has("puente") or EngineDebugger.is_active()):
		return
	set_process(true)
	servidor = Servidor.new()
	servidor.registro = registro
	_registrar()
	var extra := {"lanzada_con_puente": args.has("puente")}
	if args.has("puente-etiqueta"):
		extra["etiqueta"] = args["puente-etiqueta"]
	if not servidor.iniciar("juego", self, extra):
		set_process(false)
		return
	_autocierre = float(args.get("puente-autocierre", "0"))
	print("Puente: escuchando en 127.0.0.1:%d" % servidor.puerto)


func _process(_d: float) -> void:
	servidor.sondear()
	if _autocierre > 0.0 and Time.get_ticks_msec() - servidor.ultimo_pedido_ms > _autocierre * 1000.0:
		print("Puente: %d s sin pedidos, cierro la app." % _autocierre)
		get_tree().quit()


func _exit_tree() -> void:
	if servidor:
		servidor.detener()
	if registro:
		_informar_huerfanos()
		OS.remove_logger(registro)
		registro.cerrar_archivo()
	servidor = null
	registro = null


## Al cerrar, anota los nodos que quedaron fuera del árbol sin liberarse: son las «fugas» que Godot reporta al
## salir (RIDs de CanvasItem, RichTextLabel, ObjectDB…), pero acá con su clase, su script y su nombre.
func _informar_huerfanos() -> void:
	# Al cerrar, Godot ya está desarmando la escena: lo que sigue colgado de un padre se libera solo. Las fugas son
	# los nodos sin padre (creados y nunca agregados, o sacados del árbol sin liberarlos).
	var raices: Array[Node] = []
	for id in Node.get_orphan_node_ids():
		var n := instance_from_id(id) as Node
		if n and n.get_parent() == null and n != get_tree().root:
			raices.append(n)
	if raices.is_empty():
		registro.escribir("Al cerrar: ningún nodo suelto sin liberar.")
		return
	var grupos := {}
	for n in raices:
		var sc: Script = n.get_script()
		var clave := "%s%s" % [n.get_class(), " (%s)" % sc.resource_path.get_file() if sc else ""]
		if not grupos.has(clave):
			grupos[clave] = {"n": 0, "ejemplo": "", "hijos": 0}
		grupos[clave]["n"] += 1
		grupos[clave]["hijos"] += n.find_children("*", "", true, false).size()
		if grupos[clave]["ejemplo"] == "":
			var texto: Variant = n.get("text")
			grupos[clave]["ejemplo"] = "%s%s" % [n.name, " «%s»" % str(texto).left(40) if texto is String and texto != "" else ""]
	var lineas := PackedStringArray(["Al cerrar: %d nodos sueltos sin liberar (Godot los reporta como fugas):" % raices.size()])
	for k: String in grupos:
		var g: Dictionary = grupos[k]
		lineas.append("    %d × %s, con %d nodos adentro; ej. %s" % [g["n"], k, g["hijos"], g["ejemplo"]])
	registro.escribir("\n".join(lineas))


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var p := a.substr(2).split("=", true, 1)
			out[p[0]] = p[1] if p.size() > 1 else "1"
	return out


func _registrar() -> void:
	var s := servidor
	s.registrar("listo", _listo, "espera a que termine la carga y devuelve el estado")
	s.registrar("estado", _estado, "año, modo, cámara, selección, ventana, ajustes y fps")
	s.registrar("anio", _anio, "cambia el año {anio} (negativo = a. C.)")
	s.registrar("modo", _modo, "cambia el modo del mapa {modo}: " + ", ".join(Estado.MODOS.keys()))
	s.registrar("ir", _ir, "mueve la cámara {lon, lat, zoom, instantaneo=true}")
	s.registrar("seleccionar", _seleccionar, "selecciona el lugar en {lon, lat} y abre el panel; {limpiar:true} lo cierra")
	s.registrar("pestana", _pestana, "abre una pestaña del panel {n} (0 Resumen … 4 Datos)")
	s.registrar("recorrido", _recorrido, "hace clic en cada botón visible en varios escenarios; devuelve cuántos tocó y los que no hicieron nada {solo: escenario} (los errores salen con su traza)")
	s.registrar("ficha", _ficha, "abre una ficha {tipo: fuente|persona|hecho|lugar|region|familia|entidad, id} (familia: «capa:id», como religiones:islam-sunni; entidad: su índice)")
	s.registrar("ajuste", _ajuste, "cambia un ajuste {clave, valor} (tema, calidad, escala_ui…); se guarda como desde la interfaz")
	s.registrar("shader", _shader, "vuelve a leer del disco los shaders en uso (sin reiniciar)")
	s.registrar("recargar", _recargar, "vuelve a leer los paquetes de la enciclopedia y refresca el panel")
	s.registrar("clic", _clic, "clic en {x, y} (píxeles de ventana) o {lon, lat}; {boton=1|2|3, doble}")
	s.registrar("mover", _mover, "mueve el mouse a {x, y} o {lon, lat} (hover)")
	s.registrar("rueda", _rueda, "rueda del mouse en {x, y}: {pasos} positivos acercan")
	s.registrar("arrastrar", _arrastrar, "arrastra de {desde:[x,y]} a {hasta:[x,y]} {boton=1}")
	s.registrar("tecla", _tecla, "aprieta una tecla {tecla: Space|Right|PageUp|A…, shift, ctrl, alt}")
	s.registrar("escribir", _escribir, "escribe {texto} en el control que tiene el foco")
	s.registrar("pulsar", _pulsar, "aprieta el botón visible cuyo texto o ayuda contiene {texto}")
	s.registrar("salir", _salir, "cierra la app")


func _principal() -> Node:
	return get_tree().current_scene


func _listo(_a := {}) -> Dictionary:
	if not Estado.cargado:
		await Estado.carga_terminada
	await get_tree().process_frame
	return _estado()


func _estado(_a := {}) -> Dictionary:
	var d := {
		"cargado": Estado.cargado, "anio": Estado.anio, "anio_texto": Fechas.texto(Estado.anio), "modo": Estado.modo,
		"ventana": servidor.a_json(get_viewport().get_visible_rect().size * get_tree().root.get_final_transform().get_scale()),
		"fps": Engine.get_frames_per_second(), "ajustes": Estado.ajustes,
		"memoria_video_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
	}
	var p := _principal()
	if Estado.cargado and p and p.get("vista"):
		var camara: Camera2D = p.vista.camara
		var ll := Proyeccion.a_lonlat(camara.position)
		d["camara"] = {"lon": snappedf(ll.x, 0.01), "lat": snappedf(ll.y, 0.01), "zoom": snappedf(camara.zoom.x, 0.001)}
	var u := Estado.unidad_seleccionada
	if u > 0:
		var e := DatosMapa.dueno(u)
		d["seleccion"] = {"unidad": u, "entidad": e, "nombre": DatosMapa.nombre_entidad(e) if e > 0 else ""}
	return d


func _anio(a: Dictionary) -> Variant:
	if not a.has("anio"):
		return Servidor.error("falta «anio»")
	await _listo()
	Estado.fijar_anio(int(a["anio"]))
	await get_tree().process_frame
	return {"anio": Estado.anio, "texto": Fechas.texto(Estado.anio)}


func _modo(a: Dictionary) -> Variant:
	var m := str(a.get("modo", ""))
	if not Estado.MODOS.has(m):
		return Servidor.error("modo desconocido; hay: " + ", ".join(Estado.MODOS.keys()))
	await _listo()
	Estado.fijar_modo(m)
	await get_tree().process_frame
	return {"modo": Estado.modo}


func _px(a: Dictionary) -> Vector2:
	return Proyeccion.a_px(float(a.get("lon", 0.0)), float(a.get("lat", 0.0)))


## Punto de la pantalla (píxeles de ventana) a partir de {x, y} o de {lon, lat}.
func _pantalla(a: Dictionary) -> Vector2:
	if a.has("lon"):
		var v: Node2D = _principal().vista
		return get_tree().root.get_final_transform() * v.mundo_a_pantalla(_px(a))
	return Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))


func _ir(a: Dictionary) -> Variant:
	await _listo()
	var v: Node2D = _principal().vista
	var zoom := float(a.get("zoom", 0.0))
	v.volar_a(_px(a), zoom)
	var vuelo: Tween = v.get("_vuelo")
	if a.get("instantaneo", true) and vuelo:
		vuelo.custom_step(10.0)
	elif vuelo and vuelo.is_running():
		await vuelo.finished
	await get_tree().process_frame
	return _estado().get("camara", {})


func _seleccionar(a: Dictionary) -> Variant:
	await _listo()
	if a.get("limpiar", false):
		Estado.seleccionar_lugar(0, Vector2.ZERO)
		return {}
	var px := _px(a)
	var u := DatosMapa.unidad_en(px)
	if u <= 0:
		return Servidor.error("no hay tierra con dueño conocido en ese punto")
	Estado.seleccionar_lugar(u, px)
	await get_tree().process_frame
	return _estado().get("seleccion", {})


func _pestana(a: Dictionary) -> Variant:
	await _listo()
	_principal().interfaz.panel._ir_a_pestana(int(a.get("n", 0)))
	return {}


func _recorrido(a := {}) -> Variant:
	await _listo()
	return await Recorrido.new(_principal().interfaz).correr(str(a.get("solo", "")))


func _ficha(a: Dictionary) -> Variant:
	await _listo()
	if Enciclopedia.elemento(str(a.get("tipo", "")), str(a.get("id", ""))).is_empty():
		return Servidor.error("no existe la ficha %s:%s" % [a.get("tipo"), a.get("id")])
	Estado.pedir_ficha(str(a["tipo"]), str(a["id"]))
	return {}


func _ajuste(a: Dictionary) -> Variant:
	var clave := str(a.get("clave", ""))
	if not Estado.ajustes.has(clave):
		return Servidor.error("ajuste desconocido; hay: " + ", ".join(Estado.ajustes.keys()))
	Estado.fijar_ajuste(clave, a.get("valor"))
	await get_tree().process_frame
	return {clave: Estado.ajustes[clave]}


func _shader(_a: Dictionary) -> Dictionary:
	var hechos := {}
	for n in get_tree().root.find_children("*", "CanvasItem", true, false):
		var m: Material = (n as CanvasItem).material
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			var sh: Shader = (m as ShaderMaterial).shader
			if sh.resource_path != "" and not hechos.has(sh.resource_path):
				sh.code = FileAccess.get_file_as_string(sh.resource_path)
				hechos[sh.resource_path] = true
	# Los errores de compilación llegan cuando se dibuja: el servidor los agrega a la respuesta.
	await servidor._captura({"ancho": 8})
	return {"recargados": hechos.keys()}


func _recargar(_a: Dictionary) -> Dictionary:
	await _listo()
	Enciclopedia.recargar()
	return {"fuentes": Enciclopedia.fuentes.size(), "personas": Enciclopedia.personas.size(),
			"hechos": Enciclopedia.hechos.size(), "lugares": Enciclopedia.lugares.size(),
			"regiones": Enciclopedia.regiones.size(), "advertencias": Enciclopedia.advertencias}


# ---------------------------------------------------------------------------------------------------------------
# Entrada simulada (en píxeles de ventana, los mismos de las capturas y de «arbol»)


func _mouse(pos: Vector2, boton: int, presionado: bool, doble := false, factor := 1.0) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = boton as MouseButton
	ev.pressed = presionado
	ev.double_click = doble
	ev.factor = factor
	if presionado:
		ev.button_mask = 1 << (boton - 1)
	Input.parse_input_event(ev)


func _movimiento(pos: Vector2, mascara := 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = mascara
	Input.parse_input_event(ev)


func _clic(a: Dictionary) -> Variant:
	await _listo()
	var pos := _pantalla(a)
	var ventana := get_viewport().get_visible_rect().size * get_tree().root.get_final_transform().get_scale()
	if not Rect2(Vector2.ZERO, ventana).has_point(pos):
		return Servidor.error("el punto (%d, %d) cae fuera de la ventana %dx%d; mové la cámara con «ir»"
				% [pos.x, pos.y, ventana.x, ventana.y])
	var boton := int(a.get("boton", 1))
	_movimiento(pos)
	await get_tree().process_frame
	_mouse(pos, boton, true, a.get("doble", false))
	await get_tree().process_frame
	_mouse(pos, boton, false)
	await get_tree().process_frame
	return {"x": pos.x, "y": pos.y}


func _mover(a: Dictionary) -> Variant:
	await _listo()
	var pos := _pantalla(a)
	_movimiento(pos)
	await get_tree().process_frame
	return {"x": pos.x, "y": pos.y}


func _rueda(a: Dictionary) -> Variant:
	await _listo()
	var pos := _pantalla(a)
	var pasos := int(a.get("pasos", 1))
	var boton := MOUSE_BUTTON_WHEEL_UP if pasos > 0 else MOUSE_BUTTON_WHEEL_DOWN
	_movimiento(pos)
	for i in absi(pasos):
		_mouse(pos, boton, true)
		_mouse(pos, boton, false)
		await get_tree().process_frame
	return {}


func _arrastrar(a: Dictionary) -> Variant:
	await _listo()
	var d: Array = a.get("desde", [0, 0])
	var h: Array = a.get("hasta", [0, 0])
	var p0 := Vector2(float(d[0]), float(d[1]))
	var p1 := Vector2(float(h[0]), float(h[1]))
	var boton := int(a.get("boton", 1))
	_movimiento(p0)
	_mouse(p0, boton, true)
	for i in range(1, 11):
		await get_tree().process_frame
		_movimiento(p0.lerp(p1, i / 10.0), 1 << (boton - 1))
	_mouse(p1, boton, false)
	await get_tree().process_frame
	return {}


func _tecla(a: Dictionary) -> Variant:
	var codigo := OS.find_keycode_from_string(str(a.get("tecla", "")))
	if codigo == KEY_NONE:
		return Servidor.error("tecla desconocida «%s» (ejemplos: Space, Right, PageUp, A, Escape)" % a.get("tecla"))
	for presionada in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = codigo
		ev.physical_keycode = codigo
		ev.pressed = presionada
		ev.shift_pressed = a.get("shift", false)
		ev.ctrl_pressed = a.get("ctrl", false)
		ev.alt_pressed = a.get("alt", false)
		Input.parse_input_event(ev)
		await get_tree().process_frame
	return {}


func _escribir(a: Dictionary) -> Dictionary:
	for ch in str(a.get("texto", "")):
		for presionada in [true, false]:
			var ev := InputEventKey.new()
			ev.unicode = ch.unicode_at(0)
			ev.pressed = presionada
			Input.parse_input_event(ev)
		await get_tree().process_frame
	return {}


func _pulsar(a: Dictionary) -> Variant:
	var buscado := str(a.get("texto", "")).to_lower()
	if buscado == "":
		return Servidor.error("falta «texto»")
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		var boton := b as BaseButton
		if not boton.is_visible_in_tree() or boton.disabled:
			continue
		var t := (str(boton.get("text")) + " " + boton.tooltip_text).to_lower()
		if t.contains(buscado):
			var r := boton.get_global_rect()
			var tr := get_tree().root.get_final_transform()
			var c := tr * r.get_center()
			return await _clic({"x": c.x, "y": c.y})
	return Servidor.error("no hay un botón visible con «%s»" % a.get("texto"))


func _salir(_a: Dictionary) -> Dictionary:
	get_tree().create_timer(0.2).timeout.connect(get_tree().quit)
	return {}
