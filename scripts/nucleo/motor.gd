class_name MotorGrafico
extends RefCounted
## El motor de dibujo de Godot que usa la app y la opción de cambiarlo en Ajustes.
##
## Por defecto (project.godot): Forward+ (Vulkan, con respaldo a OpenGL si Vulkan no arranca) en Linux y Windows, y
## Compatibility (OpenGL) en macOS. En una MacBook Pro 2017 con Intel Iris Plus 640, Forward+ sobre MoltenVK arrancaba
## bien pero no dibujaba casi nada (la ventana quedaba oscura) y el respaldo a OpenGL no se activaba, porque Vulkan sí
## había arrancado. La app es 2D y se ve igual con los dos motores.
##
## Lo que se elige en Ajustes va a user://motor.cfg, que Godot lee al arrancar porque project.godot lo nombra en
## application/config/project_settings_override. Vive fuera del paquete firmado de macOS, así que no invalida su
## firma. Un --rendering-method en la línea de comandos manda sobre los dos.
##
## Para no dejar a nadie con la ventana en negro: al elegir otro motor se anota el anterior (ajuste
## «graficos_a_confirmar») y, al volver a abrir, AvisoGraficos pregunta si se ve bien; si nadie contesta, vuelve solo
## al anterior.

const RUTA := "user://motor.cfg"
## id → [nombre, descripción], en español (se traducen con tr() al mostrarlos). "auto" es no tener motor.cfg: manda
## project.godot.
const OPCIONES := {
	"auto": ["Automático", "Lo que mejor anda en cada sistema: Vulkan en Linux y Windows (OpenGL si no hay Vulkan) y OpenGL en Mac."],
	"gl_compatibility": ["Compatible (OpenGL)", "Anda en casi cualquier computadora. Elegilo si TellMAP se ve en negro, con manchas o sin mapa."],
	"forward_plus": ["Avanzado (Vulkan)", "El motor moderno de Godot (en Mac, sobre Metal). En algunas Mac con gráficos Intel se ve en negro."],
}
## Los nombres de project.godot que hay que pisar: el de macOS manda sobre el general en una Mac.
const CLAVES: Array[String] = ["renderer/rendering_method", "renderer/rendering_method.macos"]
const NOMBRES_METODO := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}
## Segundos que espera AvisoGraficos antes de volver solo al motor anterior.
const ESPERA_CONFIRMAR := 20

## Lo que decía motor.cfg al abrir la app: lo que está en uso, salvo que la línea de comandos lo cambie.
static var _al_abrir := ""


## La opción guardada: "auto", "gl_compatibility" o "forward_plus".
static func elegido() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return "auto"
	var metodo := str(cfg.get_value("rendering", CLAVES[0], "auto"))
	return metodo if OPCIONES.has(metodo) else "auto"


## La opción con que se abrió la app. Hay que llamarla una vez al arrancar, antes de que se pueda cambiar nada.
static func al_abrir() -> String:
	if _al_abrir == "":
		_al_abrir = elegido()
	return _al_abrir


## Si lo guardado se usa recién al reiniciar.
static func falta_reiniciar() -> bool:
	return elegido() != al_abrir()


## Guarda la opción para el próximo arranque. Si cambia el motor, anota el que andaba para poder volver a él.
## Durante el recorrido de la prueba automática no escribe nada (sí anota el ajuste, que el recorrido restaura).
static func elegir(id: String) -> void:
	if not OPCIONES.has(id):
		return
	var antes := str(Estado.ajustes.get("graficos_a_confirmar", ""))
	if antes == "":
		antes = al_abrir()
	if not Estado.sin_escribir:
		_guardar(id)
	Estado.fijar_ajuste("graficos_a_confirmar", "" if id == antes else antes)


## El motor anterior, si hay uno nuevo sin confirmar ("" si no).
static func a_confirmar() -> String:
	return str(Estado.ajustes.get("graficos_a_confirmar", ""))


## Se queda con el motor en uso.
static func confirmar() -> void:
	Estado.fijar_ajuste("graficos_a_confirmar", "")


## Vuelve al motor anterior (para el próximo arranque).
static func volver() -> void:
	var antes := a_confirmar()
	if antes != "":
		_guardar(antes)
	Estado.fijar_ajuste("graficos_a_confirmar", "")


static func _guardar(id: String) -> void:
	if id == "auto":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
		return
	# Mismo formato que project.godot y override.cfg.
	var cfg := ConfigFile.new()
	for clave in CLAVES:
		cfg.set_value("rendering", clave, id)
	cfg.save(RUTA)


## Lo que está dibujando, para Ajustes y para el registro: método, API y placa de video.
static func en_uso() -> String:
	var metodo := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	var placa := RenderingServer.get_video_adapter_name()
	if placa == "":
		return Idioma.t("%s (%s, sin pantalla)") % [NOMBRES_METODO.get(metodo, metodo), driver]
	return "%s · %s %s · %s" % [NOMBRES_METODO.get(metodo, metodo), {"opengl3": "OpenGL", "opengl3_angle": "OpenGL (ANGLE)",
		"vulkan": "Vulkan", "metal": "Metal", "d3d12": "Direct3D 12"}.get(driver, driver),
		RenderingServer.get_video_adapter_api_version(), placa]


## Mide una captura para saber si el motor dibujó: cuántos colores distintos hay en una grilla de puntos (con 16
## tonos por canal) y qué parte ocupa el más común. Con Forward+ en la Mac con Intel, la captura era el fondo liso y
## cinco anillos: más del 99 % de un solo color.
static func medir_dibujo(img: Image) -> Dictionary:
	var cuenta := {}
	var columnas := 160
	var filas := 90
	for j in filas:
		for i in columnas:
			var c := img.get_pixel(int((i + 0.5) * img.get_width() / columnas), int((j + 0.5) * img.get_height() / filas))
			var clave := (int(c.r * 15.0 + 0.5) << 8) | (int(c.g * 15.0 + 0.5) << 4) | int(c.b * 15.0 + 0.5)
			cuenta[clave] = int(cuenta.get(clave, 0)) + 1
	var mayor := 0
	for n: int in cuenta.values():
		mayor = maxi(mayor, n)
	return {"colores": cuenta.size(), "dominante": float(mayor) / (columnas * filas)}


## Si la captura quedó casi lisa, o sea, si el motor no dibujó el mapa ni la interfaz.
static func dibujo_vacio(medida: Dictionary) -> bool:
	return float(medida["dominante"]) > 0.85 or int(medida["colores"]) < 24
