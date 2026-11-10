class_name EditorEnciclopedia
extends Control
## Editor de la enciclopedia: formularios para fuentes, personas, hechos, lugares y regiones, coordenadas con un clic en
## el mapa, validación al guardar y revisión de los borradores (docs/es/enciclopedia.md). Escribe los JSON de
## data/enciclopedia/paquetes con el mismo formato que tienen (ver Edicion): el diff muestra solo lo cambiado.
## Va a la izquierda, para dejar el mapa y el panel de fichas a la vista. Las etiquetas de las constantes están en
## español y se traducen con tr() al mostrarlas; los datos se editan siempre en español, como están en los paquetes.

const ANCHO := 560.0
const SECCIONES := [["fuentes", "Fuentes"], ["personas", "Personas"], ["hechos", "Hechos"], ["lugares", "Lugares"],
	["regiones", "Regiones"], ["borradores", "Borradores"]]
const TITULO_NUEVO := {"fuentes": "Nueva fuente", "personas": "Nueva persona", "hechos": "Nuevo hecho", "lugares": "Nuevo lugar",
	"regiones": "Nueva región"}
## Objetos que vuelven a null si se vacían todos sus campos.
const OPCIONALES := ["nacimiento", "muerte", "activo"]
const IMPORTANCIAS := [[1, "1 · local"], [2, "2 · regional"], [3, "3 · de primer orden"]]
## Campos de cada sección: [ruta, etiqueta, tipo, extra]. Tipos: titulo (encabezado), id, texto, largo, anio, bool,
## opcion (extra: lista o nombre de lista de Edicion), importancia, lista (textos separados por comas), refs (ids
## separados por comas; extra: sección), ref (un id), wiki, punto (lon y lat del objeto en ruta; "" = el elemento),
## filas (extra: subcampos [clave, etiqueta, texto | corto | anio | bool | linea]) y poligono.
const CAMPOS := {
	"fuentes": [
		["titulo", "Título", "texto"],
		["id", "Id", "id"],
		["titulo_original", "Título original", "texto"],
		["autor", "Autor", "texto"],
		["autor_id", "Ficha del autor (id)", "ref", "personas"],
		["tipo", "Tipo", "opcion", "TIPOS_FUENTE"],
		["genero", "Género", "opcion", "GENEROS"],
		["confianza", "Confianza en la datación", "opcion", "CONFIANZAS"],
		["", "Dónde y cuándo se escribió", "titulo"],
		["escrita.anio", "Año", "anio"],
		["escrita.anio_hasta", "Hasta (si llevó años)", "anio"],
		["escrita.aprox", "Fecha aproximada", "bool"],
		["escrita.lugar", "Lugar", "texto"],
		["escrita", "Coordenadas", "punto"],
		["", "De qué lugar y época trata", "titulo"],
		["trata.regiones", "Regiones (ids)", "refs", "regiones"],
		["trata.desde", "Desde", "anio"],
		["trata.hasta", "Hasta", "anio"],
		["", "Descripción", "titulo"],
		["idioma_original", "Idioma original", "texto"],
		["soporte", "Soporte", "texto"],
		["resumen", "De qué se trata", "largo"],
		["por_que_importa", "Por qué leerla", "largo"],
		["leer", "Para leer (solo enlaces comprobados)", "filas", [["titulo", "Título", "texto"], ["idioma", "Idioma", "corto"],
			["dominio_publico", "Dominio público", "bool"], ["url", "https://…", "linea"]]],
		["wikipedia", "Wikipedia", "wiki"],
	],
	"personas": [
		["nombre", "Nombre", "texto"],
		["id", "Id", "id"],
		["roles", "Roles (separados por comas)", "lista"],
		["", "Nacimiento", "titulo"],
		["nacimiento.anio", "Año", "anio"],
		["nacimiento.aprox", "Fecha aproximada", "bool"],
		["nacimiento.lugar", "Lugar", "texto"],
		["nacimiento", "Coordenadas", "punto"],
		["", "Muerte", "titulo"],
		["muerte.anio", "Año", "anio"],
		["muerte.aprox", "Fecha aproximada", "bool"],
		["muerte.lugar", "Lugar", "texto"],
		["muerte", "Coordenadas", "punto"],
		["", "Dónde trabajó (si no es donde nació)", "titulo"],
		["activo.lugar", "Lugar", "texto"],
		["activo", "Coordenadas", "punto"],
		["activo.desde", "Activo desde", "anio"],
		["activo.hasta", "Hasta", "anio"],
		["activo.aprox", "Fechas aproximadas", "bool"],
		["", "Descripción", "titulo"],
		["resumen", "Resumen", "largo"],
		["obras", "Obras (ids de fuentes)", "refs", "fuentes"],
		["wikipedia", "Wikipedia", "wiki"],
		["wikidata", "Wikidata (Q…)", "texto"],
	],
	"hechos": [
		["titulo", "Título", "texto"],
		["id", "Id", "id"],
		["tipo", "Tipo", "opcion", "TIPOS_HECHO"],
		["anio", "Año", "anio"],
		["anio_hasta", "Hasta (si duró)", "anio"],
		["aprox", "Fecha aproximada", "bool"],
		["lugar", "Lugar", "texto"],
		["", "Coordenadas", "punto"],
		["regiones", "Regiones (ids)", "refs", "regiones"],
		["fuentes", "Fuentes que lo documentan (ids)", "refs", "fuentes"],
		["resumen", "Resumen", "largo"],
		["wikipedia", "Wikipedia", "wiki"],
	],
	"lugares": [
		["nombre", "Nombre", "texto"],
		["id", "Id", "id"],
		["tipo", "Tipo", "opcion", "TIPOS_LUGAR"],
		["importancia", "Importancia", "importancia"],
		["", "Coordenadas", "punto"],
		["fundacion", "Fundación", "anio"],
		["abandono", "Abandono (vacío si sigue)", "anio"],
		["aprox", "Fechas aproximadas", "bool"],
		["regiones", "Regiones (ids)", "refs", "regiones"],
		["resumen", "Resumen", "largo"],
		["wikipedia", "Wikipedia", "wiki"],
	],
	"regiones": [
		["nombre", "Nombre", "texto"],
		["id", "Id", "id"],
		["padre", "Región mayor (id)", "ref", "regiones"],
		["resumen", "Resumen", "largo"],
		["poligono", "Área de estudio", "poligono"],
		["eras", "Eras", "filas", [["desde", "Desde", "anio"], ["hasta", "Hasta", "anio"], ["nombre", "Nombre", "texto"],
			["resumen", "Resumen", "linea"]]],
	],
}

var _panel: PanelContainer
var _botones_seccion := {}
var _filtro: LineEdit
var _lista: ItemList
var _filas_lista: Array = []
var _indice_lista := -1
var _desliza: ScrollContainer
var _form: VBoxContainer
var _mensaje_l: RichTextLabel
var _pie: HBoxContainer
var _paquete: OptionButton
var _donde: Label
var _boton_validar: Button
var _boton_descartar: Button
var _boton_guardar: Button
var _cerrar: Button

var _seccion := "fuentes"
## Lo que se está editando: archivo, sección, id original ("" = nuevo), el elemento como estaba y la copia de trabajo.
var _ruta := ""
var _seccion_form := ""
var _id_original := ""
var _original: Dictionary = {}
var _copia: Dictionary = {}
## Aplicadores del formulario: cada uno escribe su campo en un diccionario.
var _campos: Array = []
var _id_edit: LineEdit
var _id_auto := true
## Borrador abierto (ruta) y si el elemento del formulario vino de él.
var _borrador := ""
var _desde_borrador := false
var _confirmar_cierre := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_left = 12
	_panel.offset_right = 12 + ANCHO
	_panel.offset_top = 66
	_panel.offset_bottom = -136
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_panel.add_child(caja)

	var cab := HBoxContainer.new()
	caja.add_child(cab)
	var titulo := Label.new()
	titulo.text = tr("Editor de la enciclopedia")
	titulo.theme_type_variation = "TituloGrande"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	_cerrar = IconosUI.boton("cerrar", tr("Cerrar el editor"), 18)
	_cerrar.pressed.connect(_al_cerrar)
	cab.add_child(_cerrar)

	var secciones := HBoxContainer.new()
	secciones.add_theme_constant_override("separation", 0)
	caja.add_child(secciones)
	var grupo := ButtonGroup.new()
	for s in SECCIONES:
		var b := Button.new()
		b.text = tr(s[1])
		b.toggle_mode = true
		b.button_group = grupo
		b.theme_type_variation = "Pestana"
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = s[0]
		b.pressed.connect(func(): _cambiar_seccion(id))
		secciones.add_child(b)
		_botones_seccion[id] = b

	var busca := HBoxContainer.new()
	caja.add_child(busca)
	_filtro = LineEdit.new()
	_filtro.placeholder_text = tr("Filtrar la lista…")
	_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filtro.text_changed.connect(func(_t): _llenar_lista())
	busca.add_child(_filtro)
	var nuevo := Button.new()
	nuevo.text = tr("Nuevo")
	nuevo.tooltip_text = tr("Cargar un elemento nuevo en esta sección")
	nuevo.pressed.connect(_al_nuevo)
	busca.add_child(nuevo)

	_lista = ItemList.new()
	_lista.custom_minimum_size = Vector2(0, 88)
	_lista.item_selected.connect(_al_elegir)
	caja.add_child(_lista)

	_desliza = ScrollContainer.new()
	_desliza.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desliza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desliza.follow_focus = true
	caja.add_child(_desliza)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 4)
	_desliza.add_child(_form)

	_mensaje_l = RichTextLabel.new()
	_mensaje_l.bbcode_enabled = true
	_mensaje_l.fit_content = true
	_mensaje_l.scroll_active = false
	_mensaje_l.selection_enabled = true
	_mensaje_l.custom_minimum_size = Vector2(ANCHO - 30, 0)
	caja.add_child(_mensaje_l)

	_pie = HBoxContainer.new()
	_pie.add_theme_constant_override("separation", 6)
	caja.add_child(_pie)
	_donde = Label.new()
	_donde.theme_type_variation = "Suave"
	_donde.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_donde.clip_text = true
	_pie.add_child(_donde)
	_paquete = OptionButton.new()
	_paquete.tooltip_text = tr("Paquete donde se guarda lo nuevo")
	_paquete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pie.add_child(_paquete)
	_boton_validar = Button.new()
	_boton_validar.text = tr("Validar")
	_boton_validar.pressed.connect(func(): _validar(true))
	_pie.add_child(_boton_validar)
	_boton_descartar = Button.new()
	_boton_descartar.text = tr("Descartar cambios")
	_boton_descartar.pressed.connect(_al_descartar)
	_pie.add_child(_boton_descartar)
	_boton_guardar = Button.new()
	_boton_guardar.text = tr("Guardar")
	_boton_guardar.pressed.connect(_al_guardar)
	_pie.add_child(_boton_guardar)
	_panel.add_child(Marco.new())
	_pie.visible = false


## Abre el editor en un elemento (tipo de ficha e id) o, sin tipo, en la lista de fuentes.
func abrir(tipo := "", id := "") -> void:
	visible = true
	_confirmar_cierre = false
	var seccion: String = Edicion.SECCION_DE_TIPO.get(tipo, "fuentes" if tipo == "" else "")
	if seccion == "":
		_mensaje(tr("Las fichas de tipo «%s» no se editan acá.") % tipo)
		return
	_cambiar_seccion(seccion, id)
	if Edicion.guardar_local:
		_mensaje(tr("Lo que guardes queda en tu carpeta de usuario (%s) y tapa a los datos que trae el programa. Para sumarlo al proyecto, mandá esos archivos.") % ProjectSettings.globalize_path(Edicion.DIR_LOCAL))


func cerrar() -> void:
	visible = false
	_confirmar_cierre = false
	Estado.captura_punto = Callable()


func esta_sucio() -> bool:
	return _seccion_form != "" and Edicion.a_json(_copia) != Edicion.a_json(_original)


func _al_cerrar() -> void:
	if esta_sucio() and not _confirmar_cierre:
		_confirmar_cierre = true
		_mensaje(tr("Hay cambios sin guardar. Volvé a apretar la cruz para cerrar igual, o guardalos."), true)
		return
	cerrar()


func _cambiar_seccion(seccion: String, id := "") -> void:
	if esta_sucio():
		_mensaje(tr("Guardá o descartá los cambios antes de cambiar de sección."), true)
		_botones_seccion[_seccion].button_pressed = true
		return
	_seccion = seccion
	_botones_seccion[seccion].button_pressed = true
	_filtro.text = ""
	_vaciar()
	_llenar_lista()
	if id == "":
		_mensaje(tr("Elegí un elemento de la lista o apretá «Nuevo».") if seccion != "borradores" else
			tr("Los borradores se arman con tools/enciclopedia/borradores.py a partir de la cola de consultas sin ficha."))
		return
	for i in _filas_lista.size():
		if _filas_lista[i][1] == id:
			_lista.select(i)
			_lista.ensure_current_is_visible()
			_indice_lista = i
			_abrir(_filas_lista[i][0], seccion, id)
			return
	_mensaje(tr("No encontré «%s» en %s.") % [id, seccion], true)


func _llenar_lista() -> void:
	_lista.clear()
	_filas_lista.clear()
	_indice_lista = -1
	var filtro := _filtro.text.strip_edges().to_lower()
	if _seccion == "borradores":
		for ruta in Edicion.borradores():
			var meta: Dictionary = Edicion.leer(ruta).get("borrador", {})
			var texto := "%s   · %s%s" % [meta.get("titulo", ruta.get_file()), meta.get("estado", "sin revisar"),
				tr(", con IA") if meta.get("ia") is Dictionary else ""]
			if filtro == "" or texto.to_lower().contains(filtro):
				_lista.add_item(texto)
				_filas_lista.append([ruta, ""])
		if _filas_lista.is_empty():
			_lista.add_item(tr("No hay borradores."))
			_lista.set_item_disabled(0, true)
			_filas_lista.append(["", ""])
		return
	var clave := "titulo" if _seccion in ["fuentes", "hechos"] else "nombre"
	var items: Array = (Enciclopedia.get(_seccion) as Dictionary).values().filter(func(it):
		return filtro == "" or str(it.get(clave, "")).to_lower().contains(filtro) or str(it["id"]).contains(filtro))
	items.sort_custom(func(a, b): return str(a.get(clave, "")).naturalnocasecmp_to(str(b.get(clave, ""))) < 0)
	for it in items:
		_lista.add_item("%s   · %s" % [it.get(clave, it["id"]), it.get("_paquete", "")])
		_filas_lista.append([it.get("_archivo", ""), it["id"]])


func _al_elegir(i: int) -> void:
	if i >= _filas_lista.size() or _filas_lista[i][0] == "":
		return
	if esta_sucio():
		_mensaje(tr("Guardá o descartá los cambios antes de abrir otro elemento."), true)
		if _indice_lista >= 0:
			_lista.select(_indice_lista)
		else:
			_lista.deselect_all()
		return
	_indice_lista = i
	if _seccion == "borradores":
		_mostrar_borrador(_filas_lista[i][0])
	else:
		_abrir(_filas_lista[i][0], _seccion, _filas_lista[i][1])


func _vaciar() -> void:
	for c in _form.get_children():
		_form.remove_child(c)
		c.queue_free()
	_campos.clear()
	_seccion_form = ""
	_original = {}
	_copia = {}
	_id_edit = null
	_pie.visible = false
	Estado.captura_punto = Callable()


# ---------------------------------------------------------------------------------------------------------------
# Elemento


func _abrir(ruta: String, seccion: String, id: String, desde_borrador := false) -> void:
	var lista: Array = Edicion.leer(ruta).get(seccion, [])
	var i := Edicion.indice(lista, id)
	if i < 0:
		_mensaje(tr("No encontré «%s» en %s.") % [id, ruta.get_file()], true)
		return
	_vaciar()
	_ruta = ruta
	_seccion_form = seccion
	_id_original = id
	_original = (lista[i] as Dictionary).duplicate(true)
	_copia = _original.duplicate(true)
	_desde_borrador = desde_borrador
	_construir_formulario()
	_mensaje("")


func _al_nuevo() -> void:
	if esta_sucio():
		_mensaje(tr("Guardá o descartá los cambios antes de empezar otro."), true)
		return
	if _seccion == "borradores":
		_mensaje(tr("Los borradores no se cargan a mano: se arman con tools/enciclopedia/borradores.py."), true)
		return
	if _seccion_form == _seccion and _id_original == "":
		_mensaje(tr("Ya hay un formulario nuevo abierto: completalo y guardalo."))
		return
	_vaciar()
	_lista.deselect_all()
	_indice_lista = -1
	_ruta = ""
	_seccion_form = _seccion
	_id_original = ""
	_original = {"id": ""}
	_copia = {"id": ""}
	_id_auto = true
	_desde_borrador = false
	_construir_formulario()
	_mensaje(tr("Completá el formulario; las coordenadas se pueden poner con un clic en el mapa."))


func _construir_formulario() -> void:
	for c in _form.get_children():
		_form.remove_child(c)
		c.queue_free()
	_campos.clear()
	var nuevo := _id_original == ""
	var cab := HBoxContainer.new()
	_form.add_child(cab)
	var t := Label.new()
	t.theme_type_variation = "Titulo"
	t.text = tr(TITULO_NUEVO[_seccion_form]) if nuevo else "%s «%s»" % [_nombre_seccion(_seccion_form), _id_original]
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	cab.add_child(t)
	if _desde_borrador:
		var volver := Button.new()
		volver.text = tr("Volver al borrador")
		volver.pressed.connect(func():
			if esta_sucio():
				_mensaje(tr("Guardá o descartá los cambios antes de volver."), true)
			else:
				_mostrar_borrador(_ruta))
		cab.add_child(volver)
	elif not nuevo:
		var ficha := Button.new()
		ficha.text = tr("Ver la ficha")
		ficha.pressed.connect(func(): Estado.pedir_ficha(Edicion.TIPO_DE_SECCION[_seccion_form], _id_original))
		cab.add_child(ficha)
	for campo in CAMPOS[_seccion_form]:
		_campo(campo)
	_pie.visible = true
	_paquete.visible = nuevo
	_donde.visible = not nuevo
	_donde.text = tr("En %s") % _ruta.get_file()
	if nuevo:
		_paquete.clear()
		for p in Edicion.paquetes():
			if p.get_file() != "familias.json":
				_paquete.add_item(tr("Guardar en %s") % p.get_file())
				_paquete.set_item_metadata(_paquete.item_count - 1, p)
		for i in _paquete.item_count:
			if str(_paquete.get_item_metadata(i)).get_file() == "mundo.json":
				_paquete.select(i)
	_actualizar_botones()


func _campo(c: Array) -> void:
	var ruta: String = c[0]
	var etiqueta: String = tr(c[1])
	var tipo: String = c[2]
	var extra: Variant = c[3] if c.size() > 3 else null
	var actual: Variant = _valor(_copia, ruta)
	match tipo:
		"titulo":
			var l := Label.new()
			l.theme_type_variation = "Seccion"
			l.text = etiqueta.to_upper()
			_form.add_child(l)
		"id":
			if _id_original != "":
				var l := Label.new()
				l.text = _id_original
				l.tooltip_text = tr("El id no se cambia: otras fichas lo nombran.")
				_fila(etiqueta, l)
			else:
				_id_edit = LineEdit.new()
				_id_edit.text = str(actual) if actual != null else ""
				_id_edit.placeholder_text = tr("se arma solo con el nombre")
				_id_edit.text_changed.connect(func(_t):
					_id_auto = false
					_al_cambiar())
				_fila(etiqueta, _id_edit)
				var le := _id_edit
				_campos.append(func(d: Dictionary): d["id"] = le.text.strip_edges())
		"texto", "ref":
			var le := LineEdit.new()
			le.text = "" if actual == null else str(actual)
			le.text_changed.connect(func(texto: String):
				if ruta in ["titulo", "nombre"] and _id_original == "" and _id_auto and _id_edit:
					_id_edit.text = Edicion.slug(texto)
				_al_cambiar())
			_fila(etiqueta, le)
			_campos.append(func(d: Dictionary):
				var s := le.text.strip_edges()
				_poner(d, ruta, null if s == "" else s, s == ""))
		"largo":
			var te := TextEdit.new()
			te.text = "" if actual == null else str(actual)
			te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			te.custom_minimum_size = Vector2(0, 84)
			te.text_changed.connect(_al_cambiar)
			_fila(etiqueta, te)
			_campos.append(func(d: Dictionary):
				var s := te.text.strip_edges()
				_poner(d, ruta, null if s == "" else s, s == ""))
		"anio":
			var fila := HBoxContainer.new()
			var le := _entrada_anio(actual, "", fila)
			_fila(etiqueta, fila)
			_campos.append(func(d: Dictionary):
				var n: Variant = _leer_anio(le.text)
				_poner(d, ruta, n, n == null))
		"bool":
			var cb := CheckBox.new()
			cb.text = etiqueta
			cb.button_pressed = actual == true
			cb.toggled.connect(func(_b): _al_cambiar())
			_fila("", cb)
			_campos.append(func(d: Dictionary): _poner(d, ruta, cb.button_pressed, not cb.button_pressed))
		"opcion", "importancia":
			var ob := OptionButton.new()
			var valores: Array = []
			# Un elemento que ya existía sin este campo no lo gana por abrirlo: la primera opción es «—» (vacío).
			if actual == null and _id_original != "":
				valores.append(null)
				ob.add_item("—")
			if tipo == "importancia":
				for par in IMPORTANCIAS:
					valores.append(par[0])
					ob.add_item(tr(par[1]))
			else:
				var opciones: Array = (Edicion as Script).get_script_constant_map()[extra] if extra is String else extra
				for v in opciones:
					valores.append(v)
					ob.add_item(_nombre_opcion(v))
				if actual != null and not _texto_valor(actual) in opciones:
					valores.append(_texto_valor(actual))
					ob.add_item(_texto_valor(actual))
			for i in valores.size():
				if valores[i] != null and actual != null and str(valores[i]) == _texto_valor(actual):
					ob.select(i)
			ob.item_selected.connect(func(_i): _al_cambiar())
			_fila(etiqueta, ob)
			_campos.append(func(d: Dictionary):
				var v: Variant = valores[maxi(ob.selected, 0)]
				_poner(d, ruta, v, v == null))
		"lista", "refs":
			var le := LineEdit.new()
			le.text = ", ".join(PackedStringArray(actual if actual is Array else []))
			le.placeholder_text = tr("separados por comas")
			le.text_changed.connect(func(_t): _al_cambiar())
			_fila(etiqueta, le)
			_campos.append(func(d: Dictionary):
				var out: Array = []
				for x in le.text.split(","):
					if x.strip_edges() != "":
						out.append(x.strip_edges())
				_poner(d, ruta, out, out.is_empty()))
		"wiki":
			var fila := HBoxContainer.new()
			var base: Dictionary = actual.duplicate() if actual is Dictionary else {}
			var entradas := {}
			for lengua in ["es", "en"]:
				var l := Label.new()
				l.text = lengua
				l.theme_type_variation = "Suave"
				fila.add_child(l)
				var le := LineEdit.new()
				le.text = str(base.get(lengua, ""))
				le.placeholder_text = tr("título exacto")
				le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				le.text_changed.connect(func(_t): _al_cambiar())
				fila.add_child(le)
				entradas[lengua] = le
			_fila(etiqueta, fila)
			_campos.append(func(d: Dictionary):
				var w := base.duplicate()
				for lengua in entradas:
					var s: String = (entradas[lengua] as LineEdit).text.strip_edges()
					if s == "":
						w.erase(lengua)
					else:
						w[lengua] = s
				_poner(d, ruta, w, w.is_empty()))
		"punto":
			_campo_punto(ruta, etiqueta)
		"filas":
			_campo_filas(ruta, etiqueta, extra)
		"poligono":
			_campo_poligono(ruta, etiqueta)


func _fila(etiqueta: String, control: Control) -> void:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = etiqueta
	l.theme_type_variation = "Suave"
	l.custom_minimum_size = Vector2(150, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(control)
	_form.add_child(f)


## Un año: se escribe «-1274», «1274 a. C.» o «c. 1274 a. C.»; al lado se ve cómo queda.
func _entrada_anio(actual: Variant, ayuda_texto: String, fila: HBoxContainer) -> LineEdit:
	var le := LineEdit.new()
	le.text = "" if actual == null else (str(int(actual)) if actual is float or actual is int else str(actual))
	le.placeholder_text = ayuda_texto if ayuda_texto != "" else tr("-1274 o 1274 a. C.")
	le.custom_minimum_size = Vector2(96, 0)
	fila.add_child(le)
	var ayuda := Label.new()
	ayuda.theme_type_variation = "Suave"
	fila.add_child(ayuda)
	var mostrar := func():
		var n: Variant = _leer_anio(le.text)
		ayuda.text = "" if n == null else (Fechas.texto(n) if n is int and n != 0 else tr("¿año?"))
	mostrar.call()
	le.text_changed.connect(func(_t):
		mostrar.call()
		_al_cambiar())
	return le


func _campo_punto(ruta: String, etiqueta: String) -> void:
	var base := ruta + "." if ruta != "" else ""
	var fila := HBoxContainer.new()
	var entradas: Array = []
	for clave in ["lon", "lat"]:
		var le := LineEdit.new()
		var v: Variant = _valor(_copia, base + clave)
		le.text = "" if v == null else str(v)
		le.placeholder_text = clave
		le.custom_minimum_size = Vector2(80, 0)
		le.text_changed.connect(func(_t): _al_cambiar())
		fila.add_child(le)
		entradas.append(le)
	var lon: LineEdit = entradas[0]
	var lat: LineEdit = entradas[1]
	var elegir := Button.new()
	elegir.text = tr("Elegir en el mapa")
	elegir.tooltip_text = tr("El próximo clic en el mapa pone estas coordenadas")
	elegir.pressed.connect(func():
		elegir.text = tr("Esperando el clic…")
		_mensaje(tr("Hacé clic en el mapa para ubicar «%s» (Esc cancela).") % etiqueta)
		Estado.captura_punto = func(ll: Vector2):
			if not is_instance_valid(lon):
				return
			lon.text = str(snappedf(ll.x, 0.001))
			lat.text = str(snappedf(ll.y, 0.001))
			elegir.text = tr("Elegir en el mapa")
			_mensaje(tr("Coordenadas puestas: %s.") % Proyeccion.texto_coordenadas(ll))
			_al_cambiar())
	fila.add_child(elegir)
	var ver := Button.new()
	ver.text = tr("Ver")
	ver.tooltip_text = tr("Llevar el mapa a estas coordenadas")
	ver.pressed.connect(func():
		if lon.text.is_valid_float() and lat.text.is_valid_float():
			Estado.enfocar(Proyeccion.a_px(lon.text.to_float(), lat.text.to_float()), 2.5)
			_mensaje(tr("El mapa está en %s, %s.") % [lat.text, lon.text])
		else:
			_mensaje(tr("Todavía no hay coordenadas para «%s».") % etiqueta))
	fila.add_child(ver)
	_fila(etiqueta, fila)
	_campos.append(func(d: Dictionary):
		var vacio := lon.text.strip_edges() == "" and lat.text.strip_edges() == ""
		for par in [["lon", lon], ["lat", lat]]:
			var s: String = (par[1] as LineEdit).text.strip_edges().replace(",", ".")
			var v: Variant = s.to_float() if s.is_valid_float() else (null if s == "" else s)
			_poner(d, base + par[0], v, vacio))


func _campo_filas(ruta: String, etiqueta: String, sub: Array) -> void:
	var l := Label.new()
	l.theme_type_variation = "Seccion"
	l.text = etiqueta.to_upper()
	_form.add_child(l)
	var actual: Variant = _valor(_copia, ruta)
	var lista: Array = actual if actual is Array else []
	var lectores: Array = []
	for idx in lista.size():
		var fila_d: Dictionary = (lista[idx] as Dictionary).duplicate(true) if lista[idx] is Dictionary else {}
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 2)
		var linea := HBoxContainer.new()
		caja.add_child(linea)
		var aplicadores: Array = []
		for s in sub:
			var clave: String = s[0]
			var tipo_s: String = s[2]
			var v: Variant = fila_d.get(clave)
			match tipo_s:
				"anio":
					var le := _entrada_anio(v, s[1], linea)
					aplicadores.append(func(fd: Dictionary):
						var n: Variant = _leer_anio(le.text)
						_poner(fd, clave, n, n == null))
				"bool":
					var cb := CheckBox.new()
					cb.text = s[1]
					cb.button_pressed = v == true
					cb.toggled.connect(func(_b): _al_cambiar())
					linea.add_child(cb)
					aplicadores.append(func(fd: Dictionary): _poner(fd, clave, cb.button_pressed, not cb.button_pressed))
				_:
					var le := LineEdit.new()
					le.text = "" if v == null else str(v)
					le.placeholder_text = s[1]
					le.text_changed.connect(func(_t): _al_cambiar())
					if tipo_s == "corto":
						le.custom_minimum_size = Vector2(50, 0)
					else:
						le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					(caja if tipo_s == "linea" else linea).add_child(le)
					aplicadores.append(func(fd: Dictionary):
						var t := le.text.strip_edges()
						_poner(fd, clave, null if t == "" else t, t == ""))
		var quitar := IconosUI.boton("cerrar", tr("Quitar esta fila"), 14)
		var i_fila: int = idx
		quitar.pressed.connect(func():
			_aplicar()
			(_valor(_copia, ruta) as Array).remove_at(i_fila)
			_construir_formulario()
			_al_cambiar())
		linea.add_child(quitar)
		lectores.append(func() -> Dictionary:
			for ap in aplicadores:
				ap.call(fila_d)
			return fila_d)
		_form.add_child(caja)
	var agregar := Button.new()
	agregar.text = tr("Agregar")
	agregar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	agregar.pressed.connect(func():
		_aplicar()
		if not _valor(_copia, ruta) is Array:
			_copia[ruta] = []
		var fila_nueva := {}
		for s in sub:
			fila_nueva[s[0]] = false if s[2] == "bool" else null
		(_valor(_copia, ruta) as Array).append(fila_nueva)
		_construir_formulario()
		_al_cambiar())
	_form.add_child(agregar)
	_campos.append(func(d: Dictionary):
		var out: Array = []
		for lector in lectores:
			out.append(lector.call())
		_poner(d, ruta, out, out.is_empty()))


## El nombre de una sección en singular («Fuente», «Región»), traducido.
func _nombre_seccion(seccion: String) -> String:
	return tr(PanelInfo.NOMBRES_TIPO.get(Edicion.TIPO_DE_SECCION.get(seccion, ""), seccion))


## Cómo se muestra una opción de un campo cerrado (el valor que se guarda no cambia): «cronica» → «crónica».
func _nombre_opcion(v: Variant) -> String:
	var s := str(v)
	for nombres: Dictionary in [PanelInfo.NOMBRES_GENERO, PanelInfo.NOMBRES_TIPO_HECHO, PanelInfo.NOMBRES_TIPO_LUGAR,
			PanelInfo.NOMBRES_CONFIANZA, {"primaria": "Primaria", "secundaria": "Secundaria"}]:
		if nombres.has(s):
			return tr(nombres[s])
	return s


func _campo_poligono(ruta: String, etiqueta: String) -> void:
	var poli: Variant = _valor(_copia, ruta)
	var n: int = (poli as Array).size() if poli is Array else 0
	var fila := HBoxContainer.new()
	var info := Label.new()
	info.text = tr("%d vértices") % n if n >= 3 else tr("Sin área")
	fila.add_child(info)
	var calcular := Button.new()
	calcular.text = tr("Calcular con Cliopatria")
	calcular.tooltip_text = tr("Envolvente de todo el territorio que tuvo la entidad del borrador o, si no hay, la del lugar elegido en el mapa")
	calcular.pressed.connect(func():
		var ent := _entidad_para_area()
		if ent < 0:
			_mensaje(tr("Elegí en el mapa un lugar de la entidad y volvé a apretar."), true)
			return
		var nuevo := Edicion.poligono_de_entidad(ent)
		if nuevo.size() < 3:
			_mensaje(tr("%s no tiene territorio suficiente para armar un área.") % DatosMapa.nombre_entidad(ent), true)
			return
		_aplicar()
		_copia[ruta] = nuevo
		_construir_formulario()
		_al_cambiar()
		_mensaje(tr("Área calculada con el territorio de %s: %d vértices.") % [DatosMapa.nombre_entidad(ent), nuevo.size()]))
	fila.add_child(calcular)
	var ver := Button.new()
	ver.text = tr("Ver")
	ver.pressed.connect(func():
		if n < 3:
			_mensaje(tr("Todavía no hay área de estudio."))
			return
		var caja := Rect2(Proyeccion.a_px(float(poli[0][0]), float(poli[0][1])), Vector2.ZERO)
		for p in poli:
			caja = caja.expand(Proyeccion.a_px(float(p[0]), float(p[1])))
		Estado.enfocar(caja.get_center(), 0.0)
		_mensaje(tr("El mapa está en el centro del área de estudio.")))
	fila.add_child(ver)
	_fila(etiqueta, fila)


func _entidad_para_area() -> int:
	if _ruta.begins_with(Edicion.dir_borradores):
		var origen: Dictionary = Edicion.leer(_ruta).get("borrador", {}).get("origen", {})
		var i := Edicion.entidad(str(origen.get("entidad", "")), str(origen.get("wikidata", "")))
		if i >= 0:
			return i
	return DatosMapa.dueno(Estado.unidad_seleccionada) if Estado.unidad_seleccionada > 0 else -1


static func _valor(d: Dictionary, ruta: String) -> Variant:
	var actual: Variant = d
	for p in ruta.split(".", false):
		if not actual is Dictionary:
			return null
		actual = (actual as Dictionary).get(p)
	return actual


## Escribe un campo. Si el valor está vacío solo pisa lo que había si tenía algo (así un formulario sin tocar deja el
## elemento idéntico) y nunca crea claves u objetos nuevos.
static func _poner(d: Dictionary, ruta: String, valor: Variant, vacio: bool) -> void:
	var partes := ruta.split(".")
	var actual: Dictionary = d
	for i in partes.size() - 1:
		var k: String = partes[i]
		if not actual.get(k) is Dictionary:
			if vacio:
				return
			actual[k] = {}
		actual = actual[k]
	var hoja: String = partes[partes.size() - 1]
	if vacio:
		if actual.has(hoja) and not _vacio(actual[hoja]):
			actual[hoja] = valor
		return
	actual[hoja] = valor


static func _texto_valor(v: Variant) -> String:
	return str(int(v)) if v is float and v == floorf(v) else str(v)


static func _vacio(v: Variant) -> bool:
	return v == null or (v is String and v == "") or (v is Array and v.is_empty()) or \
		(v is Dictionary and v.is_empty()) or (v is bool and not v)


## null si está vacío, el año (int) si se entiende, o el texto tal cual (la validación lo marca).
static func _leer_anio(texto: String) -> Variant:
	var s := texto.strip_edges().to_lower().replace(" ", "").replace(".", "")
	if s == "":
		return null
	var negativo := false
	# «1274 a. C.», «1274 aC» o «1274 BC»; «476 d. C.» o «476 AD».
	for sufijo in ["ac", "bce", "bc"]:
		if s.ends_with(sufijo):
			negativo = true
			s = s.trim_suffix(sufijo)
			break
	for marca in ["dc", "ce", "ad"]:
		if s.ends_with(marca):
			s = s.trim_suffix(marca)
		elif s.begins_with(marca) and s.substr(marca.length()).is_valid_int():
			s = s.substr(marca.length())
	if s.begins_with("c") and s.substr(1).is_valid_int():
		s = s.substr(1)
	if not s.is_valid_int():
		return texto.strip_edges()
	var n := s.to_int()
	return -absi(n) if negativo else n


func _aplicar() -> void:
	for aplicar in _campos:
		aplicar.call(_copia)
	# Un objeto opcional (nacimiento, muerte, activo) que quedó con todos sus campos vacíos vuelve a como estaba:
	# null, o sin la clave.
	for k in OPCIONALES:
		var c: Variant = _copia.get(k)
		var o: Variant = _original.get(k)
		if c is Dictionary and _todo_vacio(c) and not (o is Dictionary and _todo_vacio(o)):
			if _original.has(k):
				_copia[k] = null
			else:
				_copia.erase(k)


static func _todo_vacio(d: Dictionary) -> bool:
	return d.values().all(func(v): return _vacio(v))


func _al_cambiar() -> void:
	_confirmar_cierre = false
	_aplicar()
	_actualizar_botones()


func _actualizar_botones() -> void:
	var sucio := esta_sucio()
	_boton_guardar.disabled = not (sucio or _id_original == "")
	_boton_descartar.disabled = not sucio


func _al_descartar() -> void:
	if _id_original == "":
		_vaciar()
		_mensaje(tr("Descartado."))
		return
	_copia = _original.duplicate(true)
	_construir_formulario()
	_mensaje(tr("Cambios descartados."))


func _validar(mostrar_ok: bool) -> Dictionary:
	_aplicar()
	var extra := Edicion.ids_de(Edicion.leer(_ruta)) if _ruta.begins_with(Edicion.dir_borradores) else {}
	var r := Edicion.validar(_seccion_form, _copia, _id_original, extra)
	var partes: Array = []
	if not r["errores"].is_empty():
		partes.append(tr("[color=#%s][b]Hay que corregir:[/b][/color]\n• %s") % [TemaUI.color("hecho").to_html(false), "\n• ".join(r["errores"])])
	if not r["avisos"].is_empty():
		partes.append(tr("[b]Avisos:[/b]\n• %s") % "\n• ".join(r["avisos"]))
	if partes.is_empty() and mostrar_ok:
		partes.append(tr("Sin errores."))
	if not partes.is_empty():
		_mensaje_l.text = "\n".join(partes)
	return r


func _al_guardar() -> void:
	var r := _validar(false)
	if not r["errores"].is_empty():
		return
	var ruta := _ruta
	if _id_original == "":
		ruta = str(_paquete.get_item_metadata(_paquete.selected)) if _paquete.selected >= 0 else ""
		if ruta == "":
			_mensaje(tr("Elegí en qué paquete guardarlo."), true)
			return
	var err := Edicion.guardar(ruta, _seccion_form, _copia.duplicate(true), _id_original)
	if err != "":
		_mensaje(err, true)
		return
	var id := str(_copia["id"])
	var era_nuevo := _id_original == ""
	_ruta = ruta
	_id_original = id
	_original = _copia.duplicate(true)
	if not ruta.begins_with(Edicion.dir_borradores):
		Enciclopedia.recargar()
		if era_nuevo:
			_llenar_lista()
	_construir_formulario()
	_mensaje(tr("Guardado en %s%s.") % [ruta.get_file(), "" if r["avisos"].is_empty() else
		tr_n(", con %d aviso: %s", ", con %d avisos: %s", r["avisos"].size()) % [r["avisos"].size(), " ".join(r["avisos"])]])


func _mensaje(texto: String, error := false) -> void:
	_mensaje_l.text = "[color=#%s]%s[/color]" % [TemaUI.color("hecho").to_html(false), texto] if error else texto


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE and Estado.captura_punto.is_valid():
		Estado.captura_punto = Callable()
		_construir_formulario()
		_mensaje(tr("Elección en el mapa cancelada."))
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------------------------------------------
# Borradores


func _mostrar_borrador(ruta: String) -> void:
	_vaciar()
	_borrador = ruta
	_ruta = ruta
	var d := Edicion.leer(ruta)
	var meta: Dictionary = d.get("borrador", {})
	var origen: Dictionary = meta.get("origen", {})
	var t := Label.new()
	t.theme_type_variation = "Titulo"
	t.text = str(meta.get("titulo", ruta.get_file()))
	_form.add_child(t)
	var lineas: Array = [tr("Generado el %s con %s, a partir de Wikipedia y Wikidata. Estado: [b]%s[/b].") % [
		meta.get("generado", "?"), meta.get("por", "tools/enciclopedia/borradores.py"), meta.get("estado", "sin revisar")]]
	if origen.has("entidad"):
		lineas.append(tr("Entidad de Cliopatria: %s%s; consultada %s veces%s.") % [origen["entidad"],
			" (%s)" % origen["wikidata"] if origen.get("wikidata") else "", origen.get("veces", "?"),
			tr(", hacia %s") % ", ".join(PackedStringArray((origen.get("anios", []) as Array).slice(0, 4).map(func(a): return Fechas.texto(int(a))))) \
				if not (origen.get("anios", []) as Array).is_empty() else ""])
	var ia: Variant = meta.get("ia")
	if ia is Dictionary:
		lineas.append(tr("[b]La ficha extendida la redactó una IA[/b] (%s, %s) a partir de las fuentes del borrador: revisá cada afirmación contra la fuente que cita.") % [
			ia.get("modelo", "?"), ia.get("fecha", "?")])
	lineas.append(tr("Los textos que vienen de Wikipedia se publican con su licencia, CC BY-SA 4.0."))
	_parrafo("\n".join(lineas))

	var acciones := HBoxContainer.new()
	_form.add_child(acciones)
	var ver := Button.new()
	ver.text = tr("Ver en el mapa")
	ver.pressed.connect(func():
		if origen.get("lon") == null:
			_mensaje(tr("El borrador no dice dónde se consultó."))
			return
		var anios: Array = origen.get("anios", [])
		if not anios.is_empty():
			Estado.fijar_anio(int(anios[0]))
		Estado.enfocar(Proyeccion.a_px(float(origen["lon"]), float(origen["lat"])), 1.5)
		_mensaje(tr("El mapa está donde se consultó.")))
	acciones.add_child(ver)
	for r in d.get("regiones", []):
		if (r.get("poligono", []) as Array).size() < 3:
			var calc := Button.new()
			calc.text = tr("Calcular el área de «%s»") % r.get("nombre", r.get("id"))
			var rid := str(r.get("id"))
			calc.pressed.connect(func(): _calcular_area_borrador(ruta, rid))
			acciones.add_child(calc)

	_seccion_texto(tr("Contenido"))
	for s in Edicion.TIPO_DE_SECCION:
		for item in d.get(s, []):
			var b := Button.new()
			b.theme_type_variation = "FilaCompacta"
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%s: %s" % [_nombre_seccion(s), item.get("titulo", item.get("nombre", item.get("id")))]
			b.tooltip_text = tr("Revisar y editar")
			var sec: String = s
			var iid := str(item.get("id"))
			b.pressed.connect(func(): _abrir(ruta, sec, iid, true))
			_form.add_child(b)

	for r in d.get("regiones", []):
		var ext: Variant = r.get("extendida")
		if not ext is Dictionary:
			continue
		_seccion_texto(tr("Ficha extendida de %s") % r.get("nombre", ""))
		for s in ext.get("secciones", []):
			_parrafo("[b]%s[/b]\n%s" % [s.get("titulo", ""), s.get("texto", "")])
		var refs: Array = []
		for ref in ext.get("referencias", []):
			refs.append("[%s] [url=%s]%s[/url]" % [ref.get("n"), ref.get("url"), ref.get("titulo", ref.get("url"))])
		if not refs.is_empty():
			_parrafo(tr("[b]Referencias[/b]\n") + "\n".join(refs))

	if ia is Dictionary:
		var notas: Array = []
		for x in ia.get("avisos", []):
			notas.append("• " + str(x))
		if not notas.is_empty():
			_parrafo(tr("[b]Para revisar (lo marcó la verificación automática):[/b]\n") + "\n".join(notas))
		var props: Array = []
		for f in ia.get("fuentes_propuestas", []):
			var t_f := "%s, [i]%s[/i] (%s, %s): %s" % [f.get("autor", ""), f.get("titulo", ""), f.get("tipo", ""), f.get("fecha", ""), f.get("por_que", "")]
			props.append("• " + ("[url=%s]%s[/url]" % [f["url"], t_f] if str(f.get("url", "")) != "" else t_f))
		if not props.is_empty():
			_parrafo(tr("[b]Fuentes que propone para leer[/b] (se cargan a mano con «Nuevo» en Fuentes):\n") + "\n".join(props))
		if not (ia.get("descartado", []) as Array).is_empty():
			_parrafo(tr("[b]Lo que no pudo respaldar y quedó afuera:[/b]\n• ") + "\n• ".join(ia["descartado"]))

	var val := Edicion.validar_borrador(d)
	_seccion_texto(tr("Revisión"))
	if not val["errores"].is_empty():
		_parrafo(tr("[color=#%s][b]Antes de aprobar hay que corregir:[/b][/color]\n• %s") % [TemaUI.color("hecho").to_html(false), "\n• ".join(val["errores"])])
	if not val["avisos"].is_empty():
		_parrafo(tr("[b]Avisos:[/b]\n• ") + "\n• ".join(val["avisos"]))
	var revise := CheckBox.new()
	revise.text = tr("Revisé cada dato y cada sección contra sus fuentes")
	_form.add_child(revise)
	var nota := LineEdit.new()
	nota.placeholder_text = tr("Nota de la revisión (quién, qué se corrigió)")
	_form.add_child(nota)
	var fila := HBoxContainer.new()
	_form.add_child(fila)
	var destino := OptionButton.new()
	for p in Edicion.paquetes():
		if p.get_file() != "familias.json":
			destino.add_item(tr("Pasar a %s") % p.get_file())
			destino.set_item_metadata(destino.item_count - 1, p)
			if p.get_file() == "mundo.json":
				destino.select(destino.item_count - 1)
	fila.add_child(destino)
	var aprobar := Button.new()
	aprobar.text = tr("Aprobar")
	aprobar.disabled = true
	revise.toggled.connect(func(b: bool): aprobar.disabled = not b or not val["errores"].is_empty())
	aprobar.pressed.connect(func():
		var err := Edicion.aprobar_borrador(ruta, str(destino.get_item_metadata(destino.selected)), nota.text.strip_edges())
		if err != "":
			_mensaje(err, true)
			return
		Enciclopedia.recargar()
		_vaciar()
		_llenar_lista()
		_mensaje(tr("Borrador aprobado: sus elementos pasaron a %s.") % str(destino.get_item_metadata(destino.selected)).get_file()))
	fila.add_child(aprobar)
	var descartar := Button.new()
	descartar.text = tr("Descartar el borrador")
	descartar.pressed.connect(func():
		if descartar.text != tr("¿Seguro? Apretá otra vez"):
			descartar.text = tr("¿Seguro? Apretá otra vez")
			return
		var err := Edicion.borrar(ruta)
		if err != "":
			_mensaje(err, true)
			return
		_vaciar()
		_llenar_lista()
		_mensaje(tr("Borrador descartado.")))
	fila.add_child(descartar)
	_mensaje(tr("Revisá cada elemento (se abren con un clic) y la ficha extendida antes de aprobar."))


func _calcular_area_borrador(ruta: String, id_region: String) -> void:
	_ruta = ruta
	var ent := _entidad_para_area()
	if ent < 0:
		_mensaje(tr("No encontré la entidad del borrador: elegí un lugar suyo en el mapa y volvé a apretar."), true)
		return
	var d := Edicion.leer(ruta)
	var i := Edicion.indice(d.get("regiones", []), id_region)
	var region: Dictionary = d["regiones"][i]
	region["poligono"] = Edicion.poligono_de_entidad(ent)
	var err := Edicion.guardar(ruta, "regiones", region, id_region)
	if err != "":
		_mensaje(err, true)
		return
	_mostrar_borrador(ruta)
	_mensaje(tr("Área calculada con el territorio de %s: %d vértices.") % [DatosMapa.nombre_entidad(ent), (region["poligono"] as Array).size()])


func _seccion_texto(texto: String) -> void:
	var l := Label.new()
	l.theme_type_variation = "Seccion"
	l.text = texto.to_upper()
	_form.add_child(l)


func _parrafo(bbcode: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = true
	r.custom_minimum_size = Vector2(ANCHO - 50, 0)
	r.text = bbcode
	r.meta_clicked.connect(func(m): Estado.abrir_url(str(m)))
	_form.add_child(r)
