class_name VistaMapa
extends Node2D
## El mapa 2D: la lámina con el shader, las capas de nombres y marcadores, y la cámara.
## Maneja el mouse y el teclado sobre el mapa (lo que no atrapó la interfaz).

signal hover_cambiado(unidad: int, elemento: Dictionary, pos_pantalla: Vector2)

const ZOOM_MAX := 10.0
const PASO_RUEDA := 1.18
const UMBRAL_ARRASTRE := 6.0

var lamina: Sprite2D
var material_mapa: ShaderMaterial
var capa_nombres: CapaNombres
var capa_marcadores: CapaMarcadores
var camara: Camera2D

var _zoom_objetivo := 1.0
var _ancla_mundo := Vector2.ZERO
var _ancla_pantalla := Vector2.ZERO
var _anclado := false
var _arrastrando := false
var _boton_arrastre := 0
var _recorrido := 0.0
var _vuelo: Tween
var _hover_unidad := 0
var _hover_valor := -1
## Valores por unidad del modo de capa actual (religión, cultura, idioma); vacío en los otros modos.
var _valores_capa := PackedInt32Array()
## Desde qué valor una unidad de la capa actual se pinta tenue (0 en los otros modos).
var _tenue := 0


func _ready() -> void:
	lamina = Sprite2D.new()
	lamina.centered = false
	lamina.texture = DatosMapa.tex_terreno
	lamina.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var escala := float(DatosMapa.ancho) / DatosMapa.tex_terreno.get_width()
	lamina.scale = Vector2(escala, escala)
	material_mapa = ShaderMaterial.new()
	material_mapa.shader = load("res://shaders/mapa.gdshader")
	lamina.material = material_mapa
	add_child(lamina)

	capa_nombres = CapaNombres.new()
	add_child(capa_nombres)
	capa_marcadores = CapaMarcadores.new()
	add_child(capa_marcadores)

	camara = Camera2D.new()
	camara.position = Vector2(DatosMapa.ancho * 0.56, DatosMapa.alto * 0.36)
	add_child(camara)
	camara.make_current()
	_zoom_objetivo = 0.45
	camara.zoom = Vector2.ONE * _zoom_objetivo

	_configurar_shader()
	Estado.ajustes_cambiados.connect(_configurar_shader)
	Estado.modo_cambiado.connect(_al_cambiar_modo)
	Estado.anio_cambiado.connect(_al_cambiar_anio)
	Estado.enfoque_pedido.connect(volar_a)
	Estado.lugar_seleccionado.connect(_al_seleccionar)
	Estado.resaltado_cambiado.connect(func(_c): _actualizar_valor_sel())
	DatosMapa.valores_actualizados.connect(_al_actualizar_valores)
	get_viewport().size_changed.connect(_limitar)
	_al_cambiar_modo(Estado.modo)


func _configurar_shader() -> void:
	var q := Estado.calidad()
	var m := material_mapa
	m.set_shader_parameter("tex_unidades", DatosMapa.tex_unidades)
	m.set_shader_parameter("tex_relieve", DatosMapa.tex_relieve)
	m.set_shader_parameter("tex_lut", DatosMapa.tex_lut)
	m.set_shader_parameter("tex_paleta", DatosMapa.tex_paleta)
	m.set_shader_parameter("tam_mapa", Vector2(DatosMapa.ancho, DatosMapa.alto))
	m.set_shader_parameter("lut_ancho", DatosMapa.LUT_ANCHO)
	m.set_shader_parameter("paleta_ancho", DatosMapa.PALETA_ANCHO)
	m.set_shader_parameter("relieve", q["relieve"])
	m.set_shader_parameter("brillo_borde", q["brillo_borde"])
	m.set_shader_parameter("papel", q["papel"])
	m.set_shader_parameter("olas", q["olas"])
	m.set_shader_parameter("agua_animada", q["agua_animada"])
	m.set_shader_parameter("muestras", q["muestras_borde"])
	m.set_shader_parameter("color_seleccion", TemaUI.color("acento").lightened(0.2))
	# El agua animada necesita redibujar siempre; si no, la app duerme mientras nada cambia.
	OS.low_processor_usage_mode = not q["agua_animada"]
	capa_nombres.visible = Estado.modo == "politico" and Estado.ajustes.get("mostrar_nombres", true)
	capa_nombres.curvos = q["nombres_curvos"]
	capa_nombres.queue_redraw()
	capa_marcadores.actualizar()


func _al_cambiar_modo(modo: String) -> void:
	var ids := {"politico": 0, "terreno": 1}
	material_mapa.set_shader_parameter("modo", ids.get(modo, 2))
	capa_nombres.visible = modo == "politico" and Estado.ajustes.get("mostrar_nombres", true)
	_actualizar_valores_modo()


func _al_cambiar_anio(anio: int) -> void:
	DatosMapa.ir_a_anio(anio)
	if Estado.modo in ["religion", "cultura", "idioma"]:
		_actualizar_valores_modo()
	capa_nombres.actualizar()
	capa_marcadores.actualizar()
	_refrescar_hover()


func _actualizar_valores_modo() -> void:
	var capas := {"religion": "religiones", "cultura": "culturas", "idioma": "idiomas"}
	if capas.has(Estado.modo):
		var r: Array = Enciclopedia.valores_capa(capas[Estado.modo], Estado.anio)
		_valores_capa = r[0]
		_tenue = Enciclopedia.tenue_capa(capas[Estado.modo])
		material_mapa.set_shader_parameter("valor_tenue", _tenue)
		DatosMapa.usar_valores(r[0], r[1])
	else:
		_valores_capa = PackedInt32Array()
		_tenue = 0
		material_mapa.set_shader_parameter("valor_tenue", 0)
		DatosMapa.usar_valores_politicos()


func _al_actualizar_valores() -> void:
	material_mapa.set_shader_parameter("tex_lut", DatosMapa.tex_lut)
	material_mapa.set_shader_parameter("tex_paleta", DatosMapa.tex_paleta)
	_actualizar_valor_sel()


func _al_seleccionar(unidad: int, _px: Vector2) -> void:
	material_mapa.set_shader_parameter("unidad_sel", unidad)
	_actualizar_valor_sel()


## Qué se marca con el borde de selección: la familia o la entidad de la ficha abierta (o de la leyenda bajo el mouse)
## si corresponde al modo; si no, la familia o la entidad del lugar elegido.
func _actualizar_valor_sel() -> void:
	var v := -1
	var clave := Estado.resaltado()
	if clave.begins_with("entidad:") and Estado.modo in ["politico", "terreno"]:
		v = int(clave.get_slice(":", 1)) + 1
	elif clave != "" and Enciclopedia.CAPA_DE_MODO.get(Estado.modo, "") == clave.get_slice(":", 0):
		v = Enciclopedia.indice_familia(clave)
	else:
		v = _valor_de(Estado.unidad_seleccionada)
	material_mapa.set_shader_parameter("valor_sel", v if v > 0 else -1)


func _valor_de(u: int) -> int:
	if u <= 0:
		return -1
	if Estado.modo == "politico" or Estado.modo == "terreno":
		var d := DatosMapa.dueno(u)
		return d + 1 if d >= 0 else -1
	if u < _valores_capa.size() and _valores_capa[u] > 0:
		var v := _valores_capa[u]
		return v - _tenue if _tenue > 0 and v > _tenue else v
	return -1


# ---------------------------------------------------------------------------------------------------------------
# Cámara


func _process(delta: float) -> void:
	var mover := Input.get_vector("mapa_izquierda", "mapa_derecha", "mapa_arriba", "mapa_abajo")
	if mover != Vector2.ZERO:
		camara.position += mover * 900.0 * delta / camara.zoom.x
		_limitar()
		_vista_cambio()
	if _vuelo and _vuelo.is_running():
		return
	var z := camara.zoom.x
	if absf(z - _zoom_objetivo) > 0.0005:
		var nuevo := lerpf(z, _zoom_objetivo, 1.0 - exp(-delta * 14.0))
		if absf(nuevo - _zoom_objetivo) < 0.0005:
			nuevo = _zoom_objetivo
		camara.zoom = Vector2(nuevo, nuevo)
		if _anclado:
			# Mantener fijo bajo el cursor el punto del mapa donde empezó el zoom.
			var vp := get_viewport_rect().size
			camara.position = _ancla_mundo - (_ancla_pantalla - vp * 0.5) / nuevo
		_limitar()
		_vista_cambio()


## Acerca (factor > 1) o aleja la cámara alrededor del centro de la pantalla (teclas + y -).
func acercar(factor: float) -> void:
	_anclado = false
	_zoom_objetivo = clampf(_zoom_objetivo * factor, zoom_minimo(), ZOOM_MAX)


func zoom_minimo() -> float:
	var vp := get_viewport_rect().size
	return minf(vp.x / DatosMapa.ancho, vp.y / DatosMapa.alto) * 0.98


func _limitar() -> void:
	var vp := get_viewport_rect().size
	var z := camara.zoom.x
	var medio := vp * 0.5 / z
	var mapa := Vector2(DatosMapa.ancho, DatosMapa.alto)
	var p := camara.position
	for eje in 2:
		if medio[eje] * 2.0 >= mapa[eje]:
			p[eje] = mapa[eje] * 0.5
		else:
			p[eje] = clampf(p[eje], medio[eje], mapa[eje] - medio[eje])
	camara.position = p


func _vista_cambio() -> void:
	capa_nombres.queue_redraw()
	capa_marcadores.queue_redraw()


func pantalla_a_mundo(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return camara.position + (p - vp * 0.5) / camara.zoom.x


func mundo_a_pantalla(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return (p - camara.position) * camara.zoom.x + vp * 0.5


## Vuela con una animación suave hasta un punto del mapa.
func volar_a(px: Vector2, zoom: float = 0.0) -> void:
	if _vuelo and _vuelo.is_running():
		_vuelo.kill()
	_anclado = false
	var z_final := clampf(zoom if zoom > 0.0 else maxf(camara.zoom.x, 1.2), zoom_minimo(), ZOOM_MAX)
	_zoom_objetivo = z_final
	if Estado.sin_animaciones:
		camara.position = px
		camara.zoom = Vector2(z_final, z_final)
		_limitar()
		_vista_cambio()
		return
	_vuelo = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_vuelo.tween_property(camara, "position", px, 0.9)
	_vuelo.tween_property(camara, "zoom", Vector2(z_final, z_final), 0.9)
	_vuelo.tween_method(func(_v: float): _vista_cambio(), 0.0, 1.0, 0.9)
	_vuelo.finished.connect(func():
		_limitar()
		_vista_cambio())


# ---------------------------------------------------------------------------------------------------------------
# Mouse


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var b := ev as InputEventMouseButton
		if b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var factor := PASO_RUEDA if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / PASO_RUEDA
			if b.factor > 0.0 and b.factor != 1.0:
				factor = pow(factor, b.factor)
			_zoom_objetivo = clampf(_zoom_objetivo * factor, zoom_minimo(), ZOOM_MAX)
			_ancla_pantalla = b.position
			_ancla_mundo = pantalla_a_mundo(b.position)
			_anclado = true
			if _vuelo and _vuelo.is_running():
				_vuelo.kill()
			get_viewport().set_input_as_handled()
		elif b.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if b.pressed:
				_arrastrando = true
				_boton_arrastre = b.button_index
				_recorrido = 0.0
			elif b.button_index == _boton_arrastre:
				_arrastrando = false
				if _recorrido < UMBRAL_ARRASTRE and b.button_index == MOUSE_BUTTON_LEFT:
					_click(b.position)
				elif _recorrido < UMBRAL_ARRASTRE and b.button_index == MOUSE_BUTTON_RIGHT:
					Estado.seleccionar_lugar(0, Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		if _arrastrando:
			_recorrido += m.relative.length()
			if _recorrido >= UMBRAL_ARRASTRE:
				if _vuelo and _vuelo.is_running():
					_vuelo.kill()
				_anclado = false
				camara.position -= m.relative / camara.zoom.x
				_limitar()
				_vista_cambio()
		else:
			_hover(m.position)
	elif ev is InputEventMagnifyGesture:
		var g := ev as InputEventMagnifyGesture
		_zoom_objetivo = clampf(_zoom_objetivo * g.factor, zoom_minimo(), ZOOM_MAX)
		_ancla_pantalla = g.position
		_ancla_mundo = pantalla_a_mundo(g.position)
		_anclado = true
	elif ev is InputEventPanGesture:
		camara.position += (ev as InputEventPanGesture).delta * 12.0 / camara.zoom.x
		_limitar()
		_vista_cambio()


func _click(pos: Vector2) -> void:
	var mundo := pantalla_a_mundo(pos)
	if Estado.captura_punto.is_valid():
		var captura := Estado.captura_punto
		Estado.captura_punto = Callable()
		captura.call(Proyeccion.a_lonlat(mundo))
		return
	var el := capa_marcadores.elemento_en(mundo, camara.zoom.x)
	if not el.is_empty() and el["tipo"] == "grupo":
		# Un grupo de marcadores: acercarse hasta que se separen.
		volar_a(el["px"], minf(maxf(camara.zoom.x * 2.5, 1.0), CapaMarcadores.ZOOM_SEPARAR + 0.2))
		return
	if not el.is_empty():
		Estado.pedir_ficha(el["tipo"], el["id"])
		return
	var u := DatosMapa.unidad_en(mundo)
	Estado.seleccionar_lugar(u, mundo)
	# Si el lugar quedó debajo del panel lateral, correr la cámara para dejarlo a la vista.
	var vp := get_viewport_rect().size
	var libre := vp.x - PanelInfo.ANCHO - 20.0
	if u > 0 and pos.x > libre - 40.0:
		var destino := camara.position + Vector2((pos.x - libre * 0.55) / camara.zoom.x, 0.0)
		volar_a(destino, camara.zoom.x)


func _hover(pos: Vector2) -> void:
	var mundo := pantalla_a_mundo(pos)
	var el := capa_marcadores.elemento_en(mundo, camara.zoom.x)
	var u := DatosMapa.unidad_en(mundo)
	var v := _valor_de(u)
	if u != _hover_unidad:
		_hover_unidad = u
		material_mapa.set_shader_parameter("unidad_hover", u)
	if v != _hover_valor:
		_hover_valor = v
		material_mapa.set_shader_parameter("valor_hover", v)
	hover_cambiado.emit(u, el, pos)


func _refrescar_hover() -> void:
	_hover_valor = -2
	_hover(get_viewport().get_mouse_position())
	_actualizar_valor_sel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_hover_unidad = 0
		material_mapa.set_shader_parameter("unidad_hover", 0)
		material_mapa.set_shader_parameter("valor_hover", -1)
		hover_cambiado.emit(0, {}, Vector2.ZERO)
