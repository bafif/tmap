extends Node
## Punto de entrada: muestra la pantalla de carga, carga datos y arma el mapa y la interfaz.
##
## Para sacar capturas sin intervención (README, pruebas visuales):
##   godot --path . -- --captura=ruta.png [--anio=-1350] [--lon=31 --lat=27.5 --zoom=1.6] [--seleccionar] [--tema=marmol]

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
	if args.has("captura"):
		_captura_automatica(args)
	elif not Estado.ajustes.get("bienvenida_vista", false):
		interfaz.mostrar_bienvenida()


func _mostrar_carga() -> void:
	_carga = CanvasLayer.new()
	_carga.layer = 100
	add_child(_carga)
	var raiz := ColorRect.new()
	raiz.color = Color(0.074, 0.082, 0.094)
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme = TemaUI.crear(Estado.ajustes.get("tema", "marmol"))
	_carga.add_child(raiz)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		var u := DatosMapa.unidad_en(p)
		if u > 0:
			Estado.seleccionar_lugar(u, p)
	if args.has("pestana"):
		interfaz.panel._ir_a_pestana(int(args["pestana"]))
	if args.has("ficha"):
		var partes: PackedStringArray = str(args["ficha"]).split(":")
		Estado.pedir_ficha(partes[0], partes[1])
	if args.has("ajustes"):
		interfaz.ajustes.abrir()
	await get_tree().create_timer(float(args.get("espera", 2.5))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(args["captura"]))
	print("Captura guardada: ", args["captura"])
	get_tree().quit()
