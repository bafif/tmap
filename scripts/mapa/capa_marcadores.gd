class_name CapaMarcadores
extends Node2D
## Marcadores sobre el mapa que aparecen y desaparecen con el año: fuentes (donde se escribieron), personas
## (mientras viven, donde están ese año), hechos (desde su fecha y un tiempo después) y ciudades (mientras existen).
## Se dibujan a tamaño constante en pantalla; los que aparecen en el año actual hacen un pequeño destello.
## Los que se pisan en pantalla se juntan en un grupo con su número, que se separa al acercarse; los que comparten el
## punto exacto (varias fuentes de Alejandría) se abren en espiral desde ZOOM_SEPARAR.

const RADIO := 13.0
const VENTANA_HECHO := 40
const VIDA_FUENTE := 150
## Más lejos que esto no se dibujan marcadores; entre esto y ZOOM_PUNTOS, solo puntos chicos.
const ZOOM_OCULTAR := 0.26
const ZOOM_PUNTOS := 0.5
const ZOOM_SEPARAR := 3.2

const ICONOS := {
	"fuente": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><path fill='#fff' d='M7 15c9-4 17-3 23 2v34c-6-5-14-6-23-2z'/><path fill='#fff' d='M57 15c-9-4-17-3-23 2v34c6-5 14-6 23-2z'/></svg>",
	"persona": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><circle fill='#fff' cx='32' cy='21' r='11'/><path fill='#fff' d='M11 55c0-13 9-21 21-21s21 8 21 21z'/></svg>",
	"hecho": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><path fill='#fff' d='M32 5l7.5 17.5 19 1.5-14.5 12.3 4.6 18.7L32 45 15.4 55l4.6-18.7L5.5 24l19-1.5z'/></svg>",
}

var _texturas := {}
var _visibles: Array = []
var _ciudades: Array = []
var _destello := {}
## Grupos para el último zoom: [{px, miembros: [marcador…]}], y el zoom para el que se calcularon.
var _grupos: Array = []
var _zoom_grupos := -1.0


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
				_visibles.append({"tipo": "persona", "id": p["id"], "px": Enciclopedia.px_en(p, anio), "icono": "persona", "color": TemaUI.color("persona"), "alfa": 1.0, "texto": p.get("nombre", "")})
	if aj.get("mostrar_hechos", true):
		for h in Enciclopedia.hechos.values():
			if h.has("_px") and h["_desde"] <= anio and anio <= h["_hasta"] + VENTANA_HECHO:
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
	_zoom_grupos = -1.0
	queue_redraw()


## Junta los marcadores que se pisarían en pantalla con este zoom. Grilla del tamaño de un marcador y búsqueda en las
## nueve celdas vecinas: lineal en la cantidad de marcadores, así se puede recalcular en cada cuadro.
func agrupar(z: float) -> Array:
	if is_equal_approx(z, _zoom_grupos):
		return _grupos
	var celda := RADIO * 2.3 / z
	var por_celda := {}
	_grupos = []
	for v in _visibles:
		var p: Vector2 = v["px"]
		var c := Vector2i(floori(p.x / celda), floori(p.y / celda))
		var destino: Variant = null
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for g in por_celda.get(c + Vector2i(dx, dy), []):
					if (g["px"] as Vector2).distance_to(p) < celda:
						destino = g
						break
				if destino != null:
					break
			if destino != null:
				break
		if destino == null:
			destino = {"px": p, "miembros": []}
			_grupos.append(destino)
			if not por_celda.has(c):
				por_celda[c] = []
			por_celda[c].append(destino)
		destino["miembros"].append(v)
	_zoom_grupos = z
	return _grupos


## Un grupo se dibuja junto si tiene varios miembros y, o el zoom no alcanza para separarlos, o están en puntos
## distintos (entonces acercarse los separa).
func _junto(g: Dictionary, z: float) -> bool:
	var m: Array = g["miembros"]
	if m.size() < 2:
		return false
	if z < ZOOM_SEPARAR:
		return true
	for v in m:
		if (v["px"] as Vector2).distance_to(g["px"]) > 0.5:
			return true
	return false


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
	var sueltos: Array = []
	if chico:
		sueltos = _visibles
	else:
		for g in agrupar(z):
			if _junto(g, z):
				_dibujar_grupo(g, z, ahora)
			else:
				sueltos.append_array(g["miembros"])
	for v in sueltos:
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


func _dibujar_grupo(g: Dictionary, z: float, ahora: int) -> void:
	var s := 1.0 / z
	var p: Vector2 = g["px"]
	var miembros: Array = g["miembros"]
	var r := RADIO * 1.2 * s
	var acento := TemaUI.color("acento")
	for v in miembros:
		var k: String = v["tipo"] + v["id"]
		if _destello.has(k):
			var t := clampf((ahora - int(_destello[k])) / 900.0, 0.0, 1.0)
			draw_circle(p, r * (1.0 + 2.0 * t), Color(acento, 0.5 * (1.0 - t)), false, 2.0 * s)
			break
	draw_circle(p + Vector2(0, 1.5 * s), r + 2.0 * s, Color(0, 0, 0, 0.35))
	draw_circle(p, r + 1.5 * s, Color(0.06, 0.05, 0.04))
	draw_circle(p, r, Color(0.16, 0.14, 0.12))
	draw_circle(p, r, acento, false, 1.6 * s)
	# Un punto por cada tipo presente (fuente, persona, hecho), con su color.
	var colores: Array = []
	for v in miembros:
		if not colores.has(v["color"]):
			colores.append(v["color"])
	for i in mini(colores.size(), 4):
		var ang := PI * 0.5 + (i - (mini(colores.size(), 4) - 1) * 0.5) * 0.55
		draw_circle(p + Vector2(cos(ang), sin(ang)) * r, 3.2 * s, colores[i])
	var texto := str(miembros.size())
	var f := TemaUI.fuente_titulo
	var tam := 16
	var ancho := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_set_transform(p + Vector2(-ancho * 0.5, tam * 0.36) * s, 0.0, Vector2(s, s))
	draw_string(f, Vector2.ZERO, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0.98, 0.95, 0.88))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _choca(caja: Rect2, ocupados: Array[Rect2]) -> bool:
	for o in ocupados:
		if o.intersects(caja):
			return true
	return false


## El marcador bajo un punto del mapa, o {} si no hay. `holgura` agranda el margen (con el dedo).
func elemento_en(mundo: Vector2, zoom: float, holgura := 1.0) -> Dictionary:
	var s := 1.0 / zoom
	# Margen para acertarle a un marcador (más grande con el dedo).
	var m := holgura / zoom
	var mejor := {}
	var mejor_d := INF
	var chico := zoom < ZOOM_PUNTOS
	var sueltos: Array = _visibles
	if not chico and zoom >= ZOOM_OCULTAR:
		sueltos = []
		for g in agrupar(zoom):
			if not _junto(g, zoom):
				sueltos.append_array(g["miembros"])
			elif (g["px"] as Vector2).distance_to(mundo) < (RADIO * 1.2 + 3.0) * m:
				var nombres: Array = g["miembros"].slice(0, 4).map(func(v): return str(v["texto"]))
				var resto: int = g["miembros"].size() - nombres.size()
				return {"tipo": "grupo", "id": "", "px": g["px"], "n": g["miembros"].size(),
					"texto": tr("%d juntos: %s") % [g["miembros"].size(), "; ".join(nombres)] + (tr(" y %d más") % resto if resto > 0 else "")}
	for v in sueltos:
		if zoom < ZOOM_OCULTAR:
			break
		var p: Vector2 = v["px"] + (Vector2.ZERO if chico else _desplazamiento(v["orden"]) * s)
		var d := p.distance_to(mundo)
		if d < ((6.0 if chico else RADIO + 3.0)) * m and d < mejor_d:
			mejor_d = d
			mejor = {"tipo": v["tipo"], "id": v["id"], "texto": v["texto"]}
	if mejor.is_empty():
		for l in _ciudades:
			var imp := int(l.get("importancia", 2))
			if zoom < {3: 0.35, 2: 0.9, 1: 1.8}.get(imp, 0.9):
				continue
			if (l["_px"] as Vector2).distance_to(mundo) < 9.0 * m:
				return {"tipo": "lugar", "id": l["id"], "texto": l.get("nombre", "")}
	return mejor
