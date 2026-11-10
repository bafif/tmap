class_name CapaNombres
extends Node2D
## Nombres de las entidades políticas escritos sobre el territorio, siguiendo una curva suave a lo largo de su forma
## (la geometría la calcula el pipeline para cada registro de Cliopatria).

const TAM_BASE := 64
const ESPACIADO := 0.32  # separación entre letras, en fracción del tamaño
const MIN_PANTALLA := 9.0
const MAX_PANTALLA := 90.0

var curvos := true
var _activas := PackedInt32Array()
var _cache_textos := {}


func _ready() -> void:
	# Los nombres de las entidades cambian con el idioma.
	Estado.idioma_cambiado.connect(func():
		_cache_textos.clear()
		actualizar())
	actualizar()


func actualizar() -> void:
	_activas = DatosMapa.etiquetas_activas(Estado.anio)
	queue_redraw()


func _texto(ent: int) -> String:
	if not _cache_textos.has(ent):
		_cache_textos[ent] = DatosMapa.nombre_entidad(ent).to_upper()
	return _cache_textos[ent]


func _draw() -> void:
	var vista := get_parent() as VistaMapa
	if vista == null or vista.camara == null:
		return
	var z := vista.camara.zoom.x
	var vp := get_viewport_rect().size
	var visible_mundo := Rect2(vista.camara.position - vp * 0.5 / z, vp / z).grow(200.0 / z)
	var fuente := TemaUI.fuente_mapa
	var color_texto := Color(0.97, 0.93, 0.84, 0.92)
	var color_borde := Color(0.08, 0.06, 0.05, 0.55)
	for i in _activas:
		var e: Array = DatosMapa.etiquetas[i]
		var centro := Vector2(e[3], e[4])
		var largo: float = e[6]
		if not visible_mundo.grow(largo).has_point(centro):
			continue
		var texto := _texto(int(e[2]))
		if texto.is_empty():
			continue
		# Ancho del texto a tamaño base.
		var anchos := PackedFloat32Array()
		var total := 0.0
		for ch in texto:
			var w := fuente.get_char_size(ch.unicode_at(0), TAM_BASE).x
			anchos.append(w)
			total += w
		total += ESPACIADO * TAM_BASE * (texto.length() - 1)
		var escala := largo * 0.8 / maxf(total, 1.0)
		escala = minf(escala, float(e[10]) * 0.95 / TAM_BASE)
		var en_pantalla := TAM_BASE * escala * z
		if en_pantalla < MIN_PANTALLA:
			continue
		# Muy de cerca los nombres de países estorban: se apagan, como en los mapas de estrategia.
		var alfa := (1.0 - smoothstep(MAX_PANTALLA * 0.7, MAX_PANTALLA * 1.3, en_pantalla)) * (1.0 - smoothstep(2.4, 4.0, z))
		if alfa <= 0.02:
			continue
		var ang := deg_to_rad(float(e[5]))
		var e1 := Vector2(cos(ang), sin(ang))
		var e2 := Vector2(-e1.y, e1.x)
		var a: float = e[7] if curvos else 0.0
		var b: float = e[8] if curvos else 0.0
		var c: float = e[9] if curvos else 0.0
		var u := -total * escala * 0.5
		var tc := Color(color_texto, color_texto.a * alfa)
		var tb := Color(color_borde, color_borde.a * alfa)
		var contorno := 10
		for k in texto.length():
			var w := anchos[k] * escala
			var uc := u + w * 0.5
			var v := a * uc * uc + b * uc + c
			var pendiente := 2.0 * a * uc + b
			var pos := centro + e1 * uc + e2 * v
			var rot := ang + atan(pendiente)
			draw_set_transform(pos, rot, Vector2(escala, escala))
			var origen := Vector2(-anchos[k] * 0.5, TAM_BASE * 0.36)
			draw_char_outline(fuente, origen, texto[k], TAM_BASE, contorno, tb)
			draw_char(fuente, origen, texto[k], TAM_BASE, tc)
			u += w + ESPACIADO * TAM_BASE * escala
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
