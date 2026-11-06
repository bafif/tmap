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
## Nombre de Cliopatria → nombre en español revisado a mano.
var nombres_revisados := {}
var error := ""


func _paso(texto: String, fraccion: float) -> void:
	Estado.carga_progreso.emit(texto, fraccion)
	await get_tree().process_frame
	await get_tree().process_frame


func cargar() -> bool:
	var meta: Variant = _leer_json(DIR + "politico.json")
	if meta == null:
		error = "Falta data/mapa/politico.json: corré el pipeline (tools/pipeline/README.md)."
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

	await _paso("Leyendo las fronteras de 5400 años…", 0.08)
	var comp := FileAccess.get_file_as_bytes(DIR + "politico.bin")
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

	await _paso("Leyendo las unidades del mapa…", 0.2)
	comp = FileAccess.get_file_as_bytes(DIR + "unidades.bin")
	unidades_bytes = comp.decompress(int(meta["unidades_bin"]["bytes"]), FileAccess.COMPRESSION_DEFLATE)
	comp = PackedByteArray()
	var img_u := Image.create_from_data(ancho, alto, false, Image.FORMAT_RG8, unidades_bytes)
	tex_unidades = ImageTexture.create_from_image(img_u)

	var res: float = Estado.calidad()["resolucion"]
	await _paso("Pintando el terreno…", 0.35)
	var img := Image.new()
	if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(DIR + "terreno.webp")) != OK:
		error = "No se pudo leer data/mapa/terreno.webp"
		return false
	if res < 1.0:
		img.resize(int(ancho * res), int(alto * res), Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	tex_terreno = ImageTexture.create_from_image(img)

	await _paso("Levantando montañas y ríos…", 0.6)
	img = Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(DIR + "relieve.png")) != OK:
		error = "No se pudo leer data/mapa/relieve.png"
		return false
	if res < 1.0:
		img.resize(int(ancho * res), int(alto * res), Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	tex_relieve = ImageTexture.create_from_image(img)

	await _paso("Preparando la línea de tiempo…", 0.85)
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
	var img := Image.create(PALETA_ANCHO, filas, false, Image.FORMAT_RGBA8)
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
	var tramos: Array = []
	var k := ev_unidad.find(u)
	while k != -1:
		if tramos.size() > 0:
			tramos[-1]["hasta"] = Fechas.sumar(ev_anio[k], -1)
		tramos.append({"desde": ev_anio[k], "hasta": Estado.ANIO_MAX, "entidad": ev_despues[k]})
		k = ev_unidad.find(u, k + 1)
	return tramos.filter(func(t): return t["entidad"] >= 0)


func nombre_entidad(i: int) -> String:
	if i < 0 or i >= entidades.size():
		return ""
	var e: Dictionary = entidades[i]
	if nombres_revisados.has(e["n"]):
		return nombres_revisados[e["n"]]
	return e["n"]


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
		var nombre := nombre_entidad(i)
		if nombre.to_lower().contains(t) or str(entidades[i]["n"]).to_lower().contains(t):
			out.append(i)
			if out.size() >= max_res:
				break
	return out


# ---------------------------------------------------------------------------------------------------------------


func _parte(crudo: PackedByteArray, partes: Dictionary, nombre: String) -> PackedByteArray:
	var p: Dictionary = partes[nombre]
	return crudo.slice(int(p["inicio"]), int(p["inicio"]) + int(p["bytes"]))


func _leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ruta))
