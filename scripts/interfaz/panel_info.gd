class_name PanelInfo
extends PanelContainer
## Panel lateral derecho: la información del lugar seleccionado en el año actual, y las fichas de la enciclopedia.

const ANCHO := 470.0
const PESTANAS := ["Resumen", "Historia", "Fuentes", "Gente y hechos", "Datos"]
const NOMBRES_TIPO := {"fuente": "Fuente", "persona": "Persona", "hecho": "Hecho", "lugar": "Lugar", "region": "Región", "entidad": "Entidad política"}

var _abierto := false
var _tween: Tween
var _franja: ColorRect
var _titulo: Label
var _subtitulo: Label
var _volver: Button
var _barra_pestanas: HBoxContainer
var _contenido: VBoxContainer
var _scroll: ScrollContainer
var _pestana := 0
var _botones_pestana: Array = []
var _unidad := 0
var _px := Vector2.ZERO
var _ficha: Dictionary = {}  # {"tipo", "id"} si se está mostrando una ficha
var _token := 0
var _reconstruir_pendiente := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -ANCHO
	offset_right = 0
	offset_top = 66
	offset_bottom = -136
	mouse_filter = Control.MOUSE_FILTER_STOP
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	add_child(caja)

	_franja = ColorRect.new()
	_franja.custom_minimum_size = Vector2(0, 5)
	caja.add_child(_franja)

	var cab := HBoxContainer.new()
	caja.add_child(cab)
	_volver = IconosUI.boton("volver", "Volver al lugar", 18)
	_volver.pressed.connect(func():
		_ficha = {}
		_reconstruir())
	cab.add_child(_volver)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	cab.add_child(textos)
	_titulo = Label.new()
	_titulo.theme_type_variation = "TituloGrande"
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(_titulo)
	_subtitulo = Label.new()
	_subtitulo.theme_type_variation = "Suave"
	_subtitulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(_subtitulo)
	var cerrar := IconosUI.boton("cerrar", "Cerrar (Esc)", 18)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(func(): Estado.seleccionar_lugar(0, Vector2.ZERO))
	cab.add_child(cerrar)

	_barra_pestanas = HBoxContainer.new()
	_barra_pestanas.add_theme_constant_override("separation", 0)
	caja.add_child(_barra_pestanas)
	var grupo := ButtonGroup.new()
	for i in PESTANAS.size():
		var b := Button.new()
		b.text = PESTANAS[i]
		b.toggle_mode = true
		b.button_group = grupo
		b.theme_type_variation = "Pestana"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = i == 0
		b.pressed.connect(func():
			_pestana = i
			_reconstruir())
		_barra_pestanas.add_child(b)
		_botones_pestana.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(_scroll)
	_contenido = VBoxContainer.new()
	_contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenido.add_theme_constant_override("separation", 10)
	_scroll.add_child(_contenido)

	add_child(Marco.new())
	position.x = get_viewport_rect().size.x + 20
	visible = false

	Estado.lugar_seleccionado.connect(_al_seleccionar)
	Estado.ficha_pedida.connect(_al_pedir_ficha)
	Estado.anio_cambiado.connect(func(_a): _programar())
	Estado.modo_cambiado.connect(func(_m): _programar())


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k and k.pressed and k.keycode == KEY_ESCAPE and _abierto:
		Estado.seleccionar_lugar(0, Vector2.ZERO)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------
# Abrir y cerrar


func _mostrar(abrir: bool) -> void:
	if abrir == _abierto:
		return
	_abierto = abrir
	if _tween:
		_tween.kill()
	var vp := get_viewport_rect().size.x
	visible = true
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if abrir:
		position.x = vp + 20
		_tween.tween_property(self, "position:x", vp - ANCHO - 10, 0.32)
	else:
		_tween.tween_property(self, "position:x", vp + 20, 0.25)
		_tween.finished.connect(func(): visible = _abierto)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _abierto and not (_tween and _tween.is_running()):
		position.x = get_viewport_rect().size.x - ANCHO - 10


func _al_seleccionar(unidad: int, px: Vector2) -> void:
	_unidad = unidad
	_px = px
	_ficha = {}
	if unidad <= 0:
		_mostrar(false)
		return
	_reconstruir()
	_mostrar(true)
	Enciclopedia.registrar_consulta(unidad, Estado.anio)


func _al_pedir_ficha(tipo: String, id: Variant) -> void:
	_ficha = {"tipo": tipo, "id": id}
	_reconstruir()
	_mostrar(true)


func _programar() -> void:
	if not _abierto or _reconstruir_pendiente:
		return
	_reconstruir_pendiente = true
	await get_tree().create_timer(0.18).timeout
	_reconstruir_pendiente = false
	if _abierto:
		_reconstruir()


# ---------------------------------------------------------------------------------------------------------------
# Contenido


func _limpiar() -> void:
	_token += 1
	for c in _contenido.get_children():
		c.queue_free()


func _reconstruir() -> void:
	_limpiar()
	_scroll.scroll_vertical = 0
	if not _ficha.is_empty():
		_volver.visible = _unidad > 0
		_barra_pestanas.visible = false
		_construir_ficha(_ficha["tipo"], _ficha["id"])
		return
	_volver.visible = false
	_barra_pestanas.visible = true
	var ent := DatosMapa.dueno(_unidad)
	var regs := Enciclopedia.regiones_de_unidad(_unidad)
	var lonlat := Proyeccion.a_lonlat(DatosMapa.centro_unidad(_unidad))
	if ent >= 0:
		_titulo.text = DatosMapa.nombre_entidad(ent)
		_franja.color = DatosMapa.color_entidad(ent)
	else:
		_titulo.text = Enciclopedia.regiones[regs[0]]["nombre"] if not regs.is_empty() else "Sin entidad registrada"
		_franja.color = TemaUI.color("borde_suave")
	var sub: Array = [Fechas.texto(Estado.anio)]
	if not regs.is_empty():
		sub.append(Enciclopedia.regiones[regs[0]]["nombre"])
	sub.append(Proyeccion.texto_coordenadas(lonlat))
	_subtitulo.text = " · ".join(sub)
	match _pestana:
		0:
			_pestana_resumen(ent, regs)
		1:
			_pestana_historia(regs)
		2:
			_pestana_fuentes(regs)
		3:
			_pestana_gente(regs)
		4:
			_pestana_datos(ent, regs, lonlat)


func _pestana_resumen(ent: int, regs: Array) -> void:
	if ent >= 0:
		var e: Dictionary = DatosMapa.entidades[ent]
		_seccion("La entidad")
		_parrafo("[b]%s[/b] · %s" % [DatosMapa.nombre_entidad(ent), Fechas.rango(int(e["a"]), int(e["b"]))], true)
		if str(e.get("m", "")) != "":
			_parrafo("Parte de: %s" % e["m"], true)
		_bloque_wikipedia(DatosMapa.titulos_wiki_entidad(ent))
	else:
		_seccion("Sin entidad política registrada")
		_parrafo("Cliopatria no registra una entidad política aquí en %s. Puede tratarse de pueblos sin estado, de territorio poco documentado o de un hueco de los datos." % Fechas.texto(Estado.anio))
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		_seccion("La región: %s" % r["nombre"])
		var era := Enciclopedia.era_en(id, Estado.anio)
		if not era.is_empty():
			_parrafo("[b]%s[/b] (%s). %s" % [era["nombre"], Fechas.rango(int(era["desde"]), int(era["hasta"])), era.get("resumen", "")])
		_parrafo(str(r.get("resumen", "")))
		break
	var escritas := Enciclopedia.fuentes_escritas(regs, Estado.anio)
	var sobre := Enciclopedia.fuentes_sobre(regs, Estado.anio)
	if escritas.size() + sobre.size() > 0:
		var b := _boton_texto("Ver %d fuentes para este lugar y época" % (escritas.size() + sobre.size()), "libro")
		b.pressed.connect(func(): _ir_a_pestana(2))
		_contenido.add_child(b)


func _pestana_historia(regs: Array) -> void:
	_seccion("Quién gobernó este lugar")
	var tramos := DatosMapa.historia_de_unidad(_unidad)
	if tramos.is_empty():
		_parrafo("Cliopatria no registra entidades políticas para este punto.")
	for t in tramos:
		var actual: bool = t["desde"] <= Estado.anio and Estado.anio <= t["hasta"]
		var fila := _fila_color(DatosMapa.color_entidad(t["entidad"]), DatosMapa.nombre_entidad(t["entidad"]), Fechas.rango(t["desde"], t["hasta"]), actual)
		var desde: int = t["desde"]
		fila.pressed.connect(func(): Estado.fijar_anio(desde))
		_contenido.add_child(fila)
	for id in regs:
		var eras: Array = Enciclopedia.regiones[id].get("eras", [])
		if eras.is_empty():
			continue
		_seccion("Eras de %s" % Enciclopedia.regiones[id]["nombre"])
		for e in eras:
			var actual: bool = int(e["desde"]) <= Estado.anio and Estado.anio <= int(e["hasta"])
			var fila := _fila_color(TemaUI.color("acento") if actual else TemaUI.color("borde_suave"), e["nombre"], Fechas.rango(int(e["desde"]), int(e["hasta"])), actual)
			var desde := int(e["desde"])
			fila.pressed.connect(func(): Estado.fijar_anio(desde))
			fila.tooltip_text = str(e.get("resumen", ""))
			_contenido.add_child(fila)


func _pestana_fuentes(regs: Array) -> void:
	var escritas := Enciclopedia.fuentes_escritas(regs, Estado.anio)
	var sobre := Enciclopedia.fuentes_sobre(regs, Estado.anio)
	_seccion("Escritas aquí, en esta época")
	_nota("Textos producidos en la región entre %s y %s." % [Fechas.texto(Fechas.sumar(Estado.anio, -150)), Fechas.texto(Fechas.sumar(Estado.anio, 150))])
	if escritas.is_empty():
		_parrafo("[i]Todavía no hay fuentes cargadas para este lugar y momento.[/i]")
	for f in escritas:
		_contenido.add_child(_tarjeta_fuente(f))
	_seccion("Sobre este lugar y esta época")
	_nota("Textos de cualquier época que estudian o narran este lugar en %s." % Fechas.texto(Estado.anio))
	if sobre.is_empty():
		_parrafo("[i]Todavía no hay estudios cargados para este lugar y momento.[/i]")
	for f in sobre:
		if not escritas.has(f):
			_contenido.add_child(_tarjeta_fuente(f))
	if regs.is_empty():
		_nota("Este punto no está dentro de ninguna región de la enciclopedia todavía. La enciclopedia se completa por etapas: ver docs/es/enciclopedia.md.")


func _pestana_gente(regs: Array) -> void:
	_seccion("Personas vivas en %s" % Fechas.texto(Estado.anio))
	var gente := Enciclopedia.personas_vivas(regs, Estado.anio)
	if gente.is_empty():
		_parrafo("[i]No hay personas cargadas para este lugar y año.[/i]")
	for p in gente:
		var fila := _fila_color(TemaUI.color("persona"), p["nombre"], _vida(p), false)
		var id: String = p["id"]
		fila.pressed.connect(func(): Estado.pedir_ficha("persona", id))
		_contenido.add_child(fila)
	_seccion("Hechos cercanos (±100 años)")
	var hechos := Enciclopedia.hechos_cerca(regs, Estado.anio)
	if hechos.is_empty():
		_parrafo("[i]No hay hechos cargados cerca de este año.[/i]")
	for h in hechos:
		var fila := _fila_color(TemaUI.color("hecho"), h["titulo"], Fechas.rango(h["_desde"], h["_hasta"]), h["_desde"] <= Estado.anio and Estado.anio <= h["_hasta"])
		var id: String = h["id"]
		fila.pressed.connect(func(): Estado.pedir_ficha("hecho", id))
		_contenido.add_child(fila)


func _pestana_datos(ent: int, regs: Array, lonlat: Vector2) -> void:
	_seccion("Este lugar")
	var km2 := DatosMapa.area_km2(_unidad)
	_parrafo("Coordenadas: %s\nSuperficie de la unidad del mapa: ~%s km²" % [Proyeccion.texto_coordenadas(lonlat), _numero(km2)], true)
	if ent >= 0:
		var e: Dictionary = DatosMapa.entidades[ent]
		var links: Array = []
		if str(e.get("d", "")) != "":
			links.append("[url=https://www.wikidata.org/wiki/%s]Wikidata[/url]" % e["d"])
		if str(e.get("s", "")) != "":
			links.append("[url=https://seshat-db.com/core/polity/%s]Seshat[/url]" % e["s"])
		_parrafo("Entidad: [b]%s[/b], %s. %s" % [DatosMapa.nombre_entidad(ent), Fechas.rango(int(e["a"]), int(e["b"])), " · ".join(links)], true)
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		var pob := Enciclopedia.poblacion_en(id, Estado.anio)
		var capas := {"religiones": "Religión", "culturas": "Cultura", "idiomas": "Idioma"}
		var testimonios := Enciclopedia.testimonios_poblacion(id)
		var tiene_algo := not pob.is_empty() or not testimonios.is_empty()
		for c in capas:
			if not Enciclopedia.capa_en(id, c, Estado.anio).is_empty():
				tiene_algo = true
		if not tiene_algo:
			continue
		_seccion(r["nombre"])
		if not pob.is_empty():
			var aprox := "" if pob["exacta"] else "interpolada entre estimaciones, "
			_parrafo("[b]Población estimada:[/b] ~%s habitantes [color=#%s](%sfuente: %s)[/color]" % [_numero(pob["poblacion"]), TemaUI.color("texto_suave").to_html(false), aprox, pob["fuente"]])
			var grafico := GraficoSerie.new()
			grafico.serie = Enciclopedia.estimaciones(id)
			grafico.anio = Estado.anio
			if grafico.serie.size() >= 2:
				_contenido.add_child(grafico)
			var notas: Array = []
			for e in grafico.serie:
				if e.get("nota"):
					notas.append("%s: %s" % [Fechas.texto(int(e["anio"])), e["nota"]])
			if not notas.is_empty():
				_nota("\n".join(notas))
		for t in testimonios:
			_parrafo("[b]Testimonio antiguo:[/b] %s dice ~%s habitantes hacia %s. [color=#%s]%s[/color]" % [
				t.get("fuente", ""), _numero(float(t["poblacion"])), Fechas.texto(int(t["anio"])),
				TemaUI.color("texto_suave").to_html(false), t.get("nota", "")], true)
		for c in capas:
			var vigentes := Enciclopedia.capa_en(id, c, Estado.anio)
			if vigentes.is_empty():
				continue
			var partes: Array = []
			for v in vigentes:
				partes.append("%s [color=#%s](%s)[/color]" % [v["nombre"], TemaUI.color("texto_suave").to_html(false), v.get("peso", "")])
			_parrafo("[b]%s:[/b] %s" % [capas[c], ", ".join(partes)], true)
	_nota("Las cifras antiguas son estimaciones académicas con mucha incertidumbre; cada una cita su fuente.")


# ---------------------------------------------------------------------------------------------------------------
# Fichas


func _construir_ficha(tipo: String, id: Variant) -> void:
	var el := Enciclopedia.elemento(tipo, str(id))
	if el.is_empty():
		_titulo.text = "No encontrado"
		_subtitulo.text = "%s «%s»" % [tipo, id]
		return
	_franja.color = TemaUI.color({"fuente": "primaria", "persona": "persona", "hecho": "hecho"}.get(tipo, "acento"))
	match tipo:
		"fuente":
			_ficha_fuente(el)
		"persona":
			_ficha_persona(el)
		"hecho":
			_ficha_hecho(el)
		"lugar":
			_ficha_lugar(el)
		"region":
			_ficha_region(el)


func _ficha_fuente(f: Dictionary) -> void:
	var tipo := "Fuente primaria" if f.get("tipo", "") == "primaria" else "Fuente secundaria"
	if f.get("tipo", "") != "primaria":
		_franja.color = TemaUI.color("secundaria")
	_titulo.text = f.get("titulo", "")
	_subtitulo.text = "%s · %s" % [tipo, _mayus(str(f.get("genero", "")))]
	var e: Dictionary = f.get("escrita", {})
	var lineas: Array = []
	if f.get("autor"):
		lineas.append("[b]Autor:[/b] %s" % _enlace_persona(f.get("autor_id"), str(f["autor"])))
	if f.get("titulo_original"):
		lineas.append("[b]Título original:[/b] [i]%s[/i]" % f["titulo_original"])
	var cuando := Fechas.rango(f["_desde"], f["_hasta"])
	lineas.append("[b]Escrita:[/b] %s%s, %s" % ["c. " if e.get("aprox", false) else "", cuando, e.get("lugar", "lugar desconocido")])
	var trata: Dictionary = f.get("trata", {})
	if not trata.is_empty():
		var nombres: Array = []
		for r in trata.get("regiones", []):
			nombres.append(Enciclopedia.regiones.get(r, {}).get("nombre", r))
		lineas.append("[b]Trata sobre:[/b] %s, %s" % [", ".join(nombres), Fechas.rango(int(trata.get("desde", 0)), int(trata.get("hasta", 0)))])
	if f.get("idioma_original"):
		lineas.append("[b]Idioma:[/b] %s" % f["idioma_original"])
	if f.get("soporte"):
		lineas.append("[b]Soporte:[/b] %s" % f["soporte"])
	lineas.append("[b]Confianza en la datación:[/b] %s" % f.get("confianza", "—"))
	_parrafo("\n".join(lineas), true)
	if f.get("resumen"):
		_seccion("De qué se trata")
		_parrafo(f["resumen"])
	if f.get("por_que_importa"):
		_seccion("Por qué leerla")
		_parrafo(f["por_que_importa"])
	var leer: Array = f.get("leer", [])
	if not leer.is_empty():
		_seccion("Leer")
		for l in leer:
			var b := _boton_texto("%s (%s)" % [l.get("titulo", "Texto"), str(l.get("idioma", "")).to_upper()], "enlace")
			var url: String = l["url"]
			b.tooltip_text = url
			b.pressed.connect(func(): OS.shell_open(url))
			_contenido.add_child(b)
	var ir := _boton_texto("Ver dónde y cuándo se escribió", "ir")
	ir.pressed.connect(func():
		Estado.fijar_anio(f["_desde"])
		if f.has("_px"):
			Estado.enfocar(f["_px"], 2.5))
	_contenido.add_child(ir)
	_bloque_wikipedia(f.get("wikipedia", {}))


func _ficha_persona(p: Dictionary) -> void:
	_titulo.text = p.get("nombre", "")
	_subtitulo.text = "%s · %s" % [_mayus(", ".join(p.get("roles", []))), _vida(p)]
	var lineas: Array = []
	var n: Dictionary = p.get("nacimiento", {}) if p.get("nacimiento") is Dictionary else {}
	var m: Dictionary = p.get("muerte", {}) if p.get("muerte") is Dictionary else {}
	if not n.is_empty():
		lineas.append("[b]Nació:[/b] %s%s, %s" % ["c. " if n.get("aprox", false) else "", Fechas.texto(int(n.get("anio", 0))), n.get("lugar", "?")])
	if not m.is_empty() and m.get("anio") != null:
		lineas.append("[b]Murió:[/b] %s%s, %s" % ["c. " if m.get("aprox", false) else "", Fechas.texto(int(m.get("anio", 0))), m.get("lugar", "?")])
	_parrafo("\n".join(lineas), true)
	_parrafo(str(p.get("resumen", "")))
	var obras: Array = p.get("obras", [])
	if not obras.is_empty():
		_seccion("Obras")
		for id in obras:
			var f: Dictionary = Enciclopedia.fuentes.get(id, {})
			if not f.is_empty():
				_contenido.add_child(_tarjeta_fuente(f))
	var ir := _boton_texto("Ver en el mapa", "ir")
	ir.pressed.connect(func():
		Estado.fijar_anio(clampi(int(p["_desde"]) + 30, Estado.ANIO_MIN, Estado.ANIO_MAX))
		if p.has("_px"):
			Estado.enfocar(p["_px"], 2.5))
	_contenido.add_child(ir)
	_bloque_wikipedia(p.get("wikipedia", {}))


func _ficha_hecho(h: Dictionary) -> void:
	_titulo.text = h.get("titulo", "")
	_subtitulo.text = "%s · %s%s · %s" % [_mayus(str(h.get("tipo", "")).replace("-", " ")), "c. " if h.get("aprox", false) else "", Fechas.rango(h["_desde"], h["_hasta"]), h.get("lugar", "")]
	_parrafo(str(h.get("resumen", "")))
	var fs: Array = h.get("fuentes", [])
	if not fs.is_empty():
		_seccion("Fuentes que lo documentan")
		for id in fs:
			var f: Dictionary = Enciclopedia.fuentes.get(id, {})
			if not f.is_empty():
				_contenido.add_child(_tarjeta_fuente(f))
	var ir := _boton_texto("Ir a ese momento y lugar", "ir")
	ir.pressed.connect(func():
		Estado.fijar_anio(h["_desde"])
		if h.has("_px"):
			Estado.enfocar(h["_px"], 2.2))
	_contenido.add_child(ir)
	_bloque_wikipedia(h.get("wikipedia", {}))


func _ficha_lugar(l: Dictionary) -> void:
	_titulo.text = l.get("nombre", "")
	var hasta := "hoy" if l.get("abandono") == null else Fechas.texto(int(l["abandono"]))
	_subtitulo.text = "%s · %s%s – %s" % [_mayus(str(l.get("tipo", "")).replace("-", " ")), "c. " if l.get("aprox", false) else "", Fechas.texto(l["_desde"]), hasta]
	_parrafo(str(l.get("resumen", "")))
	var ir := _boton_texto("Ver en el mapa", "ir")
	ir.pressed.connect(func():
		var u := DatosMapa.unidad_en(l["_px"])
		Estado.enfocar(l["_px"], 2.5)
		if u > 0:
			Estado.seleccionar_lugar(u, l["_px"]))
	_contenido.add_child(ir)
	_bloque_wikipedia(l.get("wikipedia", {}))


func _ficha_region(r: Dictionary) -> void:
	_titulo.text = r.get("nombre", "")
	_subtitulo.text = "Región de estudio"
	_parrafo(str(r.get("resumen", "")))
	var ir := _boton_texto("Ver en el mapa", "ir")
	ir.pressed.connect(func():
		var caja: Rect2 = r["_caja"]
		Estado.enfocar(caja.get_center(), 0.0)
		var u := DatosMapa.unidad_en(caja.get_center())
		if u > 0:
			Estado.seleccionar_lugar(u, caja.get_center()))
	_contenido.add_child(ir)


# ---------------------------------------------------------------------------------------------------------------
# Piezas


func _seccion(texto: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "Seccion"
	l.text = texto.to_upper()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(l)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	_contenido.add_child(sep)


func _parrafo(bbcode: String, compacto := false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = true
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = bbcode
	if compacto:
		r.add_theme_constant_override("line_separation", 2)
	r.meta_clicked.connect(_al_click_meta)
	_contenido.add_child(r)
	return r


func _nota(texto: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "Suave"
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(l)


func _al_click_meta(meta: Variant) -> void:
	var m := str(meta)
	if m.begins_with("persona:"):
		Estado.pedir_ficha("persona", m.substr(8))
	elif m.begins_with("fuente:"):
		Estado.pedir_ficha("fuente", m.substr(7))
	else:
		OS.shell_open(m)


func _enlace_persona(id: Variant, nombre: String) -> String:
	if id != null and Enciclopedia.personas.has(str(id)):
		return "[url=persona:%s]%s[/url]" % [id, nombre]
	return nombre


func _boton_texto(texto: String, icono: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.icon = IconosUI.textura(icono, 16, TemaUI.color("acento"))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	return b


func _fila_color(color: Color, texto: String, detalle: String, resaltada: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "BotonPlano"
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s   ·   %s" % [texto, detalle]
	b.icon = _muestra_color(color)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if resaltada:
		b.add_theme_color_override("font_color", TemaUI.color("titulo"))
		b.add_theme_stylebox_override("normal", TemaUI.caja(TemaUI.color("fondo2"), TemaUI.color("acento"), 1, 3, 4.0))
	return b


func _muestra_color(c: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.05))
	img.fill_rect(Rect2i(1, 1, 12, 12), c)
	return ImageTexture.create_from_image(img)


func _tarjeta_fuente(f: Dictionary) -> Control:
	var tarjeta := PanelContainer.new()
	tarjeta.theme_type_variation = "Tarjeta"
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)
	var primaria: bool = f.get("tipo", "") == "primaria"
	var color := TemaUI.color("primaria" if primaria else "secundaria")
	var titulo := RichTextLabel.new()
	titulo.bbcode_enabled = true
	titulo.fit_content = true
	titulo.scroll_active = false
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.text = "[i][b]%s[/b][/i]" % f.get("titulo", "")
	caja.add_child(titulo)
	var meta := Label.new()
	meta.theme_type_variation = "Suave"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var partes: Array = ["Primaria" if primaria else "Secundaria"]
	if f.get("autor"):
		partes.append(str(f["autor"]))
	partes.append(("c. " if f.get("escrita", {}).get("aprox", false) else "") + Fechas.rango(f["_desde"], f["_hasta"]))
	if f.get("escrita", {}).get("lugar"):
		partes.append(str(f["escrita"]["lugar"]))
	meta.text = " · ".join(partes)
	meta.add_theme_color_override("font_color", color)
	caja.add_child(meta)
	if f.get("resumen"):
		var r := Label.new()
		r.text = f["resumen"]
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.max_lines_visible = 3
		r.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_theme_font_size_override("font_size", 16)
		caja.add_child(r)
	var botones := HBoxContainer.new()
	caja.add_child(botones)
	var ficha := Button.new()
	ficha.text = "Ficha"
	ficha.focus_mode = Control.FOCUS_NONE
	var id: String = f["id"]
	ficha.pressed.connect(func(): Estado.pedir_ficha("fuente", id))
	botones.add_child(ficha)
	var leer: Array = f.get("leer", [])
	if not leer.is_empty():
		var b := Button.new()
		b.text = "Leer"
		b.icon = IconosUI.textura("enlace", 14, TemaUI.color("acento"))
		b.focus_mode = Control.FOCUS_NONE
		var url: String = leer[0]["url"]
		b.tooltip_text = url
		b.pressed.connect(func(): OS.shell_open(url))
		botones.add_child(b)
	if f.has("_px"):
		var ir := IconosUI.boton("ir", "Ver dónde y cuándo se escribió", 16)
		ir.pressed.connect(func():
			Estado.fijar_anio(f["_desde"])
			Estado.enfocar(f["_px"], 2.5))
		botones.add_child(ir)
	return tarjeta


## Resumen de Wikipedia que se carga en segundo plano (con miniatura si la hay).
func _bloque_wikipedia(titulos: Dictionary) -> void:
	if titulos.is_empty():
		return
	var token := _token
	_seccion("Wikipedia")
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_contenido.add_child(caja)
	var cargando := Label.new()
	cargando.theme_type_variation = "Suave"
	cargando.text = "Buscando el artículo…"
	caja.add_child(cargando)
	var r := await Wiki.resumen(titulos)
	if token != _token or not is_instance_valid(caja):
		return
	cargando.queue_free()
	if r.is_empty():
		var l := Label.new()
		l.theme_type_variation = "Suave"
		l.text = "No se pudo traer el artículo (¿sin conexión?)."
		caja.add_child(l)
		return
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.selection_enabled = true
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.text = "%s\n[color=#%s][font_size=14]De «[url=%s]%s[/url]», Wikipedia en %s (CC BY-SA 4.0).[/font_size][/color]" % [
		r["texto"], TemaUI.color("texto_suave").to_html(false), r["url"], r["titulo"], "español" if r["idioma"] == "es" else "inglés"]
	texto.meta_clicked.connect(_al_click_meta)
	if r.get("miniatura", "") != "":
		var tex := await Wiki.imagen(r["miniatura"])
		if token != _token or not is_instance_valid(caja):
			return
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.custom_minimum_size = Vector2(0, 180)
			caja.add_child(img)
	caja.add_child(texto)


func _ir_a_pestana(i: int) -> void:
	_pestana = i
	(_botones_pestana[i] as Button).button_pressed = true
	_reconstruir()


func _vida(p: Dictionary) -> String:
	var a: int = p["_desde"]
	var b: int = p["_hasta"]
	if a <= -99999:
		return "fechas desconocidas"
	if b >= 99999:
		return "n. %s" % Fechas.texto(a)
	return Fechas.rango(a, b)


func _mayus(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


func _numero(x: float) -> String:
	var n := int(round(x))
	if n >= 1000000:
		return ("%.1f millones" % (n / 1000000.0)).replace(".", ",")
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
