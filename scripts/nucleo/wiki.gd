extends Node
## Resúmenes de Wikipedia en vivo (API REST pública), con caché en disco en `user://wiki/`.
##
## Wikipedia es CC BY-SA 4.0: todo lo que se muestra lleva su atribución y el enlace al artículo.
## Grokipedia no tiene API oficial; el plan para fichas más completas está en docs/es/enciclopedia.md.

const AGENTE := "TellMAP/0.1 (atlas historico de codigo abierto; https://github.com/bafif/tmap)"
const DIR_CACHE := "user://wiki/"
const DIAS_CACHE := 30
## Pedidos a la vez. Cada HTTPRequest resuelve el nombre del servidor y Godot tiene una cola de DNS chica: con una
## ficha tras otra (la prueba abre miles) se agotaba («Out of resolver queries»).
const MAX_SIMULTANEOS := 4
## Pedidos esperando turno. Pasado este número se descartan los más viejos: son de fichas que ya se cerraron.
const MAX_EN_ESPERA := 6

## Un pedido de una URL, compartido por todos los que la piden mientras está en curso.
class Pedido extends RefCounted:
	signal listo
	var url := ""
	var cuerpo := PackedByteArray()
	var codigo := 0  ## Código HTTP; 0 si no hubo respuesta.
	var descartado := false
	var terminado := false

var _memoria := {}
var _imagenes := {}
var _pedidos := {}  ## url -> Pedido, mientras espera o está en curso
var _cola: Array[Pedido] = []
var _activos := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_CACHE)


## Devuelve {titulo, texto, url, idioma, miniatura} o {} si no hay artículo. Prueba primero en el idioma elegido
## (Estado.idioma_wiki) y después en el otro.
## `titulos` = {"es": "...", "en": "..."} (cualquiera puede faltar).
func resumen(titulos: Dictionary) -> Dictionary:
	var idiomas: Array = ["es", "en"] if Estado.idioma_wiki() == "es" else ["en", "es"]
	for idioma in idiomas:
		var titulo: String = str(titulos.get(idioma, ""))
		if titulo.is_empty():
			continue
		var r := await _resumen_en(idioma, titulo)
		if r.get("_descartado", false):
			return {}
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
	var p := await _bajar(url)
	if p.descartado:
		return {"_descartado": true}
	var out := {}
	if not p.cuerpo.is_empty():
		var datos: Variant = JSON.parse_string(p.cuerpo.get_string_from_utf8())
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
	# Sin conexión no se recuerda el fallo: la próxima vez que se abra la ficha se vuelve a probar.
	if p.codigo != 0:
		_memoria[clave] = out
	return out


## Baja una imagen (miniatura de Wikipedia) y la devuelve como textura, o null.
func imagen(url: String) -> Texture2D:
	if url.is_empty():
		return null
	if _imagenes.has(url):
		return _imagenes[url]
	var cuerpo := (await _bajar(url)).cuerpo
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


## Baja `url` por la cola: devuelve el Pedido ya terminado (cuerpo vacío si falló o si se descartó).
func _bajar(url: String) -> Pedido:
	var p: Pedido = _pedidos.get(url)
	if p == null:
		p = Pedido.new()
		p.url = url
		_pedidos[url] = p
		_cola.push_back(p)
		while _cola.size() > MAX_EN_ESPERA:
			var viejo: Pedido = _cola.pop_front()
			viejo.descartado = true
			_terminar(viejo)
		_despachar()
	if not p.terminado:
		await p.listo
	return p


## Lanza los pedidos que entran; primero el más nuevo, que es el de la ficha que se está mirando.
func _despachar() -> void:
	while _activos < MAX_SIMULTANEOS and not _cola.is_empty():
		_lanzar(_cola.pop_back())


func _lanzar(p: Pedido) -> void:
	_activos += 1
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(p.url, ["User-Agent: " + AGENTE, "Accept: application/json"]) == OK:
		var res: Array = await http.request_completed
		if res[0] == HTTPRequest.RESULT_SUCCESS:
			p.codigo = res[1]
			if res[1] == 200:
				p.cuerpo = res[3]
	http.queue_free()
	_activos -= 1
	_terminar(p)
	_despachar()


func _terminar(p: Pedido) -> void:
	p.terminado = true
	_pedidos.erase(p.url)
	p.listo.emit()
