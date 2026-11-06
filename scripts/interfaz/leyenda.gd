class_name Leyenda
extends PanelContainer
## Abajo a la izquierda: qué se ve en el mapa (capas activables) y la leyenda del modo actual.

var _capas: VBoxContainer
var _leyenda: VBoxContainer
var _titulo: Label

const CAPAS := [
	["mostrar_nombres", "Nombres de entidades", "acento"],
	["mostrar_ciudades", "Ciudades y sitios", "texto"],
	["mostrar_fuentes", "Fuentes escritas", "primaria"],
	["mostrar_personas", "Personas", "persona"],
	["mostrar_hechos", "Hechos", "hecho"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 12
	offset_top = -140
	offset_bottom = -140
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(230, 0)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	add_child(caja)
	_titulo = Label.new()
	_titulo.theme_type_variation = "Seccion"
	caja.add_child(_titulo)
	_leyenda = VBoxContainer.new()
	_leyenda.add_theme_constant_override("separation", 2)
	caja.add_child(_leyenda)
	caja.add_child(HSeparator.new())
	var t := Label.new()
	t.theme_type_variation = "Seccion"
	t.text = "EN EL MAPA"
	caja.add_child(t)
	_capas = VBoxContainer.new()
	_capas.add_theme_constant_override("separation", 0)
	caja.add_child(_capas)
	for c in CAPAS:
		var cb := CheckBox.new()
		cb.text = c[1]
		cb.button_pressed = Estado.ajustes.get(c[0], true)
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_color_override("font_color", TemaUI.color(c[2]).lerp(TemaUI.color("texto"), 0.35))
		var clave: String = c[0]
		cb.toggled.connect(func(on: bool): Estado.fijar_ajuste(clave, on))
		_capas.add_child(cb)
	Estado.modo_cambiado.connect(func(_m): _actualizar())
	Estado.anio_cambiado.connect(func(_a): _actualizar())
	_actualizar()


func _actualizar() -> void:
	for c in _leyenda.get_children():
		c.queue_free()
	_titulo.text = Estado.MODOS[Estado.modo][0].to_upper()
	var capas := {"religion": "religiones", "cultura": "culturas", "idioma": "idiomas"}
	if capas.has(Estado.modo):
		var items := Enciclopedia.leyenda_capa(capas[Estado.modo], Estado.anio)
		if items.is_empty():
			_nota("Sin datos para este año en las regiones cargadas.")
		for it in items:
			var fila := HBoxContainer.new()
			var muestra := ColorRect.new()
			muestra.color = it["color"]
			muestra.custom_minimum_size = Vector2(14, 14)
			muestra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			fila.add_child(muestra)
			var l := Label.new()
			l.text = it["nombre"]
			l.add_theme_font_size_override("font_size", 16)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(190, 0)
			fila.add_child(l)
			_leyenda.add_child(fila)
		_nota("Rayado: regiones todavía sin datos.")
	elif Estado.modo == "politico":
		_nota("Fronteras de Cliopatria (Seshat, CC BY 4.0). Click en un lugar para estudiarlo.")
	else:
		_nota("Relieve, ríos y costas. Las fronteras quedan tenues.")


func _nota(texto: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "Suave"
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(210, 0)
	_leyenda.add_child(l)
