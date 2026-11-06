extends Node
## Punto de entrada: muestra la pantalla de carga, carga datos y arma el mapa y la interfaz.
##
## Para sacar capturas sin intervención (README, pruebas visuales):
##   godot --path . -- --captura=ruta.png [--anio=-1350] [--lon=31 --lat=27.5 --zoom=1.6] [--seleccionar]
##   [--sel_lon=32.6 --sel_lat=25.7] [--pestana=2] [--ficha=fuente:id] [--ajustes] [--bienvenida] [--tema=marmol] [--modo=religion]
##   (más cómodo con tools/captura.sh, que además funciona sin monitor)
##
## Para comprobar que un ejecutable exportado trae todos sus datos: TellMAP --headless -- --verificar
## (carga el mapa y la enciclopedia, lo informa y sale con 0, o con 1 si falta algo).

var vista: VistaMapa
var interfaz: Interfaz
var _carga: CanvasLayer
var _carga_texto: Label
var _carga_barra: ProgressBar


func _ready() -> void:
	TemaUI.cargar_fuentes()
	_mostrar_carga()
	Estado.carga_progreso.connect(_al_progreso)
	var args := _argumentos()
	if args.has("anio"):
		Estado.anio = int(args["anio"])
	if args.has("tema"):
		Estado.ajustes["tema"] = args["tema"]
	if args.has("calidad"):
		Estado.ajustes["calidad"] = args["calidad"]
	if args.has("modo"):
		Estado.modo = args["modo"]
	await get_tree().process_frame
	var ok := await DatosMapa.cargar()
	if not ok:
		_carga_texto.text = "No se pudo cargar el mapa: " + DatosMapa.error
		push_error(DatosMapa.error)
		if args.has("verificar"):
			get_tree().quit(1)
		return
	_al_progreso("Abriendo la biblioteca…", 0.95)
	await get_tree().process_frame
	Enciclopedia.cargar()
	vista = VistaMapa.new()
	add_child(vista)
	interfaz = Interfaz.new(vista)
	add_child(interfaz)
	Estado.cargado = true
	Estado.carga_terminada.emit()
	var t := create_tween()
	t.tween_property(_carga.get_child(0), "modulate:a", 0.0, 0.5)
	t.finished.connect(_carga.queue_free)
	if args.has("verificar"):
		var bien := DatosMapa.n_unidades > 0 and DatosMapa.entidades.size() > 0 and not Enciclopedia.regiones.is_empty() \
			and not Enciclopedia.familias.is_empty()
		print("TellMAP %s: %d unidades, %d entidades, %d regiones, %d fuentes, %d familias" % [
			"bien" if bien else "FALTAN DATOS", DatosMapa.n_unidades, DatosMapa.entidades.size(),
			Enciclopedia.regiones.size(), Enciclopedia.fuentes.size(), Enciclopedia.familias.size()])
		get_tree().quit(0 if bien else 1)
	elif args.has("prueba"):
		_prueba_automatica()
	elif args.has("captura"):
		_captura_automatica(args)
	elif not Estado.ajustes.get("bienvenida_vista", false) and not args.has("puente"):
		interfaz.mostrar_bienvenida()


func _mostrar_carga() -> void:
	_carga = CanvasLayer.new()
	_carga.layer = 100
	add_child(_carga)
	var raiz := ColorRect.new()
	raiz.color = Color(0.074, 0.082, 0.094)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.theme = TemaUI.crear(Estado.ajustes.get("tema", "marmol"))
	_carga.add_child(raiz)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	caja.custom_minimum_size = Vector2(420, 0)
	centro.add_child(caja)
	var t := Label.new()
	t.text = "TELLMAP"
	t.theme_type_variation = "TituloGrande"
	t.add_theme_font_size_override("font_size", 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(t)
	var s := Label.new()
	s.text = "atlas de la historia y sus fuentes"
	s.theme_type_variation = "Suave"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(s)
	_carga_barra = ProgressBar.new()
	_carga_barra.custom_minimum_size = Vector2(0, 6)
	_carga_barra.max_value = 1.0
	_carga_barra.show_percentage = false
	caja.add_child(_carga_barra)
	_carga_texto = Label.new()
	_carga_texto.theme_type_variation = "Suave"
	_carga_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(_carga_texto)


func _al_progreso(texto: String, fraccion: float) -> void:
	if is_instance_valid(_carga_texto):
		_carga_texto.text = texto
		_carga_barra.value = fraccion


func _argumentos() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var partes := a.substr(2).split("=", true, 1)
			out[partes[0]] = partes[1] if partes.size() > 1 else "1"
	return out


## Modo sin intervención: lleva el mapa a un punto, espera a que todo se dibuje y guarda una captura.
func _captura_automatica(args: Dictionary) -> void:
	var p := Proyeccion.a_px(float(args.get("lon", 30.0)), float(args.get("lat", 35.0)))
	vista.volar_a(p, float(args.get("zoom", 0.8)))
	await get_tree().create_timer(1.4).timeout
	if args.has("seleccionar"):
		var ps := p
		if args.has("sel_lon"):
			ps = Proyeccion.a_px(float(args["sel_lon"]), float(args["sel_lat"]))
		var u := DatosMapa.unidad_en(ps)
		if u > 0:
			Estado.seleccionar_lugar(u, ps)
	if args.has("pestana"):
		interfaz.panel._ir_a_pestana(int(args["pestana"]))
	if args.has("ficha"):
		var partes: PackedStringArray = str(args["ficha"]).split(":")
		Estado.pedir_ficha(partes[0], partes[1])
	if args.has("ajustes"):
		interfaz.ajustes.abrir()
	if args.has("bienvenida"):
		interfaz.mostrar_bienvenida()
	await get_tree().create_timer(float(args.get("espera", 2.5))).timeout
	await RenderingServer.frame_post_draw
	if args.has("diagnostico"):
		print("ventana=", get_window().size, " visible=", get_viewport().get_visible_rect().size)
		for c in interfaz.raiz.get_children():
			print("  ", c.name, " ", c.get_class(), " rect=", (c as Control).get_rect(), " min=", (c as Control).get_combined_minimum_size(), " visible=", c.visible)
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(args["captura"]))
	print("Captura guardada: ", args["captura"])
	get_tree().quit()


## Recorre la app sin intervención para detectar errores: saltos de año, modos, selección, todas las fichas,
## búsquedas, ajustes y cambio de tema. Uso: godot --headless --path . -- --prueba
func _prueba_automatica() -> void:
	var t0 := Time.get_ticks_msec()
	var paso := func(texto: String) -> void:
		print("[prueba] %s (%d ms)" % [texto, Time.get_ticks_msec() - t0])
	for anio in [-3400, -1350, -1, 1, 117, 476, 1492, 1810, 2024, -2500, 800]:
		Estado.fijar_anio(anio)
		await get_tree().process_frame
	paso.call("saltos de año")
	var t := Time.get_ticks_msec()
	for anio in range(-500, 500, 7):
		Estado.fijar_anio(anio)
	paso.call("143 pasos de año seguidos en %d ms" % (Time.get_ticks_msec() - t))
	for modo in ["terreno", "religion", "cultura", "idioma", "politico"]:
		Estado.fijar_modo(modo)
		await get_tree().process_frame
	paso.call("modos de mapa")
	Estado.fijar_anio(-1350)
	for ll in [Vector2(31.2, 30.0), Vector2(32.6, 25.7), Vector2(12.5, 41.9), Vector2(-58.4, -34.6), Vector2(116.4, 39.9), Vector2(0, -20)]:
		var px := Proyeccion.a_px(ll.x, ll.y)
		Estado.seleccionar_lugar(DatosMapa.unidad_en(px), px)
		for i in 5:
			interfaz.panel._ir_a_pestana(i)
			await get_tree().process_frame
	paso.call("selección y pestañas")
	for tipo in ["fuente", "persona", "hecho", "lugar", "region"]:
		var tabla: Dictionary = {"fuente": Enciclopedia.fuentes, "persona": Enciclopedia.personas, "hecho": Enciclopedia.hechos,
			"lugar": Enciclopedia.lugares, "region": Enciclopedia.regiones}[tipo]
		for id in tabla.keys():
			Estado.pedir_ficha(tipo, id)
		await get_tree().process_frame
	paso.call("todas las fichas")
	# Religiones, culturas e idiomas: cada ficha pasa el mapa a su modo y lo resalta.
	for clave in Enciclopedia.familias.keys():
		Estado.pedir_ficha("familia", clave)
		var modo: String = Enciclopedia.MODO_DE_CAPA[clave.get_slice(":", 0)]
		if Estado.modo != modo or Estado.resaltado() != clave:
			push_error("[prueba] la ficha de %s no dejó el mapa en modo %s resaltándola (modo %s, resaltada «%s»)" % [
				clave, modo, Estado.modo, Estado.resaltado()])
		await get_tree().process_frame
	paso.call("%d fichas de familias" % Enciclopedia.familias.size())
	# Leyenda tocable y clic en el mapa según el modo.
	# 1500: Egipto tiene entradas abiertas («hasta»: null, hasta hoy).
	for combinacion in [[-1350, "religion"], [-1350, "cultura"], [-1350, "idioma"], [1500, "religion"], [1500, "cultura"], [1500, "idioma"]]:
		Estado.fijar_anio(combinacion[0])
		var modo: String = combinacion[1]
		Estado.fijar_modo(modo)
		await get_tree().process_frame
		var filas: Array = interfaz.leyenda._leyenda.get_children().filter(func(c): return c.has_meta("familia") and not c.is_queued_for_deletion())
		if filas.is_empty():
			push_error("[prueba] la leyenda del modo %s quedó sin entradas en %d" % [modo, Estado.anio])
		for fila in filas:
			fila.mouse_entered.emit()
			if Estado.resaltado() == "":
				push_error("[prueba] pasar el mouse por «%s» en la leyenda no resaltó nada" % fila.text)
			fila.mouse_exited.emit()
		if not filas.is_empty():
			filas[0].pressed.emit()
			await get_tree().process_frame
		var px := Proyeccion.a_px(31.2, 30.0)
		Estado.seleccionar_lugar(DatosMapa.unidad_en(px), px)
		await get_tree().process_frame
		if interfaz.panel._pestana != 4:
			push_error("[prueba] en modo %s el clic no abrió la pestaña Datos" % modo)
	Estado.fijar_modo("politico")
	paso.call("leyenda y clic según el modo")
	# Línea de tiempo: el clic en la marca de un hecho y en la de una fuente abre su ficha.
	var pista: PistaTiempo = interfaz.linea.pista
	for tipo in ["hecho", "fuente"]:
		var el: Dictionary = (Enciclopedia.hechos if tipo == "hecho" else Enciclopedia.fuentes).values()[0]
		Estado.fijar_anio(int(el["_desde"]))
		await get_tree().process_frame
		var y := pista.size.y - 4.0 - (20.0 if tipo == "hecho" else 6.0)
		var pos := Vector2(pista._x(int(el["_desde"])), y)
		if pista._get_tooltip(pos) == pista.tooltip_text:
			push_error("[prueba] la marca de %s «%s» no muestra su nombre" % [tipo, el["id"]])
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		clic.position = pos
		pista._gui_input(clic)
		if interfaz.panel._ficha.get("tipo", "") != tipo:
			push_error("[prueba] el clic en la marca de %s «%s» no abrió su ficha" % [tipo, el["id"]])
	paso.call("marcas de la línea de tiempo")
	# Ficha de entidad: la de Egipto en 1350 a. C., y el gráfico de población de Egipto con su ayuda.
	Estado.fijar_anio(-1350)
	Estado.fijar_modo("religion")
	var px_egipto := Proyeccion.a_px(31.2, 30.0)
	var ent := DatosMapa.dueno(DatosMapa.unidad_en(px_egipto))
	var t_ent := Time.get_ticks_msec()
	Estado.pedir_ficha("entidad", ent)
	await get_tree().process_frame
	if Estado.modo != "politico" or Estado.resaltado() != "entidad:%d" % ent:
		push_error("[prueba] la ficha de la entidad %d no pasó al mapa político resaltándola" % ent)
	if DatosMapa.territorio_de_entidad(ent).is_empty():
		push_error("[prueba] la entidad %d no tiene territorio a lo largo del tiempo" % ent)
	paso.call("ficha de entidad (%s, %d ms)" % [DatosMapa.nombre_entidad(ent), Time.get_ticks_msec() - t_ent])
	var serie_pob := Enciclopedia.estimaciones("egipto")
	if serie_pob.size() >= 2:
		var grafico := GraficoSerie.new()
		grafico.serie = serie_pob
		grafico.size = Vector2(400, 120)
		add_child(grafico)
		await get_tree().process_frame
		if not grafico._get_tooltip(grafico._puntos[0]["p"]).contains("Fuente:"):
			push_error("[prueba] el gráfico de población no muestra la fuente de cada estimación")
		grafico.queue_free()
	paso.call("gráfico de población")
	# Marcadores agrupados: de lejos se juntan, ninguno se pierde, y de cerca se separan.
	Estado.fijar_anio(-1350)
	Estado.fijar_modo("politico")
	var capa: CapaMarcadores = interfaz.vista.capa_marcadores
	for z in [0.6, 1.5, 4.0]:
		var total := 0
		var juntos := 0
		for g in capa.agrupar(z):
			total += g["miembros"].size()
			juntos += int(capa._junto(g, z))
		if total != capa._visibles.size():
			push_error("[prueba] al agrupar con zoom %s se perdieron marcadores (%d de %d)" % [z, total, capa._visibles.size()])
		print("[prueba]   marcadores con zoom %s: %d grupos juntos" % [z, juntos])
	paso.call("marcadores agrupados")
	# Atajos de teclado, con eventos de verdad.
	var tecla := func(codigo: Key) -> void:
		var ev := InputEventKey.new()
		ev.keycode = codigo
		ev.pressed = true
		get_viewport().push_input(ev)
		await get_tree().process_frame
	for i in 5:
		await tecla.call(KEY_1 + i)
		if Estado.modo != Estado.MODOS.keys()[i]:
			push_error("[prueba] la tecla %d no puso el modo %s" % [i + 1, Estado.MODOS.keys()[i]])
	await tecla.call(KEY_1)
	var z0: float = interfaz.vista._zoom_objetivo
	await tecla.call(KEY_EQUAL)
	if interfaz.vista._zoom_objetivo <= z0:
		push_error("[prueba] la tecla + no acercó el mapa")
	var px_atajo := Proyeccion.a_px(31.2, 30.0)
	Estado.seleccionar_lugar(DatosMapa.unidad_en(px_atajo), px_atajo)
	await get_tree().process_frame
	var pestana0: int = interfaz.panel._pestana
	await tecla.call(KEY_BRACKETRIGHT)
	if interfaz.panel._pestana != (pestana0 + 1) % PanelInfo.PESTANAS.size():
		push_error("[prueba] la tecla ] no pasó a la pestaña siguiente")
	Estado.pedir_ficha("region", "egipto")
	await tecla.call(KEY_BACKSPACE)
	if not interfaz.panel._ficha.is_empty():
		push_error("[prueba] Retroceso no volvió de la ficha al lugar")
	Estado.seleccionar_lugar(0, Vector2.ZERO)
	paso.call("atajos de teclado")
	# Clic real en cada botón visible de la interfaz, en varios escenarios: falla si alguno da error o no hace nada.
	# Sin pantalla (--headless) la ventana mide 64×64 y casi todo quedaría afuera: se le da el tamaño del proyecto.
	if get_viewport().get_visible_rect().size.x < 800:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1600, 900)
		await get_tree().process_frame
		await get_tree().process_frame
	print("[prueba] ventana para el recorrido: %s" % get_viewport().get_visible_rect().size)
	var informe: Dictionary = await Recorrido.new(interfaz).correr()
	for s in informe["sin_efecto"]:
		push_error("[prueba] el clic no hizo nada: %s" % s)
	paso.call("recorrido de la interfaz: %d controles tocados en %d escenarios (%d omitidos, %d perdidos), %d sin efecto" % [
		informe["tocados"], informe["escenarios"], informe["omitidos"], informe["perdidos"], informe["sin_efecto"].size()])
	for texto in ["egip", "roma", "herod", "himno", "buenos", "zz", "islam", "lenguas"]:
		interfaz.barra._buscar(texto)
	paso.call("búsquedas")
	for i in DatosMapa.entidades.size():
		DatosMapa.historia_de_unidad(i % DatosMapa.n_unidades + 1)
		if i > 300:
			break
	paso.call("historias de unidades")
	interfaz.ajustes.abrir()
	await get_tree().process_frame
	for cal in ["baja", "media", "ultra", "alta"]:
		Estado.fijar_ajuste("calidad", cal)
	for tema in ["pergamino", "laton", "marmol"]:
		Estado.fijar_ajuste("tema", tema)
		interfaz._cambiar_tema()
		await get_tree().process_frame
	interfaz.ajustes.cerrar()
	paso.call("ajustes y temas")
	Estado.seleccionar_lugar(0, Vector2.ZERO)
	await get_tree().create_timer(0.5).timeout
	print("[prueba] TERMINADA sin cortes")
	get_tree().quit()

