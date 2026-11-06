class_name Bienvenida
extends Control
## Primera pantalla: qué es TellMAP, cómo se usa y un recorrido sugerido.

const TEXTO := """TellMAP es una biblioteca ordenada en el espacio y el tiempo. Elegí un lugar, mové la línea de tiempo y mirá cómo cambian las fronteras y cómo aparecen los textos que se escribieron ahí, y los que otros escribieron después sobre ese lugar.

[b]Cómo se usa[/b]
• [b]Rueda[/b] del mouse para acercar; [b]arrastrar[/b] para moverse; WASD o flechas también mueven.
• [b]Click[/b] en un lugar abre su ficha a la derecha: historia, fuentes, gente, datos.
• La [b]línea de tiempo[/b] de abajo se arrastra; la rueda sobre ella acerca un período. Barra espaciadora: reproducir.
• Los [color=#c9a04a]libros dorados[/color] son fuentes primarias; los [color=#7b9cc2]azules[/color], estudios posteriores.

[b]Estado[/b]: versión 0.1. Las fronteras cubren el mundo entero de 3400 a. C. a 2024; la enciclopedia empieza con un piloto sobre el antiguo Egipto y una muestra de otras regiones, y se va a ir completando."""

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
	t.text = "Bienvenido a TellMAP"
	t.theme_type_variation = "TituloGrande"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(t)
	var s := Label.new()
	s.text = "Atlas de la historia y sus fuentes"
	s.theme_type_variation = "Suave"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(s)
	caja.add_child(HSeparator.new())
	var cuerpo := RichTextLabel.new()
	cuerpo.bbcode_enabled = true
	cuerpo.fit_content = true
	cuerpo.scroll_active = false
	cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cuerpo.text = TEXTO
	caja.add_child(cuerpo)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 14)
	caja.add_child(botones)
	var egipto := Button.new()
	egipto.text = "Empezar por Egipto, 1350 a. C."
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
	libre.text = "Explorar libremente"
	libre.pressed.connect(_cerrar)
	botones.add_child(libre)
	panel.add_child(Marco.new())


func _cerrar() -> void:
	Estado.fijar_ajuste("bienvenida_vista", true)
	cerrada.emit()
	queue_free()
