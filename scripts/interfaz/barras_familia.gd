class_name BarrasFamilia
extends Control
## En la ficha de una religión, cultura o idioma: una fila por región con los períodos en que aparece, sobre la línea
## de tiempo. La intensidad marca el peso (mayoritaria, importante, minoritaria) y una línea marca el año actual.
## Un clic lleva a ese año; al pasar el mouse se ve qué hay en ese punto.

const ALTO_FILA := 22.0
const ANCHO_NOMBRE := 118.0
const ALFA_PESO := {"mayoritaria": 1.0, "importante": 0.55, "minoritaria": 0.28}

var _presencia: Array = []
var _color := Color.WHITE
var _anio := 0
var _filas: Array = []
var _a0 := 0
var _a1 := 1


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Sin un texto, Godot no llama a _get_tooltip.
	tooltip_text = tr("Períodos por región")


## presencia: lo que devuelve Enciclopedia.presencia_familia.
func configurar(presencia: Array, color: Color, anio: int) -> void:
	_presencia = presencia
	_color = color
	_anio = anio
	_filas.clear()
	_a0 = Estado.ANIO_MAX
	_a1 = Estado.ANIO_MIN
	for e in presencia:
		if not _filas.has(e["region"]):
			_filas.append(e["region"])
		_a0 = mini(_a0, int(e["desde"]))
		_a1 = maxi(_a1, int(e["hasta"]))
	_a0 = mini(_a0, anio)
	_a1 = maxi(_a1, anio)
	var margen := maxi(50, (_a1 - _a0) / 25)
	_a0 = maxi(Estado.ANIO_MIN, _a0 - margen)
	_a1 = mini(Estado.ANIO_MAX, _a1 + margen)
	if _a1 <= _a0:
		_a1 = _a0 + 1
	custom_minimum_size = Vector2(0, _filas.size() * ALTO_FILA + 24)
	queue_redraw()


func _area() -> Rect2:
	return Rect2(ANCHO_NOMBRE, 2, maxf(size.x - ANCHO_NOMBRE - 8, 10), _filas.size() * ALTO_FILA)


func _x(anio: float) -> float:
	var a := _area()
	return a.position.x + (anio - _a0) / float(_a1 - _a0) * a.size.x


func _anio_en(x: float) -> int:
	var a := _area()
	return int(round(lerpf(_a0, _a1, clampf((x - a.position.x) / a.size.x, 0.0, 1.0))))


func _draw() -> void:
	var a := _area()
	var f := TemaUI.fuente_texto
	var suave := TemaUI.color("texto_suave")
	draw_rect(Rect2(Vector2.ZERO, size), Color(TemaUI.color("fondo2"), 0.6))
	for i in _filas.size():
		var y := a.position.y + i * ALTO_FILA
		var nombre: String = Enciclopedia.regiones.get(_filas[i], {}).get("nombre", _filas[i])
		draw_string(f, Vector2(6, y + ALTO_FILA * 0.7), nombre, HORIZONTAL_ALIGNMENT_LEFT, ANCHO_NOMBRE - 10, 14,
			TemaUI.color("texto"))
		draw_line(Vector2(a.position.x, y + ALTO_FILA * 0.5), Vector2(a.end.x, y + ALTO_FILA * 0.5), Color(suave, 0.25), 1.0)
	for e in _presencia:
		var i := _filas.find(e["region"])
		var y := a.position.y + i * ALTO_FILA
		var x0 := _x(float(e["desde"]))
		var x1 := maxf(_x(float(e["hasta"])), x0 + 2.0)
		var base: Color = e.get("color", _color)
		var c := Color(base, float(ALFA_PESO.get(e["peso"], 0.5)))
		draw_rect(Rect2(x0, y + 4, x1 - x0, ALTO_FILA - 8), c)
		draw_rect(Rect2(x0, y + 4, x1 - x0, ALTO_FILA - 8), Color(base.darkened(0.45), 0.8), false, 1.0)
	var xa := _x(float(_anio))
	draw_line(Vector2(xa, a.position.y), Vector2(xa, a.end.y), TemaUI.color("acento"), 2.0)
	var abajo := a.end.y + 16
	draw_string(f, Vector2(a.position.x, abajo), Fechas.texto(_a0), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, suave)
	draw_string(f, Vector2(a.end.x - 100, abajo), Fechas.texto(_a1), HORIZONTAL_ALIGNMENT_RIGHT, 100, 13, suave)


func _gui_input(ev: InputEvent) -> void:
	var b := ev as InputEventMouseButton
	if b and b.pressed and b.button_index == MOUSE_BUTTON_LEFT and b.position.x >= ANCHO_NOMBRE:
		Estado.fijar_anio(_anio_en(b.position.x))
		accept_event()


func _get_tooltip(pos: Vector2) -> String:
	var i := int((pos.y - _area().position.y) / ALTO_FILA)
	if i < 0 or i >= _filas.size():
		return ""
	var region: String = Enciclopedia.regiones.get(_filas[i], {}).get("nombre", _filas[i])
	if pos.x < ANCHO_NOMBRE:
		return region
	var anio := _anio_en(pos.x)
	var lineas: Array = ["%s, %s" % [region, Fechas.texto(anio)]]
	for e in _presencia:
		if e["region"] == _filas[i] and int(e["desde"]) <= anio and anio <= int(e["hasta"]):
			lineas.append("%s: %s (%s)" % [e["nombre"], tr(Enciclopedia.NOMBRE_PESO.get(e["peso"], e["peso"])),
				e.get("rango", Fechas.rango(int(e["desde"]), int(e["hasta"])))])
	if lineas.size() == 1:
		lineas.append(tr("Sin registro en ese año"))
	lineas.append(tr("Clic: ir a ese año"))
	return "\n".join(lineas)
