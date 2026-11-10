extends Node
## Datos del mapa generados por `tools/pipeline`: texturas, unidades y la historia política de cada unidad.
##
## El estado político de un año se arma aplicando «eventos» (año, unidad, dueño anterior, dueño nuevo) hacia adelante
## o hacia atrás desde el año actual, o partiendo de la foto completa más cercana cuando el salto es grande.
## El resultado se escribe en una textura chica (la LUT: un valor por unidad) que el shader usa para colorear.

signal valores_actualizados

const DIR := "res://data/mapa/"
const LUT_ANCHO := 256
const PALETA_ANCHO := 1024
const SALTO_CON_FOTO := 40000

var ancho := 0
var alto := 0
var n_unidades := 0
var unidades_bytes := PackedByteArray()
var unidad_x := PackedFloat32Array()
var unidad_y := PackedFloat32Array()
var unidad_tam := PackedInt32Array()

var ev_anio := PackedInt32Array()
var ev_unidad := PackedInt32Array()
var ev_antes := PackedInt32Array()
var ev_despues := PackedInt32Array()
var fotos: Array = []

var entidades: Array = []
var etiquetas: Array = []
var duenos := PackedInt32Array()
var conteo := PackedInt32Array()
var _k := 0

var tex_terreno: ImageTexture
var tex_relieve: ImageTexture
var tex_unidades: ImageTexture
var tex_lut: ImageTexture
var tex_paleta: ImageTexture
var _img_lut: Image
var _lut_bytes := PackedByteArray()
var _lut_filas := 1
var _paleta_politica := PackedColorArray()

## Wikidata → {"es": título en es.wikipedia, "l": etiqueta en español}
var wikidata_es := {}
## Nombre de Cliopatria (en inglés) → nombre en español revisado a mano. En inglés se usa el de Cliopatria.
var nombres_revisados := {}
## Entidad duplicada → la entidad con la que se unificó (ver _unificar_duplicados).
var unificada := {}
var _territorios := {}
var _historias := {}
var error := ""


func _paso(texto: String, fraccion: float) -> void:
	Estado.carga_progreso.emit(texto, fraccion)
	await get_tree().process_frame
	await get_tree().process_frame


func cargar() -> bool:
	var meta: Variant = _leer_json(DIR + "politico.json")
	if meta == null:
		error = tr("Falta data/mapa/politico.json: corré el pipeline (tools/pipeline/README.md).")
		return false
	Proyeccion.configurar(meta["proyeccion"])
	ancho = Proyeccion.ancho
	alto = Proyeccion.alto
	n_unidades = int(meta["unidades"])
	entidades = meta["entidades"]
	etiquetas = meta["etiquetas"]
	var extra: Variant = _leer_json(DIR + "wikidata_es.json")
	if extra is Dictionary:
		wikidata_es = extra
	extra = _leer_json(DIR + "nombres_es.json")
	if extra is Dictionary:
		nombres_revisados = extra

	await _paso(tr("Leyendo las fronteras de 5400 años…"), 0.08)
	var comp := FileAccess.get_file_as_bytes(Datos.ruta(DIR + "politico.bin"))
	var crudo := comp.decompress(int(meta["politico_bin"]["bytes"]), FileAccess.COMPRESSION_DEFLATE)
	var partes: Dictionary = meta["politico_bin"]["partes"]
	unidad_x = _parte(crudo, partes, "unidad_x").to_float32_array()
	unidad_y = _parte(crudo, partes, "unidad_y").to_float32_array()
	unidad_tam = _parte(crudo, partes, "unidad_tam").to_int32_array()
	ev_anio = _parte(crudo, partes, "evento_anio").to_int32_array()
	ev_unidad = _parte(crudo, partes, "evento_unidad").to_int32_array()
	ev_antes = _parte(crudo, partes, "evento_antes").to_int32_array()
	ev_despues = _parte(crudo, partes, "evento_despues").to_int32_array()
	fotos.clear()
	for f in meta["fotos"]:
		fotos.append({"evento": int(f["evento"]), "datos": _parte(crudo, partes, f["parte"]).to_int32_array()})
	crudo = PackedByteArray()
	_corregir_entidades(_leer_json(DIR + "correcciones.json"))
	_unificar_duplicados()

	await _paso(tr("Leyendo las unidades del mapa…"), 0.2)
	comp = FileAccess.get_file_as_bytes(Datos.ruta(DIR + "unidades.bin"))
	unidades_bytes = comp.decompress(int(meta["unidades_bin"]["bytes"]), FileAccess.COMPRESSION_DEFLATE)
	comp = PackedByteArray()
	var img_u := Image.create_from_data(ancho, alto, false, Image.FORMAT_RG8, unidades_bytes)
	tex_unidades = ImageTexture.create_from_image(img_u)

	var res: float = Estado.calidad()["resolucion"]
	await _paso(tr("Pintando el terreno…"), 0.35)
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(Datos.ruta(DIR + "terreno.webp"))) != OK:
		error = tr("No se pudo leer %s") % "data/mapa/terreno.webp"
		return false
	if res < 1.0:
		img.resize(int(ancho * res), int(alto * res), Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	tex_terreno = ImageTexture.create_from_image(img)

	await _paso(tr("Levantando montañas y ríos…"), 0.6)
	img = Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(Datos.ruta(DIR + "relieve.png"))) != OK:
		error = tr("No se pudo leer %s") % "data/mapa/relieve.png"
		return false
	if res < 1.0:
		img.resize(int(ancho * res), int(alto * res), Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	tex_relieve = ImageTexture.create_from_image(img)

	await _paso(tr("Preparando la línea de tiempo…"), 0.85)
	_lut_filas = int(ceil((n_unidades + 1) / float(LUT_ANCHO)))
	_lut_bytes.resize(LUT_ANCHO * _lut_filas * 2)
	_lut_bytes.fill(0)
	_img_lut = Image.create_from_data(LUT_ANCHO, _lut_filas, false, Image.FORMAT_RG8, _lut_bytes)
	tex_lut = ImageTexture.create_from_image(_img_lut)
	_paleta_politica = PackedColorArray()
	_paleta_politica.append(Color(0, 0, 0, 0))
	for e in entidades:
		_paleta_politica.append(Color(e["c"]))
	tex_paleta = ImageTexture.create_from_image(_imagen_paleta(_paleta_politica))

	duenos.resize(n_unidades + 1)
	duenos.fill(-1)
	conteo.resize(entidades.size())
	conteo.fill(0)
	_k = 0
	ir_a_anio(Estado.anio, true)
	return true


# ---------------------------------------------------------------------------------------------------------------
# Año y valores


## Lleva el estado político al año dado. Si `escribir` y el modo es político, actualiza la LUT.
func ir_a_anio(anio: int, forzar_lut := false) -> void:
	var objetivo := ev_anio.bsearch(anio, false)
	var cambiadas := PackedInt32Array()
	var completo := forzar_lut
	if absi(objetivo - _k) > SALTO_CON_FOTO:
		var mejor_k := 0
		var mejor: Variant = null
		for f in fotos:
			if f["evento"] <= objetivo and f["evento"] > mejor_k:
				mejor_k = f["evento"]
				mejor = f
		if objetivo - mejor_k < absi(objetivo - _k):
			if mejor == null:
				duenos.fill(-1)
			else:
				duenos = (mejor["datos"] as PackedInt32Array).duplicate()
			_k = mejor_k
			completo = true
			_recontar()
	while _k < objetivo:
		_mover(ev_unidad[_k], ev_antes[_k], ev_despues[_k])
		if not completo:
			cambiadas.append(ev_unidad[_k])
		_k += 1
	while _k > objetivo:
		_k -= 1
		_mover(ev_unidad[_k], ev_despues[_k], ev_antes[_k])
		if not completo:
			cambiadas.append(ev_unidad[_k])
	if Estado.modo == "politico" or Estado.modo == "terreno":
		if completo:
			_escribir_todo_politico()
		elif cambiadas.size() > 0:
			for u in cambiadas:
				_escribir_lut(u, duenos[u] + 1)
			_subir_lut()
		valores_actualizados.emit()


func _mover(u: int, antes: int, despues: int) -> void:
	duenos[u] = despues
	if antes >= 0:
		conteo[antes] -= 1
	if despues >= 0:
		conteo[despues] += 1


func _recontar() -> void:
	conteo.fill(0)
	for u in range(1, n_unidades + 1):
		var d := duenos[u]
		if d >= 0:
			conteo[d] += 1


func _escribir_todo_politico() -> void:
	for u in range(n_unidades + 1):
		_escribir_lut(u, duenos[u] + 1 if u > 0 else 0)
	_subir_lut()


func _escribir_lut(u: int, v: int) -> void:
	var i := u * 2
	_lut_bytes[i] = v & 0xFF
	_lut_bytes[i + 1] = (v >> 8) & 0xFF


func _subir_lut() -> void:
	_img_lut.set_data(LUT_ANCHO, _lut_filas, false, Image.FORMAT_RG8, _lut_bytes)
	tex_lut.update(_img_lut)


## Vuelve a pintar el mapa con los colores políticos.
func usar_valores_politicos() -> void:
	tex_paleta = ImageTexture.create_from_image(_imagen_paleta(_paleta_politica))
	_escribir_todo_politico()
	valores_actualizados.emit()


## Pinta el mapa con valores arbitrarios por unidad (0 = sin dato) y su paleta (índice 0 = sin dato).
func usar_valores(valores: PackedInt32Array, colores: PackedColorArray) -> void:
	for u in range(n_unidades + 1):
		_escribir_lut(u, valores[u] if u < valores.size() else 0)
	_subir_lut()
	tex_paleta = ImageTexture.create_from_image(_imagen_paleta(colores))
	valores_actualizados.emit()


func _imagen_paleta(colores: PackedColorArray) -> Image:
	var filas := int(ceil(max(colores.size(), 1) / float(PALETA_ANCHO)))
	var img := Image.create_empty(PALETA_ANCHO, filas, false, Image.FORMAT_RGBA8)
	for i in colores.size():
		img.set_pixel(i % PALETA_ANCHO, i / PALETA_ANCHO, colores[i])
	return img


# ---------------------------------------------------------------------------------------------------------------
# Consultas


func unidad_en(px: Vector2) -> int:
	var x := int(px.x)
	var y := int(px.y)
	if x < 0 or y < 0 or x >= ancho or y >= alto:
		return 0
	var i := (y * ancho + x) * 2
	return unidades_bytes[i] | (unidades_bytes[i + 1] << 8)


func dueno(u: int) -> int:
	if u <= 0 or u > n_unidades:
		return -1
	return duenos[u]


func centro_unidad(u: int) -> Vector2:
	return Vector2(unidad_x[u], unidad_y[u])


func area_km2(u: int) -> float:
	var c := centro_unidad(u)
	var k := Proyeccion.km_por_px(Proyeccion.a_lonlat(c).y)
	return unidad_tam[u] * k.x * k.y


## Tramos de dueños de una unidad a lo largo del tiempo: [{desde, hasta, entidad}], entidad -1 = sin dato.
func historia_de_unidad(u: int) -> Array:
	if _historias.has(u):
		return _historias[u]
	var tramos: Array = []
	var k := ev_unidad.find(u)
	while k != -1:
		# Un cambio a la misma entidad (pasa con las unificadas) no abre un tramo nuevo.
		if tramos.is_empty() or tramos[-1]["entidad"] != ev_despues[k]:
			if tramos.size() > 0:
				tramos[-1]["hasta"] = Fechas.sumar(ev_anio[k], -1)
			tramos.append({"desde": ev_anio[k], "hasta": Estado.ANIO_MAX, "entidad": ev_despues[k]})
		k = ev_unidad.find(u, k + 1)
	_historias[u] = tramos.filter(func(t): return t["entidad"] >= 0)
	return _historias[u]


## Dueño de una unidad en cualquier año, sin mover el mapa; -1 si no hay dato.
func dueno_en(u: int, anio: int) -> int:
	for t in historia_de_unidad(u):
		if t["desde"] <= anio and anio <= t["hasta"]:
			return t["entidad"]
	return -1


## Superficie de una entidad a lo largo del tiempo: [[año, km²], …], un punto por cada año en que cambia.
## Usa find (nativo) sobre los eventos en vez de recorrerlos en GDScript; se guarda en caché.
func territorio_de_entidad(i: int) -> Array:
	if _territorios.has(i):
		return _territorios[i]
	var ks := PackedInt32Array()
	for lista in [ev_despues, ev_antes]:
		var k: int = (lista as PackedInt32Array).find(i)
		while k != -1:
			ks.append(k)
			k = (lista as PackedInt32Array).find(i, k + 1)
	ks.sort()
	var serie: Array = []
	var area := 0.0
	var previo := -1
	for k in ks:
		if k == previo:
			continue
		previo = k
		var u := ev_unidad[k]
		if ev_despues[k] == i:
			area += area_km2(u)
		if ev_antes[k] == i:
			area -= area_km2(u)
		if not serie.is_empty() and serie[-1][0] == ev_anio[k]:
			serie[-1][1] = maxf(area, 0.0)
		else:
			serie.append([ev_anio[k], maxf(area, 0.0)])
	_territorios[i] = serie
	return serie


func nombre_entidad(i: int) -> String:
	if i < 0 or i >= entidades.size():
		return ""
	return nombre_cliopatria(str(entidades[i]["n"]))


## El nombre de una entidad de Cliopatria en el idioma de la app. Cliopatria los trae en inglés; los que van entre
## paréntesis («(Carolingian Empire)») son el segundo registro de un mismo estado, y se muestran sin ellos.
func nombre_cliopatria(n: String) -> String:
	if Idioma.actual == "es" and nombres_revisados.has(n):
		return nombres_revisados[n]
	return n.trim_prefix("(").trim_suffix(")") if n.begins_with("(") and n.ends_with(")") else n


func titulos_wiki_entidad(i: int) -> Dictionary:
	var e: Dictionary = entidades[i]
	var out := {"en": e["w"]}
	var wd: Dictionary = wikidata_es.get(e["d"], {})
	if wd.has("es"):
		out["es"] = wd["es"]
	return out


func color_entidad(i: int) -> Color:
	if i < 0 or i >= entidades.size():
		return Color(0.5, 0.5, 0.5)
	return Color(entidades[i]["c"])


## Índices de etiquetas activas en un año (solo de entidades que tienen territorio ese año).
func etiquetas_activas(anio: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in etiquetas.size():
		var e: Array = etiquetas[i]
		if e[0] <= anio and anio <= e[1] and conteo[int(e[2])] > 0:
			out.append(i)
	return out


## Unidades que pertenecen a una entidad en el año actual (para centrar la cámara, por ejemplo).
func centro_entidad(i: int) -> Vector2:
	var suma := Vector2.ZERO
	var peso := 0.0
	for u in range(1, n_unidades + 1):
		if duenos[u] == i:
			var w := float(unidad_tam[u])
			suma += Vector2(unidad_x[u], unidad_y[u]) * w
			peso += w
	return suma / peso if peso > 0.0 else Vector2(-1, -1)


func buscar_entidades(texto: String, max_res := 8) -> Array:
	var t := texto.to_lower()
	var out: Array = []
	for i in entidades.size():
		if unificada.has(i):
			continue
		var nombre := nombre_entidad(i)
		if nombre.to_lower().contains(t) or str(entidades[i]["n"]).to_lower().contains(t):
			out.append(i)
			if out.size() >= max_res:
				break
	return out


# ---------------------------------------------------------------------------------------------------------------


## Correcciones revisadas a mano (data/mapa/correcciones.json): enlaces a Wikipedia (w) y Wikidata (d) que Cliopatria
## trae equivocados. Los nombres en español están en nombres_es.json.
func _corregir_entidades(c: Variant) -> void:
	if not c is Dictionary:
		return
	var cambios: Dictionary = c.get("entidades", {})
	for e in entidades:
		var n := str(e["n"])
		if cambios.has(n):
			for k in ["w", "d"]:
				if cambios[n].has(k):
					e[k] = cambios[n][k]


## Cliopatria trae 33 estados dos veces, «X» y «(X)», con el mismo Wikidata: la versión entre paréntesis es el
## conjunto, y la otra dice ser parte de ella. En el mapa salían como dos entidades con el mismo nombre, distinto color
## y una frontera entre las dos. Se unifican en la de paréntesis, con los años de ambas; cuando las etiquetas de las
## dos se superponen en el tiempo, queda la más larga.
func _unificar_duplicados() -> void:
	unificada.clear()
	var por_nombre := {}
	for i in entidades.size():
		por_nombre[str(entidades[i]["n"])] = i
	for i in entidades.size():
		var n := str(entidades[i]["n"])
		if not (n.begins_with("(") and n.ends_with(")")):
			continue
		var j: int = por_nombre.get(n.substr(1, n.length() - 2), -1)
		if j < 0 or entidades[j]["d"] != entidades[i]["d"]:
			continue
		unificada[j] = i
		entidades[i]["a"] = mini(int(entidades[i]["a"]), int(entidades[j]["a"]))
		entidades[i]["b"] = maxi(int(entidades[i]["b"]), int(entidades[j]["b"]))
		ev_antes = _reemplazado(ev_antes, j, i)
		ev_despues = _reemplazado(ev_despues, j, i)
		for f in fotos:
			f["datos"] = _reemplazado(f["datos"], j, i)
	if unificada.is_empty():
		return
	var de_entidad := {}
	for e in etiquetas:
		if unificada.has(int(e[2])):
			e[2] = unificada[int(e[2])]
		if unificada.values().has(int(e[2])):
			if not de_entidad.has(int(e[2])):
				de_entidad[int(e[2])] = []
			de_entidad[int(e[2])].append(e)
	var sobran := {}
	for lista in de_entidad.values():
		for e in lista:
			for otra in lista:
				if otra != e and float(otra[6]) > float(e[6]) and int(otra[0]) <= int(e[0]) and int(e[1]) <= int(otra[1]):
					sobran[e] = true
					break
	if not sobran.is_empty():
		etiquetas = etiquetas.filter(func(e): return not sobran.has(e))


static func _reemplazado(lista: PackedInt32Array, de: int, a: int) -> PackedInt32Array:
	var k := lista.find(de)
	while k != -1:
		lista[k] = a
		k = lista.find(de, k + 1)
	return lista


func _parte(crudo: PackedByteArray, partes: Dictionary, nombre: String) -> PackedByteArray:
	var p: Dictionary = partes[nombre]
	return crudo.slice(int(p["inicio"]), int(p["inicio"]) + int(p["bytes"]))


func _leer_json(ruta: String) -> Variant:
	ruta = Datos.ruta(ruta)
	if not FileAccess.file_exists(ruta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ruta))
