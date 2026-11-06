class_name GraficoSerie
extends Control
## Gráfico chico de una serie de estimaciones (población) con el año actual marcado.
## Escala logarítmica en el eje vertical, porque las poblaciones antiguas varían en órdenes de magnitud.

var serie: Array = []
var anio := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 120)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	# Banda de incertidumbre
	var banda := PackedVector2Array()
	for d in datos:
		banda.append(px.call(float(d["anio"]), log(float(d.get("max", d["poblacion"])))))
	for i in range(datos.size() - 1, -1, -1):
		var d: Dictionary = datos[i]
		banda.append(px.call(float(d["anio"]), log(float(d.get("min", d["poblacion"])))))
	if banda.size() >= 3:
		draw_colored_polygon(banda, Color(c, 0.18))
	var linea := PackedVector2Array()
	for d in datos:
		linea.append(px.call(float(d["anio"]), log(float(d["poblacion"]))))
	draw_polyline(linea, c, 2.0, true)
	for p in linea:
		draw_circle(p, 3.0, c)
	if anio >= a0 and anio <= a1:
		var x: float = px.call(float(anio), lo).x
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(TemaUI.color("texto"), 0.6), 1.0)
	var f := TemaUI.fuente_texto
	draw_string(f, Vector2(area.position.x, size.y - 3), Fechas.texto(int(a0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, suave)
	draw_string(f, Vector2(area.end.x - 90, size.y - 3), Fechas.texto(int(a1)), HORIZONTAL_ALIGNMENT_RIGHT, 90, 13, suave)
