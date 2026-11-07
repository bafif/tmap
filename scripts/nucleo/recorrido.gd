class_name Recorrido
extends RefCounted
## Recorre toda la interfaz: en cada escenario (panel cerrado, cada pestaña de un lugar, cada tipo de ficha, modo de
## capa, ajustes, ayuda, búsqueda) hace clic de verdad, con eventos de mouse, en cada botón visible y en los gráficos
## tocables, y anota los que no cambian nada. Los errores que salten durante los clics los ve quien lo corre: la
## prueba automática (--prueba) los cuenta como fallo y el puente (orden «recorrido») los devuelve con su traza.
## Mientras corre, los enlaces no abren el navegador: solo se anotan (Estado.sin_navegador).

var _interfaz: Interfaz
var _arbol: SceneTree
var tocados := 0
var omitidos := 0
## Controles que desaparecieron antes de poder tocarlos (la interfaz se reconstruyó mientras tanto).
var perdidos := 0
## «escenario › control» de los que no hicieron nada.
var sin_efecto: Array = []
## Los ajustes del principio: los clics en Ajustes los cambian y cada escenario los vuelve a dejar así.
var _ajustes0 := {}


func _init(interfaz: Interfaz) -> void:
	_interfaz = interfaz
	_arbol = interfaz.get_tree()


## solo: si no está vacío, corre únicamente los escenarios cuyo nombre empieza así.
func correr(solo := "") -> Dictionary:
	var anio_antes := Estado.anio
	var modo_antes := Estado.modo
	Estado.sin_navegador = true
	Estado.sin_animaciones = true
	_ajustes0 = Estado.ajustes.duplicate()
	# El editor de la enciclopedia ve un borrador de prueba y no escribe nada mientras se lo recorre.
	var borradores_antes := Edicion.dir_borradores
	Edicion.dir_borradores = "user://recorrido/borradores/"
	Edicion.escribir(Edicion.dir_borradores + "prueba.json", Edicion.borrador_de_prueba())
	Estado.sin_escribir = true
	var lon_lat := Vector2(31.2, 27.0)
	var escenarios: Array = [["inicio", func(): pass]]
	for n in PanelInfo.PESTANAS.size():
		var i: int = n
		escenarios.append(["lugar, pestaña %s" % PanelInfo.PESTANAS[i], func():
			_seleccionar(lon_lat)
			_interfaz.panel._ir_a_pestana(i)])
	var fichas := [["fuente", Enciclopedia.fuentes.keys()[0]], ["persona", Enciclopedia.personas.keys()[0]],
		["hecho", Enciclopedia.hechos.keys()[0]], ["lugar", Enciclopedia.lugares.keys()[0]],
		["region", "egipto"], ["familia", "religiones:islam-sunni"], ["entidad", -1]]
	for f in fichas:
		var tipo: String = f[0]
		var id: Variant = f[1]
		escenarios.append(["ficha de %s" % tipo, func():
			_seleccionar(lon_lat)
			Estado.pedir_ficha(tipo, id if tipo != "entidad" else DatosMapa.dueno(Estado.unidad_seleccionada))])
	escenarios.append(["modo religión", func(): Estado.fijar_modo("religion")])
	escenarios.append(["ajustes", func(): _interfaz.ajustes.abrir()])
	escenarios.append(["ayuda", func(): _interfaz.barra.ayuda_pedida.emit()])
	escenarios.append(["búsqueda", func(): _interfaz.barra._buscar("egip")])
	var region_corta := "egipto"
	for r in Enciclopedia.regiones.values():
		if (r.get("eras", []) as Array).size() > 0 and r.get("eras").size() < Enciclopedia.regiones[region_corta]["eras"].size():
			region_corta = r["id"]
	for f in [["fuente", Enciclopedia.fuentes.keys()[0]], ["persona", Enciclopedia.personas.keys()[0]], ["region", region_corta]]:
		var tipo: String = f[0]
		var id: String = f[1]
		escenarios.append(["editor, %s" % tipo, func(): Estado.editor_pedido.emit(tipo, id)])
	escenarios.append(["editor, lugar nuevo", func():
		Estado.editor_pedido.emit("lugar", "")
		_interfaz.editor._al_nuevo()])
	escenarios.append(["editor, borrador", func():
		Estado.editor_pedido.emit("", "")
		_interfaz.editor._cambiar_seccion("borradores")
		_interfaz.editor._al_elegir(0)])

	if solo != "":
		escenarios = escenarios.filter(func(e): return str(e[0]).begins_with(solo))
	for esc in escenarios:
		var t0 := Time.get_ticks_msec()
		var antes := tocados
		await _preparar(esc[1])
		var n := _tocables(true).size()
		var limpio := true
		for i in n:
			# Si el clic anterior no cambió nada, el escenario sigue igual y no hace falta prepararlo de nuevo.
			# Si el control desapareció antes del clic, se prepara todo otra vez y se reintenta una vez.
			for intento in 2:
				if not limpio:
					await _preparar(esc[1])
				var lista := _tocables()
				if i >= lista.size():
					break
				var perdidos_antes := perdidos
				limpio = not await _tocar(esc[0], lista[i])
				if perdidos == perdidos_antes:
					break
				if intento == 0:
					perdidos -= 1
		print("[prueba]   recorrido, %s: %d controles en %d ms" % [esc[0], tocados - antes, Time.get_ticks_msec() - t0])
	await _preparar(func(): pass)
	Edicion.dir_borradores = borradores_antes
	Estado.sin_escribir = false
	Estado.sin_navegador = false
	Estado.sin_animaciones = false
	Estado.fijar_modo(modo_antes)
	Estado.fijar_anio(anio_antes)
	return {"tocados": tocados, "omitidos": omitidos, "perdidos": perdidos, "sin_efecto": sin_efecto, "escenarios": escenarios.size()}


func _seleccionar(lon_lat: Vector2) -> void:
	var px := Proyeccion.a_px(lon_lat.x, lon_lat.y)
	Estado.seleccionar_lugar(DatosMapa.unidad_en(px), px)


## Deja la app en un estado conocido y aplica el escenario; espera a que terminen las animaciones.
func _preparar(escenario: Callable) -> void:
	if not _ajustes0.is_empty() and str(Estado.ajustes) != str(_ajustes0):
		var otro_tema: bool = Estado.ajustes.get("tema") != _ajustes0.get("tema")
		for k in _ajustes0:
			Estado.ajustes[k] = _ajustes0[k]
		Estado.guardar_ajustes()
		Estado.ajustes_cambiados.emit()
		if otro_tema:
			_interfaz._cambiar_tema()
		await _arbol.process_frame
	for n in _interfaz.raiz.get_children():
		if n is Bienvenida:
			n.queue_free()
	# Si un clic dejó la línea de tiempo reproduciendo, el año seguiría cambiando y reconstruyendo el panel.
	if _interfaz.linea._reproduciendo:
		_interfaz.linea.alternar_reproduccion()
	if _interfaz.ajustes.visible:
		_interfaz.ajustes.cerrar()
	_interfaz.editor._vaciar()
	_interfaz.editor.cerrar()
	Estado.captura_punto = Callable()
	_interfaz.barra._resultados.visible = false
	Estado.resaltar("", "leyenda")
	Estado.seleccionar_lugar(0, Vector2.ZERO)
	Estado.fijar_modo("politico")
	Estado.fijar_anio(-1350)
	Estado.ultima_url = ""
	await _arbol.process_frame
	escenario.call()
	await _quieto()


## Espera a que se detengan la cámara, el panel y las reconstrucciones diferidas (con tope).
func _quieto() -> void:
	for i in 90:
		await _arbol.process_frame
		var vuelo: Tween = _interfaz.vista._vuelo
		var panel_tween: Tween = _interfaz.panel._tween
		var moviendo := (vuelo != null and vuelo.is_running()) or (panel_tween != null and panel_tween.is_running())
		if not moviendo and not _interfaz.panel._reconstruir_pendiente and i >= 1:
			return


## Botones visibles y habilitados, y los gráficos que responden al clic, en orden de árbol.
func _tocables(contar := false) -> Array:
	var out: Array = []
	var pantalla := _interfaz.get_viewport().get_visible_rect()
	for c in _interfaz.raiz.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.is_queued_for_deletion():
			continue
		var es_grafico := ctl is PistaTiempo or ctl is BarrasFamilia or ctl is GraficoTerritorio
		if not (ctl is BaseButton or es_grafico):
			continue
		if ctl is BaseButton:
			var b := ctl as BaseButton
			# Un botón ya elegido de un grupo (la pestaña o el modo actuales) no tiene nada que hacer.
			if b.disabled or (b.toggle_mode and b.button_group != null and b.button_pressed):
				omitidos += int(contar)
				continue
		if not pantalla.intersects(ctl.get_global_rect()):
			omitidos += int(contar)
			continue
		out.append(ctl)
	return out


func _nombre(c: Control) -> String:
	var texto := ""
	if c is Button:
		texto = (c as Button).text
	if texto == "":
		texto = c.tooltip_text.get_slice("\n", 0)
	return "%s «%s»" % [c.get_class() if c.get_script() == null else str(c.get_script().get_global_name()), texto.left(50)]


## Devuelve si el clic cambió algo.
func _tocar(escenario: String, c: Control) -> bool:
	# Lo que está dentro de un scroll se trae a la vista antes de tocarlo.
	var padre := c.get_parent()
	while padre != null and padre != _interfaz.raiz:
		if padre is ScrollContainer:
			(padre as ScrollContainer).ensure_control_visible(c)
			await _arbol.process_frame
			if not is_instance_valid(c):
				perdidos += 1
				print("[recorrido] perdido al desplazar, en ", escenario)
				return true
			break
		padre = padre.get_parent()
	var rect := c.get_global_rect()
	var zona := _interfaz.get_viewport().get_visible_rect().intersection(rect)
	if zona.size.x < 2 or zona.size.y < 2:
		omitidos += 1
		return false
	# Los gráficos se tocan a un costado: en el centro suele estar el año actual, y el clic no cambiaría nada.
	var pos := zona.get_center() if c is BaseButton else zona.position + zona.size * Vector2(0.3, 0.5)
	var nombre := "%s › %s" % [escenario, _nombre(c)]
	var vp := _interfaz.get_viewport()
	var mover := InputEventMouseMotion.new()
	mover.position = pos
	mover.global_position = pos
	vp.push_input(mover, true)
	await _arbol.process_frame
	if not is_instance_valid(c):
		perdidos += 1
		return true
	# Si otro control lo tapa (la ayuda, un diálogo), no se puede tocar: no cuenta.
	var encima := vp.gui_get_hovered_control()
	if encima != c and not c.is_ancestor_of(encima):
		omitidos += 1
		return false
	print("[recorrido] ", nombre)
	var antes := _firma()
	# En una lista desplegable se elige otra opción (el menú emergente no se puede leer igual en todas partes).
	if c is OptionButton:
		var ob := c as OptionButton
		var otra := (ob.selected + 1) % maxi(ob.item_count, 1)
		ob.select(otra)
		ob.item_selected.emit(otra)
		await _arbol.process_frame
		tocados += 1
		# Lo que haya cambiado (un ajuste, el tema) lo deshace _preparar antes del próximo clic.
		if _firma() == antes:
			sin_efecto.append(nombre)
		return true
	# Apretar y soltar en cuadros distintos, como una persona: así salen a la luz los errores que dependen de lo que
	# pasa en el medio (por ejemplo, perder el foco cancela el clic).
	for apretado in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = apretado
		clic.position = pos
		clic.global_position = pos
		_interfaz.get_viewport().push_input(clic, true)
		await _arbol.process_frame
		if not is_instance_valid(c):
			break
	await _arbol.process_frame
	tocados += 1
	var hizo_algo := _firma() != antes
	if not hizo_algo:
		sin_efecto.append(nombre)
	return hizo_algo


## Resumen de todo lo que un clic puede cambiar: estado global, cámara, panel, enlaces abiertos y los controles
## visibles con sus textos.
func _firma() -> String:
	var v := _interfaz.vista
	var p := _interfaz.panel
	var partes: Array = [Estado.anio, Estado.modo, Estado.unidad_seleccionada, Estado.resaltado(), str(Estado.ajustes),
		Estado.ultima_url, v.camara.position.round(), snappedf(v._zoom_objetivo, 0.001), str(p._ficha), p._pestana,
		p._abierto, _interfaz.linea._reproduciendo]
	for c in _interfaz.raiz.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var texto := ""
		if ctl is Label:
			texto = (ctl as Label).text
		elif ctl is Button:
			texto = (ctl as Button).text + str((ctl as Button).button_pressed)
		elif ctl is RichTextLabel:
			texto = (ctl as RichTextLabel).text.left(60)
		elif ctl is ScrollContainer:
			texto = str((ctl as ScrollContainer).scroll_vertical)
		partes.append("%s:%s" % [ctl.get_class(), texto])
	return str(partes).md5_text()
