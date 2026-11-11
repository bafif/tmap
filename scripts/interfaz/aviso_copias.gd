class_name AvisoCopias
extends PanelContainer
## Aviso arriba al centro cuando una copia editada de un paquete (en una versión exportada, lo que guarda el editor de
## la enciclopedia) tapa una versión nueva de ese paquete, que trajo una actualización de datos o una versión nueva de
## la app. Ofrece pasarle lo nuevo a la copia (los cambios propios quedan encima), descartar la copia o dejarlo para
## la próxima vez que se abra TellMAP (ver Edicion.tapadas).

var _tapadas: Array = []


func _init(tapadas: Array) -> void:
	_tapadas = tapadas


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Debajo del aviso del Actualizador, que puede estar a la vez.
	position.y = 140
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	add_child(fila)
	var l := Label.new()
	var nombres := ", ".join(PackedStringArray(_tapadas.map(func(t): return str(t["ruta"]).get_file())))
	l.text = tr_n("Tenés cambios tuyos en %s y llegó una versión nueva de ese paquete: hoy se ve tu copia, sin lo nuevo.",
		"Tenés cambios tuyos en %s y llegaron versiones nuevas de esos paquetes: hoy se ven tus copias, sin lo nuevo.",
		_tapadas.size()) % nombres
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(l)
	var pasar := Button.new()
	pasar.text = tr("Pasarle lo nuevo")
	pasar.tooltip_text = tr("Lo nuevo de cada paquete, con tus cambios encima")
	fila.add_child(pasar)
	var descartar := Button.new()
	descartar.text = tr("Descartar mis cambios")
	descartar.tooltip_text = tr("Borra tus copias y se ve lo nuevo tal como llegó")
	fila.add_child(descartar)
	var botones: Array = [pasar, descartar]
	pasar.pressed.connect(func(): _resolver(l, botones, true))
	descartar.pressed.connect(func(): _resolver(l, botones, false))
	var cerrar := IconosUI.boton("cerrar", tr("Ahora no: se vuelve a preguntar la próxima vez"), 16)
	cerrar.pressed.connect(queue_free)
	fila.add_child(cerrar)


func _resolver(l: Label, botones: Array, pasar: bool) -> void:
	for b in botones:
		b.queue_free()
	var conflictos: Array = []
	var errores: Array = []
	for t in _tapadas:
		var r: Dictionary = Edicion.pasar_lo_nuevo(t) if pasar else Edicion.descartar_copia(t)
		if r.has("error"):
			errores.append(r["error"])
		conflictos.append_array(r.get("conflictos", []))
	Enciclopedia.recargar()
	if not errores.is_empty():
		l.text = " ".join(errores)
		return
	if not pasar:
		l.text = tr("Listo: se ve lo nuevo y tus cambios se descartaron.")
	elif conflictos.is_empty():
		l.text = tr("Listo: tus cambios quedaron encima de lo nuevo.")
	else:
		l.text = tr_n("Listo: tus cambios quedaron encima de lo nuevo. %d elemento cambió en los dos lados y quedó tu versión: %s.",
			"Listo: tus cambios quedaron encima de lo nuevo. %d elementos cambiaron en los dos lados y quedó tu versión: %s.",
			conflictos.size()) % [conflictos.size(), ", ".join(PackedStringArray(conflictos))]
	get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(self):
			queue_free())
