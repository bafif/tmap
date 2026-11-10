class_name Idioma
## El idioma de la app: español o inglés, para la interfaz y para la enciclopedia.
##
## La primera vez se elige solo: español si alguno de los idiomas preferidos del equipo es español, inglés en cualquier
## otro caso. Lo que se elige en Ajustes o en la bienvenida queda en el ajuste «idioma» y manda sobre la detección.
## `--idioma=es` o `--idioma=en` en la línea de comandos manda sobre los dos (pruebas y capturas).
##
## Los textos de la interfaz se escriben en español dentro de tr() (o de Idioma.t() en funciones estáticas) y su
## traducción está en traducciones/en.po; `python3 tools/traduccion/interfaz.py revisar` controla que no falte ninguna.
## Lo que viene de los datos se traduce aparte: la enciclopedia con su capa de traducción (Enciclopedia), los nombres de
## Cliopatria y de los países con el nombre en inglés que traen sus fuentes (DatosMapa, Demografia).

## Los idiomas que hay, cada uno con su nombre en ese idioma (así se muestran en el selector).
const NOMBRES := {"es": "Español", "en": "English"}

## El idioma en uso: "es" o "en".
static var actual := "es"
## El que pidió la línea de comandos (--idioma=es o --idioma=en), si pidió uno; elegir otro en Ajustes lo deja de lado.
static var _forzado := ""
static var _leida_linea := false


## El idioma del equipo: español si alguno de sus idiomas preferidos es español; si no, inglés. En Linux se miran
## LANGUAGE (la lista de preferidos), LC_ALL, LC_MESSAGES y LANG; en Windows y macOS, el idioma del sistema.
static func detectar() -> String:
	var preferidos: Array[String] = []
	for variable in ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"]:
		for parte in OS.get_environment(variable).split(":", false):
			preferidos.append(parte)
	preferidos.append(OS.get_locale())
	preferidos.append(OS.get_locale_language())
	for p in preferidos:
		if _codigo(p) == "es":
			return "es"
	return "en"


## «es_AR.UTF-8», «es-419» o «es» → «es».
static func _codigo(locale: String) -> String:
	return locale.get_slice(".", 0).get_slice("@", 0).replace("-", "_").get_slice("_", 0).to_lower()


## El idioma que corresponde ahora: el de la línea de comandos, el elegido o el detectado.
static func elegido() -> String:
	if not _leida_linea:
		_leida_linea = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--idioma=") and NOMBRES.has(a.substr(9)):
				_forzado = a.substr(9)
	if _forzado != "":
		return _forzado
	var guardado := str(Estado.ajustes.get("idioma", ""))
	return guardado if NOMBRES.has(guardado) else detectar()


## Pone el idioma en uso (sin guardarlo). Se llama al arrancar, después de leer los ajustes.
static func aplicar() -> void:
	actual = elegido()
	TranslationServer.set_locale(actual)


## Para las pruebas y las capturas: el idioma de la línea de comandos, que no se guarda.
static func forzar(idioma: String) -> void:
	if NOMBRES.has(idioma):
		_forzado = idioma
		aplicar()


## Cambia el idioma desde Ajustes o la bienvenida: lo guarda, vuelve a leer la enciclopedia en ese idioma y avisa
## para que la interfaz se arme de nuevo.
static func cambiar(idioma: String) -> void:
	if not NOMBRES.has(idioma):
		return
	_forzado = ""
	var antes := actual
	Estado.fijar_ajuste("idioma", idioma)
	aplicar()
	if actual == antes:
		return
	if Estado.cargado:
		Enciclopedia.recargar()
	Estado.idioma_cambiado.emit()


static func ingles() -> bool:
	return actual == "en"


## tr() para funciones estáticas, donde no hay un objeto que lo tenga.
static func t(texto: String) -> String:
	return String(TranslationServer.translate(texto))


## tr_n() para funciones estáticas.
static func tn(uno: String, varios: String, n: int) -> String:
	return String(TranslationServer.translate_plural(uno, varios, n))


## Un entero con separador de miles: «12.345» en español, «12,345» en inglés.
static func miles(n: int) -> String:
	var s := str(absi(n))
	var sep := "," if ingles() else "."
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Un número ya formateado con punto decimal («12.5»), con la coma decimal en español.
static func decimal(texto: String) -> String:
	return texto if ingles() else texto.replace(".", ",")


## Número ordinal en inglés: 1st, 2nd, 3rd, 4th, 11th, 21st.
static func ordinal_en(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]
