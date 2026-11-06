class_name DialogoAjustes
extends Control
## Ajustes: vista 2D/3D, calidad gráfica, tema de la interfaz, escala, idioma de Wikipedia y créditos de datos.

signal tema_cambiado

const DESCRIPCION_CALIDAD := {
	"baja": "Para equipos modestos: texturas a la mitad, sin relieve ni efectos.",
	"media": "Relieve, olas de costa y papel; bordes simples.",
	"alta": "Lo anterior más el brillo interior de las fronteras (recomendada).",
	"ultra": "Bordes más suaves y agua animada (redibuja siempre).",
}
const CREDITOS := """[b]Datos[/b]
• Fronteras políticas: [url=https://github.com/Seshat-Global-History-Databank/cliopatria]Cliopatria[/url], Seshat Global History Databank, CC BY 4.0.
• Costas, lagos y ríos: [url=https://www.naturalearthdata.com]Natural Earth[/url], dominio público.
• Relieve: GEBCO 2008 en la versión de la NASA; color del terreno: NASA Blue Marble Next Generation (julio de 2004), dominio público.
• Textos de la enciclopedia: Wikipedia (CC BY-SA 4.0) y los paquetes propios en data/enciclopedia.
[b]Tipografías[/b]
• Cinzel y EB Garamond, SIL Open Font License."""

var _panel: PanelContainer
var _calidad_desc: Label
## El contenido va en un scroll: con la sección de la enciclopedia ya no entra entero en una ventana baja.
var _desliza: ScrollContainer
var _contenido: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.45)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			cerrar())
	add_child(fondo)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)
	# Si crece (la lista de consultas), se vuelve a centrar para no salirse de la ventana.
	_panel.resized.connect(func(): _panel.position = ((size - _panel.size) * 0.5).max(Vector2.ZERO))
	_construir()


func _construir() -> void:
	for c in _panel.get_children():
		c.queue_free()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	var cab := HBoxContainer.new()
	caja.add_child(cab)
	var titulo := Label.new()
	titulo.text = "Ajustes"
	titulo.theme_type_variation = "TituloGrande"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	var cerrar_b := IconosUI.boton("cerrar", "Cerrar", 18)
	cerrar_b.pressed.connect(cerrar)
	cab.add_child(cerrar_b)
	_desliza = ScrollContainer.new()
	_desliza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desliza.follow_focus = true
	caja.add_child(_desliza)
	caja = VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 10)
	_desliza.add_child(caja)
	_contenido = caja

	# Vista
	caja.add_child(_seccion("Vista"))
	var vista := HBoxContainer.new()
	caja.add_child(vista)
	var grupo_vista := ButtonGroup.new()
	for v in [["2d", "Mapa 2D", true], ["3d", "Relieve 3D (en preparación)", false]]:
		var b := Button.new()
		b.text = v[1]
		b.toggle_mode = true
		b.button_group = grupo_vista
		b.disabled = not v[2]
		b.button_pressed = Estado.ajustes["vista"] == v[0]
		b.focus_mode = Control.FOCUS_ALL
		if not v[2]:
			b.tooltip_text = "La vista 3D con relieve, agua y efectos está planificada en docs/es/plan.md."
		vista.add_child(b)

	# Calidad
	caja.add_child(_seccion("Calidad gráfica"))
	var calidades := HBoxContainer.new()
	caja.add_child(calidades)
	var grupo_cal := ButtonGroup.new()
	for id in ["baja", "media", "alta", "ultra"]:
		var b := Button.new()
		b.text = id.capitalize()
		b.toggle_mode = true
		b.button_group = grupo_cal
		b.button_pressed = Estado.ajustes["calidad"] == id
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(110, 0)
		var cal: String = id
		b.pressed.connect(func():
			var antes: float = Estado.calidad()["resolucion"]
			Estado.fijar_ajuste("calidad", cal)
			_calidad_desc.text = DESCRIPCION_CALIDAD[cal]
			if Estado.calidad()["resolucion"] != antes:
				_calidad_desc.text += " La resolución de las texturas cambia al reiniciar.")
		calidades.add_child(b)
	_calidad_desc = Label.new()
	_calidad_desc.theme_type_variation = "Suave"
	_calidad_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calidad_desc.text = DESCRIPCION_CALIDAD.get(Estado.ajustes["calidad"], "")
	caja.add_child(_calidad_desc)

	# Interfaz
	caja.add_child(_seccion("Interfaz"))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	caja.add_child(fila)
	var temas := OptionButton.new()
	var ids := TemaUI.TEMAS.keys()
	for i in ids.size():
		temas.add_item(TemaUI.TEMAS[ids[i]]["nombre"])
		if ids[i] == Estado.ajustes["tema"]:
			temas.select(i)
	temas.item_selected.connect(func(i: int):
		Estado.fijar_ajuste("tema", ids[i])
		tema_cambiado.emit())
	fila.add_child(_etiqueta("Tema"))
	fila.add_child(temas)
	var escalas := OptionButton.new()
	var valores := [0.9, 1.0, 1.15, 1.3, 1.5]
	for i in valores.size():
		escalas.add_item("%d %%" % int(valores[i] * 100))
		if is_equal_approx(valores[i], float(Estado.ajustes["escala_ui"])):
			escalas.select(i)
	escalas.item_selected.connect(func(i: int):
		Estado.fijar_ajuste("escala_ui", valores[i]))
	fila.add_child(_etiqueta("Tamaño"))
	fila.add_child(escalas)
	var wiki := OptionButton.new()
	wiki.add_item("Español primero")
	wiki.add_item("Inglés primero")
	wiki.select(0 if Estado.ajustes["idioma_wiki"] == "es" else 1)
	wiki.item_selected.connect(func(i: int): Estado.fijar_ajuste("idioma_wiki", "es" if i == 0 else "en"))
	fila.add_child(_etiqueta("Wikipedia"))
	fila.add_child(wiki)

	# Cola de consultas sin ficha (llenado progresivo de la enciclopedia)
	caja.add_child(_seccion("Enciclopedia"))
	var pend := Enciclopedia.pendientes()
	var nota := _etiqueta("Todavía no hay consultas anotadas." if pend.is_empty() else
		"%d %s sin ficha en la enciclopedia: es lo primero que conviene completar. Se anota solo en esta computadora." % [
			pend.size(), "lugar consultado" if pend.size() == 1 else "lugares consultados"])
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Con ancho fijo: sin él, Godot calcula la altura de un texto con ajuste de línea como si entrara una letra por
	# renglón, y el panel crece de más.
	nota.custom_minimum_size = Vector2(580, 0)
	caja.add_child(nota)
	var fila_p := HBoxContainer.new()
	fila_p.add_theme_constant_override("separation", 8)
	caja.add_child(fila_p)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 0)
	lista.visible = false
	var ver := Button.new()
	ver.text = "Ver los más consultados"
	ver.disabled = pend.is_empty()
	ver.pressed.connect(func():
		lista.visible = not lista.visible
		ver.text = "Ocultar la lista" if lista.visible else "Ver los más consultados"
		_ajustar_alto.call_deferred())
	fila_p.add_child(ver)
	var copiar := Button.new()
	copiar.text = "Copiar la cola"
	copiar.tooltip_text = "Copia la cola en JSON al portapapeles, para pegarla en un issue o dársela a tools/enciclopedia"
	copiar.disabled = pend.is_empty()
	copiar.pressed.connect(func():
		DisplayServer.clipboard_set(FileAccess.get_file_as_string(Enciclopedia.RUTA_PENDIENTES))
		copiar.text = "Copiada")
	fila_p.add_child(copiar)
	var carpeta := Button.new()
	carpeta.text = "Abrir la carpeta"
	carpeta.tooltip_text = ProjectSettings.globalize_path(Enciclopedia.RUTA_PENDIENTES)
	carpeta.disabled = pend.is_empty()
	carpeta.pressed.connect(func(): Estado.abrir_url(ProjectSettings.globalize_path("user://")))
	fila_p.add_child(carpeta)
	caja.add_child(lista)
	for item in pend.slice(0, 8):
		var b := Button.new()
		b.theme_type_variation = "FilaCompacta"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var anios: Array = item.get("anios", [])
		b.text = "%s   ·   %d %s%s" % [item["nombre"], int(item.get("veces", 0)), "vez" if int(item.get("veces", 0)) == 1 else "veces",
			", hacia %s" % Fechas.texto(int(anios[0])) if not anios.is_empty() else ""]
		b.tooltip_text = "Ir a ese lugar y año"
		var destino: Dictionary = item
		b.pressed.connect(func():
			cerrar()
			if not (destino.get("anios", []) as Array).is_empty():
				Estado.fijar_anio(int(destino["anios"][0]))
			var px := Proyeccion.a_px(float(destino.get("lon", 0.0)), float(destino.get("lat", 0.0)))
			Estado.enfocar(px, 2.0)
			Estado.seleccionar_lugar(DatosMapa.unidad_en(px), px))
		lista.add_child(b)

	# Créditos
	caja.add_child(_seccion("Datos y créditos"))
	var cred := RichTextLabel.new()
	cred.bbcode_enabled = true
	cred.fit_content = true
	cred.scroll_active = false
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred.text = CREDITOS
	cred.add_theme_font_size_override("normal_font_size", 15)
	cred.add_theme_font_size_override("bold_font_size", 15)
	cred.meta_clicked.connect(func(m): Estado.abrir_url(str(m)))
	caja.add_child(cred)
	var version := Label.new()
	version.theme_type_variation = "Suave"
	version.text = "TellMAP %s · Bautista D. Fiori" % ProjectSettings.get_setting("application/config/version", "")
	caja.add_child(version)
	_panel.add_child(Marco.new())


func _seccion(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.theme_type_variation = "Seccion"
	return l


func _etiqueta(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.theme_type_variation = "Suave"
	return l


func abrir() -> void:
	_construir()
	visible = true
	await get_tree().process_frame
	_ajustar_alto()


## El scroll toma la altura del contenido, hasta lo que entra en la ventana; el panel queda centrado.
func _ajustar_alto() -> void:
	if not is_instance_valid(_contenido):
		return
	_desliza.custom_minimum_size.y = minf(_contenido.get_combined_minimum_size().y, maxf(size.y - 120.0, 240.0))
	_panel.reset_size()
	_panel.position = ((size - _panel.size) * 0.5).max(Vector2.ZERO)


func cerrar() -> void:
	visible = false


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()
