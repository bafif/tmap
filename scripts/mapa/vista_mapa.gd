class_name VistaMapa
extends Node2D
## El mapa 2D: la lámina con el shader, las capas de nombres y marcadores, y la cámara.
## Maneja el mouse, el teclado y la pantalla táctil sobre el mapa (lo que no atrapó la interfaz): con el dedo, arrastrar
## mueve, tocar elige, dos dedos acercan o alejan (y mueven) y un doble toque acerca.

signal hover_cambiado(unidad: int, elemento: Dictionary, pos_pantalla: Vector2)

const ZOOM_MAX := 10.0
const PASO_RUEDA := 1.18
const UMBRAL_ARRASTRE := 6.0
## Con el dedo, los marcadores se tocan con este margen de más (el dedo tapa lo que toca).
const HOLGURA_TACTIL := 1.8

var lamina: Sprite2D
var material_mapa: ShaderMaterial
var capa_nombres: CapaNombres
var capa_marcadores: CapaMarcadores
var capa_pleiades: CapaPleiades
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
## Si el último movimiento del mouse cayó sobre el mapa y no sobre la interfaz (el panel, la línea de tiempo).
var _mouse_en_mapa := false
## Un movimiento del mouse que todavía no llegó a _unhandled_input: si al procesar el cuadro sigue así, se lo quedó
## la interfaz y el globo se apaga (si no, quedaría clavado encima del panel).
var _movimiento_sin_mapa := false
## Dedos apoyados en el mapa (índice → posición en pantalla), para el pellizco.
var _toques := {}
var _pellizco_dist := 0.0
var _pellizco_medio := Vector2.ZERO
## Mientras dura un gesto de dos dedos (y hasta levantar todos), el mouse que Godot emula con el primer dedo no
## arrastra el mapa ni hace clic al soltarse.
var _gesto := false
## La última entrada fue táctil: los marcadores se tocan con más holgura y no se muestra el globo (no hay mouse que
## pase por encima: quedaría clavado donde se tocó).
var tactil := false
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
	capa_pleiades = CapaPleiades.new()
	add_child(capa_pleiades)
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
	if _movimiento_sin_mapa:
		_movimiento_sin_mapa = false
		if _mouse_en_mapa:
			_salir_hover()
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
	capa_pleiades.queue_redraw()
	capa_marcadores.queue_redraw()


## El marcador o el lugar de Pleiades bajo un punto del mapa, o {}.
func elemento_en(mundo: Vector2) -> Dictionary:
	var h := HOLGURA_TACTIL if tactil else 1.0
	var el := capa_marcadores.elemento_en(mundo, camara.zoom.x, h)
	if el.is_empty():
		el = capa_pleiades.elemento_en(mundo, camara.zoom.x, h)
	return el


## El mouse está sobre una ventana de la interfaz (el panel, la leyenda, la línea de tiempo, los ajustes…). La raíz de
## la interfaz deja pasar el mouse, así que sobre el mapa no hay ningún control debajo.
func _sobre_interfaz() -> bool:
	return get_viewport().gui_get_hovered_control() != null


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
			# Sobre una ventana la rueda nunca acerca el mapa, aunque la ventana ya no pueda desplazarse más (al llegar
			# al tope, el ScrollContainer deja pasar el evento y antes terminaba acá).
			if _sobre_interfaz():
				return
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
				if _gesto:
					pass
				elif _recorrido < UMBRAL_ARRASTRE and b.button_index == MOUSE_BUTTON_LEFT:
					_click(b.position)
				elif _recorrido < UMBRAL_ARRASTRE and b.button_index == MOUSE_BUTTON_RIGHT:
					Estado.seleccionar_lugar(0, Vector2.ZERO)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		_movimiento_sin_mapa = false
		_mouse_en_mapa = true
		if _arrastrando and not _gesto:
			_recorrido += m.relative.length()
			if _recorrido >= UMBRAL_ARRASTRE:
				if _vuelo and _vuelo.is_running():
					_vuelo.kill()
				_anclado = false
				camara.position -= m.relative / camara.zoom.x
				_limitar()
				_vista_cambio()
		elif not _arrastrando:
			_hover(m.position)
	elif ev is InputEventScreenTouch:
		_al_tocar(ev as InputEventScreenTouch)
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		tactil = true
		if _toques.has(d.index):
			_toques[d.index] = d.position
			if _toques.size() >= 2:
				_pellizcar()
	elif ev is InputEventMagnifyGesture:
		if _sobre_interfaz():
			return
		var g := ev as InputEventMagnifyGesture
		_zoom_objetivo = clampf(_zoom_objetivo * g.factor, zoom_minimo(), ZOOM_MAX)
		_ancla_pantalla = g.position
		_ancla_mundo = pantalla_a_mundo(g.position)
		_anclado = true
	elif ev is InputEventPanGesture:
		if _sobre_interfaz():
			return
		camara.position += (ev as InputEventPanGesture).delta * 12.0 / camara.zoom.x
		_limitar()
		_vista_cambio()



# ---------------------------------------------------------------------------------------------------------------
# Pantalla táctil (un dedo lo maneja el mouse que Godot emula con él: arrastrar y tocar)


func _al_tocar(t: InputEventScreenTouch) -> void:
	tactil = true
	if t.pressed:
		_toques[t.index] = t.position
		if _toques.size() >= 2:
			# Empieza un pellizco: el primer dedo deja de arrastrar el mapa.
			_gesto = true
			_arrastrando = false
			_pellizco_dist = 0.0
			if _vuelo and _vuelo.is_running():
				_vuelo.kill()
			_pellizcar()
		elif t.double_tap:
			# Doble toque: acercar al doble, con el punto tocado fijo bajo el dedo.
			_zoom_objetivo = clampf(_zoom_objetivo * 2.0, zoom_minimo(), ZOOM_MAX)
			_ancla_pantalla = t.position
			_ancla_mundo = pantalla_a_mundo(t.position)
			_anclado = true
		get_viewport().set_input_as_handled()
	else:
		_toques.erase(t.index)
		_pellizco_dist = 0.0
		if _toques.is_empty():
			_gesto = false


## Dos dedos: la distancia entre ellos acerca o aleja y el punto medio arrastra, con el lugar que estaba entre los dedos
## siempre debajo de ellos.
func _pellizcar() -> void:
	var ps: Array = _toques.values()
	var a: Vector2 = ps[0]
	var b: Vector2 = ps[1]
	var dist := a.distance_to(b)
	var medio := (a + b) * 0.5
	if _pellizco_dist > 1.0 and dist > 1.0:
		var mundo := pantalla_a_mundo(_pellizco_medio)
		var z := clampf(camara.zoom.x * dist / _pellizco_dist, zoom_minimo(), ZOOM_MAX)
		camara.zoom = Vector2(z, z)
		_zoom_objetivo = z
		_anclado = false
		camara.position = mundo - (medio - get_viewport_rect().size * 0.5) / z
		_limitar()
		_vista_cambio()
	_pellizco_dist = dist
	_pellizco_medio = medio


func _click(pos: Vector2) -> void:
	var mundo := pantalla_a_mundo(pos)
	if Estado.captura_punto.is_valid():
		var captura := Estado.captura_punto
		Estado.captura_punto = Callable()
		captura.call(Proyeccion.a_lonlat(mundo))
		return
	var el := elemento_en(mundo)
	if not el.is_empty() and el["tipo"] == "grupo":
		# Un grupo de marcadores: su lista en el panel, con el zoom que los separa para el botón de acercarse.
		var z := minf(maxf(camara.zoom.x * 2.5, 1.0), CapaMarcadores.ZOOM_SEPARAR + 0.2)
		Estado.pedir_ficha("grupo", {"px": el["px"], "zoom": z, "miembros": el["miembros"]})
		_despejar_panel(pos)
		return
	if not el.is_empty():
		Estado.pedir_ficha(el["tipo"], el["id"])
		return
	var u := DatosMapa.unidad_en(mundo)
	Estado.seleccionar_lugar(u, mundo)
	if u > 0:
		_despejar_panel(pos)


## Si lo tocado quedó debajo del panel lateral, corre la cámara para dejarlo a la vista.
func _despejar_panel(pos: Vector2) -> void:
	var libre := get_viewport_rect().size.x - PanelInfo.ANCHO - 20.0
	if pos.x > libre - 40.0:
		volar_a(camara.position + Vector2((pos.x - libre * 0.55) / camara.zoom.x, 0.0), camara.zoom.x)


func _hover(pos: Vector2) -> void:
	if tactil:
		_salir_hover()
		return
	var mundo := pantalla_a_mundo(pos)
	var el := elemento_en(mundo)
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
	# Con el mouse sobre el panel o la línea de tiempo, el globo no tiene que aparecer (al reproducir, por ejemplo).
	if _mouse_en_mapa:
		_hover(get_viewport().get_mouse_position())
	_actualizar_valor_sel()


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_movimiento_sin_mapa = true
		# El mouse que Godot emula con el dedo viene del dispositivo DEVICE_ID_EMULATION; uno de verdad vuelve al modo
		# mouse (globo y márgenes normales).
		if ev.device != InputEvent.DEVICE_ID_EMULATION:
			tactil = false
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		# Un clic de mouse de verdad: si quedó registrado un dedo cuya liberación se perdió, el mapa no queda trabado.
		tactil = false
		_toques.clear()
		_gesto = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_salir_hover()


## El mouse dejó el mapa (salió de la ventana o pasó a la interfaz): sin resaltado ni globo.
func _salir_hover() -> void:
	_mouse_en_mapa = false
	_hover_unidad = 0
	_hover_valor = -1
	material_mapa.set_shader_parameter("unidad_hover", 0)
	material_mapa.set_shader_parameter("valor_hover", -1)
	hover_cambiado.emit(0, {}, Vector2.ZERO)
