class_name Leyenda
extends PanelContainer
## Abajo a la izquierda: qué se ve en el mapa (capas activables) y la leyenda del modo actual.
## En los modos de religión, cultura e idioma, pasar el mouse por una entrada resalta sus áreas y el clic abre su ficha.

var _capas: VBoxContainer
var _leyenda: VBoxContainer
var _titulo: Label
## Con muchas familias la leyenda se corta en MAX_FILAS (las más extendidas) hasta que se pide verlas todas.
var _expandida := false
const MAX_FILAS := 7

const CAPAS := [
	["mostrar_nombres", "Nombres de entidades", "acento"],
	["mostrar_ciudades", "Ciudades y sitios", "texto"],
	["mostrar_pleiades", "Lugares antiguos (Pleiades)", "texto_suave"],
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
	t.text = tr("En el mapa").to_upper()
	caja.add_child(t)
	_capas = VBoxContainer.new()
	_capas.add_theme_constant_override("separation", 0)
	caja.add_child(_capas)
	for c in CAPAS:
		var cb := CheckBox.new()
		cb.text = tr(c[1])
		cb.button_pressed = Estado.ajustes.get(c[0], true)
		cb.focus_mode = Control.FOCUS_ALL
		cb.add_theme_color_override("font_color", TemaUI.color(c[2]).lerp(TemaUI.color("texto"), 0.35))
		var clave: String = c[0]
		cb.toggled.connect(func(on: bool): Estado.fijar_ajuste(clave, on))
		_capas.add_child(cb)
	Estado.modo_cambiado.connect(func(_m): _actualizar())
	Estado.anio_cambiado.connect(func(_a): _actualizar())
	_actualizar()


func _actualizar() -> void:
	# La fila bajo el mouse se va a borrar sin avisar que el mouse salió: se suelta el resaltado acá.
	Estado.resaltar("", "leyenda")
	for c in _leyenda.get_children():
		c.queue_free()
	_titulo.text = tr(Estado.MODOS[Estado.modo][0]).to_upper()
	var capas := {"religion": "religiones", "cultura": "culturas", "idioma": "idiomas"}
	if capas.has(Estado.modo):
		var items := Enciclopedia.leyenda_capa(capas[Estado.modo], Estado.anio)
		if items.is_empty():
			_nota(tr("Sin datos para este año en las regiones cargadas."))
		var visibles: Array = items if _expandida or items.size() <= MAX_FILAS + 1 else items.slice(0, MAX_FILAS)
		for it in visibles:
			var fila := Button.new()
			fila.theme_type_variation = "FilaCompacta"
			fila.focus_mode = Control.FOCUS_ALL
			fila.alignment = HORIZONTAL_ALIGNMENT_LEFT
			fila.icon = IconosUI.muestra(it["color"])
			fila.text = it["nombre"]
			fila.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fila.custom_minimum_size = Vector2(210, 0)
			fila.tooltip_text = tr("En %s.\nClic: ficha de %s") % [", ".join(it["regiones"]), it["nombre"]]
			var clave: String = it["clave"]
			fila.set_meta("familia", clave)
			fila.mouse_entered.connect(func(): Estado.resaltar(clave, "leyenda"))
			fila.mouse_exited.connect(func(): Estado.resaltar("", "leyenda"))
			fila.pressed.connect(func(): Estado.pedir_ficha("familia", clave))
			_leyenda.add_child(fila)
		if items.size() > MAX_FILAS + 1:
			var mas := Button.new()
			mas.theme_type_variation = "FilaCompacta"
			mas.focus_mode = Control.FOCUS_ALL
			mas.alignment = HORIZONTAL_ALIGNMENT_LEFT
			mas.text = tr("Ver menos") if _expandida else tr("Ver las %d restantes") % (items.size() - MAX_FILAS)
			mas.add_theme_color_override("font_color", TemaUI.color("acento"))
			mas.pressed.connect(func():
				_expandida = not _expandida
				_actualizar())
			_leyenda.add_child(mas)
		_nota(tr("Rayado del color: zona sin entidad política registrada ese año. Rayado gris: regiones todavía sin datos."))
	elif Estado.modo == "politico":
		_nota(tr("Fronteras de Cliopatria (Seshat, CC BY 4.0). Click en un lugar para estudiarlo."))
	else:
		_nota(tr("Relieve, ríos y costas. Las fronteras quedan tenues."))


func _nota(texto: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "Suave"
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(210, 0)
	_leyenda.add_child(l)
