class_name PanelInfo
extends PanelContainer
## Panel lateral derecho: la información del lugar seleccionado en el año actual, y las fichas de la enciclopedia.

const ANCHO := 470.0
## Los textos de las constantes están en español y se traducen con tr() al mostrarlos.
const PESTANAS := ["Resumen", "Historia", "Fuentes", "Gente y hechos", "Datos"]
const NOMBRES_TIPO := {"fuente": "Fuente", "persona": "Persona", "hecho": "Hecho", "lugar": "Lugar", "region": "Región", "entidad": "Entidad política", "familia": "Familia", "pleiades": "Lugar antiguo"}
## Cómo se muestran los valores cerrados del esquema (data/enciclopedia/ESQUEMA.md).
const NOMBRES_GENERO := {"religioso": "religioso", "historia": "historia", "cronica": "crónica", "literatura": "literatura",
	"poesia": "poesía", "filosofia": "filosofía", "legal": "legal", "administrativo": "administrativo", "epistolar": "epistolar",
	"inscripcion": "inscripción", "geografia": "geografía", "ciencia": "ciencia", "medicina": "medicina", "sabiduria": "sabiduría",
	"viajes": "viajes", "ensayo": "ensayo", "arqueologia": "arqueología", "economia": "economía", "politica": "política",
	"manifiesto": "manifiesto", "discurso": "discurso", "tecnologia": "tecnología", "periodismo": "periodismo"}
const NOMBRES_TIPO_HECHO := {"politico": "político", "batalla": "batalla", "fundacion": "fundación", "religioso": "religioso",
	"cultural": "cultural", "cientifico": "científico", "economico": "económico", "desastre": "desastre", "tratado": "tratado",
	"construccion": "construcción", "exploracion": "exploración", "revolucion": "revolución", "judicial": "judicial"}
const NOMBRES_TIPO_LUGAR := {"ciudad": "ciudad", "capital": "capital", "templo": "templo", "puerto": "puerto",
	"sitio-arqueologico": "sitio arqueológico", "biblioteca": "biblioteca", "universidad": "universidad",
	"laboratorio": "laboratorio", "institucion": "institución", "sitio-historico": "sitio histórico"}
const NOMBRES_CONFIANZA := {"alta": "alta", "media": "media", "baja": "baja"}

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
## Qué indicador del país muestra su gráfico en la pestaña «Datos» ("" = ninguno).
var _indicador_abierto := "poblacion"


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
	_volver = IconosUI.boton("volver", tr("Volver al lugar"), 18)
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
	var cerrar := IconosUI.boton("cerrar", tr("Cerrar (Esc)"), 18)
	cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cerrar.pressed.connect(func(): Estado.seleccionar_lugar(0, Vector2.ZERO))
	cab.add_child(cerrar)

	_barra_pestanas = HBoxContainer.new()
	_barra_pestanas.add_theme_constant_override("separation", 0)
	caja.add_child(_barra_pestanas)
	var grupo := ButtonGroup.new()
	for i in PESTANAS.size():
		var b := Button.new()
		b.text = tr(PESTANAS[i])
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
	_fijar_x(get_viewport_rect().size.x + 20)
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
		_fijar_x(vp - ANCHO - 10 if abrir else vp + 20)
		visible = abrir
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if abrir:
		_fijar_x(vp + 20)
		_tween.tween_method(_fijar_x, vp + 20, vp - ANCHO - 10, 0.32)
	else:
		_tween.tween_method(_fijar_x, position.x, vp + 20, 0.25)
		_tween.finished.connect(func(): visible = _abierto)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _abierto and not (_tween and _tween.is_running()):
		_fijar_x(get_viewport_rect().size.x - ANCHO - 10)


## Corre el panel en horizontal tocando solo sus márgenes izquierdo y derecho (está anclado al borde derecho). Con
## position, Godot recalcula los cuatro márgenes con el tamaño de ese instante: si mientras se armaba el contenido
## pedía más alto, el panel quedaba para siempre más largo que la ventana, por debajo de la línea de tiempo y con el
## final del texto fuera de alcance.
func _fijar_x(x: float) -> void:
	offset_left = x - get_viewport_rect().size.x
	offset_right = offset_left + ANCHO


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
		_titulo.text = Enciclopedia.regiones[regs[0]]["nombre"] if not regs.is_empty() else tr("Sin entidad registrada")
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
		_seccion(tr("La entidad"))
		_parrafo("[b]%s[/b] · %s" % [DatosMapa.nombre_entidad(ent), Fechas.rango(int(e["a"]), int(e["b"]))], true)
		if str(e.get("m", "")) != "":
			_parrafo(tr("Parte de: %s") % DatosMapa.nombre_cliopatria(str(e["m"])), true)
		var ficha := _boton_texto(tr("Ficha de la entidad: territorio, lugares y fuentes"), "ir")
		ficha.icon = IconosUI.muestra(DatosMapa.color_entidad(ent))
		ficha.pressed.connect(func(): Estado.pedir_ficha("entidad", ent))
		_contenido.add_child(ficha)
		_bloque_wikipedia(DatosMapa.titulos_wiki_entidad(ent))
	else:
		_seccion(tr("Sin entidad política registrada"))
		_parrafo(tr("Cliopatria no registra una entidad política aquí en %s Puede tratarse de pueblos sin estado, de territorio poco documentado o de un hueco de los datos.") % _con_punto(Fechas.texto(Estado.anio)))
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		_seccion(tr("La región: %s") % r["nombre"])
		var era := Enciclopedia.era_en(id, Estado.anio)
		if not era.is_empty():
			_parrafo("[b]%s[/b] (%s). %s" % [era["nombre"], Enciclopedia.rango_de(era), era.get("resumen", "")])
		_parrafo(str(r.get("resumen", "")))
		if r.get("extendida") is Dictionary:
			var rid: String = id
			var leer := _boton_texto(tr("Leer la historia completa de %s") % r["nombre"], "libro")
			leer.pressed.connect(func(): Estado.pedir_ficha("region", rid))
			_contenido.add_child(leer)
		break
	var escritas := Enciclopedia.fuentes_escritas(regs, Estado.anio)
	var sobre := Enciclopedia.fuentes_sobre(regs, Estado.anio)
	if escritas.size() + sobre.size() > 0:
		var n_fuentes := escritas.size() + sobre.size()
		var b := _boton_texto(tr_n("Ver %d fuente para este lugar y época", "Ver %d fuentes para este lugar y época", n_fuentes) % n_fuentes, "libro")
		b.pressed.connect(func(): _ir_a_pestana(2))
		_contenido.add_child(b)


func _pestana_historia(regs: Array) -> void:
	_seccion(tr("Quién gobernó este lugar"))
	var tramos := DatosMapa.historia_de_unidad(_unidad)
	if tramos.is_empty():
		_parrafo(tr("Cliopatria no registra entidades políticas para este punto."))
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
		_seccion(tr("Eras de %s") % Enciclopedia.regiones[id]["nombre"])
		for e in eras:
			var actual: bool = Enciclopedia.desde_de(e) <= Estado.anio and Estado.anio <= Enciclopedia.hasta_de(e)
			var fila := _fila_color(TemaUI.color("acento") if actual else TemaUI.color("borde_suave"), e["nombre"], Enciclopedia.rango_de(e), actual)
			# Una era sin comienzo conocido lleva a su final, no al primer año del mapa.
			var desde := Enciclopedia.desde_de(e) if e.get("desde") != null else Enciclopedia.hasta_de(e)
			fila.pressed.connect(func(): Estado.fijar_anio(desde))
			fila.tooltip_text = str(e.get("resumen", ""))
			_contenido.add_child(fila)


func _pestana_fuentes(regs: Array) -> void:
	var escritas := Enciclopedia.fuentes_escritas(regs, Estado.anio)
	var sobre := Enciclopedia.fuentes_sobre(regs, Estado.anio)
	_seccion(tr("Escritas aquí, en esta época"))
	_nota(tr("Textos producidos en la región entre %s y %s") % [Fechas.texto(Fechas.sumar(Estado.anio, -150)), _con_punto(Fechas.texto(Fechas.sumar(Estado.anio, 150)))])
	if escritas.is_empty():
		_parrafo(tr("[i]Todavía no hay fuentes cargadas para este lugar y momento.[/i]"))
	for f in escritas:
		_contenido.add_child(_tarjeta_fuente(f))
	_seccion(tr("Sobre este lugar y esta época"))
	_nota(tr("Textos de cualquier época que estudian o narran este lugar en %s") % _con_punto(Fechas.texto(Estado.anio)))
	if sobre.is_empty():
		_parrafo(tr("[i]Todavía no hay estudios cargados para este lugar y momento.[/i]"))
	for f in sobre:
		if not escritas.has(f):
			_contenido.add_child(_tarjeta_fuente(f))
	if regs.is_empty():
		_nota(tr("Este punto no está dentro de ninguna región de la enciclopedia todavía. La enciclopedia se completa por etapas: ver docs/es/enciclopedia.md."))


func _pestana_gente(regs: Array) -> void:
	_seccion(tr("Personas vivas en %s") % Fechas.texto(Estado.anio))
	var gente := Enciclopedia.personas_vivas(regs, Estado.anio)
	if gente.is_empty():
		_parrafo(tr("[i]No hay personas cargadas para este lugar y año.[/i]"))
	for p in gente:
		var fila := _fila_color(TemaUI.color("persona"), p["nombre"], _vida(p), false)
		var id: String = p["id"]
		fila.pressed.connect(func(): Estado.pedir_ficha("persona", id))
		_contenido.add_child(fila)
	_seccion(tr("Hechos cercanos (±100 años)"))
	var hechos := Enciclopedia.hechos_cerca(regs, Estado.anio)
	if hechos.is_empty():
		_parrafo(tr("[i]No hay hechos cargados cerca de este año.[/i]"))
	for h in hechos:
		var fila := _fila_color(TemaUI.color("hecho"), h["titulo"], Fechas.rango(h["_desde"], h["_hasta"]), h["_desde"] <= Estado.anio and Estado.anio <= h["_hasta"])
		var id: String = h["id"]
		fila.pressed.connect(func(): Estado.pedir_ficha("hecho", id))
		_contenido.add_child(fila)


func _pestana_datos(ent: int, regs: Array, lonlat: Vector2) -> void:
	var capa_modo: String = Enciclopedia.CAPA_DE_MODO.get(Estado.modo, "")
	var marcada := ""
	if capa_modo != "":
		var nombre_capa: String = tr(Enciclopedia.NOMBRE_CAPA[capa_modo])
		_seccion(tr("%s en este punto") % nombre_capa)
		var fam := Enciclopedia.familia_en_unidad(capa_modo, _unidad, Estado.anio)
		if fam == "":
			_nota(tr("No hay datos de %s para este punto en %s") % [nombre_capa.to_lower(), _con_punto(Fechas.texto(Estado.anio))])
		else:
			marcada = "%s:%s" % [capa_modo, fam]
			var b := _boton_texto(tr("Ficha: %s") % Enciclopedia.nombre_familia(capa_modo, fam), "ir")
			b.icon = IconosUI.muestra(Enciclopedia.color_familia(capa_modo, fam))
			b.tooltip_text = tr("Qué es, dónde está en cada época y sus fuentes")
			b.pressed.connect(func(): Estado.pedir_ficha("familia", marcada))
			_contenido.add_child(b)
	_seccion(tr("Este lugar"))
	var km2 := DatosMapa.area_km2(_unidad)
	_parrafo(tr("Coordenadas: %s\nSuperficie de la unidad del mapa: ~%s km²") % [Proyeccion.texto_coordenadas(lonlat), _numero(km2)], true)
	if ent >= 0:
		var e: Dictionary = DatosMapa.entidades[ent]
		var links: Array = []
		if str(e.get("d", "")) != "":
			links.append("[url=https://www.wikidata.org/wiki/%s]Wikidata[/url]" % e["d"])
		if str(e.get("s", "")) != "":
			links.append("[url=https://seshat-db.com/core/polity/%s]Seshat[/url]" % e["s"])
		_parrafo(tr("Entidad: [b][url=entidad:%d]%s[/url][/b], %s %s") % [ent, DatosMapa.nombre_entidad(ent), _con_punto(Fechas.rango(int(e["a"]), int(e["b"]))), " · ".join(links)], true)
	_bloque_pais()
	for id in regs:
		var r: Dictionary = Enciclopedia.regiones[id]
		var pob := Enciclopedia.poblacion_en(id, Estado.anio)
		var capas := Enciclopedia.NOMBRE_CAPA
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
			var aprox := "" if pob["exacta"] else tr("interpolada entre estimaciones, ")
			_parrafo(tr("[b]Población estimada:[/b] ~%s habitantes [color=#%s](%sfuente: %s)[/color]") % [_numero(pob["poblacion"]), TemaUI.color("texto_suave").to_html(false), aprox, pob["fuente"]])
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
			_parrafo(tr("[b]Testimonio antiguo:[/b] %s dice ~%s habitantes hacia %s. [color=#%s]%s[/color]") % [
				t.get("fuente", ""), _numero(float(t["poblacion"])), Fechas.texto(int(t["anio"])),
				TemaUI.color("texto_suave").to_html(false), t.get("nota", "")], true)
		for c in capas:
			var vigentes := Enciclopedia.capa_en(id, c, Estado.anio)
			if vigentes.is_empty():
				continue
			_parrafo("[b]%s[/b]" % tr(capas[c]), true)
			vigentes.sort_custom(func(a, b): return Enciclopedia.ORDEN_PESO.get(a.get("peso", ""), 3) < Enciclopedia.ORDEN_PESO.get(b.get("peso", ""), 3))
			for v in vigentes:
				var fam := Enciclopedia.familia_de(v)
				var clave := "%s:%s" % [c, fam]
				var fila := _fila_color(Enciclopedia.color_familia(c, fam), v["nombre"], _peso(str(v.get("peso", ""))), clave == marcada)
				fila.tooltip_text = tr("Ficha: %s") % Enciclopedia.nombre_familia(c, fam)
				fila.pressed.connect(func(): Estado.pedir_ficha("familia", clave))
				_contenido.add_child(fila)
	_nota(tr("Las cifras antiguas son estimaciones académicas con mucha incertidumbre; cada una cita su fuente."))


## El país actual de este punto con sus series de Our World in Data (fronteras de hoy): una fila por indicador con el
## último dato hasta el año elegido; la fila abierta muestra su gráfico.
func _bloque_pais() -> void:
	if Estado.anio < 1800:
		return
	var codigo := Demografia.pais_de_unidad(_unidad)
	if codigo == "" or not Demografia.paises.has(codigo):
		return
	var filas: Array = []
	for ind in Demografia.indicadores:
		var v := Demografia.valor(codigo, str(ind["clave"]), Estado.anio)
		if not v.is_empty():
			filas.append([ind, v])
	if filas.is_empty():
		return
	_seccion(tr("País actual: %s") % Demografia.nombre(codigo))
	_nota(tr("Con las fronteras de hoy; el último dato publicado hasta %s") % _con_punto(Fechas.texto(Estado.anio)))
	for par in filas:
		var ind: Dictionary = par[0]
		var v: Dictionary = par[1]
		var clave := str(ind["clave"])
		var abierto := clave == _indicador_abierto
		var detalle := Demografia.texto_valor(v["valor"], clave)
		if int(v["anio"]) != Estado.anio:
			detalle += " (%s)" % Fechas.texto(int(v["anio"]))
		var fila := _fila_color(TemaUI.color("acento") if abierto else TemaUI.color("borde_suave"), str(ind["nombre"]), detalle, abierto)
		var ayuda: Array = [str(ind.get("descripcion", ind["nombre"]))]
		var mundo := Demografia.valor(Demografia.MUNDO, clave, Estado.anio)
		if not mundo.is_empty() and clave != "poblacion":
			ayuda.append(tr("Mundo: %s (%s).") % [Demografia.texto_valor(mundo["valor"], clave), Fechas.texto(int(mundo["anio"]))])
		ayuda.append(tr("Fuente: %s.") % ind["fuente"])
		fila.tooltip_text = "\n".join(ayuda)
		fila.pressed.connect(func():
			_indicador_abierto = "" if abierto else clave
			_reconstruir(true))
		_contenido.add_child(fila)
		if abierto:
			var serie := Demografia.serie(codigo, clave)
			if serie.size() >= 2:
				var g := GraficoSerie.new()
				g.serie = serie
				g.anio = Estado.anio
				g.clave = "valor"
				g.logaritmica = bool(ind.get("log", false))
				g.formato = func(x: float) -> String: return Demografia.texto_valor(x, clave)
				g.tooltip_text = tr("%s de %s") % [ind["nombre"], Demografia.nombre(codigo)]
				_contenido.add_child(g)
			_nota(tr("%s Fuente: %s, vía Our World in Data (CC BY 4.0).") % [ind.get("descripcion", ""), ind["fuente"]])


# ---------------------------------------------------------------------------------------------------------------
# Fichas


func _construir_ficha(tipo: String, id: Variant) -> void:
	if tipo == "entidad":
		_ficha_entidad(int(id))
		return
	if tipo == "pleiades":
		_ficha_pleiades(int(id))
		return
	var el := Enciclopedia.elemento(tipo, str(id))
	if el.is_empty():
		_titulo.text = tr("No encontrado")
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
		var editar := _boton_texto(tr("Editar esta ficha"), "editar")
		editar.tooltip_text = tr("Abrir en el editor de la enciclopedia")
		editar.pressed.connect(func(): Estado.editor_pedido.emit(tipo, str(id)))
		_contenido.add_child(editar)


func _ficha_fuente(f: Dictionary) -> void:
	var tipo := tr("Fuente primaria") if f.get("tipo", "") == "primaria" else tr("Fuente secundaria")
	if f.get("tipo", "") != "primaria":
		_franja.color = TemaUI.color("secundaria")
	_titulo.text = f.get("titulo", "")
	_subtitulo.text = "%s · %s" % [tipo, _mayus(_nombre_de(NOMBRES_GENERO, f.get("genero", "")))]
	var e: Dictionary = f.get("escrita", {})
	var lineas: Array = []
	if f.get("autor"):
		lineas.append(tr("[b]Autor:[/b] %s") % _enlace_persona(f.get("autor_id"), str(f["autor"])))
	if f.get("titulo_original"):
		lineas.append(tr("[b]Título original:[/b] [i]%s[/i]") % f["titulo_original"])
	var cuando := Fechas.rango(f["_desde"], f["_hasta"])
	lineas.append(tr("[b]Escrita:[/b] %s%s, %s") % ["c. " if e.get("aprox", false) else "", cuando, e.get("lugar", tr("lugar desconocido"))])
	var trata: Dictionary = f.get("trata", {})
	if not trata.is_empty():
		var nombres: Array = []
		for r in trata.get("regiones", []):
			nombres.append(Enciclopedia.regiones.get(r, {}).get("nombre", r))
		lineas.append(tr("[b]Trata sobre:[/b] %s, %s") % [", ".join(nombres), Fechas.rango(int(trata.get("desde", 0)), int(trata.get("hasta", 0)))])
	if f.get("idioma_original"):
		lineas.append(tr("[b]Idioma:[/b] %s") % f["idioma_original"])
	if f.get("soporte"):
		lineas.append(tr("[b]Soporte:[/b] %s") % f["soporte"])
	lineas.append(tr("[b]Confianza en la datación:[/b] %s") % _nombre_de(NOMBRES_CONFIANZA, f.get("confianza", "—")))
	_parrafo("\n".join(lineas), true)
	if f.get("resumen"):
		_seccion(tr("De qué se trata"))
		_parrafo(f["resumen"])
	if f.get("por_que_importa"):
		_seccion(tr("Por qué leerla"))
		_parrafo(f["por_que_importa"])
	var leer: Array = f.get("leer", [])
	if not leer.is_empty():
		_seccion(tr("Leer"))
		for l in leer:
			var b := _boton_texto("%s (%s)" % [l.get("titulo", tr("Texto")), str(l.get("idioma", "")).to_upper()], "enlace")
			var url: String = l["url"]
			b.tooltip_text = url
			b.pressed.connect(func(): Estado.abrir_url(url))
			var copia := Enciclopedia.copia_archivada(url)
			if copia == "":
				_contenido.add_child(b)
				continue
			# Al lado, la copia de la Wayback Machine, por si el original no abre.
			var fila := HBoxContainer.new()
			fila.add_theme_constant_override("separation", 4)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			fila.add_child(b)
			var c := _boton_texto(tr("Copia"), "enlace")
			c.size_flags_horizontal = Control.SIZE_SHRINK_END
			c.clip_text = false
			c.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			c.tooltip_text = tr("Copia archivada en la Wayback Machine, por si el original no abre:\n%s") % copia
			c.pressed.connect(func(): Estado.abrir_url(copia))
			fila.add_child(c)
			_contenido.add_child(fila)
	var ir := _boton_texto(tr("Ver dónde y cuándo se escribió"), "ir")
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
		lineas.append(tr("[b]Nació:[/b] %s%s, %s") % ["c. " if n.get("aprox", false) else "", Fechas.texto(int(n.get("anio", 0))), n.get("lugar", "?")])
	if not m.is_empty() and m.get("anio") != null:
		lineas.append(tr("[b]Murió:[/b] %s%s, %s") % ["c. " if m.get("aprox", false) else "", Fechas.texto(int(m.get("anio", 0))), m.get("lugar", "?")])
	_parrafo("\n".join(lineas), true)
	_parrafo(str(p.get("resumen", "")))
	var obras: Array = p.get("obras", [])
	if not obras.is_empty():
		_seccion(tr("Obras"))
		for id in obras:
			var f: Dictionary = Enciclopedia.fuentes.get(id, {})
			if not f.is_empty():
				_contenido.add_child(_tarjeta_fuente(f))
	var ir := _boton_texto(tr("Ver en el mapa"), "ir")
	ir.pressed.connect(func():
		var anio := Enciclopedia.anio_en_activo(p, clampi(int(p["_desde"]) + 30, Estado.ANIO_MIN, Estado.ANIO_MAX))
		Estado.fijar_anio(anio)
		if p.has("_px"):
			Estado.enfocar(Enciclopedia.px_en(p, anio), 2.5))
	_contenido.add_child(ir)
	_bloque_wikipedia(p.get("wikipedia", {}))


func _ficha_hecho(h: Dictionary) -> void:
	_titulo.text = h.get("titulo", "")
	_subtitulo.text = "%s · %s%s · %s" % [_mayus(_nombre_de(NOMBRES_TIPO_HECHO, h.get("tipo", ""))), "c. " if h.get("aprox", false) else "", Fechas.rango(h["_desde"], h["_hasta"]), h.get("lugar", "")]
	_parrafo(str(h.get("resumen", "")))
	var fs: Array = h.get("fuentes", [])
	if not fs.is_empty():
		_seccion(tr("Fuentes que lo documentan"))
		for id in fs:
			var f: Dictionary = Enciclopedia.fuentes.get(id, {})
			if not f.is_empty():
				_contenido.add_child(_tarjeta_fuente(f))
	var ir := _boton_texto(tr("Ir a ese momento y lugar"), "ir")
	ir.pressed.connect(func():
		Estado.fijar_anio(h["_desde"])
		if h.has("_px"):
			Estado.enfocar(h["_px"], 2.2))
	_contenido.add_child(ir)
	_bloque_wikipedia(h.get("wikipedia", {}))


func _ficha_lugar(l: Dictionary) -> void:
	_titulo.text = l.get("nombre", "")
	var hasta := tr("hoy") if l.get("abandono") == null else Fechas.texto(int(l["abandono"]))
	_subtitulo.text = "%s · %s%s – %s" % [_mayus(_nombre_de(NOMBRES_TIPO_LUGAR, l.get("tipo", ""))), "c. " if l.get("aprox", false) else "", Fechas.texto(l["_desde"]), hasta]
	_parrafo(str(l.get("resumen", "")))
	var ir := _boton_texto(tr("Ver en el mapa"), "ir")
	ir.pressed.connect(func():
		var u := DatosMapa.unidad_en(l["_px"])
		Estado.enfocar(l["_px"], 2.5)
		if u > 0:
			Estado.seleccionar_lugar(u, l["_px"]))
	_contenido.add_child(ir)
	var pid := Pleiades.de_lugar(str(l["id"]))
	if pid >= 0:
		_bloque_pleiades(pid, str(l.get("nombre", "")), false)
	_bloque_wikipedia(l.get("wikipedia", {}))


## Un lugar de Pleiades: lo que hay en los datos (nombre, categoría, años) y, en vivo, su descripción, sus nombres
## antiguos y el resumen de Wikipedia si Pleiades lo enlaza.
func _ficha_pleiades(id: int) -> void:
	var i := Pleiades.indice(id)
	if i < 0:
		_titulo.text = tr("No encontrado")
		_subtitulo.text = "Pleiades %d" % id
		return
	_franja.color = Pleiades.color_categoria(i)
	_titulo.text = Pleiades.nombre(i)
	var hasta := tr("hoy") if Pleiades.hasta[i] >= Estado.ANIO_MAX else Fechas.texto(Pleiades.hasta[i])
	_subtitulo.text = "%s · %s – %s" % [_mayus(Pleiades.nombre_categoria(i)), Fechas.texto(Pleiades.desde[i]), hasta]
	_nota(tr("Lugar antiguo del atlas Pleiades. Los años son los de los períodos en que está atestiguado, no los de su fundación o su abandono."))
	var ir := _boton_texto(tr("Ver en el mapa"), "ir")
	ir.pressed.connect(func():
		Estado.fijar_anio(clampi(Estado.anio, Pleiades.desde[i], Pleiades.hasta[i]))
		Estado.enfocar(Pleiades.px[i], maxf(CapaPleiades.ZOOM_NOMBRES, 4.5)))
	_contenido.add_child(ir)
	_bloque_pleiades(id, Pleiades.nombre(i), true)


## Lo que se pide en vivo a Pleiades: descripción, nombres antiguos y, si `con_wikipedia`, el resumen de Wikipedia
## que enlaza. Va en la ficha de un lugar de Pleiades y en la de un lugar de la enciclopedia unido a uno.
func _bloque_pleiades(id: int, nombre: String, con_wikipedia: bool) -> void:
	var token := _token
	_seccion("Pleiades")
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_contenido.add_child(caja)
	var cargando := Label.new()
	cargando.theme_type_variation = "Suave"
	cargando.text = tr("Buscando la ficha…")
	caja.add_child(cargando)
	var d := await Wiki.pleiades(id)
	if token != _token or not is_instance_valid(caja):
		return
	cargando.queue_free()
	var credito := tr("De «[url=%s]%s[/url]», Pleiades (CC BY 3.0).") % [Pleiades.url(id), nombre]
	var gris := TemaUI.color("texto_suave").to_html(false)
	if d.is_empty():
		var l := Label.new()
		l.theme_type_variation = "Suave"
		l.text = tr("No se pudo traer la ficha (¿sin conexión?).")
		caja.add_child(l)
		var enlace := RichTextLabel.new()
		enlace.bbcode_enabled = true
		enlace.fit_content = true
		enlace.text = "[color=#%s][font_size=14]%s[/font_size][/color]" % [gris, credito]
		enlace.meta_clicked.connect(_al_click_meta)
		caja.add_child(enlace)
		return
	var partes: Array = []
	if str(d.get("descripcion", "")) != "":
		partes.append(str(d["descripcion"]) + (" " + tr("(en inglés)") if not Idioma.ingles() else ""))
	var nombres: Array = []
	for n in d.get("nombres", []):
		var texto := str(n["nombre"]) if str(n["nombre"]) != "" else str(n["transliterado"])
		if str(n["transliterado"]) != "" and str(n["transliterado"]) != texto:
			texto += " (%s)" % str(n["transliterado"]).get_slice(",", 0).strip_edges()
		if str(n["idioma"]) != "":
			texto += " [color=#%s]%s[/color]" % [gris, n["idioma"]]
		if not nombres.has(texto):
			nombres.append(texto)
	if not nombres.is_empty():
		partes.append("[b]%s[/b] %s" % [tr("Nombres:"), ", ".join(nombres.slice(0, 12))])
	partes.append("[color=#%s][font_size=14]%s[/font_size][/color]" % [gris, credito])
	var texto_ficha := RichTextLabel.new()
	texto_ficha.bbcode_enabled = true
	texto_ficha.fit_content = true
	texto_ficha.scroll_active = false
	texto_ficha.selection_enabled = true
	texto_ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_ficha.text = "\n\n".join(partes)
	texto_ficha.meta_clicked.connect(_al_click_meta)
	caja.add_child(texto_ficha)
	if con_wikipedia and str(d.get("wikipedia", "")) != "":
		_bloque_wikipedia({"en": str(d["wikipedia"])})


func _ficha_region(r: Dictionary) -> void:
	_titulo.text = r.get("nombre", "")
	_subtitulo.text = tr("Región de estudio")
	_parrafo(str(r.get("resumen", "")))
	var ext: Variant = r.get("extendida")
	if ext is Dictionary:
		_ficha_extendida(ext)
	var ir := _boton_texto(tr("Ver en el mapa"), "ir")
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
		_seccion(tr("Referencias"))
		_parrafo("\n".join(refs), true)
	var ia: Variant = ext.get("ia")
	var rev: Variant = ext.get("revision")
	if ia is Dictionary:
		_nota(tr("Redactada con IA (%s) a partir de las fuentes citadas%s.") % [ia.get("modelo", "?"),
			tr("; revisada por una persona el %s") % rev.get("fecha") if rev is Dictionary else tr(", sin revisión humana todavía")])


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
		_parrafo(tr("[b]Familia mayor:[/b] %s") % " › ".join(cadena), true)
	if f.get("nota"):
		_nota(str(f["nota"]))
	var hijas: Array = f["_hijas"]
	if not hijas.is_empty():
		_seccion(tr("Incluye"))
		for h in hijas:
			var hf := Enciclopedia.familia(h)
			var n_regiones := {}
			for e in Enciclopedia.presencia_familia(h):
				n_regiones[e["region"]] = true
			var detalle := tr("sin datos en el mapa") if n_regiones.is_empty() else \
				tr_n("%d región", "%d regiones", n_regiones.size()) % n_regiones.size()
			var fila := _fila_color(Enciclopedia.color_familia(capa, hf["id"]), hf["nombre"], detalle, false)
			var hc: String = h
			fila.pressed.connect(func(): Estado.pedir_ficha("familia", hc))
			_contenido.add_child(fila)

	var pres := Enciclopedia.presencia_familia(clave)
	for e in pres:
		e["color"] = Enciclopedia.color_familia(capa, e["familia"])
	_seccion(tr("En %s") % Fechas.texto(anio))
	var ahora := pres.filter(func(e): return e["desde"] <= anio and anio <= e["hasta"])
	ahora.sort_custom(func(a, b): return Enciclopedia.ORDEN_PESO.get(a["peso"], 3) < Enciclopedia.ORDEN_PESO.get(b["peso"], 3))
	if ahora.is_empty():
		_nota(tr("No aparece en las regiones cargadas en este año."))
		var cerca := _anio_mas_cercano(pres, anio)
		if cerca != anio:
			var b := _boton_texto(tr("Ir a %s, cuando sí aparece") % Fechas.texto(cerca), "ir")
			b.pressed.connect(func(): Estado.fijar_anio(cerca))
			_contenido.add_child(b)
	for e in ahora:
		var r: Dictionary = Enciclopedia.regiones[e["region"]]
		var fila := _fila_color(e["color"], r["nombre"], "%s · %s" % [_peso(e["peso"]), e["nombre"]], e["peso"] == "mayoritaria")
		fila.tooltip_text = tr("%s: %s, %s\nClic: ver la región en el mapa") % [r["nombre"], e["nombre"], e["rango"]]
		fila.pressed.connect(func(): Estado.enfocar((r["_caja"] as Rect2).get_center(), 0.0))
		_contenido.add_child(fila)
	var modo: String = Enciclopedia.MODO_DE_CAPA[capa]
	if Estado.modo != modo:
		var b := _boton_texto(tr("Ver en el mapa (modo %s)") % tr(Estado.MODOS[modo][0]).to_lower(), "ir")
		b.pressed.connect(func(): Estado.fijar_modo(modo))
		_contenido.add_child(b)
	elif Enciclopedia.indice_familia(clave) <= 0 and not pres.is_empty():
		_nota(tr("Esta familia no se pinta directo en el mapa: sus áreas son las de las familias que incluye, cada una con su color."))

	if not pres.is_empty():
		_seccion(tr("A lo largo del tiempo"))
		var barras := BarrasFamilia.new()
		barras.configurar(pres, color, anio)
		_contenido.add_child(barras)
		_nota(tr("Más intenso: mayoritaria; más claro: importante o minoritaria. Clic en las barras para ir a ese año."))
		var notas: Array = []
		for e in pres:
			if e["nota"] != "":
				notas.append("[b]%s[/b], %s: %s" % [Enciclopedia.regiones[e["region"]]["nombre"], e["rango"], e["nota"]])
		if not notas.is_empty():
			_seccion(tr("Notas"))
			_parrafo("\n".join(notas))
	else:
		_nota({"religiones": tr("Todavía no hay regiones cargadas con esta religión."), "culturas": tr("Todavía no hay regiones cargadas con esta cultura."),
			"idiomas": tr("Todavía no hay regiones cargadas con este idioma.")}.get(capa, ""))

	var fs := Enciclopedia.fuentes_de_familia(clave)
	if not fs.is_empty():
		_seccion(tr("Fuentes de esas regiones y épocas"))
		for fu in fs.slice(0, 6):
			_contenido.add_child(_tarjeta_fuente(fu))
		if fs.size() > 6:
			_nota(tr("Y %d más en la pestaña Fuentes de cada región.") % (fs.size() - 6))
	_bloque_wikipedia(f.get("wikipedia", {}))


func _ficha_entidad(i: int) -> void:
	if i < 0 or i >= DatosMapa.entidades.size():
		_titulo.text = tr("No encontrado")
		_subtitulo.text = tr("entidad %d") % i
		return
	var e: Dictionary = DatosMapa.entidades[i]
	var desde := int(e["a"])
	var hasta := int(e["b"])
	var anio := Estado.anio
	var color := DatosMapa.color_entidad(i)
	_franja.color = color
	_titulo.text = DatosMapa.nombre_entidad(i)
	_subtitulo.text = tr("Entidad política · %s") % Fechas.rango(desde, hasta)
	if str(e.get("m", "")) != "":
		_parrafo(tr("Parte de: %s") % DatosMapa.nombre_cliopatria(str(e["m"])), true)
	var serie := DatosMapa.territorio_de_entidad(i)
	var pico := [desde, 0.0]
	for punto in serie:
		if float(punto[1]) > float(pico[1]):
			pico = punto
	var grafico := GraficoTerritorio.new()
	grafico.configurar(serie, color, desde, hasta)
	var ahora := grafico.valor_en(anio) if desde <= anio and anio <= hasta else 0.0
	if ahora > 0.0:
		_parrafo(tr("[b]En %s:[/b] ~%s km² (resaltado en el mapa)") % [Fechas.texto(anio), GraficoSerie._numero(ahora)], true)
		var ir := _boton_texto(tr("Centrar el mapa en su territorio"), "ir")
		ir.pressed.connect(func():
			var c := DatosMapa.centro_entidad(i)
			if c.x >= 0:
				Estado.enfocar(c, 0.0))
		_contenido.add_child(ir)
	else:
		_nota(tr("En %s no tiene territorio en los datos.") % Fechas.texto(anio))
	if not Estado.modo in ["politico", "terreno"]:
		var b := _boton_texto(tr("Ver en el mapa político"), "ir")
		b.pressed.connect(func(): Estado.fijar_modo("politico"))
		_contenido.add_child(b)

	_seccion(tr("Territorio a lo largo del tiempo"))
	_contenido.add_child(grafico)
	if float(pico[1]) > 0.0:
		_nota(tr("Máxima extensión en los datos: ~%s km², hacia %s Clic en el gráfico para ir a un año.") % [
			GraficoSerie._numero(float(pico[1])), _con_punto(Fechas.texto(int(pico[0])))])
		if int(pico[0]) != anio:
			var b := _boton_texto(tr("Ir a %s, su máxima extensión") % Fechas.texto(int(pico[0])), "ir")
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
		_parrafo(tr("Fronteras de Cliopatria (Seshat). %s") % " · ".join(links), true)

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
		_seccion(tr("Lugares de su territorio"))
		lugares.sort_custom(func(a, b): return int(a.get("importancia", 1)) > int(b.get("importancia", 1)))
		for l in lugares.slice(0, 10):
			var fila := _fila_color(TemaUI.color("texto"), l["nombre"], _mayus(_nombre_de(NOMBRES_TIPO_LUGAR, l.get("tipo", ""))), false)
			var id: String = l["id"]
			fila.pressed.connect(func(): Estado.pedir_ficha("lugar", id))
			_contenido.add_child(fila)
	if not hechos.is_empty():
		_seccion(tr("Hechos en su territorio"))
		hechos.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
		for h in hechos.slice(0, 10):
			var fila := _fila_color(TemaUI.color("hecho"), h["titulo"], Fechas.texto(h["_desde"]), false)
			var id: String = h["id"]
			fila.pressed.connect(func(): Estado.pedir_ficha("hecho", id))
			_contenido.add_child(fila)
	if not fuentes.is_empty():
		_seccion(tr("Fuentes escritas en su territorio"))
		fuentes.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
		for f in fuentes.slice(0, 6):
			_contenido.add_child(_tarjeta_fuente(f))
		if fuentes.size() > 6:
			_nota(tr("Y %d más.") % (fuentes.size() - 6))
	if lugares.is_empty() and hechos.is_empty() and fuentes.is_empty():
		_nota(tr("Todavía no hay lugares, hechos ni fuentes de la enciclopedia dentro de su territorio."))
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
	var partes: Array = [tr("Primaria") if primaria else tr("Secundaria")]
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
	ficha.text = tr("Ficha")
	ficha.focus_mode = Control.FOCUS_ALL
	var id: String = f["id"]
	ficha.pressed.connect(func(): Estado.pedir_ficha("fuente", id))
	botones.add_child(ficha)
	var leer: Array = f.get("leer", [])
	if not leer.is_empty():
		var b := Button.new()
		b.text = tr("Leer")
		b.icon = IconosUI.textura("enlace", 14, TemaUI.color("acento"))
		b.focus_mode = Control.FOCUS_ALL
		var url: String = leer[0]["url"]
		b.tooltip_text = url
		b.pressed.connect(func(): Estado.abrir_url(url))
		botones.add_child(b)
	if f.has("_px"):
		var ir := IconosUI.boton("ir", tr("Ver dónde y cuándo se escribió"), 16)
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
	cargando.text = tr("Buscando el artículo…")
	caja.add_child(cargando)
	var r := await Wiki.resumen(titulos)
	if token != _token or not is_instance_valid(caja):
		return
	cargando.queue_free()
	if r.is_empty():
		var l := Label.new()
		l.theme_type_variation = "Suave"
		l.text = tr("No se pudo traer el artículo (¿sin conexión?).")
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
	var credito := tr("De «[url=%s]%s[/url]», Wikipedia en español (CC BY-SA 4.0).") if r["idioma"] == "es" else \
		tr("De «[url=%s]%s[/url]», Wikipedia en inglés (CC BY-SA 4.0).")
	texto.text = "%s\n[color=#%s][font_size=14]%s[/font_size][/color]" % [
		r["texto"], TemaUI.color("texto_suave").to_html(false), credito % [r["url"], r["titulo"]]]
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
		return tr("fechas desconocidas")
	var n: Variant = p.get("nacimiento", {}).get("anio") if p.get("nacimiento") is Dictionary else null
	var m: Variant = p.get("muerte", {}).get("anio") if p.get("muerte") is Dictionary else null
	if n != null and m != null:
		return Fechas.rango(int(n), int(m))
	if n == null and m == null:
		return tr("activo c. %s") % Fechas.rango(p["_desde"], p["_hasta"])
	if n == null:
		return tr("m. %s") % Fechas.texto(int(m))
	return tr("n. %s") % Fechas.texto(int(n))


## Para cerrar una oración con una fecha: «1400 a. C.» ya trae su punto; «1200» no.
func _con_punto(s: String) -> String:
	return s if s.ends_with(".") else s + "."


func _mayus(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## El nombre de un valor cerrado del esquema (un género, un tipo), traducido; si no está en la lista, el valor mismo.
func _nombre_de(nombres: Dictionary, valor: Variant) -> String:
	var v := str(valor)
	return tr(nombres[v]) if nombres.has(v) else v.replace("-", " ")


func _peso(peso: String) -> String:
	return _nombre_de(Enciclopedia.NOMBRE_PESO, peso)


func _numero(x: float) -> String:
	var n := int(round(x))
	if n >= 1000000:
		return tr("%s millones") % Idioma.decimal("%.1f" % (n / 1000000.0))
	return Idioma.miles(n)
