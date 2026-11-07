class_name PanelInfo
extends PanelContainer
## Panel lateral derecho: la información del lugar seleccionado en el año actual, y las fichas de la enciclopedia.

const ANCHO := 470.0
const PESTANAS := ["Resumen", "Historia", "Fuentes", "Gente y hechos", "Datos"]
const NOMBRES_TIPO := {"fuente": "Fuente", "persona": "Persona", "hecho": "Hecho", "lugar": "Lugar", "region": "Región", "entidad": "Entidad política", "familia": "Familia"}

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
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
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
		b.focus_mode = Control.FOCUS_ALL
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
	_scroll.follow_focus = true
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
	# Al cerrar el panel, la familia de la ficha deja de resaltarse en el mapa.
	visibility_changed.connect(func():
		if not visible:
			Estado.resaltar(""))


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
	if Estado.sin_animaciones:
		position.x = vp - ANCHO - 10 if abrir else vp + 20
		visible = abrir
		return
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
		Estado.resaltar("")
		_mostrar(false)
		return
	# En los modos de religión, cultura e idioma, el clic abre directo la pestaña Datos con la familia de ese punto.
	if Enciclopedia.CAPA_DE_MODO.has(Estado.modo):
		_pestana = 4
		(_botones_pestana[4] as Button).button_pressed = true
	_reconstruir()
	_mostrar(true)
	Enciclopedia.registrar_consulta(unidad, Estado.anio)


func _al_pedir_ficha(tipo: String, id: Variant) -> void:
	_ficha = {"tipo": tipo, "id": id}
	_reconstruir()
	_mostrar(true)
	# La ficha de una entidad necesita el mapa político para verse resaltada; la de una religión, cultura o idioma,
	# su modo.
	if tipo == "entidad" and not Estado.modo in ["politico", "terreno"]:
		Estado.fijar_modo("politico")
	if tipo == "familia":
		var modo: String = Enciclopedia.MODO_DE_CAPA.get(str(id).get_slice(":", 0), "")
		if modo != "":
			Estado.fijar_modo(modo)


func _programar() -> void:
	if not _abierto or _reconstruir_pendiente:
		return
	if Estado.sin_animaciones:
		_reconstruir(true)
		return
	_reconstruir_pendiente = true
	await get_tree().create_timer(0.18).timeout
	_reconstruir_pendiente = false
	if _abierto:
		_reconstruir(true)


# ---------------------------------------------------------------------------------------------------------------
# Contenido


func _limpiar() -> void:
	_token += 1
	for c in _contenido.get_children():
		c.queue_free()


## conservar_scroll: al cambiar el año o el modo se queda en la misma altura (por ejemplo, al tocar las barras de una
## familia); al abrir algo nuevo vuelve arriba.
func _reconstruir(conservar_scroll := false) -> void:
	var altura := _scroll.scroll_vertical
	_limpiar()
	_scroll.scroll_vertical = 0
	if conservar_scroll and altura > 0:
		_restaurar_scroll(altura)
	match _ficha.get("tipo", ""):
		"familia":
			Estado.resaltar(str(_ficha["id"]))
		"entidad":
			Estado.resaltar("entidad:%d" % int(_ficha["id"]))
		_:
			Estado.resaltar("")
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
			_parrafo("Parte de: %s" % DatosMapa.nombres_revisados.get(e["m"], str(e["m"]).trim_prefix("(").trim_suffix(")")), true)
		var ficha := _boton_texto("Ficha de la entidad: territorio, lugares y fuentes", "ir")
		ficha.icon = IconosUI.muestra(DatosMapa.color_entidad(ent))
		ficha.pressed.connect(func(): Estado.pedir_ficha("entidad", ent))
		_contenido.add_child(ficha)
		_bloque_wikipedia(DatosMapa.titulos_wiki_entidad(ent))
	else:
		_seccion("Sin entidad política registrada")
		_parrafo("Cliopatria no registra una entidad política aquí en %s Puede tratarse de pueblos sin estado, de territorio poco documentado o de un hueco de los datos." % _con_punto(Fechas.texto(Estado.anio)))
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		_seccion("La región: %s" % r["nombre"])
		var era := Enciclopedia.era_en(id, Estado.anio)
		if not era.is_empty():
			_parrafo("[b]%s[/b] (%s). %s" % [era["nombre"], Fechas.rango(int(era["desde"]), int(era["hasta"])), era.get("resumen", "")])
		_parrafo(str(r.get("resumen", "")))
		if r.get("extendida") is Dictionary:
			var rid: String = id
			var leer := _boton_texto("Leer la historia completa de %s" % r["nombre"], "libro")
			leer.pressed.connect(func(): Estado.pedir_ficha("region", rid))
			_contenido.add_child(leer)
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
	_nota("Textos producidos en la región entre %s y %s" % [Fechas.texto(Fechas.sumar(Estado.anio, -150)), _con_punto(Fechas.texto(Fechas.sumar(Estado.anio, 150)))])
	if escritas.is_empty():
		_parrafo("[i]Todavía no hay fuentes cargadas para este lugar y momento.[/i]")
	for f in escritas:
		_contenido.add_child(_tarjeta_fuente(f))
	_seccion("Sobre este lugar y esta época")
	_nota("Textos de cualquier época que estudian o narran este lugar en %s" % _con_punto(Fechas.texto(Estado.anio)))
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
	var capa_modo: String = Enciclopedia.CAPA_DE_MODO.get(Estado.modo, "")
	var marcada := ""
	if capa_modo != "":
		var nombre_capa: String = Enciclopedia.NOMBRE_CAPA[capa_modo]
		_seccion("%s en este punto" % nombre_capa)
		var fam := Enciclopedia.familia_en_unidad(capa_modo, _unidad, Estado.anio)
		if fam == "":
			_nota("No hay datos de %s para este punto en %s" % [nombre_capa.to_lower(), _con_punto(Fechas.texto(Estado.anio))])
		else:
			marcada = "%s:%s" % [capa_modo, fam]
			var b := _boton_texto("Ficha: %s" % Enciclopedia.nombre_familia(capa_modo, fam), "ir")
			b.icon = IconosUI.muestra(Enciclopedia.color_familia(capa_modo, fam))
			b.tooltip_text = "Qué es, dónde está en cada época y sus fuentes"
			b.pressed.connect(func(): Estado.pedir_ficha("familia", marcada))
			_contenido.add_child(b)
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
		_parrafo("Entidad: [b][url=entidad:%d]%s[/url][/b], %s %s" % [ent, DatosMapa.nombre_entidad(ent), _con_punto(Fechas.rango(int(e["a"]), int(e["b"]))), " · ".join(links)], true)
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		var pob := Enciclopedia.poblacion_en(id, Estado.anio)
		var capas := {"religiones": "Religión", "culturas": "Cultura", "idiomas": "Idioma"}
		var testimonios := Enciclopedia.testimonios_poblacion(id).filter(
			func(t): return absi(int(t["anio"]) - Estado.anio) <= 300)
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
			var serie := Enciclopedia.estimaciones(id)
			if serie.size() >= 2:
				var grafico := GraficoSerie.new()
				grafico.serie = serie
				grafico.anio = Estado.anio
				_contenido.add_child(grafico)
			var notas: Array = []
			for e in serie:
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
			_parrafo("[b]%s[/b]" % capas[c], true)
			vigentes.sort_custom(func(a, b): return Enciclopedia.ORDEN_PESO.get(a.get("peso", ""), 3) < Enciclopedia.ORDEN_PESO.get(b.get("peso", ""), 3))
			for v in vigentes:
				var fam := Enciclopedia.familia_de(v)
				var clave := "%s:%s" % [c, fam]
				var fila := _fila_color(Enciclopedia.color_familia(c, fam), v["nombre"], str(v.get("peso", "")), clave == marcada)
				fila.tooltip_text = "Ficha: %s" % Enciclopedia.nombre_familia(c, fam)
				fila.pressed.connect(func(): Estado.pedir_ficha("familia", clave))
				_contenido.add_child(fila)
	_nota("Las cifras antiguas son estimaciones académicas con mucha incertidumbre; cada una cita su fuente.")


# ---------------------------------------------------------------------------------------------------------------
# Fichas


func _construir_ficha(tipo: String, id: Variant) -> void:
	if tipo == "entidad":
		_ficha_entidad(int(id))
		return
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
		"familia":
			_ficha_familia(el)
	if Edicion.SECCION_DE_TIPO.has(tipo):
		var editar := _boton_texto("Editar esta ficha", "editar")
		editar.tooltip_text = "Abrir en el editor de la enciclopedia"
		editar.pressed.connect(func(): Estado.editor_pedido.emit(tipo, str(id)))
		_contenido.add_child(editar)


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
			b.pressed.connect(func(): Estado.abrir_url(url))
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
	var ext: Variant = r.get("extendida")
	if ext is Dictionary:
		_ficha_extendida(ext)
	var ir := _boton_texto("Ver en el mapa", "ir")
	ir.pressed.connect(func():
		var caja: Rect2 = r["_caja"]
		Estado.enfocar(caja.get_center(), 0.0)
		var u := DatosMapa.unidad_en(caja.get_center())
		if u > 0:
			Estado.seleccionar_lugar(u, caja.get_center()))
	_contenido.add_child(ir)


## La ficha extendida (nivel 3): historia por secciones, cada afirmación con su cita [n] que lleva a la referencia.
func _ficha_extendida(ext: Dictionary) -> void:
	var urls := {}
	for ref in ext.get("referencias", []):
		urls[int(ref.get("n", 0))] = str(ref.get("url", ""))
	var cita := RegEx.create_from_string("\\[(\\d+)\\]")
	for s in ext.get("secciones", []):
		_seccion(str(s.get("titulo", "")))
		# Las citas se marcan antes de escapar los corchetes del texto, y después se vuelven enlaces.
		var texto := cita.sub(str(s.get("texto", "")), "{{cita:$1}}", true).replace("[", "[lb]")
		for n in urls:
			texto = texto.replace("{{cita:%d}}" % n, "[url=%s][lb]%d][/url]" % [urls[n], n])
		_parrafo(texto.replace("{{cita:", "[lb]").replace("}}", "]"))
	var refs: Array = []
	for ref in ext.get("referencias", []):
		refs.append("[lb]%s] [url=%s]%s[/url]" % [ref.get("n"), ref.get("url"), ref.get("titulo", ref.get("url"))])
	if not refs.is_empty():
		_seccion("Referencias")
		_parrafo("\n".join(refs), true)
	var ia: Variant = ext.get("ia")
	var rev: Variant = ext.get("revision")
	if ia is Dictionary:
		_nota("Redactada con IA (%s) a partir de las fuentes citadas%s." % [ia.get("modelo", "?"),
			"; revisada por una persona el %s" % rev.get("fecha") if rev is Dictionary else ", sin revisión humana todavía"])


func _ficha_familia(f: Dictionary) -> void:
	var capa: String = f["capa"]
	var clave: String = f["_clave"]
	var color := Enciclopedia.color_familia(capa, f["id"])
	var anio := Estado.anio
	_franja.color = color
	_titulo.text = f.get("nombre", "")
	var cadena: Array = []
	for a in Enciclopedia.ancestros_familia(clave):
		cadena.append("[url=familia:%s]%s[/url]" % [a, Enciclopedia.familia(a)["nombre"]])
	_subtitulo.text = Enciclopedia.NOMBRE_CAPA[capa]
	if not cadena.is_empty():
		_parrafo("[b]Familia mayor:[/b] %s" % " › ".join(cadena), true)
	if f.get("nota"):
		_nota(str(f["nota"]))
	var hijas: Array = f["_hijas"]
	if not hijas.is_empty():
		_seccion("Incluye")
		for h in hijas:
			var hf := Enciclopedia.familia(h)
			var n_regiones := {}
			for e in Enciclopedia.presencia_familia(h):
				n_regiones[e["region"]] = true
			var detalle := "sin datos en el mapa" if n_regiones.is_empty() else "%d %s" % [n_regiones.size(), "región" if n_regiones.size() == 1 else "regiones"]
			var fila := _fila_color(Enciclopedia.color_familia(capa, hf["id"]), hf["nombre"], detalle, false)
			var hc: String = h
			fila.pressed.connect(func(): Estado.pedir_ficha("familia", hc))
			_contenido.add_child(fila)

	var pres := Enciclopedia.presencia_familia(clave)
	for e in pres:
		e["color"] = Enciclopedia.color_familia(capa, e["familia"])
	_seccion("En %s" % Fechas.texto(anio))
	var ahora := pres.filter(func(e): return e["desde"] <= anio and anio <= e["hasta"])
	ahora.sort_custom(func(a, b): return Enciclopedia.ORDEN_PESO.get(a["peso"], 3) < Enciclopedia.ORDEN_PESO.get(b["peso"], 3))
	if ahora.is_empty():
		_nota("No aparece en las regiones cargadas en este año.")
		var cerca := _anio_mas_cercano(pres, anio)
		if cerca != anio:
			var b := _boton_texto("Ir a %s, cuando sí aparece" % Fechas.texto(cerca), "ir")
			b.pressed.connect(func(): Estado.fijar_anio(cerca))
			_contenido.add_child(b)
	for e in ahora:
		var r: Dictionary = Enciclopedia.regiones[e["region"]]
		var fila := _fila_color(e["color"], r["nombre"], "%s · %s" % [e["peso"], e["nombre"]], e["peso"] == "mayoritaria")
		fila.tooltip_text = "%s: %s, %s\nClic: ver la región en el mapa" % [r["nombre"], e["nombre"], Fechas.rango(e["desde"], e["hasta"])]
		fila.pressed.connect(func(): Estado.enfocar((r["_caja"] as Rect2).get_center(), 0.0))
		_contenido.add_child(fila)
	var modo: String = Enciclopedia.MODO_DE_CAPA[capa]
	if Estado.modo != modo:
		var b := _boton_texto("Ver en el mapa (modo %s)" % Estado.MODOS[modo][0].to_lower(), "ir")
		b.pressed.connect(func(): Estado.fijar_modo(modo))
		_contenido.add_child(b)
	elif Enciclopedia.indice_familia(clave) <= 0 and not pres.is_empty():
		_nota("Esta familia no se pinta directo en el mapa: sus áreas son las de las familias que incluye, cada una con su color.")

	if not pres.is_empty():
		_seccion("A lo largo del tiempo")
		var barras := BarrasFamilia.new()
		barras.configurar(pres, color, anio)
		_contenido.add_child(barras)
		_nota("Más intenso: mayoritaria; más claro: importante o minoritaria. Clic en las barras para ir a ese año.")
		var notas: Array = []
		for e in pres:
			if e["nota"] != "":
				notas.append("[b]%s[/b], %s: %s" % [Enciclopedia.regiones[e["region"]]["nombre"], Fechas.rango(e["desde"], e["hasta"]), e["nota"]])
		if not notas.is_empty():
			_seccion("Notas")
			_parrafo("\n".join(notas))
	else:
		_nota("Todavía no hay regiones cargadas con esta %s." % Enciclopedia.NOMBRE_CAPA[capa].to_lower())

	var fs := Enciclopedia.fuentes_de_familia(clave)
	if not fs.is_empty():
		_seccion("Fuentes de esas regiones y épocas")
		for fu in fs.slice(0, 6):
			_contenido.add_child(_tarjeta_fuente(fu))
		if fs.size() > 6:
			_nota("Y %d más en la pestaña Fuentes de cada región." % (fs.size() - 6))
	_bloque_wikipedia(f.get("wikipedia", {}))


func _ficha_entidad(i: int) -> void:
	if i < 0 or i >= DatosMapa.entidades.size():
		_titulo.text = "No encontrado"
		_subtitulo.text = "entidad %d" % i
		return
	var e: Dictionary = DatosMapa.entidades[i]
	var desde := int(e["a"])
	var hasta := int(e["b"])
	var anio := Estado.anio
	var color := DatosMapa.color_entidad(i)
	_franja.color = color
	_titulo.text = DatosMapa.nombre_entidad(i)
	_subtitulo.text = "Entidad política · %s" % Fechas.rango(desde, hasta)
	if str(e.get("m", "")) != "":
		_parrafo("Parte de: %s" % e["m"], true)
	var serie := DatosMapa.territorio_de_entidad(i)
	var pico := [desde, 0.0]
	for punto in serie:
		if float(punto[1]) > float(pico[1]):
			pico = punto
	var grafico := GraficoTerritorio.new()
	grafico.configurar(serie, color, desde, hasta)
	var ahora := grafico.valor_en(anio) if desde <= anio and anio <= hasta else 0.0
	if ahora > 0.0:
		_parrafo("[b]En %s:[/b] ~%s km² (resaltado en el mapa)" % [Fechas.texto(anio), GraficoSerie._numero(ahora)], true)
		var ir := _boton_texto("Centrar el mapa en su territorio", "ir")
		ir.pressed.connect(func():
			var c := DatosMapa.centro_entidad(i)
			if c.x >= 0:
				Estado.enfocar(c, 0.0))
		_contenido.add_child(ir)
	else:
		_nota("En %s no tiene territorio en los datos." % Fechas.texto(anio))
	if not Estado.modo in ["politico", "terreno"]:
		var b := _boton_texto("Ver en el mapa político", "ir")
		b.pressed.connect(func(): Estado.fijar_modo("politico"))
		_contenido.add_child(b)

	_seccion("Territorio a lo largo del tiempo")
	_contenido.add_child(grafico)
	if float(pico[1]) > 0.0:
		_nota("Máxima extensión en los datos: ~%s km², hacia %s Clic en el gráfico para ir a un año." % [
			GraficoSerie._numero(float(pico[1])), _con_punto(Fechas.texto(int(pico[0])))])
		if int(pico[0]) != anio:
			var b := _boton_texto("Ir a %s, su máxima extensión" % Fechas.texto(int(pico[0])), "ir")
			var anio_pico := int(pico[0])
			b.pressed.connect(func():
				Estado.fijar_anio(anio_pico)
				var c := DatosMapa.centro_entidad(i)
				if c.x >= 0:
					Estado.enfocar(c, 0.0))
			_contenido.add_child(b)
	var links: Array = []
	if str(e.get("d", "")) != "":
		links.append("[url=https://www.wikidata.org/wiki/%s]Wikidata[/url]" % e["d"])
	if str(e.get("s", "")) != "":
		links.append("[url=https://seshat-db.com/core/polity/%s]Seshat[/url]" % e["s"])
	if not links.is_empty():
		_parrafo("Fronteras de Cliopatria (Seshat). %s" % " · ".join(links), true)

	# Lugares, hechos y fuentes dentro de su territorio mientras le pertenecía.
	var lugares: Array = []
	for l in Enciclopedia.lugares.values():
		if not l.has("_px"):
			continue
		for tramo in DatosMapa.historia_de_unidad(DatosMapa.unidad_en(l["_px"])):
			if tramo["entidad"] == i and tramo["desde"] <= l["_hasta"] and l["_desde"] <= tramo["hasta"]:
				lugares.append(l)
				break
	var hechos: Array = []
	for h in Enciclopedia.hechos.values():
		if h.has("_px") and DatosMapa.dueno_en(DatosMapa.unidad_en(h["_px"]), h["_desde"]) == i:
			hechos.append(h)
	var fuentes: Array = []
	for f in Enciclopedia.fuentes.values():
		if f.has("_px") and DatosMapa.dueno_en(DatosMapa.unidad_en(f["_px"]), f["_desde"]) == i:
			fuentes.append(f)
	if not lugares.is_empty():
		_seccion("Lugares de su territorio")
		lugares.sort_custom(func(a, b): return int(a.get("importancia", 1)) > int(b.get("importancia", 1)))
		for l in lugares.slice(0, 10):
			var fila := _fila_color(TemaUI.color("texto"), l["nombre"], _mayus(str(l.get("tipo", "")).replace("-", " ")), false)
			var id: String = l["id"]
			fila.pressed.connect(func(): Estado.pedir_ficha("lugar", id))
			_contenido.add_child(fila)
	if not hechos.is_empty():
		_seccion("Hechos en su territorio")
		hechos.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
		for h in hechos.slice(0, 10):
			var fila := _fila_color(TemaUI.color("hecho"), h["titulo"], Fechas.texto(h["_desde"]), false)
			var id: String = h["id"]
			fila.pressed.connect(func(): Estado.pedir_ficha("hecho", id))
			_contenido.add_child(fila)
	if not fuentes.is_empty():
		_seccion("Fuentes escritas en su territorio")
		fuentes.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
		for f in fuentes.slice(0, 6):
			_contenido.add_child(_tarjeta_fuente(f))
		if fuentes.size() > 6:
			_nota("Y %d más." % (fuentes.size() - 6))
	if lugares.is_empty() and hechos.is_empty() and fuentes.is_empty():
		_nota("Todavía no hay lugares, hechos ni fuentes de la enciclopedia dentro de su territorio.")
	_bloque_wikipedia(DatosMapa.titulos_wiki_entidad(i))


func _anio_mas_cercano(pres: Array, anio: int) -> int:
	var mejor := anio
	var dist := 1 << 30
	for e in pres:
		var destino: int = e["desde"] if anio < e["desde"] else (e["hasta"] if anio > e["hasta"] else anio)
		if absi(destino - anio) < dist:
			dist = absi(destino - anio)
			mejor = destino
	return mejor


func _restaurar_scroll(altura: int) -> void:
	var token := _token
	await get_tree().process_frame
	await get_tree().process_frame
	if token == _token:
		_scroll.scroll_vertical = altura


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
	elif m.begins_with("familia:"):
		Estado.pedir_ficha("familia", m.substr(8))
	elif m.begins_with("entidad:"):
		Estado.pedir_ficha("entidad", int(m.substr(8)))
	else:
		Estado.abrir_url(m)


func _enlace_persona(id: Variant, nombre: String) -> String:
	if id != null and Enciclopedia.personas.has(str(id)):
		return "[url=persona:%s]%s[/url]" % [id, nombre]
	return nombre


func _boton_texto(texto: String, icono: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.icon = IconosUI.textura(icono, 16, TemaUI.color("acento"))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	return b


func _fila_color(color: Color, texto: String, detalle: String, resaltada: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "BotonPlano"
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s   ·   %s" % [texto, detalle]
	b.icon = IconosUI.muestra(color)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if resaltada:
		b.add_theme_color_override("font_color", TemaUI.color("titulo"))
		b.add_theme_stylebox_override("normal", TemaUI.caja(TemaUI.color("fondo2"), TemaUI.color("acento"), 1, 3, 4.0))
	return b


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
	ficha.focus_mode = Control.FOCUS_ALL
	var id: String = f["id"]
	ficha.pressed.connect(func(): Estado.pedir_ficha("fuente", id))
	botones.add_child(ficha)
	var leer: Array = f.get("leer", [])
	if not leer.is_empty():
		var b := Button.new()
		b.text = "Leer"
		b.icon = IconosUI.textura("enlace", 14, TemaUI.color("acento"))
		b.focus_mode = Control.FOCUS_ALL
		var url: String = leer[0]["url"]
		b.tooltip_text = url
		b.pressed.connect(func(): Estado.abrir_url(url))
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
	# El texto se crea recién acá: si se creara antes de esperar la imagen y el panel cambiara mientras tanto,
	# quedaría suelto sin liberarse.
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.selection_enabled = true
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.text = "%s\n[color=#%s][font_size=14]De «[url=%s]%s[/url]», Wikipedia en %s (CC BY-SA 4.0).[/font_size][/color]" % [
		r["texto"], TemaUI.color("texto_suave").to_html(false), r["url"], r["titulo"], "español" if r["idioma"] == "es" else "inglés"]
	texto.meta_clicked.connect(_al_click_meta)
	caja.add_child(texto)


## Teclas [ y ]: la pestaña anterior o la siguiente del lugar (con una ficha abierta no hay pestañas).
func pestana_vecina(paso: int) -> void:
	if _abierto and _ficha.is_empty() and _unidad > 0:
		_ir_a_pestana(posmod(_pestana + paso, PESTANAS.size()))


## Tecla Retroceso: de una ficha al lugar elegido, como el botón de volver.
func volver() -> void:
	if _abierto and not _ficha.is_empty() and _unidad > 0:
		_ficha = {}
		_reconstruir()


func _ir_a_pestana(i: int) -> void:
	_pestana = i
	(_botones_pestana[i] as Button).button_pressed = true
	_reconstruir()


func _vida(p: Dictionary) -> String:
	if p.get("_sin_fechas", false):
		return "fechas desconocidas"
	var n: Variant = p.get("nacimiento", {}).get("anio") if p.get("nacimiento") is Dictionary else null
	var m: Variant = p.get("muerte", {}).get("anio") if p.get("muerte") is Dictionary else null
	if n != null and m != null:
		return Fechas.rango(int(n), int(m))
	if n == null and m == null:
		return "activo c. %s" % Fechas.rango(p["_desde"], p["_hasta"])
	if n == null:
		return "m. %s" % Fechas.texto(int(m))
	return "n. %s" % Fechas.texto(int(n))


## Para cerrar una oración con una fecha: «1400 a. C.» ya trae su punto; «1200» no.
func _con_punto(s: String) -> String:
	return s if s.ends_with(".") else s + "."


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
