class_name PruebaEditor
extends RefCounted
## Prueba del editor de la enciclopedia (parte de --prueba). Comprueba que leer y volver a escribir cada paquete no
## cambie un byte, que abrir cada elemento en el formulario sin tocar nada no lo cambie, que la validación frene los
## errores típicos, que guardar cambie solo lo editado, que un borrador se apruebe entero y que el clic en el mapa
## ponga coordenadas sin seleccionar. Escribe solo en user://prueba_editor/.

const DIR := "user://prueba_editor/"

var fallas := 0


func _falla(texto: String) -> void:
	fallas += 1
	push_error("[prueba] editor: " + texto)


## Devuelve un resumen para el registro de la prueba.
func correr(interfaz: Interfaz) -> String:
	var arbol := interfaz.get_tree()
	var ed := interfaz.editor
	Estado.sin_escribir = false
	DirAccess.make_dir_recursive_absolute(DIR + "borradores")

	# 1. Leer y volver a escribir no cambia nada.
	for ruta in Edicion.paquetes():
		if Edicion.a_json(Edicion.leer(ruta)) != FileAccess.get_file_as_string(ruta):
			_falla("leer y volver a escribir %s cambia el archivo" % ruta.get_file())

	# 2. Cada elemento, abierto en el formulario y sin tocar, queda igual.
	var n := 0
	for seccion in Edicion.TIPO_DE_SECCION:
		for id in (Enciclopedia.get(seccion) as Dictionary).keys():
			ed._vaciar()
			ed.abrir(Edicion.TIPO_DE_SECCION[seccion], id)
			ed._aplicar()
			if ed._seccion_form != seccion:
				_falla("no se abrió %s «%s»" % [seccion, id])
			elif ed.esta_sucio():
				_falla("abrir %s «%s» y no tocar nada lo cambia: %s" % [seccion, id, _diferencia(ed._original, ed._copia)])
			n += 1
		await arbol.process_frame
	ed._vaciar()

	# 3. La validación frena lo que tiene que frenar.
	var hecho := _limpio(Enciclopedia.hechos.values()[0])
	hecho["anio"] = 0
	# Los mensajes salen en el idioma de la app: se busca un pedazo del mensaje traducido.
	_espera_error("hechos", hecho, hecho["id"], Idioma.t("%s: no existe el año 0 (el 1 a. C. es -1 y el 1 d. C. es 1).").get_slice("%s", 1))
	var persona := _limpio(Enciclopedia.personas.values()[0])
	persona["nombre"] = ""
	persona["obras"] = ["no-existe"]
	_espera_error("personas", persona, persona["id"], Idioma.t("Falta el nombre."))
	_espera_error("personas", persona, persona["id"], "no-existe")
	var lugar := _limpio(Enciclopedia.lugares.values()[0])
	lugar.erase("lon")
	_espera_error("lugares", lugar, lugar["id"], Idioma.t("Faltan las coordenadas: un lugar sin ellas no aparece en el mapa."))
	var repetido := _limpio(Enciclopedia.fuentes.values()[0])
	_espera_error("fuentes", repetido, "", Idioma.t("Ya hay un elemento con el id «%s» en %s.").get_slice("%s", 0))
	if not EditorEnciclopedia._leer_anio("1274 a. C.") == -1274 or not EditorEnciclopedia._leer_anio("c. 476") == 476:
		_falla("no entiende los años escritos con «a. C.» o «c.»")
	var region_mal := _limpio(Enciclopedia.regiones.values()[0])
	region_mal["religiones"] = [{"desde": null, "hasta": null, "nombre": "Prueba", "familia": "no-existe", "peso": "casi"}]
	region_mal["demografia"] = [{"anio": 100, "poblacion": "muchos", "fuente": ""}]
	_espera_error("regiones", region_mal, region_mal["id"], "no-existe")
	_espera_error("regiones", region_mal, region_mal["id"], "muchos")
	for mensaje in ["%s: el peso tiene que ser mayoritaria, importante o minoritaria.",
			"%s: falta «desde» (si es anterior a lo documentado, va desde cuándo hay registro y una nota).",
			"%s: falta la fuente (solo van estimaciones publicadas)."]:
		_espera_error("regiones", region_mal, region_mal["id"], Idioma.t(mensaje).get_slice("%s", 1))
	if EditorEnciclopedia._leer_numero("1.600.000") != 1600000 or EditorEnciclopedia._leer_numero("2 500") != 2500 \
			or not EditorEnciclopedia._leer_numero("1.5") is String:
		_falla("no entiende las cifras de población con separadores de miles")

	# 3b. Una cifra de población nueva queda en su lugar por año, sin claves vacías, y las de Our World in Data (que no
	# se muestran) siguen intactas.
	var con_serie := ""
	for r in Enciclopedia.regiones.values():
		if (r.get("demografia", []) as Array).any(func(e): return str(e.get("fuente", "")).ends_with(Edicion.MARCA_OWID)):
			con_serie = r["id"]
			break
	if con_serie == "":
		_falla("ninguna región tiene la serie de Our World in Data")
	else:
		ed._vaciar()
		ed.abrir("region", con_serie)
		ed._aplicar()
		var antes_dem: Array = (ed._copia["demografia"] as Array).duplicate(true)
		(ed._copia["demografia"] as Array).append({"anio": 1450, "poblacion": 123456, "min": null, "max": null,
			"fuente": "Prueba (2026), obra", "tipo": null, "nota": null})
		ed._construir_formulario()
		ed._aplicar()
		var dem: Array = ed._copia["demografia"]
		var anios: Array = dem.map(func(e): return float(e["anio"]))
		var ordenados := anios.duplicate()
		ordenados.sort()
		var nueva: Array = dem.filter(func(e): return e.get("fuente") == "Prueba (2026), obra")
		var owid := func(lista: Array): return Edicion.a_json({"x": lista.filter(func(e): return str(e.get("fuente", "")).ends_with(Edicion.MARCA_OWID))})
		if dem.size() != antes_dem.size() + 1 or anios != ordenados or nueva.size() != 1 or nueva[0].values().has(null) \
				or owid.call(dem) != owid.call(antes_dem):
			_falla("agregar una cifra de población a «%s» no la dejó en su lugar o tocó la serie de Our World in Data: %s" % [con_serie, nueva])
		ed._vaciar()

	# 4. Guardar cambia solo lo editado, y lo nuevo se agrega al final.
	var origen: String = Enciclopedia.hechos.values()[0]["_archivo"]
	var copia := DIR + origen.get_file()
	# Con FileAccess y no DirAccess.copy_absolute: en una versión exportada el paquete está dentro del ejecutable.
	var f_copia := FileAccess.open(copia, FileAccess.WRITE)
	f_copia.store_string(FileAccess.get_file_as_string(origen))
	f_copia.close()
	var esperado := Edicion.leer(origen)
	var editado := _limpio(Enciclopedia.hechos.values()[0])
	editado["resumen"] = "Resumen cambiado por la prueba."
	var i := Edicion.indice(esperado["hechos"], editado["id"])
	esperado["hechos"][i] = editado
	var err := Edicion.guardar(copia, "hechos", editado, editado["id"])
	if err != "" or FileAccess.get_file_as_string(copia) != Edicion.a_json(esperado):
		_falla("guardar un hecho cambió más que ese hecho (%s)" % err)
	var nuevo := {"id": "prueba-nuevo", "nombre": "Lugar nuevo", "lon": 10.0, "lat": 20.0, "tipo": "ciudad", "importancia": 1}
	Edicion.guardar(copia, "lugares", nuevo, "")
	var lugares: Array = Edicion.leer(copia)["lugares"]
	if lugares.is_empty() or lugares[lugares.size() - 1].get("id") != "prueba-nuevo":
		_falla("un lugar nuevo no quedó al final de su sección")
	if Edicion.guardar(copia, "lugares", nuevo, "") == "":
		_falla("dejó guardar dos veces un elemento nuevo con el mismo id")

	# 5. Borrador: área con el territorio de Cliopatria, revisión en el editor y aprobación.
	var ruta_b := DIR + "borradores/prueba.json"
	Edicion.escribir(ruta_b, Edicion.borrador_de_prueba())
	var ent := Edicion.entidad("Roman Empire", "Q12544")
	var area := Edicion.poligono_de_entidad(ent)
	if ent < 0 or area.size() < 3 or area.size() > 32:
		_falla("el área de estudio de la entidad %d salió con %d vértices" % [ent, area.size()])
	var antes := Edicion.dir_borradores
	Edicion.dir_borradores = DIR + "borradores/"
	ed.abrir()
	ed._cambiar_seccion("borradores")
	ed._al_elegir(0)
	ed._calcular_area_borrador(ruta_b, "prueba-imperio")
	var region: Dictionary = Edicion.leer(ruta_b)["regiones"][0]
	if (region["poligono"] as Array).size() < 3:
		_falla("«Calcular el área» no le puso área de estudio a la región del borrador")
	var val := Edicion.validar_borrador(Edicion.leer(ruta_b))
	if not val["errores"].is_empty():
		_falla("el borrador de prueba no valida: %s" % [val["errores"]])
	err = Edicion.aprobar_borrador(ruta_b, copia, "revisado por la prueba")
	var final := Edicion.leer(copia)
	var aprobada: Dictionary = final["regiones"][final["regiones"].size() - 1] if final.has("regiones") else {}
	if err != "" or FileAccess.file_exists(ruta_b) or aprobada.get("id") != "prueba-imperio" \
			or not aprobada.get("extendida", {}).has("revision") or Edicion.indice(final["lugares"], "prueba-roma") < 0:
		_falla("aprobar el borrador no pasó todo al paquete y no lo borró (%s)" % err)
	Edicion.dir_borradores = antes
	ed._vaciar()

	# 6. En una versión exportada se guarda una copia en la carpeta del usuario, que tapa al paquete de adentro sin
	# tocarlo. Si ya había una copia local (cambios de quien usa la app), se respeta y se repone.
	var local_antes := Edicion.guardar_local
	Edicion.guardar_local = true
	var archivo: String = Enciclopedia.hechos.values()[0]["_archivo"]
	var id: String = Enciclopedia.hechos.values()[0]["id"]
	var local := Edicion.destino(archivo)
	var previa := FileAccess.get_file_as_string(local) if FileAccess.file_exists(local) else ""
	var original := FileAccess.get_file_as_string(archivo)
	# Se parte del hecho como está en el paquete, en español (en memoria puede estar traducido), y se cambia también
	# «aprox», que no se traduce: con la app en inglés el resumen se sigue viendo con su traducción.
	var del_paquete: Array = Edicion.leer(Edicion.para_leer(archivo)).get("hechos", [])
	var cambio := _limpio(del_paquete[Edicion.indice(del_paquete, id)])
	cambio["resumen"] = "Cambio local de la prueba."
	cambio["aprox"] = not bool(cambio.get("aprox", false))
	err = Edicion.guardar(archivo, "hechos", cambio, cambio["id"])
	Enciclopedia.cargar()
	var cargado: Dictionary = Enciclopedia.hechos.get(cambio["id"], {})
	var tapa: bool = bool(cargado.get("aprox", false)) == cambio["aprox"] \
			and (Idioma.actual != "es" or cargado.get("resumen") == cambio["resumen"])
	if err != "" or not FileAccess.file_exists(local) or not tapa or FileAccess.get_file_as_string(archivo) != original:
		_falla("en modo exportado, guardar no dejó una copia local que tape al paquete (%s)" % err)
	if previa != "":
		var f := FileAccess.open(local, FileAccess.WRITE)
		f.store_string(previa)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(local))
	Edicion.guardar_local = local_antes
	Enciclopedia.cargar()

	# 7. Con «Elegir en el mapa», el clic pone las coordenadas y no selecciona.
	var recibido: Array = []
	Estado.seleccionar_lugar(0, Vector2.ZERO)
	Estado.captura_punto = func(ll: Vector2): recibido.append(ll)
	interfaz.vista._click(interfaz.get_viewport().get_visible_rect().size * 0.5)
	if recibido.size() != 1 or Estado.unidad_seleccionada != 0 or Estado.captura_punto.is_valid():
		_falla("el clic en el mapa no pasó las coordenadas al editor (o además seleccionó)")
	ed.cerrar()
	return "editor de la enciclopedia: %d elementos abiertos sin cambios, validación, guardado y borrador (%d fallas)" % [n, fallas]


func _espera_error(seccion: String, item: Dictionary, id_original: String, texto: String) -> void:
	var r := Edicion.validar(seccion, item, id_original)
	for e in r["errores"]:
		if str(e).contains(texto):
			return
	_falla("la validación de %s no avisó «%s»: %s" % [seccion, texto, r["errores"]])


## Copia limpia de un elemento cargado (sin los campos internos «_»).
func _limpio(item: Dictionary) -> Dictionary:
	return JSON.parse_string(Edicion.a_json(item))


func _diferencia(a: Dictionary, b: Dictionary) -> String:
	for k in a.keys() + b.keys():
		var ja := Edicion.a_json({"x": a.get(k)})
		var jb := Edicion.a_json({"x": b.get(k)})
		if ja != jb or a.has(k) != b.has(k):
			return "«%s»: %s → %s" % [k, JSON.stringify(a.get(k)), JSON.stringify(b.get(k))]
	return "?"
