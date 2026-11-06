class_name TemaUI
## Construye el Theme de Godot a partir de una paleta. Cada «piel» es solo un diccionario de colores:
## agregar una nueva es copiar una entrada de TEMAS y cambiarle los colores.

const TEMAS := {
	"marmol": {
		"nombre": "Mármol y bronce",
		"fondo": "#1a1e24", "fondo2": "#232931", "fondo3": "#2c333d",
		"borde": "#a8875a", "borde_suave": "#4f4639",
		"texto": "#ece3cf", "texto_suave": "#a99e88", "titulo": "#e2c48a",
		"acento": "#d4ab62", "acento_texto": "#1a1e24",
		"boton": "#2a3038", "boton_hover": "#36404a", "boton_activo": "#4a3e2a",
		"primaria": "#c9a04a", "secundaria": "#7b9cc2", "persona": "#a77bb8", "hecho": "#c0583f",
		"sombra": "#00000099",
	},
	"pergamino": {
		"nombre": "Pergamino iluminado",
		"fondo": "#e6d9bb", "fondo2": "#ddcda8", "fondo3": "#d3c099",
		"borde": "#7c2d22", "borde_suave": "#b49b70",
		"texto": "#2c2116", "texto_suave": "#6a5843", "titulo": "#7c2d22",
		"acento": "#8e2b22", "acento_texto": "#f4ead2",
		"boton": "#d9c9a2", "boton_hover": "#e8dbbb", "boton_activo": "#c4ab7e",
		"primaria": "#9a6f1c", "secundaria": "#3d5f8a", "persona": "#6d3f80", "hecho": "#9e2f22",
		"sombra": "#3a2a1866",
	},
	"laton": {
		"nombre": "Tinta y latón",
		"fondo": "#131916", "fondo2": "#1b231f", "fondo3": "#24302a",
		"borde": "#b89a55", "borde_suave": "#3f4a40",
		"texto": "#e9e4d4", "texto_suave": "#a3a895", "titulo": "#d6bd7a",
		"acento": "#5fa79a", "acento_texto": "#0f1513",
		"boton": "#1f2924", "boton_hover": "#2b3731", "boton_activo": "#2c4a42",
		"primaria": "#d0aa52", "secundaria": "#79a8c4", "persona": "#b48ac4", "hecho": "#d0674c",
		"sombra": "#000000a0",
	},
}

static var actual: Dictionary = TEMAS["marmol"]
static var fuente_titulo: Font
static var fuente_texto: Font
static var fuente_cursiva: Font
static var fuente_negrita: Font
static var fuente_mapa: Font
static var _base_cinzel: FontFile
static var _base_garamond: FontFile
static var _base_garamond_it: FontFile


static func color(clave: String) -> Color:
	return Color(actual.get(clave, "#ff00ff"))


static func cargar_fuentes() -> void:
	if _base_cinzel != null:
		return
	_base_cinzel = _fuente_de("res://assets/fuentes/Cinzel.ttf")
	_base_garamond = _fuente_de("res://assets/fuentes/EBGaramond.ttf")
	_base_garamond_it = _fuente_de("res://assets/fuentes/EBGaramond-Italic.ttf")
	fuente_titulo = _variacion(_base_cinzel, 650)
	fuente_texto = _variacion(_base_garamond, 480)
	fuente_negrita = _variacion(_base_garamond, 650)
	fuente_cursiva = _variacion(_base_garamond_it, 450)
	# Para los nombres sobre el mapa: campo de distancia firmado, así se escala sin perder nitidez.
	var mapa := _fuente_de("res://assets/fuentes/Cinzel.ttf")
	mapa.multichannel_signed_distance_field = true
	mapa.msdf_pixel_range = 14
	mapa.msdf_size = 64
	fuente_mapa = _variacion(mapa, 600)


static func _fuente_de(ruta: String) -> FontFile:
	var f := FontFile.new()
	f.data = FileAccess.get_file_as_bytes(ruta)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


static func _variacion(base: FontFile, peso: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
	return v


static func caja(fondo: Color, borde: Color = Color.TRANSPARENT, ancho_borde := 0, radio := 3, margen := 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho_borde)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	s.anti_aliasing = true
	return s


static func crear(id: String) -> Theme:
	cargar_fuentes()
	actual = TEMAS.get(id, TEMAS["marmol"])
	var t := Theme.new()
	t.default_font = fuente_texto
	t.default_font_size = 18

	var texto := color("texto")
	var suave := color("texto_suave")

	# Paneles
	var panel := caja(color("fondo"), color("borde"), 1, 3, 12.0)
	panel.shadow_color = color("sombra")
	panel.shadow_size = 10
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_type_variation("Tarjeta", "PanelContainer")
	var tarjeta := caja(color("fondo2"), color("borde_suave"), 1, 3, 10.0)
	t.set_stylebox("panel", "Tarjeta", tarjeta)
	t.set_type_variation("Franja", "PanelContainer")
	var franja := caja(color("fondo"), color("borde"), 0, 0, 6.0)
	franja.border_width_bottom = 1
	franja.shadow_color = color("sombra")
	franja.shadow_size = 8
	t.set_stylebox("panel", "Franja", franja)
	t.set_type_variation("Transparente", "PanelContainer")
	t.set_stylebox("panel", "Transparente", StyleBoxEmpty.new())

	# Textos
	t.set_color("font_color", "Label", texto)
	t.set_type_variation("Titulo", "Label")
	t.set_font("font", "Titulo", fuente_titulo)
	t.set_font_size("font_size", "Titulo", 20)
	t.set_color("font_color", "Titulo", color("titulo"))
	t.set_type_variation("TituloGrande", "Label")
	t.set_font("font", "TituloGrande", fuente_titulo)
	t.set_font_size("font_size", "TituloGrande", 27)
	t.set_color("font_color", "TituloGrande", color("titulo"))
	t.set_type_variation("Seccion", "Label")
	t.set_font("font", "Seccion", fuente_titulo)
	t.set_font_size("font_size", "Seccion", 15)
	t.set_color("font_color", "Seccion", color("acento"))
	t.set_type_variation("Suave", "Label")
	t.set_font_size("font_size", "Suave", 15)
	t.set_color("font_color", "Suave", suave)
	t.set_type_variation("Anio", "Label")
	t.set_font("font", "Anio", fuente_titulo)
	t.set_font_size("font_size", "Anio", 30)
	t.set_color("font_color", "Anio", color("titulo"))

	t.set_font("normal_font", "RichTextLabel", fuente_texto)
	t.set_font("italics_font", "RichTextLabel", fuente_cursiva)
	t.set_font("bold_font", "RichTextLabel", fuente_negrita)
	t.set_font("bold_italics_font", "RichTextLabel", fuente_cursiva)
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("italics_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_color("default_color", "RichTextLabel", texto)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# Botones
	var b_normal := caja(color("boton"), color("borde_suave"), 1, 3, 6.0)
	b_normal.content_margin_left = 12
	b_normal.content_margin_right = 12
	var b_hover := caja(color("boton_hover"), color("borde"), 1, 3, 6.0)
	b_hover.content_margin_left = 12
	b_hover.content_margin_right = 12
	var b_activo := caja(color("boton_activo"), color("acento"), 1, 3, 6.0)
	b_activo.content_margin_left = 12
	b_activo.content_margin_right = 12
	var b_off := caja(color("boton").darkened(0.15), color("borde_suave").darkened(0.3), 1, 3, 6.0)
	b_off.content_margin_left = 12
	b_off.content_margin_right = 12
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_activo)
	t.set_stylebox("hover_pressed", "Button", b_activo)
	t.set_stylebox("disabled", "Button", b_off)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", texto)
	t.set_color("font_hover_color", "Button", texto.lightened(0.1))
	t.set_color("font_pressed_color", "Button", color("titulo"))
	t.set_color("font_hover_pressed_color", "Button", color("titulo"))
	t.set_color("font_disabled_color", "Button", suave.darkened(0.25))
	t.set_color("icon_normal_color", "Button", texto)
	t.set_font_size("font_size", "Button", 17)

	t.set_type_variation("BotonModo", "Button")
	t.set_font("font", "BotonModo", fuente_titulo)
	t.set_font_size("font_size", "BotonModo", 14)
	t.set_type_variation("BotonPlano", "Button")
	var plano := caja(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3, 4.0)
	var plano_hover := caja(color("boton_hover"), Color.TRANSPARENT, 0, 3, 4.0)
	t.set_stylebox("normal", "BotonPlano", plano)
	t.set_stylebox("hover", "BotonPlano", plano_hover)
	t.set_stylebox("pressed", "BotonPlano", plano_hover)
	t.set_stylebox("hover_pressed", "BotonPlano", plano_hover)
	t.set_color("font_color", "BotonPlano", suave)
	t.set_color("font_hover_color", "BotonPlano", texto)
	# Filas de leyenda: como BotonPlano, pero sin aire, para que entren muchas.
	t.set_type_variation("FilaCompacta", "BotonPlano")
	var fila := caja(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3, 1.0)
	var fila_hover := caja(color("boton_hover"), Color.TRANSPARENT, 0, 3, 1.0)
	fila.content_margin_left = 3.0
	fila_hover.content_margin_left = 3.0
	t.set_stylebox("normal", "FilaCompacta", fila)
	t.set_stylebox("hover", "FilaCompacta", fila_hover)
	t.set_stylebox("pressed", "FilaCompacta", fila_hover)
	t.set_stylebox("hover_pressed", "FilaCompacta", fila_hover)
	t.set_font_size("font_size", "FilaCompacta", 15)
	t.set_color("font_color", "FilaCompacta", texto)
	t.set_type_variation("Pestana", "Button")
	var pest := caja(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 6.0)
	var pest_on := caja(color("fondo2"), color("acento"), 0, 0, 6.0)
	pest_on.border_width_bottom = 2
	var pest_hover := caja(color("fondo2").darkened(0.05), color("borde_suave"), 0, 0, 6.0)
	pest_hover.border_width_bottom = 1
	t.set_stylebox("normal", "Pestana", pest)
	t.set_stylebox("hover", "Pestana", pest_hover)
	t.set_stylebox("pressed", "Pestana", pest_on)
	t.set_stylebox("hover_pressed", "Pestana", pest_on)
	t.set_font("font", "Pestana", fuente_titulo)
	t.set_font_size("font_size", "Pestana", 13)
	t.set_color("font_color", "Pestana", suave)
	t.set_color("font_pressed_color", "Pestana", color("titulo"))
	t.set_color("font_hover_pressed_color", "Pestana", color("titulo"))

	# Campos de texto
	var le := caja(color("fondo2"), color("borde_suave"), 1, 3, 6.0)
	le.content_margin_left = 10
	var le_foco := caja(color("fondo2"), color("acento"), 1, 3, 6.0)
	le_foco.content_margin_left = 10
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_foco)
	t.set_color("font_color", "LineEdit", texto)
	t.set_color("font_placeholder_color", "LineEdit", suave.darkened(0.1))
	t.set_color("caret_color", "LineEdit", color("acento"))
	t.set_color("selection_color", "LineEdit", Color(color("acento"), 0.35))

	# Barras de desplazamiento finas
	var scroll := caja(Color(color("fondo2"), 0.6), Color.TRANSPARENT, 0, 4, 0.0)
	var agarre := caja(color("borde_suave"), Color.TRANSPARENT, 0, 4, 0.0)
	var agarre_h := caja(color("borde"), Color.TRANSPARENT, 0, 4, 0.0)
	for tipo in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", tipo, scroll)
		t.set_stylebox("grabber", tipo, agarre)
		t.set_stylebox("grabber_highlight", tipo, agarre_h)
		t.set_stylebox("grabber_pressed", tipo, agarre_h)

	# Casillas, separadores y menús
	t.set_color("font_color", "CheckBox", texto)
	t.set_color("font_hover_color", "CheckBox", color("titulo"))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckBox", _icono_casilla(true))
	t.set_icon("unchecked", "CheckBox", _icono_casilla(false))
	var sep := StyleBoxLine.new()
	sep.color = color("borde_suave")
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 10)
	var popup := caja(color("fondo"), color("borde"), 1, 3, 6.0)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", texto)
	t.set_color("font_hover_color", "PopupMenu", color("titulo"))
	t.set_stylebox("hover", "PopupMenu", caja(color("boton_hover"), Color.TRANSPARENT, 0, 2, 4.0))
	t.set_stylebox("normal", "OptionButton", b_normal)
	t.set_stylebox("hover", "OptionButton", b_hover)
	t.set_stylebox("pressed", "OptionButton", b_activo)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", texto)

	# Barra de progreso (pantalla de carga)
	t.set_stylebox("background", "ProgressBar", caja(color("fondo2"), color("borde_suave"), 1, 2, 0.0))
	t.set_stylebox("fill", "ProgressBar", caja(color("acento"), Color.TRANSPARENT, 0, 2, 0.0))
	t.set_color("font_color", "ProgressBar", Color.TRANSPARENT)

	# Globos de ayuda
	var globo := caja(color("fondo"), color("borde"), 1, 3, 8.0)
	globo.shadow_color = color("sombra")
	globo.shadow_size = 6
	t.set_stylebox("panel", "TooltipPanel", globo)
	t.set_color("font_color", "TooltipLabel", texto)
	t.set_font_size("font_size", "TooltipLabel", 16)
	return t


static func _icono_casilla(marcada: bool) -> Texture2D:
	var n := 18
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var borde := color("borde")
	var fondo := color("fondo2")
	var marca := color("acento")
	for y in n:
		for x in n:
			var c := fondo
			if x < 1 or y < 1 or x >= n - 1 or y >= n - 1:
				c = borde
			elif marcada and x >= 4 and y >= 4 and x < n - 4 and y < n - 4:
				c = marca
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
