class_name PistaTiempo
extends Control
## La pista de la línea de tiempo: eras, marcas de siglos, hechos y fuentes, y el año actual.
## Clic = elegir el año; arrastrar (o el botón derecho, Mayús + rueda, la rueda horizontal o dos dedos en el trackpad) =
## correr el tramo visible sin cambiar la escala; arrastrar la línea del año = moverlo; rueda = acercar o alejar.
## Con el dedo: tocar elige, arrastrar corre y dos dedos acercan o alejan.
## Las marcas de fuentes y hechos muestran su nombre al pasar el mouse y abren su ficha con un clic.

signal anio_elegido(anio: int)

## En español: se traducen con tr() al usarlas (_eras_globales).
const ERAS_GLOBALES := [
	[-3400, -1201, "Edad del Bronce"],
	[-1200, -801, "Edad del Hierro"],
	[-800, 475, "Antigüedad clásica"],
	[476, 1491, "Edad Media"],
	[1492, 1788, "Edad Moderna"],
	[1789, 2024, "Edad Contemporánea"],
]
const PASOS := [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]
const TRAMO_MIN := 40.0

var vista_desde := float(Estado.ANIO_MIN)
var vista_hasta := float(Estado.ANIO_MAX)
var eras: Array = _eras_globales()
var titulo_eras := tr("Periodización europea, orientativa")
## Qué hace el arrastre en curso: "" (nada), "pendiente" (todavía puede ser un clic), "anio" (mueve el año, empezó
## sobre su línea) o "desplazar" (corre el tramo).
var _modo := ""
var _inicio_x := 0.0
## Dedos apoyados en la pista (índice → x) y la distancia entre los dos primeros, para acercar con dos dedos.
var _toques := {}
var _pellizco_dist := 0.0
## Mientras dura un pellizco, el mouse emulado con el primer dedo no corre la pista ni elige año al soltarse.
var _gesto := false
var _hover_x := -1.0
## Marcas bajo el mouse: [{tipo, id, x}], la más cercana primero.
var _hover_marcas: Array = []
const RADIO_MARCA := 5.0
## Hasta cuántos píxeles de la línea del año un arrastre mueve el año (con el dedo, el doble).
const AGARRE_ANIO := 7.0
## Un arrastre más corto que esto todavía es un clic.
const UMBRAL_ARRASTRE := 5.0


func _init() -> void:
	custom_minimum_size = Vector2(300, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true


func _ready() -> void:
	fijar_eras([], "")
	Estado.anio_cambiado.connect(_al_cambiar_anio)
	resized.connect(queue_redraw)


func _al_cambiar_anio(_a: int) -> void:
	_seguir_anio()
	queue_redraw()


# Años lineales: el año 0 no existe, así que -1 y 1 quedan pegados.
static func lineal(anio: int) -> float:
	return float(anio) if anio < 0 else float(anio - 1)


static func desde_lineal(x: float) -> int:
	var a := int(round(x))
	return a if a < 0 else a + 1


func _x(anio: int) -> float:
	return (lineal(anio) - vista_desde) / (vista_hasta - vista_desde) * size.x


func _anio_en(x: float) -> int:
	var lin := vista_desde + x / maxf(size.x, 1.0) * (vista_hasta - vista_desde)
	return clampi(desde_lineal(lin), Estado.ANIO_MIN, Estado.ANIO_MAX)


func _seguir_anio() -> void:
	var l := lineal(Estado.anio)
	var tramo := vista_hasta - vista_desde
	if l < vista_desde or l > vista_hasta:
		vista_desde = l - tramo * 0.5
		vista_hasta = l + tramo * 0.5
		_ajustar_vista()


func _ajustar_vista() -> void:
	var minimo := lineal(Estado.ANIO_MIN)
	var maximo := lineal(Estado.ANIO_MAX)
	var tramo := clampf(vista_hasta - vista_desde, TRAMO_MIN, maximo - minimo)
	if vista_desde < minimo:
		vista_desde = minimo
	vista_hasta = vista_desde + tramo
	if vista_hasta > maximo:
		vista_hasta = maximo
		vista_desde = maximo - tramo


## Las eras de la periodización general, con el nombre en el idioma de la app.
func _eras_globales() -> Array:
	return ERAS_GLOBALES.map(func(e: Array) -> Array: return [e[0], e[1], tr(e[2])])


func fijar_eras(nuevas: Array, titulo: String) -> void:
	eras = nuevas if not nuevas.is_empty() else _eras_globales()
	titulo_eras = titulo if not nuevas.is_empty() else tr("Periodización europea, orientativa")
	if not nuevas.is_empty():
		# Acercar la pista alrededor del año actual para que se lean las eras locales.
		var l := lineal(Estado.anio)
		vista_desde = l - 1200.0
		vista_hasta = l + 1200.0
		_ajustar_vista()
	tooltip_text = tr("%s.\nClic: elegir el año · arrastrar: correr el período · arrastrar la línea del año: moverlo · rueda: acercar o alejar · Mayús + rueda: correr · doble clic: todo el período.") % titulo_eras
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		var emulado := b.device == InputEvent.DEVICE_ID_EMULATION
		if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT,
				MOUSE_BUTTON_WHEEL_RIGHT]:
			var paso := b.factor if b.factor > 0.0 else 1.0
			if b.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] or b.shift_pressed:
				# Mayús + rueda (o la rueda horizontal): correr el tramo un décimo, sin cambiar la escala.
				var hacia := 1.0 if b.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT] else -1.0
				_correr(hacia * 0.1 * paso * (vista_hasta - vista_desde))
			else:
				var f := 0.8 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
				_acercar(pow(f, paso), b.position.x)
			accept_event()
		elif b.button_index == MOUSE_BUTTON_LEFT:
			if _gesto:
				if not b.pressed:
					_modo = ""
				accept_event()
				return
			var marcas := marcas_en(b.position)
			if b.pressed and not b.double_click and not marcas.is_empty():
				var m: Dictionary = marcas[0]
				anio_elegido.emit(int(Enciclopedia.elemento(m["tipo"], m["id"])["_desde"]))
				Estado.pedir_ficha(m["tipo"], m["id"])
				accept_event()
				return
			if b.pressed:
				if b.double_click:
					vista_desde = lineal(Estado.ANIO_MIN)
					vista_hasta = lineal(Estado.ANIO_MAX)
					_modo = ""
					queue_redraw()
				elif absf(b.position.x - _x(Estado.anio)) <= AGARRE_ANIO * (2.0 if emulado else 1.0):
					# Sobre la línea del año: arrastrar mueve el año, como antes.
					_modo = "anio"
					anio_elegido.emit(_anio_en(b.position.x))
				else:
					_modo = "pendiente"
					_inicio_x = b.position.x
			else:
				if _modo == "pendiente":
					# Un clic (sin arrastrar): elegir ese año.
					anio_elegido.emit(_anio_en(b.position.x))
				_modo = ""
				_actualizar_cursor(b.position)
			accept_event()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			_modo = "desplazar" if b.pressed else ""
			accept_event()
	elif ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		_hover_x = m.position.x
		if _modo == "pendiente" and absf(m.position.x - _inicio_x) >= UMBRAL_ARRASTRE:
			_modo = "desplazar"
		if _modo == "anio":
			anio_elegido.emit(_anio_en(m.position.x))
		elif _modo == "desplazar" and not _gesto:
			_correr(-m.relative.x / size.x * (vista_hasta - vista_desde))
		_hover_marcas = [] if _modo != "" else marcas_en(m.position)
		_actualizar_cursor(m.position)
		queue_redraw()
	elif ev is InputEventPanGesture:
		# Dos dedos en el trackpad: hacia los costados corre el tramo.
		var g := ev as InputEventPanGesture
		_correr(g.delta.x * 0.02 * (vista_hasta - vista_desde))
		accept_event()
	elif ev is InputEventMagnifyGesture:
		var g := ev as InputEventMagnifyGesture
		_acercar(1.0 / g.factor, g.position.x)
		accept_event()
	elif ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			_toques[t.index] = t.position.x
			if _toques.size() >= 2:
				_gesto = true
				_modo = ""
				_pellizco_dist = 0.0
		else:
			_toques.erase(t.index)
			_pellizco_dist = 0.0
			if _toques.is_empty():
				_gesto = false
		accept_event()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if _toques.has(d.index):
			_toques[d.index] = d.position.x
			if _toques.size() >= 2:
				# Dos dedos: la distancia entre ellos acerca o aleja alrededor del punto medio.
				var xs: Array = _toques.values()
				var dist := absf(float(xs[0]) - float(xs[1]))
				if _pellizco_dist > 1.0 and dist > 1.0:
					_acercar(_pellizco_dist / dist, (float(xs[0]) + float(xs[1])) * 0.5)
				_pellizco_dist = dist
		accept_event()


## Corre el tramo visible `d` años lineales, sin cambiar la escala.
func _correr(d: float) -> void:
	vista_desde += d
	vista_hasta += d
	_ajustar_vista()
	queue_redraw()


## Acerca (f < 1) o aleja (f > 1) el tramo visible, con el año bajo `x` fijo.
func _acercar(f: float, x: float) -> void:
	var centro := vista_desde + x / maxf(size.x, 1.0) * (vista_hasta - vista_desde)
	vista_desde = centro - (centro - vista_desde) * f
	vista_hasta = centro + (vista_hasta - centro) * f
	_ajustar_vista()
	queue_redraw()


func _actualizar_cursor(pos: Vector2) -> void:
	if _modo == "desplazar":
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif _modo == "anio" or absf(pos.x - _x(Estado.anio)) <= AGARRE_ANIO:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif not _hover_marcas.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_x = -1.0
		_hover_marcas = []
		queue_redraw()


## Fuentes (franja de abajo) y hechos (rombos) que caen bajo un punto de la pista, la más cercana primero.
func marcas_en(pos: Vector2) -> Array:
	var y_base := size.y - 4.0
	var tabla: Dictionary = {}
	var tipo := ""
	if pos.y >= y_base - 15 and pos.y <= y_base + 3:
		tabla = Enciclopedia.fuentes
		tipo = "fuente"
	elif absf(pos.y - (y_base - 20)) <= 6.0:
		tabla = Enciclopedia.hechos
		tipo = "hecho"
	else:
		return []
	var out: Array = []
	for el in tabla.values():
		var x := _x(int(el["_desde"]))
		if absf(x - pos.x) <= RADIO_MARCA:
			out.append({"tipo": tipo, "id": el["id"], "x": x})
	out.sort_custom(func(a, b): return absf(a["x"] - pos.x) < absf(b["x"] - pos.x))
	return out


func _get_tooltip(pos: Vector2) -> String:
	var marcas := marcas_en(pos)
	if marcas.is_empty():
		return tooltip_text
	var lineas: Array = []
	for m in marcas.slice(0, 6):
		var el := Enciclopedia.elemento(m["tipo"], m["id"])
		var nombre: String = el.get("titulo", el.get("nombre", m["id"]))
		var tipo: String = tr("Hecho") if m["tipo"] == "hecho" else (tr("Fuente primaria") if el.get("tipo", "") == "primaria" else tr("Fuente secundaria"))
		lineas.append("%s · %s · %s" % [nombre, tipo, Fechas.texto(int(el["_desde"]))])
	if marcas.size() > 6:
		lineas.append(tr("y %d más (acercá la pista con la rueda)") % (marcas.size() - 6))
	lineas.append(tr("Clic: abrir la ficha de la primera") if marcas.size() > 1 else tr("Clic: abrir la ficha"))
	return "\n".join(lineas)


## El texto tal cual si entra en `ancho`; si no, recortado con «…»; vacío si no entran ni cuatro letras.
func _recortar(texto: String, fuente: Font, tam: int, ancho: float) -> String:
	if fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= ancho:
		return texto
	var n := texto.length() - 1
	while n >= 4:
		var corto := texto.substr(0, n).strip_edges() + "…"
		if fuente.get_string_size(corto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= ancho:
			return corto
		n -= 1
	return ""


func _draw() -> void:
	var w := size.x
	var h := size.y
	var fuente := TemaUI.fuente_titulo
	var fuente_t := TemaUI.fuente_texto
	var c_borde := TemaUI.color("borde")
	var c_suave := TemaUI.color("texto_suave")
	var c_texto := TemaUI.color("texto")
	var fondo := TemaUI.color("fondo2")
	draw_rect(Rect2(Vector2.ZERO, size), fondo.darkened(0.15))

	# Eras (franja superior)
	var alto_era := 22.0
	for i in eras.size():
		var e: Array = eras[i]
		var x0 := _x(int(e[0]))
		var x1 := _x(int(e[1]) + 1)
		if x1 < 0 or x0 > w:
			continue
		var tono := 0.06 if i % 2 == 0 else 0.0
		var c := fondo.lightened(0.08 + tono)
		var activa := int(e[0]) <= Estado.anio and Estado.anio <= int(e[1])
		if activa:
			c = c.lerp(TemaUI.color("acento"), 0.35)
		draw_rect(Rect2(x0, 0, x1 - x0, alto_era), c)
		draw_line(Vector2(x0, 0), Vector2(x0, alto_era), c_borde.darkened(0.3), 1.0)
		var visible_x0 := maxf(x0, 0.0)
		var visible_x1 := minf(x1, w)
		var texto_era := _recortar(str(e[2]).get_slice(" (", 0).to_upper(), fuente, 11, visible_x1 - visible_x0 - 8.0)
		if texto_era != "":
			draw_string(fuente, Vector2(visible_x0 + 4.0, 15.5), texto_era, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c_texto if activa else c_suave)
	draw_line(Vector2(0, alto_era), Vector2(w, alto_era), c_borde, 1.0)

	# Marcas de años
	var tramo := vista_hasta - vista_desde
	var paso := 1000
	for p in PASOS:
		if tramo / p <= 12.0:
			paso = p
			break
	var primero := int(floor(vista_desde / paso)) * paso
	var y_base := h - 4.0
	var lin := float(primero)
	while lin <= vista_hasta + paso:
		var anio := desde_lineal(lin)
		var x := _x(anio)
		if x >= -40 and x <= w + 40:
			draw_line(Vector2(x, alto_era + 1), Vector2(x, alto_era + 9), c_borde, 1.0)
			draw_string(fuente_t, Vector2(x + 3, alto_era + 22), Fechas.texto(anio), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c_suave)
			var sub := paso / 5.0
			if sub >= 1.0:
				for k in range(1, 5):
					var xs := x + k * sub / tramo * w
					draw_line(Vector2(xs, alto_era + 1), Vector2(xs, alto_era + 5), Color(c_borde, 0.5), 1.0)
		lin += paso

	# Fuentes (barras finas abajo) y hechos (rombos)
	var c_prim := TemaUI.color("primaria")
	var c_sec := TemaUI.color("secundaria")
	for f in Enciclopedia.fuentes.values():
		var x := _x(int(f["_desde"]))
		if x < 0 or x > w:
			continue
		var c: Color = c_prim if f.get("tipo", "") == "primaria" else c_sec
		draw_line(Vector2(x, y_base - 12), Vector2(x, y_base), Color(c, 0.85), 2.0)
	var c_hecho := TemaUI.color("hecho")
	for hh in Enciclopedia.hechos.values():
		var x := _x(int(hh["_desde"]))
		if x < 0 or x > w:
			continue
		var y := y_base - 20
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 4), Vector2(x + 4, y), Vector2(x, y + 4), Vector2(x - 4, y)]), c_hecho)

	# Marca bajo el mouse
	if not _hover_marcas.is_empty():
		var m: Dictionary = _hover_marcas[0]
		var ym := y_base - 6 if m["tipo"] == "fuente" else y_base - 20
		draw_circle(Vector2(m["x"], ym), 7.0, Color(TemaUI.color("titulo"), 0.9), false, 1.5)

	# Año bajo el mouse
	if _hover_x >= 0.0 and _modo != "anio":
		var a := _anio_en(_hover_x)
		draw_line(Vector2(_hover_x, alto_era), Vector2(_hover_x, h), Color(c_texto, 0.25), 1.0)
		var t := Fechas.texto(a)
		var tx := clampf(_hover_x + 6, 2, w - 90)
		draw_string(fuente_t, Vector2(tx, h - 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(c_texto, 0.8))

	# Año actual
	var xa := _x(Estado.anio)
	if xa >= -2 and xa <= w + 2:
		var acento := TemaUI.color("acento")
		draw_line(Vector2(xa, 0), Vector2(xa, h), Color(0, 0, 0, 0.4), 4.0)
		draw_line(Vector2(xa, 0), Vector2(xa, h), acento, 2.0)
		var y0 := alto_era
		draw_colored_polygon(PackedVector2Array([Vector2(xa - 7, y0 - 7), Vector2(xa + 7, y0 - 7), Vector2(xa, y0 + 3)]), acento)
		draw_polyline(PackedVector2Array([Vector2(xa - 7, y0 - 7), Vector2(xa + 7, y0 - 7), Vector2(xa, y0 + 3), Vector2(xa - 7, y0 - 7)]), Color(0, 0, 0, 0.6), 1.0)

