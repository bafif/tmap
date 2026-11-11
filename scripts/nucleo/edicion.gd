class_name Edicion
## Los mensajes de validación salen en el idioma de la app (Idioma.t); los datos se escriben siempre en español.
## Escribir la enciclopedia desde la app: leer y guardar paquetes sin cambiar su formato, validar un elemento antes de
## guardarlo, armar el área de estudio de una región con el territorio de una entidad y aprobar o descartar borradores
## (docs/es/enciclopedia.md). Desde el código fuente (con el editor de Godot o `godot --path .`) escribe en los paquetes
## del proyecto; en una versión exportada, donde esos paquetes van dentro del ejecutable y son de solo lectura, guarda
## copias en la carpeta del usuario (DIR_LOCAL) que tapan a las de adentro.

## Secciones que se editan con formularios ↔ tipo de ficha.
const SECCION_DE_TIPO := {"fuente": "fuentes", "persona": "personas", "hecho": "hechos", "lugar": "lugares", "region": "regiones"}
const TIPO_DE_SECCION := {"fuentes": "fuente", "personas": "persona", "hechos": "hecho", "lugares": "lugar", "regiones": "region"}
const TIPOS_FUENTE := ["primaria", "secundaria"]
const TIPOS_HECHO := ["politico", "batalla", "fundacion", "religioso", "cultural", "cientifico", "economico", "desastre",
	"tratado", "construccion", "exploracion", "revolucion", "judicial"]
const TIPOS_LUGAR := ["ciudad", "capital", "templo", "puerto", "sitio-arqueologico", "biblioteca", "universidad",
	"laboratorio", "institucion", "sitio-historico"]
const GENEROS := ["religioso", "historia", "cronica", "literatura", "poesia", "filosofia", "legal", "administrativo",
	"epistolar", "inscripcion", "geografia", "ciencia", "medicina", "sabiduria", "viajes", "ensayo", "arqueologia",
	"economia", "politica", "manifiesto", "discurso", "tecnologia", "periodismo"]
const CONFIANZAS := ["alta", "media", "baja"]
const PESOS := ["mayoritaria", "importante", "minoritaria"]
## Capas de una región con familia y peso (ver la sección «familias» del esquema).
const CAPAS := ["religiones", "culturas", "idiomas"]
## Las cifras de población cuya fuente termina así las escribe tools/enciclopedia/poblacion.py: no se editan a mano.
const MARCA_OWID := "vía Our World in Data"
## Números que se guardan siempre con decimales. Godot lee todos los números de un JSON como float: al escribir, los
## enteros vuelven a ir sin decimales (años, población, importancia) y las coordenadas conservan el suyo. Así un
## paquete leído y vuelto a escribir sale idéntico, byte por byte, y el diff muestra solo lo que se cambió.
const CLAVES_DECIMALES := ["lon", "lat"]

## Lo que se edita en una versión exportada: copias de los paquetes, con las mismas rutas que en data/enciclopedia/.
const DIR_LOCAL := "user://enciclopedia/"
const DIR_ENCICLOPEDIA := "res://data/enciclopedia/"
## Si se guarda en DIR_LOCAL en vez de en el proyecto: cuando la app no corre desde la carpeta del código fuente.
static var guardar_local := not FileAccess.file_exists(ProjectSettings.globalize_path("res://project.godot"))
## Carpeta de los borradores (las pruebas la cambian por una en user://).
static var dir_borradores := (DIR_LOCAL if guardar_local else DIR_ENCICLOPEDIA) + "paquetes/borradores/"
## Carpeta de los paquetes (ídem).
static var dir_paquetes := "res://data/enciclopedia/paquetes/"
## Última ruta escrita (o que se habría escrito con Estado.sin_escribir), para las pruebas.
static var ultima_escritura := ""


## Dónde se guarda un archivo de la enciclopedia: en el proyecto o, en una versión exportada, en su copia local.
static func destino(ruta: String) -> String:
	if guardar_local and ruta.begins_with(DIR_ENCICLOPEDIA):
		return DIR_LOCAL + ruta.trim_prefix(DIR_ENCICLOPEDIA)
	return ruta


## De dónde se lee un archivo de la enciclopedia: la copia local si la versión exportada ya guardó una; si no, la de
## la última actualización de datos, si trajo una (Datos.ruta), o la de adentro.
static func para_leer(ruta: String) -> String:
	var local := destino(ruta)
	return local if local != ruta and FileAccess.file_exists(local) else Datos.ruta(ruta)


## El JSON de un paquete con el formato de siempre (sangría de 2 espacios, claves en su orden, sin los campos internos
## que empiezan con «_»).
static func a_json(datos: Variant) -> String:
	return JSON.stringify(_preparar(datos, "", false), "  ", false)


static func _preparar(v: Variant, clave: String, en_poligono: bool) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if not str(k).begins_with("_"):
				out[k] = _preparar(v[k], str(k), en_poligono or str(k) == "poligono")
		return out
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_preparar(x, clave, en_poligono))
		return out
	if v is float and not en_poligono and not clave in CLAVES_DECIMALES and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	return v


static func leer(ruta: String) -> Dictionary:
	ruta = para_leer(ruta)
	if not FileAccess.file_exists(ruta):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return d if d is Dictionary else {}


static func escribir(ruta: String, datos: Dictionary) -> String:
	ruta = destino(ruta)
	var texto := a_json(datos)
	ultima_escritura = ruta
	if Estado.sin_escribir:
		return ""
	DirAccess.make_dir_recursive_absolute(ruta.get_base_dir())
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return Idioma.t("No se pudo escribir %s (%s).") % [ruta, error_string(FileAccess.get_open_error())]
	f.store_string(texto)
	f.close()
	return ""


static func borrar(ruta: String) -> String:
	ruta = para_leer(ruta)
	if ruta.begins_with(Datos.DIR_LOCAL) or (ruta.begins_with("res://") and guardar_local):
		return Idioma.t("Ese archivo viene dentro del programa y no se puede borrar.")
	ultima_escritura = ruta
	if Estado.sin_escribir:
		return ""
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	return "" if err == OK else Idioma.t("No se pudo borrar %s (%s).") % [ruta, error_string(err)]


## Archivos de paquete (sin los borradores), ordenados.
static func paquetes() -> Array:
	return _jsons(dir_paquetes)


static func borradores() -> Array:
	return _jsons(dir_borradores)


static func _jsons(dir: String) -> Array:
	if not DirAccess.dir_exists_absolute(Datos.ruta(dir)):
		return []
	var out: Array = []
	for f in DirAccess.get_files_at(Datos.ruta(dir)):
		if f.ends_with(".json"):
			out.append(dir + f)
	out.sort()
	return out


static func indice(lista: Array, id: String) -> int:
	for i in lista.size():
		if lista[i] is Dictionary and str(lista[i].get("id", "")) == id:
			return i
	return -1


## Reemplaza (o agrega, si id_original es "") un elemento en su archivo.
static func guardar(ruta: String, seccion: String, item: Dictionary, id_original: String) -> String:
	var datos := leer(ruta)
	if datos.is_empty():
		return Idioma.t("No se pudo leer %s.") % ruta
	var lista: Array = datos.get(seccion, [])
	var i := indice(lista, id_original if id_original != "" else str(item.get("id", "")))
	if id_original == "" and i >= 0:
		return Idioma.t("Ya hay un elemento «%s» en %s.") % [item.get("id"), ruta.get_file()]
	if id_original != "" and i < 0:
		return Idioma.t("«%s» ya no está en %s: ¿lo cambió otro programa?") % [id_original, ruta.get_file()]
	if i >= 0:
		lista[i] = item
	else:
		lista.append(item)
	datos[seccion] = lista
	return escribir(ruta, datos)


## Id a partir de un nombre: minúsculas, sin tildes, con guiones.
static func slug(texto: String) -> String:
	var s := texto.to_lower()
	var tildes := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n", "à": "a", "è": "e", "ì": "i",
		"ò": "o", "ù": "u", "â": "a", "ê": "e", "î": "i", "ô": "o", "û": "u", "ç": "c", "ā": "a", "ē": "e", "ī": "i",
		"ō": "o", "ū": "u"}
	for k in tildes:
		s = s.replace(k, tildes[k])
	var out := ""
	for c in s:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	return out.trim_prefix("-").trim_suffix("-").left(60)


static func hoy() -> String:
	return Time.get_date_string_from_system()


# ---------------------------------------------------------------------------------------------------------------
# Validación (la misma que tools/enciclopedia/validar.py, para un elemento)


## Errores y avisos de un elemento. extra: {sección: {id: true}} con los ids que existen además de los cargados (los
## del mismo borrador).
static func validar(seccion: String, item: Dictionary, id_original: String, extra := {}) -> Dictionary:
	var e: Array = []
	var a: Array = []
	var id := str(item.get("id", ""))
	if not RegEx.create_from_string("^[a-z0-9]+(-[a-z0-9]+)*$").search(id):
		e.append(Idioma.t("El id «%s» no sirve: van minúsculas sin tildes, números y guiones (por ejemplo «batalla-de-qadesh»).") % id)
	elif id_original == "" and _existe(seccion, id, {}):
		e.append(Idioma.t("Ya hay un elemento con el id «%s» en %s.") % [id, seccion])
	elif id_original != "" and id != id_original:
		e.append(Idioma.t("El id no se puede cambiar (otras fichas lo nombran)."))
	var titulo := "titulo" if seccion in ["fuentes", "hechos"] else "nombre"
	if str(item.get(titulo, "") if item.get(titulo) != null else "").strip_edges() == "":
		e.append(Idioma.t("Falta el título.") if titulo == "titulo" else Idioma.t("Falta el nombre."))
	match seccion:
		"fuentes":
			if not item.get("tipo") in ["primaria", "secundaria"]:
				e.append(Idioma.t("El tipo tiene que ser primaria o secundaria."))
			if not item.get("genero") in GENEROS:
				a.append(Idioma.t("Género no previsto: %s.") % item.get("genero"))
			var es: Dictionary = _dic(item, "escrita")
			_anio(es.get("anio"), Idioma.t("Año en que se escribió"), e)
			_anio(es.get("anio_hasta"), Idioma.t("Hasta"), e)
			_orden(es.get("anio"), es.get("anio_hasta"), Idioma.t("La escritura"), e)
			if es.get("anio") == null:
				a.append(Idioma.t("Sin año de escritura: la fuente no se ubica en el tiempo."))
			_punto(es, Idioma.t("Lugar de escritura"), e)
			if es.get("lon") == null:
				a.append(Idioma.t("Sin coordenadas del lugar de escritura: no aparece en el mapa."))
			var tr: Dictionary = _dic(item, "trata")
			_anio(tr.get("desde"), Idioma.t("Trata desde"), e)
			_anio(tr.get("hasta"), Idioma.t("Trata hasta"), e)
			_orden(tr.get("desde"), tr.get("hasta"), Idioma.t("La época de la que trata"), e)
			_refs(tr.get("regiones", []), "regiones", Idioma.t("Región"), extra, e)
			if item.get("autor_id") != null and str(item.get("autor_id")) != "":
				_refs([item["autor_id"]], "personas", Idioma.t("Autor"), extra, e)
			for l in item.get("leer", []) if item.get("leer") is Array else []:
				var url := str(l.get("url", "")) if l is Dictionary else ""
				if not (url.begins_with("https://") or url.begins_with("http://")):
					e.append(Idioma.t("El enlace de lectura «%s» no es una URL.") % url)
				elif str(l.get("titulo", "")).strip_edges() == "":
					a.append(Idioma.t("Un enlace de lectura no tiene título."))
			if not item.get("confianza") in CONFIANZAS:
				a.append(Idioma.t("Confianza no prevista: %s.") % item.get("confianza"))
		"personas":
			var anios: Array = []
			for clave in ["nacimiento", "muerte"]:
				var d: Dictionary = _dic(item, clave)
				var que: String = Idioma.t("Nacimiento") if clave == "nacimiento" else Idioma.t("Muerte")
				_anio(d.get("anio"), que, e)
				_punto(d, que, e)
				anios.append(d.get("anio"))
			var ac: Dictionary = _dic(item, "activo")
			_anio(ac.get("desde"), Idioma.t("Activo desde"), e)
			_anio(ac.get("hasta"), Idioma.t("Activo hasta"), e)
			_orden(ac.get("desde"), ac.get("hasta"), Idioma.t("La actividad"), e)
			_orden(anios[0], anios[1], Idioma.t("La vida"), e)
			_punto(ac, Idioma.t("Dónde trabajó"), e)
			anios += [ac.get("desde"), ac.get("hasta")]
			if anios.all(func(x): return x == null):
				a.append(Idioma.t("Sin ningún año: la persona no aparece en el mapa ni entre las personas vivas."))
			_refs(item.get("obras", []), "fuentes", Idioma.t("Obra"), extra, e)
			if item.get("wikidata") != null and not RegEx.create_from_string("^Q[0-9]+$").search(str(item["wikidata"])):
				e.append(Idioma.t("Wikidata va como Q seguido de números (Q26825)."))
		"hechos":
			if item.get("anio") == null:
				e.append(Idioma.t("Falta el año."))
			_anio(item.get("anio"), Idioma.t("Año"), e)
			_anio(item.get("anio_hasta"), Idioma.t("Hasta"), e)
			_orden(item.get("anio"), item.get("anio_hasta"), Idioma.t("El hecho"), e)
			_punto(item, Idioma.t("Lugar"), e)
			if item.get("lon") == null:
				a.append(Idioma.t("Sin coordenadas: no aparece en el mapa."))
			if not item.get("tipo") in TIPOS_HECHO:
				a.append(Idioma.t("Tipo no previsto: %s.") % item.get("tipo"))
			_refs(item.get("regiones", []), "regiones", Idioma.t("Región"), extra, e)
			_refs(item.get("fuentes", []), "fuentes", Idioma.t("Fuente"), extra, e)
		"lugares":
			_anio(item.get("fundacion"), Idioma.t("Fundación"), e)
			_anio(item.get("abandono"), Idioma.t("Abandono"), e)
			_orden(item.get("fundacion"), item.get("abandono"), Idioma.t("El lugar"), e)
			if item.get("lon") == null or item.get("lat") == null:
				e.append(Idioma.t("Faltan las coordenadas: un lugar sin ellas no aparece en el mapa."))
			_punto(item, Idioma.t("Lugar"), e)
			if not item.get("tipo") in TIPOS_LUGAR:
				a.append(Idioma.t("Tipo no previsto: %s.") % item.get("tipo"))
			if not item.get("importancia") in [1, 2, 3, 1.0, 2.0, 3.0]:
				e.append(Idioma.t("La importancia va de 1 a 3."))
			_refs(item.get("regiones", []), "regiones", Idioma.t("Región"), extra, e)
		"regiones":
			var poli: Array = item.get("poligono", []) if item.get("poligono") is Array else []
			if poli.size() < 3:
				e.append(Idioma.t("Falta el área de estudio (un polígono de al menos 3 puntos)."))
			for p in poli:
				if not (p is Array and p.size() == 2 and absf(float(p[0])) <= 180 and absf(float(p[1])) <= 90):
					e.append(Idioma.t("Un vértice del área de estudio está fuera de rango: %s.") % [p])
					break
			if item.get("padre") != null and str(item.get("padre")) != "":
				if str(item["padre"]) == id:
					e.append(Idioma.t("Una región no puede estar dentro de sí misma."))
				else:
					_refs([item["padre"]], "regiones", Idioma.t("Región mayor"), extra, e)
			for era in item.get("eras", []) if item.get("eras") is Array else []:
				var nombre := str(era.get("nombre", "")) if era is Dictionary else ""
				if nombre.strip_edges() == "":
					e.append(Idioma.t("Hay una era sin nombre."))
				_anio(era.get("desde"), Idioma.t("La era «%s», desde") % nombre, e)
				_anio(era.get("hasta"), Idioma.t("La era «%s», hasta") % nombre, e)
				_orden(era.get("desde"), era.get("hasta"), Idioma.t("La era «%s»") % nombre, e)
			if (item.get("eras", []) as Array).is_empty() if item.get("eras") is Array else true:
				a.append(Idioma.t("Sin eras: los lugares de esta región siguen contando como «sin ficha»."))
			for capa in CAPAS:
				_capa(item.get(capa), capa, e)
			_demografia(item.get("demografia"), e, a)
			_extendida(item.get("extendida"), e)
	var wiki: Variant = item.get("wikipedia")
	if wiki != null and not wiki is Dictionary:
		e.append(Idioma.t("Wikipedia va como {\"es\": título, \"en\": título}."))
	return {"errores": e, "avisos": a}


## Religiones, culturas o idiomas de una región: las mismas reglas que tools/enciclopedia/validar.py.
static func _capa(lista: Variant, capa: String, e: Array) -> void:
	if not lista is Array:
		return
	var titulo: String = {"religiones": Idioma.t("Religión"), "culturas": Idioma.t("Cultura"), "idiomas": Idioma.t("Idioma")}[capa]
	for x in lista:
		if not x is Dictionary:
			continue
		var nombre := str(x.get("nombre", "")) if x.get("nombre") != null else ""
		var que := "%s «%s»" % [titulo, nombre]
		if nombre.strip_edges() == "":
			e.append(Idioma.t("%s: hay una entrada sin nombre.") % titulo)
		if x.get("desde") == null:
			e.append(Idioma.t("%s: falta «desde» (si es anterior a lo documentado, va desde cuándo hay registro y una nota).") % que)
		_anio(x.get("desde"), que, e)
		_anio(x.get("hasta"), que, e)
		_orden(x.get("desde"), x.get("hasta"), que, e)
		if not x.get("peso") in PESOS:
			e.append(Idioma.t("%s: el peso tiene que ser mayoritaria, importante o minoritaria.") % que)
		var fam := str(x.get("familia")) if x.get("familia") != null else ""
		if fam.strip_edges() == "":
			e.append(Idioma.t("%s: falta la familia.") % que)
		elif not Enciclopedia.familias.has("%s:%s" % [capa, fam]):
			e.append(Idioma.t("%s: la familia «%s» no está en familias.json.") % [que, fam])


## Población de una región: solo estimaciones publicadas, con su fuente.
static func _demografia(lista: Variant, e: Array, a: Array) -> void:
	if not lista is Array:
		return
	for x in lista:
		if not x is Dictionary:
			continue
		var anio: Variant = x.get("anio")
		var que := Idioma.t("Población de %s") % (Fechas.texto(int(anio)) if (anio is int or anio is float) and int(anio) != 0 else "?")
		if anio == null:
			e.append(Idioma.t("Hay una cifra de población sin año."))
		_anio(anio, Idioma.t("Población"), e)
		var cifras := {}
		for clave in ["poblacion", "min", "max"]:
			var v: Variant = x.get(clave)
			if v == null and clave != "poblacion":
				continue
			if not ((v is int or v is float) and v == floorf(v) and v > 0):
				e.append(Idioma.t("%s: «%s» no es un número entero mayor que cero.") % [que, "" if v == null else str(v)])
			else:
				cifras[clave] = float(v)
		if cifras.has("poblacion") and (cifras.get("min", cifras["poblacion"]) > cifras["poblacion"]
				or cifras.get("max", cifras["poblacion"]) < cifras["poblacion"]):
			a.append(Idioma.t("%s: la cifra queda fuera del rango entre el mínimo y el máximo.") % que)
		if str(x.get("fuente", "") if x.get("fuente") != null else "").strip_edges() == "":
			e.append(Idioma.t("%s: falta la fuente (solo van estimaciones publicadas).") % que)


static func _extendida(x: Variant, e: Array) -> void:
	if x == null:
		return
	if not x is Dictionary:
		e.append(Idioma.t("La ficha extendida no tiene el formato del esquema."))
		return
	var refs := {}
	for r in x.get("referencias", []):
		refs[int(r.get("n", 0))] = true
		if not str(r.get("url", "")).begins_with("http"):
			e.append(Idioma.t("La referencia %s de la ficha extendida no tiene URL.") % r.get("n"))
	for s in x.get("secciones", []):
		for n in s.get("citas", []):
			if not refs.has(int(n)):
				e.append(Idioma.t("La sección «%s» cita [%s], que no está en las referencias.") % [s.get("titulo"), n])


static func _dic(d: Dictionary, clave: String) -> Dictionary:
	return d[clave] if d.get(clave) is Dictionary else {}


static func _existe(seccion: String, id: String, extra: Dictionary) -> bool:
	return (Enciclopedia.get(seccion) as Dictionary).has(id) or (extra.get(seccion, {}) as Dictionary).has(id)


static func _anio(v: Variant, que: String, e: Array) -> void:
	if v == null:
		return
	if not (v is int or (v is float and v == floorf(v))):
		e.append(Idioma.t("%s: «%s» no es un año (van enteros; antes de Cristo, negativos o con «a. C.»).") % [que, v])
	elif int(v) == 0:
		e.append(Idioma.t("%s: no existe el año 0 (el 1 a. C. es -1 y el 1 d. C. es 1).") % que)


static func _orden(desde: Variant, hasta: Variant, que: String, e: Array) -> void:
	if (desde is int or desde is float) and (hasta is int or hasta is float) and float(desde) > float(hasta):
		e.append(Idioma.t("%s termina antes de empezar.") % que)


static func _punto(d: Dictionary, que: String, e: Array) -> void:
	var lon: Variant = d.get("lon")
	var lat: Variant = d.get("lat")
	if lon == null and lat == null:
		return
	if not (lon is float or lon is int) or not (lat is float or lat is int):
		e.append(Idioma.t("%s: faltan la longitud o la latitud, o no son números.") % que)
	elif absf(float(lon)) > 180 or absf(float(lat)) > 90:
		e.append(Idioma.t("%s: coordenadas fuera de rango (%s, %s).") % [que, lon, lat])


static func _refs(ids: Variant, seccion: String, que: String, extra: Dictionary, e: Array) -> void:
	if not ids is Array:
		return
	for id in ids:
		if not _existe(seccion, str(id), extra):
			e.append(Idioma.t("%s «%s»: no existe en la enciclopedia.") % [que, id])


# ---------------------------------------------------------------------------------------------------------------
# Área de estudio y borradores


## Índice en DatosMapa de una entidad de Cliopatria por su nombre original o su Wikidata; -1 si no está.
static func entidad(nombre: String, wikidata := "") -> int:
	for i in DatosMapa.entidades.size():
		if str(DatosMapa.entidades[i]["n"]) == nombre:
			return i
	for i in DatosMapa.entidades.size():
		if wikidata != "" and str(DatosMapa.entidades[i]["d"]) == wikidata:
			return i
	return -1


## Área de estudio aproximada de una entidad: la envolvente convexa de todas las unidades que tuvo alguna vez, con
## hasta max_vertices vértices, en [[lon, lat], …]. La app pinta igual el contorno real de cada año dentro de ella.
static func poligono_de_entidad(i: int, max_vertices := 32) -> Array:
	var vistos := {}
	var puntos := PackedVector2Array()
	var k := DatosMapa.ev_despues.find(i)
	while k != -1:
		var u := DatosMapa.ev_unidad[k]
		if not vistos.has(u):
			vistos[u] = true
			puntos.append(DatosMapa.centro_unidad(u))
		k = DatosMapa.ev_despues.find(i, k + 1)
	if puntos.size() < 3:
		return []
	var casco := Geometry2D.convex_hull(puntos)
	if casco.size() > 1 and casco[0] == casco[casco.size() - 1]:
		casco.remove_at(casco.size() - 1)
	var paso := maxf(1.0, casco.size() / float(max_vertices))
	var out: Array = []
	var j := 0.0
	while int(j) < casco.size():
		var ll := Proyeccion.a_lonlat(casco[int(j)])
		out.append([snappedf(ll.x, 0.1), snappedf(ll.y, 0.1)])
		j += paso
	return out


## Ids de cada sección de un archivo: {sección: {id: true}}.
static func ids_de(datos: Dictionary) -> Dictionary:
	var out := {}
	for s in TIPO_DE_SECCION:
		out[s] = {}
		for item in datos.get(s, []):
			if item is Dictionary:
				out[s][str(item.get("id", ""))] = true
	return out


## Errores de todos los elementos de un borrador, con el nombre de cada uno.
static func validar_borrador(datos: Dictionary) -> Dictionary:
	var extra := ids_de(datos)
	var e: Array = []
	var a: Array = []
	for s in TIPO_DE_SECCION:
		for item in datos.get(s, []):
			var r := validar(s, item, str(item.get("id", "")), extra)
			var nombre := str(item.get("titulo", item.get("nombre", item.get("id", ""))))
			for x in r["errores"]:
				e.append("%s: %s" % [nombre, x])
			for x in r["avisos"]:
				a.append("%s: %s" % [nombre, x])
			if _existe(s, str(item.get("id", "")), {}):
				e.append(Idioma.t("%s: ya hay un elemento «%s» en la enciclopedia.") % [nombre, item.get("id")])
	return {"errores": e, "avisos": a}


## Pasa los elementos de un borrador revisado a un paquete y borra el borrador. La ficha extendida queda con la fecha
## y la nota de la revisión, y la región con el origen del borrador.
static func aprobar_borrador(ruta_borrador: String, ruta_paquete: String, nota: String) -> String:
	var b := leer(ruta_borrador)
	var d := leer(ruta_paquete)
	if b.is_empty() or d.is_empty():
		return Idioma.t("No se pudo leer el borrador o el paquete.")
	var r := validar_borrador(b)
	if not r["errores"].is_empty():
		return Idioma.t("El borrador todavía tiene errores:\n• ") + "\n• ".join(r["errores"])
	var meta: Dictionary = b.get("borrador", {})
	for s in TIPO_DE_SECCION:
		var lista: Array = d.get(s, [])
		for item in b.get(s, []):
			if s == "regiones":
				item["origen"] = {"borrador": ruta_borrador.get_file(), "generado": meta.get("generado"),
					"revisado": hoy(), "nota": nota}
				if item.get("extendida") is Dictionary:
					item["extendida"]["revision"] = {"fecha": hoy(), "nota": nota}
			lista.append(item)
		if not lista.is_empty():
			d[s] = lista
	var err := escribir(ruta_paquete, d)
	if err != "":
		return err
	return borrar(ruta_borrador)


## Un borrador chico para la prueba automática y el recorrido (no se guarda en el repo).
static func borrador_de_prueba() -> Dictionary:
	return {
		"paquete": "borrador-prueba",
		"descripcion": "Borrador de prueba",
		"borrador": {"titulo": "Imperio de prueba", "estado": "sin revisar", "generado": hoy(), "por": "la prueba automática",
			"origen": {"entidad": "Roman Empire", "wikidata": "Q12544", "veces": 3, "anios": [117], "lon": 12.5, "lat": 41.9},
			"ia": {"modelo": "prueba", "fecha": hoy()}},
		"regiones": [{"id": "prueba-imperio", "nombre": "Imperio de prueba", "padre": null, "poligono": [],
			"resumen": "Región de prueba.", "eras": [{"desde": -27, "hasta": 476, "nombre": "Imperio", "resumen": "Prueba."}],
			"extendida": {"secciones": [{"titulo": "Historia", "texto": "Augusto gobernó desde Roma [1].", "citas": [1]}],
				"referencias": [{"n": 1, "titulo": "Imperio romano (Wikipedia)", "url": "https://es.wikipedia.org/wiki/Imperio_romano"}]}}],
		"lugares": [{"id": "prueba-roma", "nombre": "Roma (prueba)", "lon": 12.483, "lat": 41.893, "fundacion": -753,
			"abandono": null, "aprox": true, "tipo": "capital", "importancia": 3, "resumen": "Prueba.", "regiones": ["prueba-imperio"]}],
	}
