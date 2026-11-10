class_name DialogoAjustes
extends Control
## Ajustes: vista 2D/3D, calidad gráfica, motor de dibujo, idioma, tema de la interfaz, escala, idioma de Wikipedia y
## créditos de datos. Los textos de las constantes están en español y se traducen al mostrarlos (tr()).

signal tema_cambiado

const NOMBRES_CALIDAD := {"baja": "Baja", "media": "Media", "alta": "Alta", "ultra": "Ultra"}
const DESCRIPCION_CALIDAD := {
	"baja": "Para equipos modestos: texturas a la mitad, sin relieve ni efectos.",
	"media": "Relieve, olas de costa y papel; bordes simples.",
	"alta": "Lo anterior más el brillo interior de las fronteras (recomendada).",
	"ultra": "Bordes más suaves y agua animada (redibuja siempre).",
}
const CREDITOS := """[b]Datos[/b]
• Fronteras políticas: [url=https://github.com/Seshat-Global-History-Databank/cliopatria]Cliopatria[/url], Seshat Global History Databank, CC BY 4.0.
• Costas, lagos, ríos y países actuales: [url=https://www.naturalearthdata.com]Natural Earth[/url], dominio público.
• Población por país: [url=https://ourworldindata.org/population-sources]Our World in Data[/url] (HYDE 3.3, Gapminder y ONU, World Population Prospects 2024), CC BY 4.0.
• Relieve: GEBCO 2008 en la versión de la NASA; color del terreno: NASA Blue Marble Next Generation (julio de 2004), dominio público.
• Textos de la enciclopedia: Wikipedia (CC BY-SA 4.0) y los paquetes propios en data/enciclopedia.
[b]Tipografías[/b]
• Cinzel y EB Garamond, SIL Open Font License."""

var _panel: PanelContainer
var _calidad_desc: Label
## El contenido va en un scroll: con la sección de la enciclopedia ya no entra entero en una ventana baja.
var _desliza: ScrollContainer
var _contenido: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.45)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			cerrar())
	add_child(fondo)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(620, 0)
	add_child(_panel)
	# Si crece (la lista de consultas), se vuelve a centrar para no salirse de la ventana.
	_panel.resized.connect(func(): _panel.position = ((size - _panel.size) * 0.5).max(Vector2.ZERO))
	_construir()


func _construir() -> void:
	for c in _panel.get_children():
		c.queue_free()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_panel.add_child(caja)

	var cab := HBoxContainer.new()
	caja.add_child(cab)
	var titulo := Label.new()
	titulo.text = tr("Ajustes")
	titulo.theme_type_variation = "TituloGrande"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	var cerrar_b := IconosUI.boton("cerrar", tr("Cerrar"), 18)
	cerrar_b.pressed.connect(cerrar)
	cab.add_child(cerrar_b)
	_desliza = ScrollContainer.new()
	_desliza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_desliza.follow_focus = true
	caja.add_child(_desliza)
	caja = VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 10)
	_desliza.add_child(caja)
	_contenido = caja

	# Vista
	caja.add_child(_seccion(tr("Vista")))
	var vista := HBoxContainer.new()
	caja.add_child(vista)
	var grupo_vista := ButtonGroup.new()
	for v in [["2d", tr("Mapa 2D"), true], ["3d", tr("Relieve 3D (en preparación)"), false]]:
		var b := Button.new()
		b.text = v[1]
		b.toggle_mode = true
		b.button_group = grupo_vista
		b.disabled = not v[2]
		b.button_pressed = Estado.ajustes["vista"] == v[0]
		b.focus_mode = Control.FOCUS_ALL
		if not v[2]:
			b.tooltip_text = tr("La vista 3D con relieve, agua y efectos está planificada en docs/es/plan.md.")
		vista.add_child(b)

	# Calidad
	caja.add_child(_seccion(tr("Calidad gráfica")))
	var calidades := HBoxContainer.new()
	caja.add_child(calidades)
	var grupo_cal := ButtonGroup.new()
	for id in ["baja", "media", "alta", "ultra"]:
		var b := Button.new()
		b.text = tr(NOMBRES_CALIDAD[id])
		b.toggle_mode = true
		b.button_group = grupo_cal
		b.button_pressed = Estado.ajustes["calidad"] == id
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(110, 0)
		var cal: String = id
		b.pressed.connect(func():
			var antes: float = Estado.calidad()["resolucion"]
			Estado.fijar_ajuste("calidad", cal)
			_calidad_desc.text = tr(DESCRIPCION_CALIDAD[cal])
			if Estado.calidad()["resolucion"] != antes:
				_calidad_desc.text += " " + tr("La resolución de las texturas cambia al reiniciar."))
		calidades.add_child(b)
	_calidad_desc = Label.new()
	_calidad_desc.theme_type_variation = "Suave"
	_calidad_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_calidad_desc.text = tr(DESCRIPCION_CALIDAD.get(Estado.ajustes["calidad"], ""))
	caja.add_child(_calidad_desc)

	_construir_motor(caja)

	# Interfaz
	caja.add_child(_seccion(tr("Interfaz")))
	# El idioma, en su propia fila: cada opción con su nombre en ese idioma, para encontrarla aunque no se lea el otro.
	var fila_idioma := HBoxContainer.new()
	fila_idioma.add_theme_constant_override("separation", 12)
	caja.add_child(fila_idioma)
	var idiomas := OptionButton.new()
	var codigos: Array = Idioma.NOMBRES.keys()
	for i in codigos.size():
		idiomas.add_item(Idioma.NOMBRES[codigos[i]])
		if codigos[i] == Idioma.actual:
			idiomas.select(i)
	idiomas.item_selected.connect(func(i: int): Idioma.cambiar(codigos[i]))
	fila_idioma.add_child(_etiqueta(tr("Idioma")))
	fila_idioma.add_child(idiomas)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	caja.add_child(fila)
	var temas := OptionButton.new()
	var ids := TemaUI.TEMAS.keys()
	for i in ids.size():
		temas.add_item(tr(TemaUI.TEMAS[ids[i]]["nombre"]))
		if ids[i] == Estado.ajustes["tema"]:
			temas.select(i)
	temas.item_selected.connect(func(i: int):
		Estado.fijar_ajuste("tema", ids[i])
		tema_cambiado.emit())
	fila.add_child(_etiqueta(tr("Tema")))
	fila.add_child(temas)
	var escalas := OptionButton.new()
	var valores := [0.9, 1.0, 1.15, 1.3, 1.5]
	for i in valores.size():
		escalas.add_item("%d %%" % int(valores[i] * 100))
		if is_equal_approx(valores[i], float(Estado.ajustes["escala_ui"])):
			escalas.select(i)
	escalas.item_selected.connect(func(i: int):
		Estado.fijar_ajuste("escala_ui", valores[i]))
	fila.add_child(_etiqueta(tr("Tamaño")))
	fila.add_child(escalas)
	var wiki := OptionButton.new()
	wiki.add_item(tr("Español primero"))
	wiki.add_item(tr("Inglés primero"))
	wiki.select(0 if Estado.idioma_wiki() == "es" else 1)
	wiki.item_selected.connect(func(i: int): Estado.fijar_ajuste("idioma_wiki", "es" if i == 0 else "en"))
	fila.add_child(_etiqueta("Wikipedia"))
	fila.add_child(wiki)

	# Cola de consultas sin ficha (llenado progresivo de la enciclopedia)
	caja.add_child(_seccion(tr("Enciclopedia")))
	var pend := Enciclopedia.pendientes()
	var nota := _etiqueta(tr("Todavía no hay consultas anotadas.") if pend.is_empty() else
		tr_n("%d lugar consultado sin ficha en la enciclopedia: es lo primero que conviene completar. Se anota solo en esta computadora.",
			"%d lugares consultados sin ficha en la enciclopedia: es lo primero que conviene completar. Se anota solo en esta computadora.",
			pend.size()) % pend.size())
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Con ancho fijo: sin él, Godot calcula la altura de un texto con ajuste de línea como si entrara una letra por
	# renglón, y el panel crece de más.
	nota.custom_minimum_size = Vector2(580, 0)
	caja.add_child(nota)
	var fila_p := HBoxContainer.new()
	fila_p.add_theme_constant_override("separation", 8)
	caja.add_child(fila_p)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 0)
	lista.visible = false
	var ver := Button.new()
	ver.text = tr("Ver los más consultados")
	ver.disabled = pend.is_empty()
	ver.pressed.connect(func():
		lista.visible = not lista.visible
		ver.text = tr("Ocultar la lista") if lista.visible else tr("Ver los más consultados")
		_ajustar_alto.call_deferred())
	fila_p.add_child(ver)
	var copiar := Button.new()
	copiar.text = tr("Copiar la cola")
	copiar.tooltip_text = tr("Copia la cola en JSON al portapapeles, para pegarla en un issue o dársela a tools/enciclopedia")
	copiar.disabled = pend.is_empty()
	copiar.pressed.connect(func():
		DisplayServer.clipboard_set(FileAccess.get_file_as_string(Enciclopedia.RUTA_PENDIENTES))
		copiar.text = tr("Copiada"))
	fila_p.add_child(copiar)
	var carpeta := Button.new()
	carpeta.text = tr("Abrir la carpeta")
	carpeta.tooltip_text = ProjectSettings.globalize_path(Enciclopedia.RUTA_PENDIENTES)
	carpeta.disabled = pend.is_empty()
	carpeta.pressed.connect(func(): Estado.abrir_url(ProjectSettings.globalize_path("user://")))
	fila_p.add_child(carpeta)
	var editar := Button.new()
	var n_borr := Edicion.borradores().size()
	editar.text = tr("Abrir el editor de la enciclopedia") + ("  (%s)" % (tr_n("%d borrador sin revisar", "%d borradores sin revisar", n_borr) % n_borr)
		if n_borr > 0 else "")
	editar.tooltip_text = tr("Cargar y corregir fuentes, personas, hechos, lugares y regiones, y revisar borradores")
	editar.icon = IconosUI.textura("editar", 16, TemaUI.color("acento"))
	editar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	editar.pressed.connect(func(): Estado.editor_pedido.emit("", ""))
	caja.add_child(editar)
	caja.add_child(lista)
	for item in pend.slice(0, 8):
		var b := Button.new()
		b.theme_type_variation = "FilaCompacta"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var anios: Array = item.get("anios", [])
		var veces := int(item.get("veces", 0))
		b.text = "%s   ·   %s%s" % [item["nombre"], tr_n("%d vez", "%d veces", veces) % veces,
			tr(", hacia %s") % Fechas.texto(int(anios[0])) if not anios.is_empty() else ""]
		b.tooltip_text = tr("Ir a ese lugar y año")
		var destino: Dictionary = item
		b.pressed.connect(func():
			cerrar()
			if not (destino.get("anios", []) as Array).is_empty():
				Estado.fijar_anio(int(destino["anios"][0]))
			var px := Proyeccion.a_px(float(destino.get("lon", 0.0)), float(destino.get("lat", 0.0)))
			Estado.enfocar(px, 2.0)
			Estado.seleccionar_lugar(DatosMapa.unidad_en(px), px))
		lista.add_child(b)

	_construir_actualizaciones(caja)

	# Créditos
	caja.add_child(_seccion(tr("Datos y créditos")))
	var cred := RichTextLabel.new()
	cred.bbcode_enabled = true
	cred.fit_content = true
	cred.scroll_active = false
	cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cred.text = tr(CREDITOS)
	cred.add_theme_font_size_override("normal_font_size", 15)
	cred.add_theme_font_size_override("bold_font_size", 15)
	cred.meta_clicked.connect(func(m): Estado.abrir_url(str(m)))
	caja.add_child(cred)
	var version := Label.new()
	version.theme_type_variation = "Suave"
	version.text = "TellMAP %s · Bautista D. Fiori" % ProjectSettings.get_setting("application/config/version", "")
	caja.add_child(version)
	_panel.add_child(Marco.new())


## Motor de dibujo (MotorGrafico): cuál usar desde el próximo arranque y cuál está en uso, con la placa de video.
func _construir_motor(caja: VBoxContainer) -> void:
	caja.add_child(_seccion(tr("Motor de dibujo")))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	caja.add_child(fila)
	var motores := OptionButton.new()
	var ids: Array = MotorGrafico.OPCIONES.keys()
	for i in ids.size():
		motores.add_item(tr(MotorGrafico.OPCIONES[ids[i]][0]))
		if ids[i] == MotorGrafico.elegido():
			motores.select(i)
	fila.add_child(motores)
	var reiniciar := Button.new()
	reiniciar.text = tr("Reiniciar ahora")
	reiniciar.tooltip_text = tr("Vuelve a abrir TellMAP con el motor elegido")
	reiniciar.pressed.connect(Actualizador.reiniciar)
	fila.add_child(reiniciar)
	var desc := _etiqueta("")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(580, 0)
	caja.add_child(desc)
	var en_uso := _etiqueta(tr("En uso: %s") % MotorGrafico.en_uso())
	en_uso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	en_uso.custom_minimum_size = Vector2(580, 0)
	en_uso.tooltip_text = tr("Si TellMAP se ve mal, este dato ayuda a encontrar el problema")
	en_uso.mouse_filter = Control.MOUSE_FILTER_PASS
	caja.add_child(en_uso)
	var mostrar := func(id: String) -> void:
		desc.text = tr(MotorGrafico.OPCIONES[id][1])
		var cambia := id != MotorGrafico.al_abrir()
		if cambia:
			desc.text += " " + tr("Se usa al reiniciar TellMAP, que después pregunta si se ve bien.")
		# Durante la prueba automática no se reinicia (el recorrido apretaría el botón).
		reiniciar.visible = cambia and not Estado.sin_escribir
	motores.item_selected.connect(func(i: int):
		MotorGrafico.elegir(ids[i])
		mostrar.call(ids[i]))
	mostrar.call(MotorGrafico.elegido())


## Actualizaciones automáticas (Actualizador): estado, la casilla para apagarlas y los botones.
func _construir_actualizaciones(caja: VBoxContainer) -> void:
	caja.add_child(_seccion(tr("Actualizaciones")))
	var estado := _etiqueta("")
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.custom_minimum_size = Vector2(580, 0)
	caja.add_child(estado)
	var solo := CheckBox.new()
	solo.text = tr("Buscar actualizaciones al abrir TellMAP")
	solo.tooltip_text = (tr("Consulta la página del proyecto en GitHub y, si hay algo nuevo, pregunta antes de bajarlo.")
		+ " " + tr("«Buscar ahora» instala sin preguntar. No manda nada tuyo."))
	solo.button_pressed = bool(Estado.ajustes.get("actualizar_solo", true))
	solo.toggled.connect(func(si: bool): Estado.fijar_ajuste("actualizar_solo", si))
	caja.add_child(solo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var buscar := Button.new()
	buscar.text = tr("Buscar ahora")
	buscar.pressed.connect(Actualizador.buscar)
	fila.add_child(buscar)
	var reiniciar := Button.new()
	reiniciar.text = tr("Reiniciar ahora")
	reiniciar.tooltip_text = tr("Vuelve a abrir TellMAP con lo que se instaló")
	reiniciar.pressed.connect(Actualizador.reiniciar)
	fila.add_child(reiniciar)
	var bajar := Button.new()
	bajar.text = tr("Ir a la descarga")
	bajar.pressed.connect(func(): Estado.abrir_url(Actualizador.pagina_nueva))
	fila.add_child(bajar)
	var refrescar := func() -> void:
		if not is_instance_valid(estado):
			return
		var t := Actualizador.texto
		if t == "":
			t = (tr("Versión %s") % Actualizador.version_app() + (tr(", datos del %s") % Datos.fecha(Datos.version)
				if Datos.version > 0 else "") + ".") if Actualizador.habilitado else \
				tr("Desde el código fuente, TellMAP se actualiza con git: esta copia no busca versiones nuevas.")
		estado.text = t
		# Durante la prueba automática no se sale a internet: el recorrido salta los botones deshabilitados.
		buscar.disabled = not Actualizador.habilitado or Actualizador.ocupado or Estado.sin_escribir
		reiniciar.visible = Actualizador.pide_reinicio and not Estado.sin_escribir
		bajar.visible = Actualizador.pagina_nueva != "" and Actualizador.app_lista == ""
	refrescar.call()
	Actualizador.estado_cambiado.connect(refrescar)
	estado.tree_exiting.connect(func(): Actualizador.estado_cambiado.disconnect(refrescar))


func _seccion(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.theme_type_variation = "Seccion"
	return l


func _etiqueta(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.theme_type_variation = "Suave"
	return l


func abrir() -> void:
	_construir()
	visible = true
	await get_tree().process_frame
	_ajustar_alto()


## El scroll toma la altura del contenido, hasta lo que entra en la ventana; el panel queda centrado.
func _ajustar_alto() -> void:
	if not is_instance_valid(_contenido):
		return
	_desliza.custom_minimum_size.y = minf(_contenido.get_combined_minimum_size().y, maxf(size.y - 120.0, 240.0))
	_panel.reset_size()
	_panel.position = ((size - _panel.size) * 0.5).max(Vector2.ZERO)


func cerrar() -> void:
	visible = false


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if visible and k and k.pressed and k.keycode == KEY_ESCAPE:
		cerrar()
		get_viewport().set_input_as_handled()
