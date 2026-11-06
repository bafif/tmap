class_name CapaMarcadores
extends Node2D
## Marcadores sobre el mapa que aparecen y desaparecen con el año: fuentes (donde se escribieron), personas
## (mientras viven), hechos (cerca de su fecha) y ciudades (mientras existen).
## Se dibujan a tamaño constante en pantalla; los que aparecen en el año actual hacen un pequeño destello.

const RADIO := 13.0
const VENTANA_HECHO := 40
const VIDA_FUENTE := 150
## Más lejos que esto no se dibujan marcadores; entre esto y ZOOM_PUNTOS, solo puntos chicos.
const ZOOM_OCULTAR := 0.26
const ZOOM_PUNTOS := 0.5

const ICONOS := {
	"fuente": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><path fill='#fff' d='M7 15c9-4 17-3 23 2v34c-6-5-14-6-23-2z'/><path fill='#fff' d='M57 15c-9-4-17-3-23 2v34c6-5 14-6 23-2z'/></svg>",
	"persona": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><circle fill='#fff' cx='32' cy='21' r='11'/><path fill='#fff' d='M11 55c0-13 9-21 21-21s21 8 21 21z'/></svg>",
	"hecho": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><path fill='#fff' d='M32 5l7.5 17.5 19 1.5-14.5 12.3 4.6 18.7L32 45 15.4 55l4.6-18.7L5.5 24l19-1.5z'/></svg>",
}

var _texturas := {}
var _visibles: Array = []
var _ciudades: Array = []
var _destello := {}


func _ready() -> void:
	for clave in ICONOS:
		var img := Image.new()
		if img.load_svg_from_string(ICONOS[clave], 1.0) == OK:
			_texturas[clave] = ImageTexture.create_from_image(img)
	actualizar()


func _process(_delta: float) -> void:
	if not _destello.is_empty():
		var ahora := Time.get_ticks_msec()
		for k in _destello.keys():
			if ahora - int(_destello[k]) > 900:
				_destello.erase(k)
		queue_redraw()


func actualizar() -> void:
	var anio := Estado.anio
	var aj := Estado.ajustes
	var antes := {}
	for v in _visibles:
		antes[v["tipo"] + v["id"]] = true
	_visibles.clear()
	_ciudades.clear()
	if aj.get("mostrar_fuentes", true):
		for f in Enciclopedia.fuentes.values():
			if f.has("_px") and f["_desde"] <= anio and anio <= f["_hasta"] + VIDA_FUENTE:
				var tipo_f := "primaria" if f.get("tipo", "") == "primaria" else "secundaria"
				var alfa := 1.0 - smoothstep(f["_hasta"] + VIDA_FUENTE * 0.4, f["_hasta"] + VIDA_FUENTE, anio)
				_visibles.append({"tipo": "fuente", "id": f["id"], "px": f["_px"], "icono": "fuente", "color": TemaUI.color(tipo_f), "alfa": maxf(alfa, 0.35), "texto": f.get("titulo", "")})
	if aj.get("mostrar_personas", true):
		for p in Enciclopedia.personas.values():
			if p.has("_px") and not p["_sin_fechas"] and p["_desde"] <= anio and anio <= p["_hasta"]:
				_visibles.append({"tipo": "persona", "id": p["id"], "px": p["_px"], "icono": "persona", "color": TemaUI.color("persona"), "alfa": 1.0, "texto": p.get("nombre", "")})
	if aj.get("mostrar_hechos", true):
		for h in Enciclopedia.hechos.values():
			if h.has("_px") and h["_desde"] - 3 <= anio and anio <= h["_hasta"] + VENTANA_HECHO:
				var alfa_h := 1.0 - smoothstep(h["_hasta"] + 5, h["_hasta"] + VENTANA_HECHO, anio)
				_visibles.append({"tipo": "hecho", "id": h["id"], "px": h["_px"], "icono": "hecho", "color": TemaUI.color("hecho"), "alfa": maxf(alfa_h, 0.3), "texto": h.get("titulo", "")})
	if aj.get("mostrar_ciudades", true):
		for l in Enciclopedia.lugares.values():
			if l.has("_px") and l["_desde"] <= anio and anio <= l["_hasta"]:
				_ciudades.append(l)
		_ciudades.sort_custom(func(a, b): return int(a.get("importancia", 2)) > int(b.get("importancia", 2)))
	# Separar marcadores que caen en el mismo punto (por ejemplo, varias fuentes de Alejandría).
	var por_punto := {}
	for v in _visibles:
		var clave := Vector2i(v["px"] / 2.0)
		var n: int = por_punto.get(clave, 0)
		por_punto[clave] = n + 1
		v["orden"] = n
	var ahora := Time.get_ticks_msec()
	for v in _visibles:
		var k: String = v["tipo"] + v["id"]
		if not antes.has(k) and not antes.is_empty():
			_destello[k] = ahora
	queue_redraw()


func _desplazamiento(orden: int) -> Vector2:
	if orden == 0:
		return Vector2.ZERO
	var ang := orden * 2.39996
	return Vector2(cos(ang), sin(ang)) * RADIO * 1.9 * sqrt(float(orden))


func _draw() -> void:
	var vista := get_parent() as VistaMapa
	if vista == null or vista.camara == null:
		return
	var z := vista.camara.zoom.x
	var s := 1.0 / z
	var fuente := TemaUI.fuente_texto
	var fuente_t := TemaUI.fuente_titulo
	# Rectángulos de texto ya dibujados (en coordenadas del mapa), para no encimar nombres.
	var ocupados: Array[Rect2] = []

	# Ciudades: punto y nombre; las menos importantes solo de cerca.
	for l in _ciudades:
		var imp := int(l.get("importancia", 2))
		var umbral: float = {3: 0.35, 2: 0.9, 1: 1.8}.get(imp, 0.9)
		if z < umbral:
			continue
		var p: Vector2 = l["_px"]
		var r := (3.2 + imp) * s
		draw_circle(p, r + 1.6 * s, Color(0.08, 0.07, 0.06, 0.85))
		draw_circle(p, r, Color(0.96, 0.92, 0.82))
		if imp >= 3 or l.get("tipo", "") == "capital":
			draw_circle(p, r * 0.45, Color(0.55, 0.15, 0.12))
		var tam := 15 + imp * 2
		var nombre := str(l.get("nombre", ""))
		var pos := p + Vector2(r + 5.0 * s, 5.0 * s)
		var caja := Rect2(pos + Vector2(0, -tam * 0.8 * s), fuente_t.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam) * s)
		if _choca(caja, ocupados):
			continue
		ocupados.append(caja)
		draw_set_transform(pos, 0.0, Vector2(s, s))
		draw_string_outline(fuente_t, Vector2.ZERO, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(0.05, 0.04, 0.03, 0.75))
		draw_string(fuente_t, Vector2.ZERO, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.98, 0.95, 0.88))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if z < ZOOM_OCULTAR:
		return
	var chico := z < ZOOM_PUNTOS
	var ahora := Time.get_ticks_msec()
	for v in _visibles:
		var p: Vector2 = v["px"] + (Vector2.ZERO if chico else _desplazamiento(v["orden"]) * s)
		var col: Color = v["color"]
		var alfa: float = v["alfa"]
		if chico:
			draw_circle(p, 4.5 * s, Color(0.06, 0.05, 0.04, alfa))
			draw_circle(p, 3.2 * s, Color(col, alfa))
			continue
		var k: String = v["tipo"] + v["id"]
		var r := RADIO * s
		if _destello.has(k):
			var t := clampf((ahora - int(_destello[k])) / 900.0, 0.0, 1.0)
			r *= 1.0 + 0.6 * (1.0 - t) * sin(t * PI)
			draw_circle(p, RADIO * s * (1.0 + 2.2 * t), Color(col, 0.5 * (1.0 - t)), false, 2.0 * s)
		draw_circle(p + Vector2(0, 1.5 * s), r + 2.0 * s, Color(0, 0, 0, 0.35 * alfa))
		draw_circle(p, r + 1.5 * s, Color(0.06, 0.05, 0.04, alfa))
		draw_circle(p, r, Color(col.darkened(0.25), alfa))
		draw_circle(p, r, Color(col.lightened(0.35), alfa), false, 1.3 * s)
		var tex: Texture2D = _texturas.get(v["icono"])
		if tex:
			var lado := r * 1.25
			draw_texture_rect(tex, Rect2(p - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false, Color(1, 0.97, 0.9, alfa))
		if z >= 2.2:
			var pos := p + Vector2(r + 4.0 * s, 4.5 * s)
			var texto: String = v["texto"]
			if texto.length() > 34:
				texto = texto.substr(0, 32) + "…"
			var caja := Rect2(pos + Vector2(0, -12 * s), fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15) * s)
			if _choca(caja, ocupados):
				continue
			ocupados.append(caja)
			draw_set_transform(pos, 0.0, Vector2(s, s))
			draw_string_outline(fuente, Vector2.ZERO, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.05, 0.04, 0.03, 0.7 * alfa))
			draw_string(fuente, Vector2.ZERO, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.98, 0.95, 0.88, alfa))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _choca(caja: Rect2, ocupados: Array[Rect2]) -> bool:
	for o in ocupados:
		if o.intersects(caja):
			return true
	return false


## El marcador bajo un punto del mapa, o {} si no hay.
func elemento_en(mundo: Vector2, zoom: float) -> Dictionary:
	var s := 1.0 / zoom
	var mejor := {}
	var mejor_d := INF
	var chico := zoom < ZOOM_PUNTOS
	for v in _visibles:
		if zoom < ZOOM_OCULTAR:
			break
		var p: Vector2 = v["px"] + (Vector2.ZERO if chico else _desplazamiento(v["orden"]) * s)
		var d := p.distance_to(mundo)
		if d < ((6.0 if chico else RADIO + 3.0)) * s and d < mejor_d:
			mejor_d = d
			mejor = {"tipo": v["tipo"], "id": v["id"], "texto": v["texto"]}
	if mejor.is_empty():
		for l in _ciudades:
			var imp := int(l.get("importancia", 2))
			if zoom < {3: 0.35, 2: 0.9, 1: 1.8}.get(imp, 0.9):
				continue
			if (l["_px"] as Vector2).distance_to(mundo) < 9.0 * s:
				return {"tipo": "lugar", "id": l["id"], "texto": l.get("nombre", "")}
	return mejor
