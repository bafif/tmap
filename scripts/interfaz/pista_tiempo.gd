class_name PistaTiempo
extends Control
## La pista de la línea de tiempo: eras, marcas de siglos, hechos y fuentes, y el año actual.
## Rueda del mouse = acercar o alejar el tramo visible; arrastrar = elegir año; botón derecho = desplazar el tramo.

signal anio_elegido(anio: int)

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
var eras: Array = ERAS_GLOBALES
var titulo_eras := "Periodización europea, orientativa"
var _arrastrando := false
var _desplazando := false
var _hover_x := -1.0


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


func fijar_eras(nuevas: Array, titulo: String) -> void:
	eras = nuevas if not nuevas.is_empty() else ERAS_GLOBALES
	titulo_eras = titulo if not nuevas.is_empty() else "Periodización europea, orientativa"
	if not nuevas.is_empty():
		# Acercar la pista alrededor del año actual para que se lean las eras locales.
		var l := lineal(Estado.anio)
		vista_desde = l - 1200.0
		vista_hasta = l + 1200.0
		_ajustar_vista()
	tooltip_text = "%s.\nArrastrá para elegir el año · rueda: acercar o alejar · botón derecho: desplazar · doble click: todo el período." % titulo_eras
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var centro := vista_desde + b.position.x / size.x * (vista_hasta - vista_desde)
			var f := 0.8 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.25
			vista_desde = centro - (centro - vista_desde) * f
			vista_hasta = centro + (vista_hasta - centro) * f
			_ajustar_vista()
			queue_redraw()
			accept_event()
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_arrastrando = b.pressed
			if b.pressed:
				if b.double_click:
					vista_desde = lineal(Estado.ANIO_MIN)
					vista_hasta = lineal(Estado.ANIO_MAX)
					queue_redraw()
				anio_elegido.emit(_anio_en(b.position.x))
			accept_event()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			_desplazando = b.pressed
			accept_event()
	elif ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		_hover_x = m.position.x
		if _arrastrando:
			anio_elegido.emit(_anio_en(m.position.x))
		elif _desplazando:
			var d := -m.relative.x / size.x * (vista_hasta - vista_desde)
			vista_desde += d
			vista_hasta += d
			_ajustar_vista()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_x = -1.0
		queue_redraw()


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

	# Año bajo el mouse
	if _hover_x >= 0.0 and not _arrastrando:
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

