extends Node
## La enciclopedia: regiones, fuentes, personas, hechos y lugares, leídos de `data/enciclopedia/paquetes/*.json`.
## El formato está en `data/enciclopedia/ESQUEMA.md`.
##
## Los paquetes están en español. Con la app en otro idioma, al leer cada paquete se le aplica su capa de traducción
## (`data/enciclopedia/traducciones/<idioma>/<paquete>.json`, ver «Traducciones» en el esquema): los textos traducidos
## reemplazan a los españoles en memoria y lo que no tiene traducción queda en español. Los archivos no cambian: el
## editor lee y escribe siempre los paquetes en español.

const DIR := "res://data/enciclopedia/paquetes/"
const RUTA_PENDIENTES := "user://pendientes.json"
const DIR_TRADUCCIONES := "res://data/enciclopedia/traducciones/"
## Copias en la Wayback Machine de los enlaces de lectura (url → copia), que arma tools/enciclopedia/enlaces.py.
const ARCHIVO_COPIAS := "res://data/enciclopedia/archivo.json"
const SECCIONES := ["regiones", "fuentes", "personas", "hechos", "lugares"]

const CAPAS := ["religiones", "culturas", "idiomas"]
const CAPA_DE_MODO := {"religion": "religiones", "cultura": "culturas", "idioma": "idiomas"}
const MODO_DE_CAPA := {"religiones": "religion", "culturas": "cultura", "idiomas": "idioma"}
## En español: se traducen con tr() al mostrarlos.
const NOMBRE_CAPA := {"religiones": "Religión", "culturas": "Cultura", "idiomas": "Idioma"}
const ORDEN_PESO := {"mayoritaria": 0, "importante": 1, "minoritaria": 2}
## El peso como se muestra (en español: se traduce con tr()).
const NOMBRE_PESO := {"mayoritaria": "mayoritaria", "importante": "importante", "minoritaria": "minoritaria"}

var regiones := {}
var fuentes := {}
var personas := {}
var hechos := {}
var lugares := {}
## Familias de religión, cultura e idioma por clave «capa:id» (ver la sección `familias` del esquema).
var familias := {}
var advertencias: Array = []
var _copias := {}
var _copias_leidas := false
## De dónde se leen las capas de traducción (la prueba de tools/traduccion la cambia con --traducciones=<carpeta>).
var dir_traducciones := DIR_TRADUCCIONES
## Cuántos textos tradujo la capa en la última carga.
var traducidos := 0

## Caché: unidad → regiones que contienen su centro (de la más chica a la más grande).
var _regiones_de_unidad := {}
## Familias de cada capa → índice en la paleta (1..n).
var _indices_capa := {}
var _colores_capa := {}
## Valores por unidad ya calculados, según qué familia rige en cada región (muchos años comparten la misma).
var _cache_valores := {}


func cargar() -> void:
	for sec in SECCIONES:
		get(sec).clear()
	familias.clear()
	_cache_valores.clear()
	# Al recargar (después de editar) puede haber regiones nuevas o con otra área.
	_regiones_de_unidad.clear()
	# Con una actualización de datos instalada, los paquetes se listan (y se leen) de su carpeta local.
	if not DirAccess.dir_exists_absolute(Datos.ruta(DIR)):
		return
	var archivos := Array(DirAccess.get_files_at(Datos.ruta(DIR))).filter(func(f): return f.ends_with(".json"))
	archivos.sort()
	# Cuánto pesa y cuánto tarda: el plan de almacenamiento (docs/es/almacenamiento.md) fija umbrales sobre esto.
	var t0 := Time.get_ticks_msec()
	var bytes := 0
	traducidos = 0
	for nombre in archivos:
		# En una versión exportada, lo editado en el editor queda en una copia local que tapa al paquete de adentro.
		var texto := FileAccess.get_file_as_string(Edicion.para_leer(DIR + nombre))
		bytes += texto.length()
		var datos: Variant = JSON.parse_string(texto)
		if not datos is Dictionary:
			advertencias.append("No se pudo leer %s" % nombre)
			continue
		if Idioma.actual != "es":
			traducidos += _traducir(datos, nombre)
		for sec in SECCIONES:
			var destino: Dictionary = get(sec)
			for item in datos.get(sec, []):
				if not item is Dictionary or not item.has("id"):
					continue
				if destino.has(item["id"]):
					advertencias.append("%s: «%s» repetido en %s" % [sec, item["id"], nombre])
					continue
				item["_paquete"] = datos.get("paquete", nombre)
				item["_archivo"] = DIR + nombre
				destino[item["id"]] = item
		for f in datos.get("familias", []):
			if not f is Dictionary or not f.has("id") or not CAPAS.has(f.get("capa")):
				continue
			var clave := "%s:%s" % [f["capa"], f["id"]]
			if familias.has(clave):
				advertencias.append("familias: «%s» repetida en %s" % [clave, nombre])
				continue
			f["_clave"] = clave
			f["_hijas"] = []
			familias[clave] = f
	var t1 := Time.get_ticks_msec()
	_preparar_regiones()
	_preparar_puntos()
	_preparar_capas()
	var n := 0
	for sec in SECCIONES:
		n += (get(sec) as Dictionary).size()
	print("Enciclopedia: %d elementos de %d paquetes (%.1f MB) en %d ms: lectura %d ms, preparación %d ms%s" % [
		n, archivos.size(), bytes / 1048576.0, Time.get_ticks_msec() - t0, t1 - t0, Time.get_ticks_msec() - t1,
		"; %d textos en %s" % [traducidos, Idioma.actual] if Idioma.actual != "es" else ""])
	for a in advertencias:
		push_warning(a)


## La capa de traducción de un paquete: {"textos": {"sección/id/campo": {"hash", "texto"}}}, donde el campo es un
## camino con puntos («eras.2.nombre», «escrita.lugar») y las familias se nombran «capa:id». Cada texto traducido
## reemplaza al español; los que ya no encuentran su lugar (un elemento borrado) se ignoran. El hash es del texto
## español que se tradujo: lo usa tools/traduccion/enciclopedia.py para saber qué hay que volver a traducir; la app
## muestra la traducción aunque el español haya cambiado después. Devuelve cuántos textos tradujo.
func _traducir(datos: Dictionary, archivo: String) -> int:
	var ruta := dir_traducciones + Idioma.actual + "/" + archivo
	if ruta.begins_with("res://"):
		ruta = Datos.ruta(ruta)
	if not FileAccess.file_exists(ruta):
		return 0
	var capa: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if not capa is Dictionary or not capa.get("textos") is Dictionary:
		advertencias.append("No se pudo leer la traducción %s" % ruta)
		return 0
	var por_id := {}
	var n := 0
	var textos: Dictionary = capa["textos"]
	for clave: String in textos:
		var partes := clave.split("/", true, 2)
		var valor: Variant = textos[clave]
		if partes.size() < 3 or not valor is Dictionary or str(valor.get("texto", "")) == "":
			continue
		var sec := partes[0]
		if not por_id.has(sec):
			var indice := {}
			for item in datos.get(sec, []):
				if item is Dictionary and item.has("id"):
					indice["%s:%s" % [item.get("capa"), item["id"]] if sec == "familias" else str(item["id"])] = item
			por_id[sec] = indice
		var item: Variant = por_id[sec].get(partes[1])
		if item is Dictionary and _poner(item, partes[2].split("."), str(valor["texto"])):
			n += 1
	return n


## Reemplaza el texto en el camino dado («eras.2.nombre») si existe y es un texto.
static func _poner(item: Dictionary, camino: PackedStringArray, texto: String) -> bool:
	var actual: Variant = item
	for i in camino.size():
		var paso := camino[i]
		var ultimo := i == camino.size() - 1
		if actual is Array:
			if not paso.is_valid_int() or int(paso) < 0 or int(paso) >= (actual as Array).size():
				return false
			if ultimo:
				if not actual[int(paso)] is String:
					return false
				actual[int(paso)] = texto
				return true
			actual = actual[int(paso)]
		elif actual is Dictionary:
			if ultimo:
				if not actual.get(paso) is String:
					return false
				actual[paso] = texto
				return true
			actual = actual.get(paso)
		else:
			return false
	return false


## Vuelve a leer los paquetes (después de editarlos) y refresca lo que se ve: mapa, marcadores y panel.
func recargar() -> void:
	advertencias.clear()
	cargar()
	Estado.anio_cambiado.emit(Estado.anio)
	var u := Estado.unidad_seleccionada
	if u > 0:
		Estado.seleccionar_lugar(u, DatosMapa.centro_unidad(u))


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
		var en_activo := lugar.has("lon")
		if not en_activo:
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
		# Si `activo` tiene años, el mapa la muestra ahí solo esos años: antes, donde nació, y después, donde murió
		# (Pedro de Mendoza no está en Buenos Aires hasta 1536). Sin esos lugares, se queda en `activo`.
		p.erase("_antes")
		p.erase("_despues")
		if en_activo:
			var nacimiento := _dic(p, "nacimiento")
			var muerte := _dic(p, "muerte")
			if activo.get("desde") != null and nacimiento.get("lon") != null and nacimiento.get("lat") != null:
				p["_antes"] = [int(activo["desde"]), Proyeccion.a_px(float(nacimiento["lon"]), float(nacimiento["lat"]))]
			if activo.get("hasta") != null and muerte.get("lon") != null and muerte.get("lat") != null:
				p["_despues"] = [int(activo["hasta"]), Proyeccion.a_px(float(muerte["lon"]), float(muerte["lat"]))]
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


## Dónde está un elemento en `anio`. Solo las personas cambian de lugar (ver `_preparar_puntos`).
func px_en(el: Dictionary, anio: int) -> Vector2:
	if el.has("_antes") and anio < int(el["_antes"][0]):
		return el["_antes"][1]
	if el.has("_despues") and anio > int(el["_despues"][0]):
		return el["_despues"][1]
	return el["_px"]


## Un año en que se ve a la persona donde trabajó: `anio` llevado a sus años de actividad, si los tiene.
func anio_en_activo(p: Dictionary, anio: int) -> int:
	if p.has("_despues"):
		anio = mini(anio, int(p["_despues"][0]))
	if p.has("_antes"):
		anio = maxi(anio, int(p["_antes"][0]))
	return anio


func _dic(d: Dictionary, clave: String) -> Dictionary:
	var v: Variant = d.get(clave)
	return v if v is Dictionary else {}


func _anio(d: Dictionary, clave: String, defecto: int) -> int:
	var v: Variant = d.get(clave)
	return int(v) if v != null else defecto


func _preparar_capas() -> void:
	for f in familias.values():
		var padre := "%s:%s" % [f["capa"], f.get("padre")] if f.get("padre") != null else ""
		if familias.has(padre):
			familias[padre]["_hijas"].append(f["_clave"])
	for capa in CAPAS:
		var indices := {}
		var colores := PackedColorArray([Color(0, 0, 0, 0)])
		for r in regiones.values():
			for v in r.get(capa, []):
				var fam := familia_de(v)
				if not indices.has(fam):
					indices[fam] = colores.size()
					colores.append(color_familia(capa, fam))
				if not familias.has("%s:%s" % [capa, fam]):
					advertencias.append("%s: la familia «%s» de la región %s no está en la sección familias" % [capa, fam, r["id"]])
		_indices_capa[capa] = indices
		_colores_capa[capa] = colores


## Extremos de una entrada de era o de capa; `null` es «desde siempre» o «hasta hoy».
func desde_de(v: Dictionary) -> int:
	return int(v["desde"]) if v.get("desde") != null else Estado.ANIO_MIN


func hasta_de(v: Dictionary) -> int:
	return int(v["hasta"]) if v.get("hasta") != null else Estado.ANIO_MAX


## El período de una entrada de era o de capa en texto, sin inventar extremos: «desde 1100», «hasta 432».
func rango_de(v: Dictionary) -> String:
	var abierto_antes: bool = v.get("desde") == null
	var abierto_despues: bool = v.get("hasta") == null
	if abierto_antes and abierto_despues:
		return tr("siempre")
	if abierto_antes:
		return tr("hasta %s") % Fechas.texto(hasta_de(v))
	if abierto_despues:
		return tr("desde %s") % Fechas.texto(desde_de(v))
	return Fechas.rango(desde_de(v), hasta_de(v))


## El id de familia de una entrada de capa (si falta, su nombre).
func familia_de(v: Dictionary) -> String:
	return str(v.get("familia", v.get("nombre", "?")))


func color_familia(capa: String, fam: String) -> Color:
	var f: Dictionary = familias.get("%s:%s" % [capa, fam], {})
	if f.get("color"):
		return Color(str(f["color"]))
	var h := float(fam.hash() & 0xFFFF) / 65535.0
	return Color.from_hsv(h, 0.45, 0.72)


# ---------------------------------------------------------------------------------------------------------------
# Familias de religión, cultura e idioma


func familia(clave: String) -> Dictionary:
	return familias.get(clave, {})


func nombre_familia(capa: String, fam: String) -> String:
	return str(familias.get("%s:%s" % [capa, fam], {}).get("nombre", fam))


## Índice de la familia en la paleta de su capa (el valor que el mapa usa para pintarla), o -1.
func indice_familia(clave: String) -> int:
	var partes := clave.split(":", true, 1)
	if partes.size() < 2:
		return -1
	return int(_indices_capa.get(partes[0], {}).get(partes[1], -1))


## Claves de las familias mayores, de la madre a la más general.
func ancestros_familia(clave: String) -> Array:
	var out: Array = []
	var f := familia(clave)
	while f.get("padre") != null:
		var padre := "%s:%s" % [f["capa"], f["padre"]]
		if out.has(padre) or not familias.has(padre):
			break
		out.append(padre)
		f = familias[padre]
	return out


## La familia y todas sus descendientes (ids, sin la capa).
func con_descendientes(clave: String) -> Array:
	var out: Array = []
	var pendientes: Array = [clave]
	while not pendientes.is_empty():
		var c: String = pendientes.pop_back()
		if not familias.has(c) or out.has(familias[c]["id"]):
			continue
		out.append(familias[c]["id"])
		pendientes.append_array(familias[c]["_hijas"])
	return out


## Dónde aparece una familia (y sus descendientes) a lo largo del tiempo:
## [{region, desde, hasta, peso, nombre, familia, nota}], ordenado por región y por año.
func presencia_familia(clave: String) -> Array:
	var capa := clave.get_slice(":", 0)
	var ids := con_descendientes(clave)
	if ids.is_empty():
		ids = [clave.get_slice(":", 1)]
	var out: Array = []
	for r in regiones.values():
		for v in r.get(capa, []):
			if ids.has(familia_de(v)):
				out.append({"region": r["id"], "desde": desde_de(v), "hasta": hasta_de(v), "rango": rango_de(v), "nombre": v["nombre"],
					"peso": str(v.get("peso", "")), "familia": familia_de(v), "nota": str(v.get("nota", ""))})
	out.sort_custom(func(a, b): return [regiones[a["region"]]["nombre"], a["desde"]] < [regiones[b["region"]]["nombre"], b["desde"]])
	return out


## Fuentes que tratan sobre las regiones y los años donde aparece una familia. En religiones, primero las de
## género religioso; después, las que pasan más parte de su período dentro de esa presencia.
func fuentes_de_familia(clave: String) -> Array:
	var pres := presencia_familia(clave)
	var puntaje := {}
	var out: Array = []
	for f in fuentes.values():
		var trata: Dictionary = f.get("trata", {})
		var desde := int(trata.get("desde", Estado.ANIO_MIN))
		var hasta := int(trata.get("hasta", Estado.ANIO_MAX))
		var regs := con_ancestros(trata.get("regiones", []))
		var mejor := 0.0
		for e in pres:
			if regs.has(e["region"]) and desde <= e["hasta"] and e["desde"] <= hasta:
				var cruce := mini(hasta, e["hasta"]) - maxi(desde, e["desde"]) + 1
				mejor = maxf(mejor, float(cruce) / float(maxi(hasta - desde + 1, 1)))
		if mejor > 0.0:
			puntaje[f["id"]] = mejor
			out.append(f)
	var religion := clave.begins_with("religiones:")
	out.sort_custom(func(a, b):
		var ra: bool = religion and a.get("genero", "") == "religioso"
		var rb: bool = religion and b.get("genero", "") == "religioso"
		if ra != rb:
			return ra
		if not is_equal_approx(puntaje[a["id"]], puntaje[b["id"]]):
			return puntaje[a["id"]] > puntaje[b["id"]]
		return a["_desde"] < b["_desde"])
	return out


## La familia que el mapa pinta en una unidad en un año (la mayoritaria de la región más chica con datos), o "".
func familia_en_unidad(capa: String, u: int, anio: int) -> String:
	for id in regiones_de_unidad(u):
		var v := _vigente_principal(id, capa, anio)
		if not v.is_empty():
			return familia_de(v)
	return ""


func _vigente_principal(id_region: String, capa: String, anio: int) -> Dictionary:
	var vigentes := capa_en(id_region, capa, anio)
	for v in vigentes:
		if v.get("peso", "") == "mayoritaria":
			return v
	return vigentes[0] if vigentes.size() > 0 else {}


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
		if desde_de(e) <= anio and anio <= hasta_de(e):
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
		if desde_de(v) <= anio and anio <= hasta_de(v):
			out.append(v)
	return out


## Valores por unidad para pintar una capa en el mapa: la mayoritaria de la región más chica con datos.
## Las unidades sin entidad política registrada ese año (desiertos, zonas sin estado) llevan el valor + tenue_capa(),
## y el mapa las pinta más tenues: así cada región toma el contorno real de Cliopatria en vez del de su polígono.
func valores_capa(capa: String, anio: int) -> Array:
	var r := _valores_base(capa, anio)
	var base: PackedInt32Array = r[0]
	var valores := base.duplicate()
	var tenue := tenue_capa(capa)
	var duenos := DatosMapa.duenos
	for u in range(1, mini(valores.size(), duenos.size())):
		if valores[u] > 0 and duenos[u] < 0:
			valores[u] += tenue
	return [valores, r[1]]


## Desde qué valor una unidad se pinta tenue en una capa (la cantidad de colores de su paleta).
func tenue_capa(capa: String) -> int:
	return (_colores_capa.get(capa, PackedColorArray()) as PackedColorArray).size()


func _valores_base(capa: String, anio: int) -> Array:
	var valores := PackedInt32Array()
	valores.resize(DatosMapa.n_unidades + 1)
	valores.fill(0)
	var indices: Dictionary = _indices_capa.get(capa, {})
	var por_region := {}
	for id in regiones.keys():
		var elegido := _vigente_principal(id, capa, anio)
		if not elegido.is_empty():
			por_region[id] = indices.get(familia_de(elegido), 0)
	var clave := capa + str(por_region)
	if _cache_valores.has(clave):
		return [_cache_valores[clave], _colores_capa.get(capa, PackedColorArray([Color(0, 0, 0, 0)]))]
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
	if _cache_valores.size() > 48:
		_cache_valores.clear()
	_cache_valores[clave] = valores
	return [valores, _colores_capa.get(capa, PackedColorArray([Color(0, 0, 0, 0)]))]


## Leyenda de una capa en un año: [{clave, nombre, color, regiones}] de las familias que el mapa pinta, con las
## regiones donde aparecen, de la más extendida a la menos.
func leyenda_capa(capa: String, anio: int) -> Array:
	var por_familia := {}
	for r in regiones.values():
		var v := _vigente_principal(r["id"], capa, anio)
		if v.is_empty():
			continue
		var fam := familia_de(v)
		if not por_familia.has(fam):
			por_familia[fam] = {"clave": "%s:%s" % [capa, fam], "nombre": nombre_familia(capa, fam),
				"color": color_familia(capa, fam), "regiones": []}
		por_familia[fam]["regiones"].append(r["nombre"])
	var out: Array = por_familia.values()
	out.sort_custom(func(a, b): return a["regiones"].size() > b["regiones"].size() or (
		a["regiones"].size() == b["regiones"].size() and a["nombre"] < b["nombre"]))
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
	for f in familias.values():
		if str(f.get("nombre", "")).to_lower().contains(t):
			out.append({"tipo": "familia", "id": f["_clave"], "texto": f["nombre"], "detalle": tr(NOMBRE_CAPA[f["capa"]])})
			if out.size() >= max_res:
				return out
	return out


## Anota en una lista local lo que se consultó y no tiene ficha curada, para saber qué completar primero
## (docs/es/enciclopedia.md, paso 1 del llenado progresivo). No sale de la computadora.
## La copia archivada de un enlace de lectura, o "" si no hay. El archivo se lee la primera vez que se pide.
func copia_archivada(url: String) -> String:
	if not _copias_leidas:
		_copias_leidas = true
		var ruta := Datos.ruta(ARCHIVO_COPIAS)
		if FileAccess.file_exists(ruta):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
			if d is Dictionary and d.get("copias") is Dictionary:
				_copias = d["copias"]
	return str(_copias.get(url, ""))


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


## La cola de consultas sin ficha, de la más consultada a la menos: [{clave, nombre, veces, anios, lon, lat,
## wikidata, wikipedia}]. Es lo que conviene completar primero (docs/es/enciclopedia.md).
func pendientes() -> Array:
	if not FileAccess.file_exists(RUTA_PENDIENTES):
		return []
	var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PENDIENTES))
	if not leido is Dictionary:
		return []
	var out: Array = []
	for clave in leido:
		var item: Dictionary = (leido[clave] as Dictionary).duplicate()
		item["clave"] = clave
		var crudo := str(clave).substr(8) if str(clave).begins_with("entidad:") else ""
		item["nombre"] = DatosMapa.nombre_cliopatria(crudo) if crudo != "" else (
			tr("Lugar sin entidad (%s, %s)") % [item.get("lat", "?"), item.get("lon", "?")])
		out.append(item)
	out.sort_custom(func(a, b): return int(a.get("veces", 0)) > int(b.get("veces", 0)))
	return out


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
		"familia":
			return familias.get(id, {})
	return {}
