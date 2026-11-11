class_name Bienvenida
extends Control
## Primera pantalla: qué es TellMAP, cómo se usa y un recorrido sugerido. Arriba, el idioma, por si el que se eligió solo
## no es el que se lee. Los textos de las constantes se traducen con tr() al mostrarlos.

const TEXTO := """TellMAP es una biblioteca ordenada en el espacio y el tiempo. Elegí un lugar, mové la línea de tiempo y mirá cómo cambian las fronteras y cómo aparecen los textos que se escribieron ahí, y los que otros escribieron después sobre ese lugar.

[b]Cómo se usa[/b]
• [b]Rueda[/b] del mouse para acercar; [b]arrastrar[/b] para moverse; WASD o flechas también mueven.
• [b]Click[/b] en un lugar abre su ficha a la derecha: historia, fuentes, gente, datos.
• En la [b]línea de tiempo[/b] de abajo, un click elige el año y arrastrar la recorre (arrastrando la línea del año, se lo mueve); la rueda acerca un período y Mayús + rueda la corre. Barra espaciadora: reproducir.
• Con [b]pantalla táctil[/b]: un dedo mueve el mapa y toca lugares y marcas, dos dedos acercan o alejan, un doble toque acerca y las ventanas se corren con el dedo. Si los botones quedan chicos, se agrandan en Ajustes → Tamaño.
• Los [color=#c9a04a]libros dorados[/color] son fuentes primarias; los [color=#7b9cc2]azules[/color], estudios posteriores.

[b]Estado[/b]: versión 0.2, en desarrollo. Las fronteras cubren el mundo entero de 3400 a. C. a 2024; la enciclopedia empieza con un piloto sobre el antiguo Egipto y una muestra de otras regiones, y se va a ir completando."""

## Atajos de teclado (los maneja Interfaz._unhandled_key_input; esta es la lista que se muestra).
const ATAJOS := [
	["Tab y Mayús+Tab", "recorrer los botones (Enter o espacio los aprieta)"],
	["1 a 5", "modos: político, terreno, religión, cultura, idioma"],
	["Barra espaciadora", "reproducir o pausar"],
	["Re Pág / Av Pág (o . y ,)", "10 años adelante o atrás; con Mayús, 1 año"],
	["G", "ir a un año (escribirlo y Enter)"],
	["/ o Ctrl+F", "buscar"],
	["WASD o flechas", "mover el mapa"],
	["+ y -", "acercar y alejar"],
	["[ y ]", "pestaña anterior y siguiente del panel"],
	["Retroceso", "volver de una ficha al lugar"],
	["Esc", "cerrar el panel o los ajustes"],
	["F1 o ?", "esta ayuda"],
]

signal cerrada


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.5)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	var t := Label.new()
	t.text = tr("Bienvenido a TellMAP")
	t.theme_type_variation = "TituloGrande"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(t)
	var s := Label.new()
	s.text = tr("Atlas de la historia y sus fuentes")
	s.theme_type_variation = "Suave"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(s)
	var idiomas := HBoxContainer.new()
	idiomas.alignment = BoxContainer.ALIGNMENT_CENTER
	idiomas.add_theme_constant_override("separation", 6)
	caja.add_child(idiomas)
	for codigo: String in Idioma.NOMBRES:
		var b := Button.new()
		b.text = Idioma.NOMBRES[codigo]
		b.theme_type_variation = "BotonPlano"
		b.toggle_mode = true
		b.button_pressed = codigo == Idioma.actual
		b.disabled = codigo == Idioma.actual
		b.pressed.connect(func(): Idioma.cambiar(codigo))
		idiomas.add_child(b)
	caja.add_child(HSeparator.new())
	var cuerpo := RichTextLabel.new()
	cuerpo.bbcode_enabled = true
	cuerpo.fit_content = true
	cuerpo.scroll_active = false
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.text = tr(TEXTO)
	# El texto va en un scroll: con los atajos ya no entra entero en una ventana baja y los botones quedarían afuera.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y - 300.0, 160.0, 560.0))
	caja.add_child(scroll)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 12)
	scroll.add_child(textos)
	textos.add_child(cuerpo)
	var atajos := RichTextLabel.new()
	atajos.bbcode_enabled = true
	atajos.fit_content = true
	atajos.scroll_active = false
	atajos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lineas: Array = [tr("[b]Teclado[/b] (todo se puede usar sin mouse; en Ajustes también hay un tema de alto contraste y la escala de la interfaz)")]
	for a in ATAJOS:
		lineas.append("• [b]%s[/b]: %s" % [tr(a[0]), tr(a[1])])
	atajos.text = "\n".join(lineas)
	textos.add_child(atajos)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 14)
	caja.add_child(botones)
	var egipto := Button.new()
	egipto.text = tr("Empezar por Egipto, 1350 a. C.")
	egipto.icon = IconosUI.textura("ir", 18, TemaUI.color("acento"))
	egipto.pressed.connect(func():
		_cerrar()
		Estado.fijar_anio(-1350)
		var p := Proyeccion.a_px(31.0, 27.5)
		Estado.enfocar(p, 1.6)
		var u := DatosMapa.unidad_en(Proyeccion.a_px(32.65, 25.7))
		if u > 0:
			Estado.seleccionar_lugar(u, p))
	botones.add_child(egipto)
	var libre := Button.new()
	libre.text = tr("Explorar libremente")
	libre.pressed.connect(_cerrar)
	botones.add_child(libre)
	panel.add_child(Marco.new())


func _cerrar() -> void:
	Estado.fijar_ajuste("bienvenida_vista", true)
	cerrada.emit()
	queue_free()
