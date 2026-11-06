extends Node
## Resúmenes de Wikipedia en vivo (API REST pública), con caché en disco en `user://wiki/`.
##
## Wikipedia es CC BY-SA 4.0: todo lo que se muestra lleva su atribución y el enlace al artículo.
## Grokipedia no tiene API oficial; el plan para fichas más completas está en docs/es/enciclopedia.md.

const AGENTE := "TellMAP/0.1 (atlas historico de codigo abierto; https://github.com/bafif/tmap)"
const DIR_CACHE := "user://wiki/"
const DIAS_CACHE := 30

var _memoria := {}
var _imagenes := {}
var _en_curso := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_CACHE)


## Devuelve {titulo, texto, url, idioma, miniatura} o {} si no hay artículo. Prueba primero en español.
## `titulos` = {"es": "...", "en": "..."} (cualquiera puede faltar).
func resumen(titulos: Dictionary) -> Dictionary:
	var idiomas: Array = ["es", "en"] if Estado.ajustes.get("idioma_wiki", "es") == "es" else ["en", "es"]
	for idioma in idiomas:
		var titulo: String = str(titulos.get(idioma, ""))
		if titulo.is_empty():
			continue
		var r := await _resumen_en(idioma, titulo)
		if not r.is_empty():
			return r
	return {}


func _resumen_en(idioma: String, titulo: String) -> Dictionary:
	var clave := idioma + ":" + titulo
	if _memoria.has(clave):
		return _memoria[clave]
	var ruta := DIR_CACHE + "%s_%s.json" % [idioma, clave.md5_text()]
	if FileAccess.file_exists(ruta):
		var edad := Time.get_unix_time_from_system() - FileAccess.get_modified_time(ruta)
		if edad < DIAS_CACHE * 86400:
			var guardado: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
			if guardado is Dictionary:
				_memoria[clave] = guardado
				return guardado
	var url := "https://%s.wikipedia.org/api/rest_v1/page/summary/%s" % [idioma, titulo.replace(" ", "_").uri_encode()]
	var cuerpo := await _bajar(url)
	var out := {}
	if not cuerpo.is_empty():
		var datos: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
		if datos is Dictionary and datos.has("extract") and datos.get("type", "") != "disambiguation":
			out = {
				"titulo": datos.get("title", titulo),
				"texto": datos.get("extract", ""),
				"url": datos.get("content_urls", {}).get("desktop", {}).get("page", ""),
				"idioma": idioma,
				"miniatura": datos.get("thumbnail", {}).get("source", "") if datos.get("thumbnail") is Dictionary else "",
			}
			var f := FileAccess.open(ruta, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(out))
	_memoria[clave] = out
	return out


## Baja una imagen (miniatura de Wikipedia) y la devuelve como textura, o null.
func imagen(url: String) -> Texture2D:
	if url.is_empty():
		return null
	if _imagenes.has(url):
		return _imagenes[url]
	var cuerpo := await _bajar(url)
	if cuerpo.is_empty():
		return null
	var img := Image.new()
	var ext := url.get_extension().to_lower()
	var err := ERR_FILE_UNRECOGNIZED
	if ext in ["jpg", "jpeg"]:
		err = img.load_jpg_from_buffer(cuerpo)
	elif ext == "png":
		err = img.load_png_from_buffer(cuerpo)
	elif ext == "webp":
		err = img.load_webp_from_buffer(cuerpo)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_imagenes[url] = tex
	return tex


func _bajar(url: String) -> PackedByteArray:
	if _en_curso.has(url):
		await _en_curso[url].request_completed
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	_en_curso[url] = http
	var err := http.request(url, ["User-Agent: " + AGENTE, "Accept: application/json"])
	if err != OK:
		_en_curso.erase(url)
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	_en_curso.erase(url)
	http.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return PackedByteArray()
	return res[3]
