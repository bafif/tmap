class_name GraficoSerie
extends Control
## Gráfico chico de una serie de estimaciones (población) con el año actual marcado.
## Escala logarítmica en el eje vertical, porque las poblaciones antiguas varían en órdenes de magnitud.
## Al pasar el mouse se ve el valor, el año, el rango y la fuente de la estimación más cercana.

var serie: Array = []
var anio := 0
## Posición en pantalla de cada estimación (la calcula _draw) y la que está bajo el mouse.
var _puntos: Array = []
var _cerca := -1


func _init() -> void:
	custom_minimum_size = Vector2(0, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Sin un texto, Godot no llama a _get_tooltip.
	tooltip_text = "Estimaciones de población"


func _draw() -> void:
	if serie.size() < 2:
		return
	var datos := serie.duplicate()
	datos.sort_custom(func(a, b): return int(a["anio"]) < int(b["anio"]))
	var a0 := float(datos[0]["anio"])
	var a1 := float(datos[-1]["anio"])
	var lo := INF
	var hi := -INF
	for d in datos:
		lo = minf(lo, log(float(d.get("min", d["poblacion"]))))
		hi = maxf(hi, log(float(d.get("max", d["poblacion"]))))
	if hi - lo < 0.1:
		hi += 0.5
		lo -= 0.5
	var m := Vector2(8, 10)
	var area := Rect2(m, size - m * 2.0 - Vector2(0, 14))
	var px := func(an: float, v: float) -> Vector2:
		return Vector2(area.position.x + (an - a0) / maxf(a1 - a0, 1.0) * area.size.x, area.end.y - (v - lo) / (hi - lo) * area.size.y)
	var c := TemaUI.color("acento")
	var suave := TemaUI.color("texto_suave")
	draw_rect(Rect2(Vector2.ZERO, size), Color(TemaUI.color("fondo2"), 0.6))
	# Banda de incertidumbre, de a tramos entre estimaciones: una estimación sin rango la cierra en un punto, y un solo
	# polígono que se toca a sí mismo no se puede triangular.
	for i in datos.size() - 1:
		var tramo := PackedVector2Array()
		for par in [[datos[i], "max"], [datos[i + 1], "max"], [datos[i + 1], "min"], [datos[i], "min"]]:
			var d: Dictionary = par[0]
			var p: Vector2 = px.call(float(d["anio"]), log(float(d.get(par[1], d["poblacion"]))))
			if tramo.is_empty() or not tramo[tramo.size() - 1].is_equal_approx(p):
				tramo.append(p)
		if tramo.size() > 3 and tramo[0].is_equal_approx(tramo[tramo.size() - 1]):
			tramo.remove_at(tramo.size() - 1)
		var doble_area := 0.0
		for k in tramo.size():
			doble_area += tramo[k].cross(tramo[(k + 1) % tramo.size()])
		if tramo.size() >= 3 and absf(doble_area) > 1.0:
			draw_colored_polygon(tramo, Color(c, 0.18))
	var linea := PackedVector2Array()
	for d in datos:
		linea.append(px.call(float(d["anio"]), log(float(d["poblacion"]))))
	draw_polyline(linea, c, 2.0, true)
	_puntos.clear()
	for i in linea.size():
		draw_circle(linea[i], 3.0, c)
		_puntos.append({"p": linea[i], "d": datos[i]})
	if _cerca >= 0 and _cerca < linea.size():
		draw_circle(linea[_cerca], 6.0, TemaUI.color("titulo"), false, 1.5)
	if anio >= a0 and anio <= a1:
		var x: float = px.call(float(anio), lo).x
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(TemaUI.color("texto"), 0.6), 1.0)
	var f := TemaUI.fuente_texto
	draw_string(f, Vector2(area.position.x, size.y - 3), Fechas.texto(int(a0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, suave)
	draw_string(f, Vector2(area.end.x - 90, size.y - 3), Fechas.texto(int(a1)), HORIZONTAL_ALIGNMENT_RIGHT, 90, 13, suave)


func _mas_cercano(pos: Vector2) -> int:
	var mejor := -1
	var dist := 24.0
	for i in _puntos.size():
		var d := absf((_puntos[i]["p"] as Vector2).x - pos.x)
		if d < dist:
			dist = d
			mejor = i
	return mejor


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var i := _mas_cercano((ev as InputEventMouseMotion).position)
		if i != _cerca:
			_cerca = i
			queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _cerca != -1:
		_cerca = -1
		queue_redraw()


func _get_tooltip(pos: Vector2) -> String:
	var i := _mas_cercano(pos)
	if i < 0:
		return "Población estimada (escala logarítmica). Pasá el mouse por un punto para ver su fuente."
	var d: Dictionary = _puntos[i]["d"]
	var texto := "%s: ~%s habitantes" % [Fechas.texto(int(d["anio"])), _numero(float(d["poblacion"]))]
	if d.has("min") and d.has("max"):
		texto += " (entre %s y %s)" % [_numero(float(d["min"])), _numero(float(d["max"]))]
	texto += "\nFuente: %s" % d.get("fuente", "sin fuente")
	if d.get("nota"):
		texto += "\n%s" % d["nota"]
	return texto


static func _numero(x: float) -> String:
	if x >= 1000000.0:
		return ("%.1f millones" % (x / 1000000.0)).replace(".", ",")
	var s := str(int(round(x)))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
