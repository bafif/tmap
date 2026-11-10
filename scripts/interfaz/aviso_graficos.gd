class_name AvisoGraficos
extends PanelContainer
## Aviso arriba al centro al abrir la app después de cambiar el motor de dibujo en Ajustes: pregunta si se ve bien.
## Si nadie contesta en MotorGrafico.ESPERA_CONFIRMAR segundos (por ejemplo, porque la ventana quedó en negro y no se
## ve el aviso), vuelve solo al motor anterior y reabre TellMAP.

var _texto: Label
var _quedan := MotorGrafico.ESPERA_CONFIRMAR


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Debajo del aviso de actualización, que va en 70.
	position.y = 130
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	add_child(fila)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(420, 0)
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(_texto)
	var bien := Button.new()
	bien.text = tr("Se ve bien")
	bien.pressed.connect(func():
		MotorGrafico.confirmar()
		queue_free())
	fila.add_child(bien)
	var volver := Button.new()
	volver.text = tr("Volver al anterior")
	volver.tooltip_text = tr("Vuelve al motor de antes y reabre TellMAP")
	volver.pressed.connect(_volver)
	fila.add_child(volver)
	var reloj := Timer.new()
	reloj.wait_time = 1.0
	reloj.autostart = true
	reloj.timeout.connect(func():
		_quedan -= 1
		if _quedan <= 0:
			_volver()
		else:
			_escribir())
	add_child(reloj)
	_escribir()


func _escribir() -> void:
	_texto.text = tr("TellMAP dibuja ahora con el motor «%s». ¿Se ve bien? Si no contestás, en %d s vuelve al anterior y se reabre.") % [
		tr(MotorGrafico.OPCIONES[MotorGrafico.elegido()][0]), _quedan]


func _volver() -> void:
	MotorGrafico.volver()
	Actualizador.reiniciar()
