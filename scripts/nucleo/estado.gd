extends Node
## Estado global de la aplicación: el año, el modo de mapa, lo seleccionado y los ajustes.
## Todo lo demás escucha sus señales en vez de hablarse entre sí.

signal anio_cambiado(anio: int)
signal modo_cambiado(modo: String)
## Se seleccionó un lugar del mapa (unidad > 0) o se limpió la selección (unidad = 0).
signal lugar_seleccionado(unidad: int, px: Vector2)
## Se pidió abrir la ficha de un elemento de la enciclopedia: tipo = fuente, persona, hecho, lugar, region, entidad.
signal ficha_pedida(tipo: String, id: Variant)
## Se pidió mover la cámara a un punto del mapa (en píxeles) con un zoom dado (0 = mantener).
signal enfoque_pedido(px: Vector2, zoom: float)
signal ajustes_cambiados
signal carga_progreso(texto: String, fraccion: float)
signal carga_terminada

const ANIO_MIN := -3400
const ANIO_MAX := 2024
const RUTA_AJUSTES := "user://ajustes.cfg"

## Modos de mapa: id → [nombre visible, descripción].
const MODOS := {
	"politico": ["Político", "Entidades políticas y sus fronteras (Cliopatria)"],
	"terreno": ["Terreno", "Relieve, ríos y costas, sin colores políticos"],
	"religion": ["Religión", "Religión mayoritaria (solo regiones con datos)"],
	"cultura": ["Cultura", "Cultura mayoritaria (solo regiones con datos)"],
	"idioma": ["Idioma", "Idioma mayoritario (solo regiones con datos)"],
}

## Preajustes de calidad gráfica.
const CALIDADES := {
	"baja": {"resolucion": 0.5, "relieve": false, "muestras_borde": 4, "brillo_borde": false, "papel": false, "agua_animada": false, "olas": false, "nombres_curvos": false},
	"media": {"resolucion": 1.0, "relieve": true, "muestras_borde": 8, "brillo_borde": false, "papel": true, "agua_animada": false, "olas": true, "nombres_curvos": true},
	"alta": {"resolucion": 1.0, "relieve": true, "muestras_borde": 8, "brillo_borde": true, "papel": true, "agua_animada": false, "olas": true, "nombres_curvos": true},
	"ultra": {"resolucion": 1.0, "relieve": true, "muestras_borde": 12, "brillo_borde": true, "papel": true, "agua_animada": true, "olas": true, "nombres_curvos": true},
}

var anio: int = -1350
var modo: String = "politico"
var unidad_seleccionada: int = 0
var cargado := false

var ajustes := {
	"vista": "2d",
	"calidad": "alta",
	"tema": "marmol",
	"escala_ui": 1.0,
	"idioma_wiki": "es",
	"mostrar_fuentes": true,
	"mostrar_personas": true,
	"mostrar_hechos": true,
	"mostrar_ciudades": true,
	"mostrar_nombres": true,
	"bienvenida_vista": false,
}


func _ready() -> void:
	cargar_ajustes()


func fijar_anio(nuevo: int) -> void:
	nuevo = clampi(nuevo, ANIO_MIN, ANIO_MAX)
	nuevo = Fechas.normalizar(nuevo, anio)
	if nuevo == anio:
		return
	anio = nuevo
	anio_cambiado.emit(anio)


func fijar_modo(nuevo: String) -> void:
	if nuevo == modo or not MODOS.has(nuevo):
		return
	modo = nuevo
	modo_cambiado.emit(modo)


func seleccionar_lugar(unidad: int, px: Vector2) -> void:
	unidad_seleccionada = unidad
	lugar_seleccionado.emit(unidad, px)


func pedir_ficha(tipo: String, id: Variant) -> void:
	ficha_pedida.emit(tipo, id)


func enfocar(px: Vector2, zoom: float = 0.0) -> void:
	enfoque_pedido.emit(px, zoom)


func calidad() -> Dictionary:
	return CALIDADES.get(ajustes["calidad"], CALIDADES["alta"])


func fijar_ajuste(clave: String, valor: Variant) -> void:
	ajustes[clave] = valor
	guardar_ajustes()
	ajustes_cambiados.emit()


func cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA_AJUSTES) != OK:
		return
	for clave in ajustes.keys():
		ajustes[clave] = cfg.get_value("ajustes", clave, ajustes[clave])
	anio = int(cfg.get_value("sesion", "anio", anio))


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	for clave in ajustes.keys():
		cfg.set_value("ajustes", clave, ajustes[clave])
	cfg.set_value("sesion", "anio", anio)
	cfg.save(RUTA_AJUSTES)
