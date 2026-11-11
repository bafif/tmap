class_name CapaPleiades
extends Node2D
## Los lugares antiguos de Pleiades (ver `Pleiades`): puntos chicos que aparecen al acercarse, mientras el lugar está
## atestiguado, y sus nombres de muy cerca. Los puntos son un MultiMesh (unos 27 000 en una sola llamada de dibujo,
## filtrados por año en `shaders/pleiades.gdshader`); los nombres se dibujan acá, solo los de la pantalla.

## Desde este zoom aparecen los puntos (con un fundido hasta ZOOM_PLENO); desde ZOOM_NOMBRES, los nombres.
const ZOOM_APARECER := 1.3
const ZOOM_PLENO := 2.0
const ZOOM_NOMBRES := 4.5
## Desde este zoom llevan nombre todos los lugares; antes, solo los asentamientos.
const ZOOM_TODOS_LOS_NOMBRES := 7.0
## Diámetro de los puntos en pantalla: chicos de lejos (para no confundirse con las ciudades de la enciclopedia),
## más grandes de cerca.
const DIAMETRO := 7.0
const DIAMETRO_LEJOS := 4.5
const MAX_NOMBRES := 180

var _malla: MultiMeshInstance2D
var _material: ShaderMaterial


func _ready() -> void:
	Estado.anio_cambiado.connect(func(_a): queue_redraw())
	Estado.ajustes_cambiados.connect(queue_redraw)


func _vista() -> VistaMapa:
	return get_parent() as VistaMapa


func activa() -> bool:
	var v := _vista()
	return Estado.ajustes.get("mostrar_pleiades", true) and v != null and v.camara != null \
		and v.camara.zoom.x >= ZOOM_APARECER


## Arma el MultiMesh la primera vez que hace falta: la lectura de los datos no pesa en el arranque.
func _armar() -> void:
	if _malla != null:
		return
	var n := Pleiades.cantidad()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(DIAMETRO, DIAMETRO)
	mm.mesh = quad
	mm.instance_count = n
	# Por instancia: transformación 2D (8 números), color (4) y datos propios (4: desde, hasta).
	var buf := PackedFloat32Array()
	buf.resize(n * 16)
	for i in n:
		var o := i * 16
		var p := Pleiades.px[i]
		var c := Pleiades.color_categoria(i)
		buf[o] = 1.0
		buf[o + 3] = p.x
		buf[o + 5] = 1.0
		buf[o + 7] = p.y
		buf[o + 8] = c.r
		buf[o + 9] = c.g
		buf[o + 10] = c.b
		buf[o + 11] = 1.0
		# Los unidos a un lugar de la enciclopedia no se dibujan: un rango vacío los deja siempre afuera.
		buf[o + 12] = Pleiades.desde[i] if Pleiades.unido[i] == 0 else 1.0e6
		buf[o + 13] = Pleiades.hasta[i]
	mm.buffer = buf
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/pleiades.gdshader")
	_malla = MultiMeshInstance2D.new()
	_malla.multimesh = mm
	_malla.material = _material
	add_child(_malla)


func _draw() -> void:
	if not activa():
		if _malla:
			_malla.visible = false
		return
	_armar()
	var z := _vista().camara.zoom.x
	_malla.visible = true
	_material.set_shader_parameter("anio", float(Estado.anio))
	var diametro := lerpf(DIAMETRO_LEJOS, DIAMETRO, smoothstep(ZOOM_PLENO, ZOOM_NOMBRES, z))
	_material.set_shader_parameter("escala", diametro / DIAMETRO / z)
	_material.set_shader_parameter("alfa", smoothstep(ZOOM_APARECER, ZOOM_PLENO, z) * lerpf(0.8, 1.0, smoothstep(ZOOM_PLENO, ZOOM_NOMBRES, z)))
	if z < ZOOM_NOMBRES:
		return
	# Nombres: los de la pantalla, sin encimarse (una grilla de celdas ocupadas en coordenadas de pantalla).
	var v := _vista()
	var vp := v.get_viewport_rect().size
	var rect := Rect2(v.pantalla_a_mundo(Vector2.ZERO), vp / z)
	var s := 1.0 / z
	var fuente := TemaUI.fuente_texto
	var tam := 13
	var ocupadas := {}
	var dibujados := 0
	var color := TemaUI.color("texto").lerp(TemaUI.color("texto_suave"), 0.3)
	var todos := z >= ZOOM_TODOS_LOS_NOMBRES
	var asentamiento := Pleiades.categorias.find("asentamiento")
	for i in Pleiades.en_rect(rect, Estado.anio):
		var nombre := Pleiades.nombres[i]
		if nombre == "" or not (todos or Pleiades.categoria[i] == asentamiento):
			continue
		if nombre.length() > 30:
			nombre = nombre.substr(0, 28) + "…"
		var p := Pleiades.px[i]
		var pantalla := (p - rect.position) * z
		var ancho := fuente.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var fila := floori(pantalla.y / 16.0)
		var c0 := floori((pantalla.x + 6.0) / 24.0)
		var c1 := floori((pantalla.x + 6.0 + ancho) / 24.0)
		var libre := true
		for c in range(c0, c1 + 1):
			if ocupadas.has(Vector2i(c, fila)):
				libre = false
				break
		if not libre:
			continue
		for c in range(c0, c1 + 1):
			ocupadas[Vector2i(c, fila)] = true
		var pos := p + Vector2(6.0, 4.5) * s
		draw_set_transform(pos, 0.0, Vector2(s, s))
		draw_string_outline(fuente, Vector2.ZERO, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 4, Color(0.05, 0.04, 0.03, 0.7))
		draw_string(fuente, Vector2.ZERO, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
		dibujados += 1
		if dibujados >= MAX_NOMBRES:
			break
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El lugar de Pleiades bajo un punto del mapa, o {} si no hay (o la capa no se ve).
func elemento_en(mundo: Vector2, zoom: float, holgura := 1.0) -> Dictionary:
	if not activa():
		return {}
	var i := Pleiades.cercano(mundo, (DIAMETRO * 0.5 + 3.0) * holgura / zoom, Estado.anio)
	if i < 0:
		return {}
	return {"tipo": "pleiades", "id": str(Pleiades.ids[i]), "texto": Pleiades.nombre(i)}
