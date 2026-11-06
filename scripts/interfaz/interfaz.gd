class_name Interfaz
extends CanvasLayer
## Arma y conecta toda la interfaz sobre el mapa. Al cambiar de tema se reconstruye completa.

var vista: VistaMapa
var raiz: Control
var barra: BarraSuperior
var linea: LineaTiempo
var panel: PanelInfo
var leyenda: Leyenda
var globo: GloboMapa
var ajustes: DialogoAjustes


func _init(v: VistaMapa) -> void:
	vista = v
	layer = 10


func _ready() -> void:
	_construir()
	vista.hover_cambiado.connect(_al_hover)
	Estado.ajustes_cambiados.connect(aplicar_escala)
	get_tree().root.size_changed.connect(func():
		if get_tree().root.content_scale_mode != Window.CONTENT_SCALE_MODE_DISABLED:
			get_tree().root.content_scale_size = get_tree().root.size)


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
	raiz.add_child(globo)
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


func _cambiar_tema() -> void:
	var seleccion := Estado.unidad_seleccionada
	_construir()
	vista._configurar_shader()
	if seleccion > 0:
		Estado.seleccionar_lugar(seleccion, DatosMapa.centro_unidad(seleccion))
	ajustes.abrir()


func _al_hover(unidad: int, elemento: Dictionary, pos: Vector2) -> void:
	if globo:
		globo.mostrar(unidad, elemento, pos)
