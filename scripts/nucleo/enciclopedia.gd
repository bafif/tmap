extends Node
## La enciclopedia: regiones, fuentes, personas, hechos y lugares, leídos de `data/enciclopedia/paquetes/*.json`.
## El formato está en `data/enciclopedia/ESQUEMA.md`.

const DIR := "res://data/enciclopedia/paquetes/"
const RUTA_PENDIENTES := "user://pendientes.json"
const SECCIONES := ["regiones", "fuentes", "personas", "hechos", "lugares"]

## Colores de las familias de religión, cultura e idioma (lo que no esté acá recibe un color derivado del nombre).
const COLORES_FAMILIA := {
	"politeismo-egipcio": "#d1a54a", "politeismo-mesopotamico": "#b8763a", "politeismo-griego": "#5f86b8",
	"politeismo-romano": "#a34a3a", "judaismo": "#3f78b5", "cristianismo": "#c9c3e6", "cristianismo-copto": "#8e7cc3",
	"cristianismo-ortodoxo": "#7a5aa8", "catolicismo": "#e8e0c8", "protestantismo": "#6f9fd0", "islam-sunni": "#3f8a4e",
	"islam-chii": "#2f6e5a", "zoroastrismo": "#d9663a", "budismo": "#e3a83a", "hinduismo": "#e07a3a",
	"vedismo": "#c4682e", "jainismo": "#d8b04a", "confucianismo": "#b23a3a", "taoismo": "#4a4a4a",
	"religion-tradicional-china": "#a8433a", "religion-mesoamericana": "#3f9a8a", "religion-andina": "#c98a3a",
	"religiones-originarias": "#8a6a4a",
	"egipcia": "#d1a54a", "semitica": "#b8763a", "griega": "#5f86b8", "latina": "#a34a3a", "persa": "#3e7f6b",
	"arabe": "#3f8a4e", "turca": "#3b7a7a", "china": "#d4b95e", "india": "#e07a3a", "mesoamericana": "#3f9a8a",
	"andina": "#c98a3a", "hispana": "#c9a04a", "criolla": "#6e9cc0", "pueblos-originarios": "#8a6a4a",
}

var regiones := {}
var fuentes := {}
var personas := {}
var hechos := {}
var lugares := {}
var advertencias: Array = []

## Caché: unidad → regiones que contienen su centro (de la más chica a la más grande).
var _regiones_de_unidad := {}
## Familias de cada capa → índice en la paleta (1..n).
var _indices_capa := {}
var _colores_capa := {}


func cargar() -> void:
	for sec in SECCIONES:
		get(sec).clear()
	if not DirAccess.dir_exists_absolute(DIR):
		return
	var archivos := Array(DirAccess.get_files_at(DIR)).filter(func(f): return f.ends_with(".json"))
	archivos.sort()
	for nombre in archivos:
		var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + nombre))
		if not datos is Dictionary:
			advertencias.append("No se pudo leer %s" % nombre)
			continue
		for sec in SECCIONES:
			var destino: Dictionary = get(sec)
			for item in datos.get(sec, []):
				if not item is Dictionary or not item.has("id"):
					continue
				if destino.has(item["id"]):
					advertencias.append("%s: «%s» repetido en %s" % [sec, item["id"], nombre])
					continue
				item["_paquete"] = datos.get("paquete", nombre)
				destino[item["id"]] = item
	_preparar_regiones()
	_preparar_puntos()
	_preparar_capas()
	for a in advertencias:
		push_warning(a)


func _preparar_regiones() -> void:
	for r in regiones.values():
		var poly := PackedVector2Array()
		for p in r.get("poligono", []):
			poly.append(Proyeccion.a_px(float(p[0]), float(p[1])))
		r["_poly"] = poly
		var caja := Rect2(poly[0], Vector2.ZERO) if poly.size() > 0 else Rect2()
		for p in poly:
			caja = caja.expand(p)
		r["_caja"] = caja
		r["_area"] = absf(_area(poly))


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Posición en el mapa de cada elemento con coordenadas y regiones de su punto de escritura.
func _preparar_puntos() -> void:
	for f in fuentes.values():
		var e: Dictionary = f.get("escrita", {})
		if e.has("lon") and e.has("lat"):
			f["_px"] = Proyeccion.a_px(float(e["lon"]), float(e["lat"]))
			f["_regiones_escrita"] = regiones_en(f["_px"])
		f["_desde"] = _anio(e, "anio", 0)
		f["_hasta"] = _anio(e, "anio_hasta", f["_desde"])
	for p in personas.values():
		var lugar: Dictionary = _dic(p, "activo")
		if not lugar.has("lon"):
			lugar = _dic(p, "nacimiento")
		if lugar.has("lon") and lugar.get("lat") != null:
			p["_px"] = Proyeccion.a_px(float(lugar["lon"]), float(lugar["lat"]))
			p["_regiones"] = regiones_en(p["_px"])
		# Vida: nacimiento y muerte; si faltan, los años de actividad (reinado, época conocida); si solo hay uno de
		# los extremos, se estima una vida de unos 60 años. Sin ningún año, la persona no se ubica en el tiempo.
		var activo := _dic(p, "activo")
		var nace := _anio(_dic(p, "nacimiento"), "anio", _anio(activo, "desde", -99999))
		var muere := _anio(_dic(p, "muerte"), "anio", _anio(activo, "hasta", 99999))
		if nace == -99999 and muere != 99999:
			nace = muere - 60
		elif muere == 99999 and nace != -99999:
			muere = mini(nace + 60, Estado.ANIO_MAX) if nace < 1950 else Estado.ANIO_MAX
		p["_desde"] = nace
		p["_hasta"] = muere
		p["_sin_fechas"] = nace == -99999
	for h in hechos.values():
		if h.has("lon"):
			h["_px"] = Proyeccion.a_px(float(h["lon"]), float(h["lat"]))
		h["_desde"] = int(h.get("anio", 0))
		h["_hasta"] = int(h["anio_hasta"]) if h.get("anio_hasta") != null else h["_desde"]
	for l in lugares.values():
		if l.has("lon"):
			l["_px"] = Proyeccion.a_px(float(l["lon"]), float(l["lat"]))
		l["_desde"] = int(l["fundacion"]) if l.get("fundacion") != null else Estado.ANIO_MIN
		l["_hasta"] = int(l["abandono"]) if l.get("abandono") != null else Estado.ANIO_MAX


func _dic(d: Dictionary, clave: String) -> Dictionary:
	var v: Variant = d.get(clave)
	return v if v is Dictionary else {}


func _anio(d: Dictionary, clave: String, defecto: int) -> int:
	var v: Variant = d.get(clave)
	return int(v) if v != null else defecto


func _preparar_capas() -> void:
	for capa in ["religiones", "culturas", "idiomas"]:
		var indices := {}
		var colores := PackedColorArray([Color(0, 0, 0, 0)])
		for r in regiones.values():
			for v in r.get(capa, []):
				var fam: String = str(v.get("familia", v.get("nombre", "?")))
				if not indices.has(fam):
					indices[fam] = colores.size()
					colores.append(color_familia(fam))
		_indices_capa[capa] = indices
		_colores_capa[capa] = colores


func color_familia(fam: String) -> Color:
	if COLORES_FAMILIA.has(fam):
		return Color(COLORES_FAMILIA[fam])
	var h := float(fam.hash() & 0xFFFF) / 65535.0
	return Color.from_hsv(h, 0.45, 0.72)


# ---------------------------------------------------------------------------------------------------------------
# Consultas espaciales


## Regiones que contienen un punto (px del mapa), de la más chica a la más grande.
func regiones_en(px: Vector2) -> Array:
	var out: Array = []
	for r in regiones.values():
		if r["_caja"].has_point(px) and Geometry2D.is_point_in_polygon(px, r["_poly"]):
			out.append(r)
	out.sort_custom(func(a, b): return a["_area"] < b["_area"])
	return out.map(func(r): return r["id"])


func regiones_de_unidad(u: int) -> Array:
	if not _regiones_de_unidad.has(u):
		_regiones_de_unidad[u] = regiones_en(DatosMapa.centro_unidad(u))
	return _regiones_de_unidad[u]


## Las regiones y todos sus ancestros.
func con_ancestros(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var actual: Variant = id
		while actual != null and regiones.has(actual) and not out.has(actual):
			out.append(actual)
			actual = regiones[actual].get("padre")
	return out


# ---------------------------------------------------------------------------------------------------------------
# Consultas temporales


## Fuentes escritas en esas regiones cerca de un año.
func fuentes_escritas(ids_regiones: Array, anio: int, ventana := 150) -> Array:
	var regs := con_ancestros(ids_regiones)
	var out: Array = []
	for f in fuentes.values():
		if not f.has("_regiones_escrita"):
			continue
		var cruza := false
		for r in f["_regiones_escrita"]:
			if regs.has(r):
				cruza = true
				break
		if cruza and f["_desde"] - ventana <= anio and anio <= f["_hasta"] + ventana:
			out.append(f)
	out.sort_custom(func(a, b): return absi(a["_desde"] - anio) < absi(b["_desde"] - anio))
	return out


## Fuentes (de cualquier época) que tratan sobre esas regiones en ese año.
func fuentes_sobre(ids_regiones: Array, anio: int, margen := 25) -> Array:
	var regs := con_ancestros(ids_regiones)
	var out: Array = []
	for f in fuentes.values():
		var trata: Dictionary = f.get("trata", {})
		var cruza := false
		for r in trata.get("regiones", []):
			if regs.has(r):
				cruza = true
				break
		if not cruza:
			continue
		var desde := int(trata.get("desde", Estado.ANIO_MIN))
		var hasta := int(trata.get("hasta", Estado.ANIO_MAX))
		if desde - margen <= anio and anio <= hasta + margen:
			out.append(f)
	out.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
	return out


func personas_vivas(ids_regiones: Array, anio: int) -> Array:
	var regs := con_ancestros(ids_regiones)
	var out: Array = []
	for p in personas.values():
		if not p["_sin_fechas"] and p["_desde"] <= anio and anio <= p["_hasta"]:
			for r in p.get("_regiones", []):
				if regs.has(r):
					out.append(p)
					break
	return out


func hechos_cerca(ids_regiones: Array, anio: int, ventana := 100) -> Array:
	var regs := con_ancestros(ids_regiones)
	var out: Array = []
	for h in hechos.values():
		var cruza := false
		for r in h.get("regiones", []):
			if regs.has(r):
				cruza = true
				break
		if cruza and h["_desde"] - ventana <= anio and anio <= h["_hasta"] + ventana:
			out.append(h)
	out.sort_custom(func(a, b): return a["_desde"] < b["_desde"])
	return out


func era_en(id_region: String, anio: int) -> Dictionary:
	for e in regiones.get(id_region, {}).get("eras", []):
		if int(e["desde"]) <= anio and anio <= int(e["hasta"]):
			return e
	return {}


## Población estimada (interpolación geométrica entre estimaciones publicadas). {} si no hay datos cerca.
func poblacion_en(id_region: String, anio: int) -> Dictionary:
	var serie: Array = estimaciones(id_region)
	if serie.is_empty():
		return {}
	serie.sort_custom(func(a, b): return int(a["anio"]) < int(b["anio"]))
	if anio < int(serie[0]["anio"]) - 300 or anio > int(serie[-1]["anio"]) + 300:
		return {}
	var antes: Dictionary = serie[0]
	var despues: Dictionary = serie[-1]
	for s in serie:
		if int(s["anio"]) <= anio:
			antes = s
		if int(s["anio"]) >= anio:
			despues = s
			break
	if antes == despues or int(antes["anio"]) > anio or int(despues["anio"]) < anio:
		var cerca: Dictionary = antes if absi(int(antes["anio"]) - anio) < absi(int(despues["anio"]) - anio) else despues
		return {"poblacion": float(cerca["poblacion"]), "exacta": int(cerca["anio"]) == anio, "fuente": cerca.get("fuente", ""), "anio": int(cerca["anio"])}
	var t := float(anio - int(antes["anio"])) / float(int(despues["anio"]) - int(antes["anio"]))
	var p := exp(lerpf(log(float(antes["poblacion"])), log(float(despues["poblacion"])), t))
	return {"poblacion": p, "exacta": false, "fuente": "%s; %s" % [antes.get("fuente", ""), despues.get("fuente", "")], "anio": anio}


## Estimaciones modernas de población (sin testimonios antiguos), ordenadas por año.
func estimaciones(id_region: String) -> Array:
	var serie: Array = regiones.get(id_region, {}).get("demografia", []).filter(
		func(e): return e.get("tipo", "") != "testimonio-antiguo")
	serie.sort_custom(func(a, b): return int(a["anio"]) < int(b["anio"]))
	return serie


## Cifras de población dadas por autores antiguos: se muestran como testimonio, no como estimación.
func testimonios_poblacion(id_region: String) -> Array:
	return regiones.get(id_region, {}).get("demografia", []).filter(
		func(e): return e.get("tipo", "") == "testimonio-antiguo")


## Valores de una capa (religiones, culturas, idiomas) vigentes en una región y un año.
func capa_en(id_region: String, capa: String, anio: int) -> Array:
	var out: Array = []
	for v in regiones.get(id_region, {}).get(capa, []):
		if int(v["desde"]) <= anio and anio <= int(v["hasta"]):
			out.append(v)
	return out


## Valores por unidad para pintar una capa en el mapa: la mayoritaria de la región más chica con datos.
func valores_capa(capa: String, anio: int) -> Array:
	var valores := PackedInt32Array()
	valores.resize(DatosMapa.n_unidades + 1)
	valores.fill(0)
	var indices: Dictionary = _indices_capa.get(capa, {})
	var por_region := {}
	for id in regiones.keys():
		var vigentes := capa_en(id, capa, anio)
		var elegido: Variant = null
		for v in vigentes:
			if v.get("peso", "") == "mayoritaria":
				elegido = v
				break
		if elegido == null and vigentes.size() > 0:
			elegido = vigentes[0]
		if elegido != null:
			por_region[id] = indices.get(str(elegido.get("familia", elegido.get("nombre", "?"))), 0)
	if not por_region.is_empty():
		for u in range(1, DatosMapa.n_unidades + 1):
			var c := DatosMapa.centro_unidad(u)
			for r in regiones.values():
				if por_region.has(r["id"]) and r["_caja"].has_point(c):
					var regs := regiones_de_unidad(u)
					for id in regs:
						if por_region.has(id):
							valores[u] = por_region[id]
							break
					break
	return [valores, _colores_capa.get(capa, PackedColorArray([Color(0, 0, 0, 0)]))]


## Leyenda de una capa en un año: [{nombre, color}] de los valores que aparecen.
func leyenda_capa(capa: String, anio: int) -> Array:
	var vistos := {}
	var out: Array = []
	for r in regiones.values():
		for v in capa_en(r["id"], capa, anio):
			var fam := str(v.get("familia", v.get("nombre", "?")))
			if v.get("peso", "") == "mayoritaria" and not vistos.has(fam):
				vistos[fam] = true
				out.append({"nombre": v["nombre"], "color": color_familia(fam)})
	return out


## Busca en todas las secciones por nombre o título.
func buscar(texto: String, max_res := 12) -> Array:
	var t := texto.to_lower()
	var out: Array = []
	var fuentes_busqueda := [["lugar", lugares, "nombre"], ["persona", personas, "nombre"], ["fuente", fuentes, "titulo"],
		["hecho", hechos, "titulo"], ["region", regiones, "nombre"]]
	for fb in fuentes_busqueda:
		for item in fb[1].values():
			if str(item.get(fb[2], "")).to_lower().contains(t):
				out.append({"tipo": fb[0], "id": item["id"], "texto": item[fb[2]]})
				if out.size() >= max_res:
					return out
	return out


## Anota en una lista local lo que se consultó y no tiene ficha curada, para saber qué completar primero
## (docs/es/enciclopedia.md, paso 1 del llenado progresivo). No sale de la computadora.
func registrar_consulta(unidad: int, anio: int) -> void:
	var regs := regiones_de_unidad(unidad)
	var con_ficha := false
	for id in regs:
		if not regiones[id].get("eras", []).is_empty():
			con_ficha = true
	if con_ficha:
		return
	var ent := DatosMapa.dueno(unidad)
	var clave := "entidad:%s" % DatosMapa.entidades[ent]["n"] if ent >= 0 else "lugar:%d" % unidad
	var lista: Dictionary = {}
	if FileAccess.file_exists(RUTA_PENDIENTES):
		var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PENDIENTES))
		if leido is Dictionary:
			lista = leido
	var item: Dictionary = lista.get(clave, {"veces": 0, "anios": []})
	item["veces"] = int(item["veces"]) + 1
	var anios: Array = item["anios"]
	if not anios.has(anio) and anios.size() < 20:
		anios.append(anio)
	if ent >= 0:
		item["wikidata"] = DatosMapa.entidades[ent]["d"]
		item["wikipedia"] = DatosMapa.entidades[ent]["w"]
	var ll := Proyeccion.a_lonlat(DatosMapa.centro_unidad(unidad))
	item["lon"] = snappedf(ll.x, 0.01)
	item["lat"] = snappedf(ll.y, 0.01)
	lista[clave] = item
	var f := FileAccess.open(RUTA_PENDIENTES, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(lista, "\t"))


func elemento(tipo: String, id: String) -> Dictionary:
	match tipo:
		"fuente":
			return fuentes.get(id, {})
		"persona":
			return personas.get(id, {})
		"hecho":
			return hechos.get(id, {})
		"lugar":
			return lugares.get(id, {})
		"region":
			return regiones.get(id, {})
	return {}
