class_name GraficoTerritorio
extends Control
## En la ficha de una entidad política: su superficie a lo largo del tiempo, en escalones, con el año actual marcado.
## Al pasar el mouse se ve la superficie de ese año; un clic lleva a ese año.

var _serie: Array = []
var _color := Color.WHITE
var _a0 := 0
var _a1 := 1
var _maximo := 1.0
var _hover_x := -1.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 110)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Sin un texto, Godot no llama a _get_tooltip.
	tooltip_text = tr("Superficie a lo largo del tiempo")


## serie: [[año, km²], …] (lo que devuelve DatosMapa.territorio_de_entidad); desde y hasta: la vida de la entidad.
func configurar(serie: Array, color: Color, desde: int, hasta: int) -> void:
	_serie = serie
	_color = color
	_a0 = desde
	_a1 = maxi(hasta, desde + 1)
	_maximo = 1.0
	for p in serie:
		_maximo = maxf(_maximo, float(p[1]))
	var margen := maxi(10, (_a1 - _a0) / 20)
	_a0 = maxi(Estado.ANIO_MIN, _a0 - margen)
	_a1 = mini(Estado.ANIO_MAX, _a1 + margen)
	queue_redraw()


func _area() -> Rect2:
	return Rect2(8, 8, maxf(size.x - 16, 10), maxf(size.y - 30, 10))


func _x(anio: float) -> float:
	var a := _area()
	return a.position.x + (anio - _a0) / float(_a1 - _a0) * a.size.x


func _anio_en(x: float) -> int:
	var a := _area()
	return int(round(lerpf(_a0, _a1, clampf((x - a.position.x) / a.size.x, 0.0, 1.0))))


## Superficie en un año: la del último cambio anterior o igual.
func valor_en(anio: int) -> float:
	var v := 0.0
	for p in _serie:
		if int(p[0]) > anio:
			break
		v = float(p[1])
	return v


func _draw() -> void:
	var a := _area()
	var suave := TemaUI.color("texto_suave")
	var f := TemaUI.fuente_texto
	draw_rect(Rect2(Vector2.ZERO, size), Color(TemaUI.color("fondo2"), 0.6))
	if _serie.is_empty():
		return
	var y := func(v: float) -> float: return a.end.y - v / _maximo * a.size.y
	var poli := PackedVector2Array([Vector2(_x(float(_serie[0][0])), a.end.y)])
	var previo := 0.0
	for p in _serie:
		var x := clampf(_x(float(p[0])), a.position.x, a.end.x)
		poli.append(Vector2(x, y.call(previo)))
		poli.append(Vector2(x, y.call(float(p[1]))))
		previo = float(p[1])
	poli.append(Vector2(a.end.x, y.call(previo)))
	poli.append(Vector2(a.end.x, a.end.y))
	var contorno := poli.slice(1, poli.size() - 1)
	if poli.size() >= 3:
		draw_colored_polygon(poli, Color(_color, 0.35))
	if contorno.size() >= 2:
		draw_polyline(contorno, _color.lightened(0.15), 1.5)
	var xa := _x(float(Estado.anio))
	if xa >= a.position.x and xa <= a.end.x:
		draw_line(Vector2(xa, a.position.y), Vector2(xa, a.end.y), TemaUI.color("acento"), 2.0)
	if _hover_x >= 0.0:
		draw_line(Vector2(_hover_x, a.position.y), Vector2(_hover_x, a.end.y), Color(TemaUI.color("texto"), 0.35), 1.0)
	draw_string(f, Vector2(a.position.x, size.y - 4), Fechas.texto(_a0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, suave)
	draw_string(f, Vector2(a.end.x - 100, size.y - 4), Fechas.texto(_a1), HORIZONTAL_ALIGNMENT_RIGHT, 100, 13, suave)


func _gui_input(ev: InputEvent) -> void:
	var b := ev as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		Estado.fijar_anio(_anio_en(b.position.x))
		accept_event()
	elif ev is InputEventMouseMotion:
		_hover_x = (ev as InputEventMouseMotion).position.x
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_x = -1.0
		queue_redraw()


func _get_tooltip(pos: Vector2) -> String:
	var anio := _anio_en(pos.x)
	var v := valor_en(anio)
	var texto := tr("%s: sin territorio en los datos") % Fechas.texto(anio) if v <= 0.0 else "%s: ~%s km²" % [Fechas.texto(anio), GraficoSerie._numero(v)]
	return texto + "\n" + tr("Clic: ir a ese año")
