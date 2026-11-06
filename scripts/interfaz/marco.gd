class_name Marco
extends Control
## Ornamento de marco: doble filete con rombos en las esquinas, dibujado encima de un panel.
## No intercepta el mouse. Se agrega como último hijo de un PanelContainer (o de cualquier Control).

@export var margen := 4.0
@export var rombo := 5.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := TemaUI.color("borde")
	var c2 := Color(c, 0.35)
	var r := Rect2(Vector2(margen, margen), size - Vector2(margen, margen) * 2.0)
	if r.size.x < 20 or r.size.y < 20:
		return
	draw_rect(r, c2, false, 1.0)
	for esquina in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var p: Vector2 = esquina
		var pts := PackedVector2Array([p + Vector2(0, -rombo), p + Vector2(rombo, 0), p + Vector2(0, rombo), p + Vector2(-rombo, 0)])
		draw_colored_polygon(pts, c)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), TemaUI.color("fondo"), 1.0)
