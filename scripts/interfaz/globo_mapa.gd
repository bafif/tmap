class_name GloboMapa
extends PanelContainer
## Globo que sigue al mouse sobre el mapa: la entidad y la región bajo el cursor, o el marcador.

var _titulo: Label
var _detalle: Label
var _pendiente := false
var _ultimo_texto := ""
## El panel lateral: con el cursor sobre el mapa, a su izquierda, el globo no lo cruza (taparía el texto).
var panel: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	top_level = true
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)
	_titulo = Label.new()
	_titulo.theme_type_variation = "Titulo"
	_titulo.add_theme_font_size_override("font_size", 16)
	caja.add_child(_titulo)
	_detalle = Label.new()
	_detalle.theme_type_variation = "Suave"
	caja.add_child(_detalle)


func mostrar(unidad: int, elemento: Dictionary, pos: Vector2) -> void:
	if not elemento.is_empty():
		var tipos := {"fuente": "Fuente", "persona": "Persona", "hecho": "Hecho", "lugar": "Lugar"}
		_titulo.text = str(elemento.get("texto", ""))
		_detalle.text = "Marcadores juntos · click para acercarse y separarlos" if elemento["tipo"] == "grupo" else (
			"%s · click para ver la ficha" % tipos.get(elemento["tipo"], ""))
	elif unidad > 0:
		var ent := DatosMapa.dueno(unidad)
		var regs := Enciclopedia.regiones_de_unidad(unidad)
		var region := ""
		if not regs.is_empty():
			region = Enciclopedia.regiones[regs[0]]["nombre"]
		if ent >= 0:
			var e: Dictionary = DatosMapa.entidades[ent]
			_titulo.text = DatosMapa.nombre_entidad(ent)
			_detalle.text = Fechas.rango(int(e["a"]), int(e["b"])) + ("   ·   " + region if region != "" else "")
		elif region != "":
			_titulo.text = region
			_detalle.text = "Sin entidad política registrada"
		else:
			visible = false
			return
	else:
		visible = false
		return
	var vp := get_viewport_rect().size
	reset_size()
	var p := pos + Vector2(18, 20)
	var derecha := vp.x - 8.0
	if panel and panel.visible and pos.x < panel.position.x:
		derecha = panel.position.x - 6.0
	if p.x + size.x > derecha:
		p.x = pos.x - size.x - 12
	if p.y + size.y > vp.y - 140:
		p.y = pos.y - size.y - 12
	global_position = p
	visible = true
