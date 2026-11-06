class_name LineaTiempo
extends PanelContainer
## Barra inferior: el año actual, la era, la reproducción y la pista con eras, hechos y fuentes.

const VELOCIDADES := [1, 5, 10, 25, 50, 100]

var pista: PistaTiempo
var _anio_lbl: Label
var _era_lbl: Label
var _entrada: LineEdit
var _play: Button
var _velocidad: OptionButton
var _reproduciendo := false
var _acumulado := 0.0


func _ready() -> void:
	theme_type_variation = "Franja"
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -128
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	add_child(fila)

	# Año y era
	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(250, 0)
	izq.add_theme_constant_override("separation", 0)
	fila.add_child(izq)
	_anio_lbl = Label.new()
	_anio_lbl.theme_type_variation = "Anio"
	izq.add_child(_anio_lbl)
	_era_lbl = Label.new()
	_era_lbl.theme_type_variation = "Suave"
	_era_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_era_lbl.custom_minimum_size = Vector2(250, 0)
	izq.add_child(_era_lbl)

	# Controles
	var centro := VBoxContainer.new()
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(centro)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 2)
	centro.add_child(botones)
	botones.add_child(_boton_salto("atras2", -100, "100 años atrás"))
	botones.add_child(_boton_salto("atras1", -10, "10 años atrás (Mayús: 1 año)"))
	_play = IconosUI.boton("play", "Reproducir (barra espaciadora)", 22, false)
	_play.custom_minimum_size = Vector2(46, 36)
	_play.pressed.connect(alternar_reproduccion)
	botones.add_child(_play)
	botones.add_child(_boton_salto("adelante1", 10, "10 años adelante (Mayús: 1 año)"))
	botones.add_child(_boton_salto("adelante2", 100, "100 años adelante"))
	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 6)
	centro.add_child(abajo)
	_velocidad = OptionButton.new()
	for v in VELOCIDADES:
		_velocidad.add_item("%d años/s" % v)
	_velocidad.select(2)
	_velocidad.focus_mode = Control.FOCUS_ALL
	_velocidad.tooltip_text = "Velocidad de reproducción"
	abajo.add_child(_velocidad)
	_entrada = LineEdit.new()
	_entrada.placeholder_text = "Ir a año…"
	_entrada.tooltip_text = "Escribí un año: «-1350», «1350 a. C.» o «1810»"
	_entrada.custom_minimum_size = Vector2(118, 0)
	_entrada.text_submitted.connect(_ir_a_texto)
	abajo.add_child(_entrada)

	# Pista
	pista = PistaTiempo.new()
	pista.anio_elegido.connect(Estado.fijar_anio)
	fila.add_child(pista)

	Estado.anio_cambiado.connect(_actualizar)
	Estado.lugar_seleccionado.connect(_al_seleccionar)
	_actualizar(Estado.anio)


func _boton_salto(icono: String, delta: int, ayuda: String) -> Button:
	var b := IconosUI.boton(icono, ayuda, 18, false)
	b.custom_minimum_size = Vector2(38, 36)
	b.pressed.connect(func():
		var d := delta
		if Input.is_key_pressed(KEY_SHIFT):
			d = signi(delta)
		Estado.fijar_anio(Fechas.sumar(Estado.anio, d)))
	return b


func enfocar_anio() -> void:
	_entrada.grab_focus()
	_entrada.select_all()


func alternar_reproduccion() -> void:
	_reproduciendo = not _reproduciendo
	_acumulado = 0.0
	_play.icon = IconosUI.textura("pausa" if _reproduciendo else "play", 22, TemaUI.color("texto"))
	OS.low_processor_usage_mode = not _reproduciendo and not Estado.calidad()["agua_animada"]


func _process(delta: float) -> void:
	if not _reproduciendo:
		return
	_acumulado += VELOCIDADES[_velocidad.selected] * delta
	if _acumulado >= 1.0:
		var pasos := int(_acumulado)
		_acumulado -= pasos
		var nuevo := Fechas.sumar(Estado.anio, pasos)
		if nuevo >= Estado.ANIO_MAX:
			nuevo = Estado.ANIO_MAX
			alternar_reproduccion()
		Estado.fijar_anio(nuevo)


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo and k.keycode == KEY_SPACE:
		return
	match k.keycode:
		KEY_SPACE:
			alternar_reproduccion()
		KEY_PAGEUP, KEY_PERIOD:
			Estado.fijar_anio(Fechas.sumar(Estado.anio, 1 if k.shift_pressed else 10))
		KEY_PAGEDOWN, KEY_COMMA:
			Estado.fijar_anio(Fechas.sumar(Estado.anio, -1 if k.shift_pressed else -10))
		_:
			return
	get_viewport().set_input_as_handled()


func _ir_a_texto(texto: String) -> void:
	var t := texto.strip_edges().to_lower().replace(".", "").replace(" ", "")
	var negativo := t.begins_with("-") or t.contains("ac") or t.contains("aC".to_lower())
	var digitos := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digitos += ch
	if digitos.is_empty():
		return
	var anio := int(digitos)
	Estado.fijar_anio(-anio if negativo else anio)
	_entrada.text = ""
	_entrada.release_focus()


func _actualizar(anio: int) -> void:
	_anio_lbl.text = Fechas.texto(anio)
	var partes: Array = [Fechas.siglo(anio)]
	for e in pista.eras:
		if int(e[0]) <= anio and anio <= int(e[1]):
			partes.append(str(e[2]))
			break
	_era_lbl.text = " · ".join(partes)


func _al_seleccionar(unidad: int, _px: Vector2) -> void:
	if unidad <= 0:
		pista.fijar_eras([], "")
		_actualizar(Estado.anio)
		return
	for id in Enciclopedia.regiones_de_unidad(unidad):
		var r: Dictionary = Enciclopedia.regiones[id]
		var eras: Array = r.get("eras", [])
		if not eras.is_empty():
			var lista: Array = []
			for e in eras:
				lista.append([int(e["desde"]), int(e["hasta"]), e["nombre"]])
			pista.fijar_eras(lista, "Eras de %s" % r["nombre"])
			_actualizar(Estado.anio)
			return
	pista.fijar_eras([], "")
	_actualizar(Estado.anio)
