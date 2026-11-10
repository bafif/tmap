class_name AvisoActualizacion
extends PanelContainer
## Aviso arriba al centro del Actualizador: el cartel que ofrece una actualización al abrir («Actualizar» o «Ahora no»;
## cerrarlo es «Ahora no»), la app nueva ya instalada (con «Reiniciar ahora»), una versión para bajar a mano (con «Ir a
## la descarga») o datos nuevos (se cierra solo si ya se ven).

var _tipo := ""
var _texto := ""


func _init(tipo: String, texto: String) -> void:
	_tipo = tipo
	_texto = texto


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	position.y = 70
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	add_child(fila)
	var l := Label.new()
	l.text = _texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# El cartel lleva dos botones y una pregunta: más ancho, para que no corte «¿La instalo?».
	l.custom_minimum_size = Vector2(520 if _tipo == "oferta" else 380, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(l)
	if _tipo == "oferta":
		var si := Button.new()
		si.text = "Actualizar"
		fila.add_child(si)
		var no := Button.new()
		no.text = "Ahora no"
		no.pressed.connect(_posponer)
		fila.add_child(no)
		si.pressed.connect(func():
			si.queue_free()
			no.queue_free()
			_seguir(l)
			Actualizador.aceptar())
	elif _tipo == "app" and Actualizador.app_lista == "":
		var bajar := Button.new()
		bajar.text = "Ir a la descarga"
		bajar.pressed.connect(func(): Estado.abrir_url(Actualizador.pagina_nueva))
		fila.add_child(bajar)
	elif _tipo in ["app", "datos_mapa"]:
		var reiniciar := Button.new()
		reiniciar.text = "Reiniciar ahora"
		reiniciar.pressed.connect(Actualizador.reiniciar)
		fila.add_child(reiniciar)
	var cerrar := IconosUI.boton("cerrar", "Cerrar el aviso", 16)
	cerrar.pressed.connect(_posponer if _tipo == "oferta" else queue_free)
	fila.add_child(cerrar)
	if _tipo == "datos":
		get_tree().create_timer(12.0).timeout.connect(func():
			if is_instance_valid(self):
				queue_free())


## «Ahora no» (o la cruz del cartel): no se instala nada y se vuelve a ofrecer la próxima vez que se abra TellMAP.
func _posponer() -> void:
	Actualizador.posponer()
	queue_free()


## Después de «Actualizar», el cartel muestra cómo va. Al terminar lo reemplaza el aviso de lo instalado; si algo falla,
## queda el error, y la cruz lo cierra.
func _seguir(l: Label) -> void:
	var refrescar := func() -> void:
		if is_instance_valid(l):
			l.text = Actualizador.texto
	Actualizador.estado_cambiado.connect(refrescar)
	tree_exiting.connect(func(): Actualizador.estado_cambiado.disconnect(refrescar))
