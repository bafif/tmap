class_name Demografia
## Series por país de Our World in Data (población, esperanza de vida, fecundidad, economía, educación) y el país
## actual de cada unidad del mapa: `data/demografia/`, que arman `tools/demografia/series.py` y
## `tools/pipeline/p4_paises.py`. Todas usan las fronteras de hoy.
##
## Se leen la primera vez que hacen falta (la pestaña «Datos»), no al arrancar: así la apertura de la app no crece con
## los datos. Es el primer paso del plan de docs/es/almacenamiento.md.

const DIR := "res://data/demografia/"
const MUNDO := "OWID_WRL"
## Un dato publicado vale para los años siguientes hasta este margen; más lejos, no se muestra.
const MARGEN := 15

static var indicadores: Array = []
static var paises: Dictionary = {}
static var _cargado := false
static var _pais_de_unidad := PackedByteArray()
static var _codigos: Array = [""]
static var _por_clave: Dictionary = {}
## Código → nombre del país en inglés (paises_mapa.json; en paises.json está el español).
static var _nombres_en: Dictionary = {}


static func _cargar() -> void:
	if _cargado:
		return
	_cargado = true
	var t0 := Time.get_ticks_msec()
	var mapa: Variant = JSON.parse_string(FileAccess.get_file_as_string(Datos.ruta(DIR + "paises_mapa.json")))
	var series: Variant = JSON.parse_string(FileAccess.get_file_as_string(Datos.ruta(DIR + "paises.json")))
	if not (mapa is Dictionary and series is Dictionary):
		push_warning("Demografía: no se pudieron leer los datos de %s" % DIR)
		return
	for p in mapa["paises"]:
		_codigos.append(str(p["codigo"]))
		_nombres_en[str(p["codigo"])] = str(p.get("nombre_en", ""))
	var comp := FileAccess.get_file_as_bytes(Datos.ruta(DIR + "unidades_pais.bin"))
	_pais_de_unidad = comp.decompress(int(mapa["unidades"]) + 1, FileAccess.COMPRESSION_DEFLATE)
	indicadores = series["indicadores"]
	paises = series["paises"]
	for ind in indicadores:
		_por_clave[str(ind["clave"])] = ind
	print("Demografía: %d países y %d indicadores en %d ms" % [paises.size(), indicadores.size(), Time.get_ticks_msec() - t0])


## Código del país actual (el de Our World in Data) que cubre la unidad, o "" si ninguno (mar, hielo, zonas en disputa).
static func pais_de_unidad(u: int) -> String:
	_cargar()
	if u <= 0 or u >= _pais_de_unidad.size():
		return ""
	var i := int(_pais_de_unidad[u])
	return _codigos[i] if i > 0 and i < _codigos.size() else ""


static func nombre(codigo: String) -> String:
	_cargar()
	if Idioma.ingles():
		if codigo == MUNDO:
			return Idioma.t("Mundo")
		if str(_nombres_en.get(codigo, "")) != "":
			return _nombres_en[codigo]
	return str(paises.get(codigo, {}).get("nombre", codigo))


static func indicador(clave: String) -> Dictionary:
	_cargar()
	return _por_clave.get(clave, {})


## El último dato publicado hasta `anio`, si no tiene más de MARGEN años: {"valor", "anio"}; vacío si no hay.
static func valor(codigo: String, clave: String, anio: int) -> Dictionary:
	_cargar()
	var ind := indicador(clave)
	var fila: Variant = paises.get(codigo, {}).get("series", {}).get(clave)
	if ind.is_empty() or not fila is Array:
		return {}
	var anios: Array = ind["anios"]
	var mejor := -1
	for i in anios.size():
		if int(anios[i]) > anio:
			break
		if fila[i] != null:
			mejor = i
	if mejor < 0 or anio - int(anios[mejor]) > MARGEN:
		return {}
	return {"valor": float(fila[mejor]), "anio": int(anios[mejor])}


## La serie completa para GraficoSerie: [{"anio", "valor", "fuente"}].
static func serie(codigo: String, clave: String) -> Array:
	_cargar()
	var ind := indicador(clave)
	var fila: Variant = paises.get(codigo, {}).get("series", {}).get(clave)
	var out: Array = []
	if ind.is_empty() or not fila is Array:
		return out
	var anios: Array = ind["anios"]
	for i in anios.size():
		if fila[i] != null:
			out.append({"anio": int(anios[i]), "valor": float(fila[i]), "fuente": ind["fuente"]})
	return out


## Un valor con su unidad: «45,7 millones», «76,1 años», «2,31», «12,4 %», «US$ 14.832»; en inglés, «45.7 million»,
## «76.1 years», «12.4%», «US$ 14,832». Las unidades vienen de los datos en español y se traducen con en.po.
static func texto_valor(v: float, clave: String) -> String:
	var ind := indicador(clave)
	var dec := int(ind.get("decimales", 0))
	var unidad := str(ind.get("unidad", ""))
	var n := _numero(v, dec)
	match unidad:
		"habitantes":
			return n + (" " + Idioma.t("habitantes") if v < 1000000.0 else "")
		"%":
			return n + ("%" if Idioma.ingles() else " %")
		"US$ de 2011":
			return "US$ " + n
		"hijos":
			return n
		_:
			return "%s %s" % [n, Idioma.t(unidad)]


static func _numero(x: float, dec: int) -> String:
	if dec == 0 and absf(x) >= 1000000.0:
		return Idioma.t("%s millones") % Idioma.decimal("%.1f" % (x / 1000000.0))
	var partes := (("%." + str(dec) + "f") % absf(x)).split(".")
	var out := Idioma.miles(int(partes[0]))
	if dec > 0:
		out += Idioma.decimal(".") + partes[1]
	return ("-" if x < 0 else "") + out
