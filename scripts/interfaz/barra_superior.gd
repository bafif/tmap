class_name BarraSuperior
extends PanelContainer
## Barra superior: marca, modos de mapa, buscador, ayuda y ajustes.

signal ajustes_pedidos
signal ayuda_pedida

var _busqueda: LineEdit
var _resultados: PanelContainer
var _lista: VBoxContainer
var _botones_modo := {}


func _ready() -> void:
	theme_type_variation = "Franja"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 56)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	add_child(fila)

	var marca := VBoxContainer.new()
	marca.add_theme_constant_override("separation", -4)
	fila.add_child(marca)
	var nombre := Label.new()
	nombre.text = "TELLMAP"
	nombre.theme_type_variation = "TituloGrande"
	nombre.add_theme_font_size_override("font_size", 24)
	marca.add_child(nombre)
	var lema := Label.new()
	lema.text = "atlas de la historia y sus fuentes"
	lema.theme_type_variation = "Suave"
	lema.add_theme_font_size_override("font_size", 13)
	marca.add_child(lema)

	var sep := VSeparator.new()
	fila.add_child(sep)

	var modos := HBoxContainer.new()
	modos.add_theme_constant_override("separation", 4)
	modos.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(modos)
	var grupo := ButtonGroup.new()
	for id in Estado.MODOS:
		var b := Button.new()
		b.text = Estado.MODOS[id][0]
		b.tooltip_text = Estado.MODOS[id][1]
		b.toggle_mode = true
		b.button_group = grupo
		b.theme_type_variation = "BotonModo"
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = id == Estado.modo
		var modo_id: String = id
		b.pressed.connect(func(): Estado.fijar_modo(modo_id))
		modos.add_child(b)
		_botones_modo[id] = b
	# El modo también cambia desde afuera (la ficha de una religión, la línea de comandos, el puente).
	Estado.modo_cambiado.connect(func(m: String):
		if _botones_modo.has(m):
			(_botones_modo[m] as Button).button_pressed = true)

	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)

	_busqueda = LineEdit.new()
	_busqueda.placeholder_text = "Buscar entidad, lugar, persona, texto…"
	_busqueda.custom_minimum_size = Vector2(330, 0)
	_busqueda.right_icon = IconosUI.textura("buscar", 16, TemaUI.color("texto_suave"))
	_busqueda.clear_button_enabled = true
	_busqueda.text_changed.connect(_buscar)
	_busqueda.text_submitted.connect(func(_t): _elegir_primero())
	fila.add_child(_busqueda)

	var ayuda := IconosUI.boton("ayuda", "Cómo se usa", 22)
	ayuda.pressed.connect(func(): ayuda_pedida.emit())
	fila.add_child(ayuda)
	var ajustes := IconosUI.boton("ajustes", "Ajustes: calidad, vista 2D/3D, tema de la interfaz", 22)
	ajustes.pressed.connect(func(): ajustes_pedidos.emit())
	fila.add_child(ajustes)

	_resultados = PanelContainer.new()
	_resultados.visible = false
	_resultados.top_level = true
	_resultados.custom_minimum_size = Vector2(420, 0)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 2)
	_resultados.add_child(_lista)
	add_child(_resultados)


func _buscar(texto: String) -> void:
	for c in _lista.get_children():
		c.queue_free()
	if texto.strip_edges().length() < 2:
		_resultados.visible = false
		return
	var items: Array = []
	for i in DatosMapa.buscar_entidades(texto, 7):
		var e: Dictionary = DatosMapa.entidades[i]
		items.append({"tipo": "entidad", "id": i, "texto": DatosMapa.nombre_entidad(i), "detalle": "Entidad política · " + Fechas.rango(int(e["a"]), int(e["b"]))})
	for r in Enciclopedia.buscar(texto, 10):
		var detalle: String = r.get("detalle", {"lugar": "Lugar", "persona": "Persona", "fuente": "Fuente", "hecho": "Hecho", "region": "Región"}.get(r["tipo"], ""))
		r["detalle"] = detalle
		items.append(r)
	if items.is_empty():
		var l := Label.new()
		l.theme_type_variation = "Suave"
		l.text = "Sin resultados"
		_lista.add_child(l)
	for it in items:
		var b := Button.new()
		b.theme_type_variation = "BotonPlano"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.text = "%s   ·   %s" % [it["texto"], it["detalle"]]
		b.clip_text = true
		var item: Dictionary = it
		b.pressed.connect(func(): _elegir(item))
		_lista.add_child(b)
	_resultados.global_position = _busqueda.global_position + Vector2(_busqueda.size.x - 420, _busqueda.size.y + 6)
	_resultados.size = Vector2(420, 0)
	_resultados.visible = true


func _elegir_primero() -> void:
	for c in _lista.get_children():
		if c is Button:
			(c as Button).pressed.emit()
			return


func _elegir(item: Dictionary) -> void:
	_resultados.visible = false
	_busqueda.release_focus()
	if item["tipo"] == "entidad":
		var i: int = item["id"]
		var e: Dictionary = DatosMapa.entidades[i]
		if Estado.anio < int(e["a"]) or Estado.anio > int(e["b"]):
			Estado.fijar_anio(int(e["a"]) + mini(30, (int(e["b"]) - int(e["a"])) / 2))
		var centro := DatosMapa.centro_entidad(i)
		if centro.x >= 0:
			Estado.enfocar(centro, 0.0)
			var u := DatosMapa.unidad_en(centro)
			if DatosMapa.dueno(u) != i:
				u = _unidad_de_entidad(i)
			if u > 0:
				Estado.seleccionar_lugar(u, centro)
		Estado.pedir_ficha("entidad", i)
		return
	Estado.pedir_ficha(item["tipo"], item["id"])
	var el := Enciclopedia.elemento(item["tipo"], item["id"])
	if el.has("_px"):
		if el.has("_desde") and (Estado.anio < el["_desde"] or Estado.anio > el.get("_hasta", el["_desde"])):
			Estado.fijar_anio(el["_desde"])
		Estado.enfocar(el["_px"], 2.0)


func _unidad_de_entidad(i: int) -> int:
	var mejor := 0
	var tam := 0
	for u in range(1, DatosMapa.n_unidades + 1):
		if DatosMapa.duenos[u] == i and DatosMapa.unidad_tam[u] > tam:
			tam = DatosMapa.unidad_tam[u]
			mejor = u
	return mejor


func _input(ev: InputEvent) -> void:
	if _resultados.visible and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var p := (ev as InputEventMouseButton).position
		if not _resultados.get_global_rect().has_point(p) and not _busqueda.get_global_rect().has_point(p):
			_resultados.visible = false
