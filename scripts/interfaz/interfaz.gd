class_name Interfaz
extends CanvasLayer
## Arma y conecta toda la interfaz sobre el mapa. Al cambiar de tema o de idioma se reconstruye completa.

var vista: VistaMapa
var raiz: Control
var barra: BarraSuperior
var linea: LineaTiempo
var panel: PanelInfo
var leyenda: Leyenda
var globo: GloboMapa
var ajustes: DialogoAjustes
var editor: EditorEnciclopedia


func _init(v: VistaMapa) -> void:
	vista = v
	layer = 10


func _ready() -> void:
	_construir()
	vista.hover_cambiado.connect(_al_hover)
	Estado.editor_pedido.connect(func(tipo: String, id: String):
		ajustes.cerrar()
		editor.abrir(tipo, id))
	Estado.ajustes_cambiados.connect(aplicar_escala)
	Estado.idioma_cambiado.connect(_cambiar_idioma)
	Actualizador.aviso.connect(func(tipo: String, texto: String):
		for c in raiz.get_children():
			if c is AvisoActualizacion:
				c.queue_free()
		# Debajo del diálogo de ajustes y del editor, que están al final de raiz.
		var a := AvisoActualizacion.new(tipo, texto)
		raiz.add_child(a)
		raiz.move_child(a, editor.get_index())
		if tipo.begins_with("datos"):
			revisar_copias())
	Estado.carga_terminada.connect(revisar_copias, CONNECT_ONE_SHOT)
	get_tree().root.size_changed.connect(func():
		if get_tree().root.content_scale_mode != Window.CONTENT_SCALE_MODE_DISABLED:
			get_tree().root.content_scale_size = get_tree().root.size)


## Si una copia editada de un paquete tapa una versión nueva de ese paquete, lo avisa (ver AvisoCopias).
func revisar_copias() -> void:
	var tapadas := Edicion.tapadas()
	for c in raiz.get_children():
		if c is AvisoCopias:
			c.queue_free()
	if tapadas.is_empty():
		return
	var a := AvisoCopias.new(tapadas)
	raiz.add_child(a)
	raiz.move_child(a, editor.get_index())


func _construir() -> void:
	if raiz:
		raiz.queue_free()
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = TemaUI.crear(Estado.ajustes["tema"])
	add_child(raiz)

	var vineta := ColorRect.new()
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vineta.gdshader")
	vineta.material = mat
	raiz.add_child(vineta)

	leyenda = Leyenda.new()
	raiz.add_child(leyenda)
	panel = PanelInfo.new()
	raiz.add_child(panel)
	linea = LineaTiempo.new()
	raiz.add_child(linea)
	barra = BarraSuperior.new()
	raiz.add_child(barra)
	globo = GloboMapa.new()
	globo.panel = panel
	raiz.add_child(globo)
	editor = EditorEnciclopedia.new()
	raiz.add_child(editor)
	ajustes = DialogoAjustes.new()
	raiz.add_child(ajustes)
	barra.ajustes_pedidos.connect(ajustes.abrir)
	barra.ayuda_pedida.connect(mostrar_bienvenida)
	ajustes.tema_cambiado.connect(_cambiar_tema)
	aplicar_escala()


## Escala de la interfaz (y del mapa) sin depender del tamaño de la ventana.
func aplicar_escala() -> void:
	var w := get_tree().root
	var f := float(Estado.ajustes.get("escala_ui", 1.0))
	if is_equal_approx(f, 1.0):
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		w.content_scale_factor = 1.0
		return
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	w.content_scale_size = w.size
	w.content_scale_factor = f


func mostrar_bienvenida() -> void:
	var b := Bienvenida.new()
	raiz.add_child(b)


## Después de cambiar el motor de dibujo: pregunta si se ve bien. Va encima de todo (también de la bienvenida): si
## quedara tapado, volvería solo al motor anterior aunque se viera bien.
func confirmar_graficos() -> void:
	raiz.add_child(AvisoGraficos.new())


## Con el idioma nuevo: la interfaz se arma de nuevo y vuelve a mostrar lo que estaba abierto (la bienvenida, si el
## idioma se eligió ahí, o Ajustes).
func _cambiar_idioma() -> void:
	var en_bienvenida := raiz.get_children().any(func(c): return c is Bienvenida)
	var en_ajustes := ajustes.visible
	var seleccion := Estado.unidad_seleccionada
	_construir()
	if seleccion > 0:
		Estado.seleccionar_lugar(seleccion, DatosMapa.centro_unidad(seleccion))
	if en_bienvenida:
		mostrar_bienvenida()
	elif en_ajustes:
		ajustes.abrir()


func _cambiar_tema() -> void:
	var seleccion := Estado.unidad_seleccionada
	_construir()
	vista._configurar_shader()
	if seleccion > 0:
		Estado.seleccionar_lugar(seleccion, DatosMapa.centro_unidad(seleccion))
	ajustes.abrir()


## Atajos de teclado de toda la app (los de la línea de tiempo y Esc están en sus paneles). La lista que se muestra
## en la ayuda está en Bienvenida.ATAJOS: si se cambia uno, cambiarlo también ahí.
## Con el mouse, un botón no se queda con el foco: si no, la barra espaciadora lo volvería a apretar en vez de
## reproducir. Con el teclado (Tab) el foco sí queda, con su recuadro. Se suelta al soltar el botón del mouse, nunca
## al apretarlo: perder el foco en medio del clic lo cancela.
func _input(ev: InputEvent) -> void:
	var b := ev as InputEventMouseButton
	if b and not b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
		_soltar_foco.call_deferred()


func _soltar_foco() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f is BaseButton:
		f.release_focus()


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# Tab sin nada enfocado: empezar a recorrer la interfaz desde la barra de modos.
	if k.keycode == KEY_TAB and get_viewport().gui_get_focus_owner() == null:
		barra.enfocar_modos()
		get_viewport().set_input_as_handled()
		return
	var modos: Array = Estado.MODOS.keys()
	if k.keycode >= KEY_1 and k.keycode <= KEY_5 and not k.ctrl_pressed and not k.alt_pressed:
		Estado.fijar_modo(modos[k.keycode - KEY_1])
	elif k.keycode == KEY_SLASH or (k.keycode == KEY_F and k.ctrl_pressed):
		barra.enfocar_busqueda()
	elif k.keycode == KEY_F1 or k.unicode == "?".unicode_at(0):
		barra.ayuda_pedida.emit()
	elif k.keycode == KEY_G and not k.ctrl_pressed:
		linea.enfocar_anio()
	elif k.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
		vista.acercar(1.35)
	elif k.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		vista.acercar(1.0 / 1.35)
	elif k.keycode == KEY_BRACKETLEFT or k.keycode == KEY_BRACKETRIGHT:
		panel.pestana_vecina(-1 if k.keycode == KEY_BRACKETLEFT else 1)
	elif k.keycode == KEY_BACKSPACE:
		panel.volver()
	else:
		return
	get_viewport().set_input_as_handled()


func _al_hover(unidad: int, elemento: Dictionary, pos: Vector2) -> void:
	if globo:
		globo.mostrar(unidad, elemento, pos)
