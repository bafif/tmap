class_name Pleiades
## Lugares antiguos de Pleiades (https://pleiades.stoa.org, CC BY 3.0): `data/pleiades/lugares.json`, que arma
## `tools/pleiades/pleiades.py`. Son unos 27 000 puntos con nombre, años y categoría; la descripción y los nombres
## antiguos se piden en vivo a Pleiades cuando se abre una ficha (`Wiki.pleiades`).
##
## Se leen la primera vez que hacen falta (al acercarse al mapa con la capa encendida), no al arrancar.

const ARCHIVO := "res://data/pleiades/lugares.json"
## Lugares de la enciclopedia que son el mismo que uno de Pleiades (lo arma `tools/pleiades/enlazar.py`): su punto de
## Pleiades no se dibuja ni se toca en el mapa, porque ya está la ciudad de la enciclopedia.
const ARCHIVO_UNION := "res://data/pleiades/enciclopedia.json"
## Lado de la celda de la grilla, en píxeles del mapa (unos 3 grados).
const CELDA := 64.0
const NOMBRES_CATEGORIA := {
	"asentamiento": "asentamiento", "villa": "villa o finca", "fortificacion": "fortificación",
	"santuario": "santuario o templo", "tumba": "tumba o necrópolis", "puerto": "puerto",
	"camino": "camino, puente u obra hidráulica", "edificio": "edificio público", "produccion": "mina o cantera",
	"sitio": "sitio arqueológico",
}
const COLORES_CATEGORIA := {
	"asentamiento": Color("#e8d9b5"), "villa": Color("#c9b98a"), "fortificacion": Color("#c9826b"),
	"santuario": Color("#d9b65e"), "tumba": Color("#a99aa8"), "puerto": Color("#7fb2c9"),
	"camino": Color("#9fb59a"), "edificio": Color("#e0a96d"), "produccion": Color("#b59c7f"),
	"sitio": Color("#b8ad98"),
}

static var ids := PackedInt32Array()
static var nombres := PackedStringArray()
static var px := PackedVector2Array()
static var desde := PackedInt32Array()
static var hasta := PackedInt32Array()
static var categoria := PackedByteArray()
static var categorias: Array = []
static var _por_celda := {}
static var _por_id := {}
static var _minusculas := PackedStringArray()
## 1 si el lugar está unido a uno de la enciclopedia (no se dibuja en el mapa).
static var unido := PackedByteArray()
static var _de_lugar := {}
static var _union_leida := false
static var _cargado := false


static func cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var t0 := Time.get_ticks_msec()
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(Datos.ruta(ARCHIVO)))
	if not datos is Dictionary or not datos.get("lugares") is Array:
		push_warning("Pleiades: no se pudo leer %s" % ARCHIVO)
		return
	categorias = datos.get("categorias", [])
	var lista: Array = datos["lugares"]
	var n := lista.size()
	ids.resize(n)
	nombres.resize(n)
	px.resize(n)
	desde.resize(n)
	hasta.resize(n)
	categoria.resize(n)
	for i in n:
		var l: Array = lista[i]
		ids[i] = int(l[0])
		nombres[i] = str(l[1])
		px[i] = Proyeccion.a_px(float(l[2]), float(l[3]))
		desde[i] = int(l[4])
		hasta[i] = int(l[5])
		categoria[i] = int(l[6])
		_por_id[ids[i]] = i
		var c := _celda(px[i])
		if not _por_celda.has(c):
			_por_celda[c] = PackedInt32Array()
		_por_celda[c].append(i)
	unido.resize(n)
	unido.fill(0)
	for lugar in _union():
		var k: int = _por_id.get(int(_de_lugar[lugar]), -1)
		if k >= 0:
			unido[k] = 1
	print("Pleiades: %d lugares en %d ms" % [n, Time.get_ticks_msec() - t0])


## Lugar de la enciclopedia → id de Pleiades. Se lee aparte (es chico): la ficha de un lugar lo consulta sin cargar
## los 27 000 de Pleiades.
static func _union() -> Dictionary:
	if not _union_leida:
		_union_leida = true
		var ruta := Datos.ruta(ARCHIVO_UNION)
		if FileAccess.file_exists(ruta):
			var u: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
			if u is Dictionary and u.get("lugares") is Dictionary:
				_de_lugar = u["lugares"]
	return _de_lugar


## El id de Pleiades del lugar de la enciclopedia, o -1.
static func de_lugar(id_lugar: String) -> int:
	return int(_union().get(id_lugar, -1))


static func cantidad() -> int:
	cargar()
	return ids.size()


static func _celda(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELDA), floori(p.y / CELDA))


## Índices de los lugares dentro de `rect` (píxeles del mapa) que existen en `anio`.
static func en_rect(rect: Rect2, anio: int) -> PackedInt32Array:
	cargar()
	var out := PackedInt32Array()
	var a := _celda(rect.position)
	var b := _celda(rect.end)
	for cx in range(a.x, b.x + 1):
		for cy in range(a.y, b.y + 1):
			for i in _por_celda.get(Vector2i(cx, cy), PackedInt32Array()):
				if desde[i] <= anio and anio <= hasta[i] and unido[i] == 0 and rect.has_point(px[i]):
					out.append(i)
	return out


## El lugar más cercano a `p` a menos de `radio` píxeles del mapa que existe en `anio`, o -1.
static func cercano(p: Vector2, radio: float, anio: int) -> int:
	var mejor := -1
	var mejor_d := radio
	for i in en_rect(Rect2(p - Vector2(radio, radio), Vector2(radio, radio) * 2.0), anio):
		var d := px[i].distance_to(p)
		if d < mejor_d:
			mejor_d = d
			mejor = i
	return mejor


## Índice del lugar con ese id de Pleiades, o -1.
static func indice(id: int) -> int:
	cargar()
	return _por_id.get(id, -1)


## El nombre para mostrar: los que Pleiades no tiene con nombre («Untitled») van como «Villa sin nombre».
static func nombre(i: int) -> String:
	if nombres[i] != "":
		return nombres[i]
	var s := Idioma.t("%s sin nombre") % nombre_categoria(i)
	return s.substr(0, 1).to_upper() + s.substr(1)


## Hasta `max_res` índices de lugares cuyo nombre contiene `texto` (sin distinguir mayúsculas).
static func buscar(texto: String, max_res := 6) -> PackedInt32Array:
	cargar()
	if _minusculas.is_empty():
		_minusculas.resize(nombres.size())
		for i in nombres.size():
			_minusculas[i] = nombres[i].to_lower()
	var t := texto.to_lower()
	var out := PackedInt32Array()
	for i in _minusculas.size():
		if _minusculas[i].contains(t):
			out.append(i)
			if out.size() >= max_res:
				break
	return out


static func clave_categoria(i: int) -> String:
	var c := int(categoria[i])
	return str(categorias[c]) if c < categorias.size() else "sitio"


static func nombre_categoria(i: int) -> String:
	return Idioma.t(NOMBRES_CATEGORIA.get(clave_categoria(i), "sitio arqueológico"))


static func color_categoria(i: int) -> Color:
	return COLORES_CATEGORIA.get(clave_categoria(i), Color("#b8ad98"))


static func url(id: int) -> String:
	return "https://pleiades.stoa.org/places/%d" % id
