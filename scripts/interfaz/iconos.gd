class_name IconosUI
## Íconos de la interfaz dibujados en SVG (originales del proyecto), rasterizados al tamaño pedido y cacheados.

const SVG := {
	"play": "<path d='M20 12v40l34-20z'/>",
	"pausa": "<path d='M18 12h10v40H18zM36 12h10v40H36z'/>",
	"atras1": "<path d='M40 12L20 32l20 20 4-4-16-16 16-16z'/>",
	"adelante1": "<path d='M24 12l20 20-20 20-4-4 16-16-16-16z'/>",
	"atras2": "<path d='M30 12L10 32l20 20 4-4-16-16 16-16zM50 12L30 32l20 20 4-4-16-16 16-16z'/>",
	"adelante2": "<path d='M14 12l20 20-20 20-4-4 16-16-16-16zM34 12l20 20-20 20-4-4 16-16-16-16z'/>",
	"buscar": "<path d='M27 8a19 19 0 1 1 0 38 19 19 0 0 1 0-38zm0 6a13 13 0 1 0 0 26 13 13 0 0 0 0-26z'/><path d='M39 43l5-5 14 14-5 5z'/>",
	"ajustes": "<path d='M28 4h8l2 8 6 3 7-4 6 6-4 7 3 6 8 2v8l-8 2-3 6 4 7-6 6-7-4-6 3-2 8h-8l-2-8-6-3-7 4-6-6 4-7-3-6-8-2v-8l8-2 3-6-4-7 6-6 7 4 6-3zm4 18a10 10 0 1 0 0 20 10 10 0 0 0 0-20z'/>",
	"cerrar": "<path d='M16 12l16 16 16-16 4 4-16 16 16 16-4 4-16-16-16 16-4-4 16-16-16-16z'/>",
	"volver": "<path d='M28 14L10 32l18 18 4-4-11-11h33v-6H21l11-11z'/>",
	"libro": "<path d='M7 15c9-4 17-3 23 2v34c-6-5-14-6-23-2zM57 15c-9-4-17-3-23 2v34c6-5 14-6 23-2z'/>",
	"enlace": "<path d='M36 8h20v20l-7-7-17 17-5-5 17-17zM12 16h16v6H18v24h24V36h6v16H12z'/>",
	"ir": "<path d='M32 6a26 26 0 1 1 0 52 26 26 0 0 1 0-52zm0 6a20 20 0 1 0 0 40 20 20 0 0 0 0-40zm0 12a8 8 0 1 1 0 16 8 8 0 0 1 0-16z'/>",
	"capas": "<path d='M32 8l26 13-26 13L6 21zM12 30l20 10 20-10 6 3-26 13L6 33zM12 42l20 10 20-10 6 3-26 13L6 45z'/>",
	"editar": "<path d='M42 8l14 14-30 30H12V38zM10 56h44v4H10z'/>",
	"ayuda": "<path d='M32 6a26 26 0 1 1 0 52 26 26 0 0 1 0-52zm0 6a20 20 0 1 0 0 40 20 20 0 0 0 0-40zm-1 30h6v6h-6zm1-24c7 0 12 4 12 10 0 7-8 8-8 13h-6c0-8 8-9 8-13 0-3-2-5-6-5s-6 2-6 5h-6c0-6 5-10 12-10z'/>",
}

static var _cache := {}


static func textura(nombre: String, tam := 20, color := Color.WHITE) -> Texture2D:
	var clave := "%s_%d_%s" % [nombre, tam, color.to_html()]
	if _cache.has(clave):
		return _cache[clave]
	var cuerpo: String = SVG.get(nombre, SVG["cerrar"])
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64' fill='#%s'>%s</svg>" % [color.to_html(false), cuerpo]
	var img := Image.new()
	img.load_svg_from_string(svg, tam / 64.0)
	var tex := ImageTexture.create_from_image(img)
	_cache[clave] = tex
	return tex


## Botón con ícono, plano o normal, con texto de ayuda.
static func boton(nombre: String, ayuda: String, tam := 20, plano := true) -> Button:
	var b := Button.new()
	b.icon = textura(nombre, tam, TemaUI.color("texto"))
	b.tooltip_text = ayuda
	b.theme_type_variation = "BotonPlano" if plano else ""
	b.focus_mode = Control.FOCUS_ALL
	b.expand_icon = false
	return b


## Cuadradito de color con borde oscuro, para leyendas y filas de religión, cultura e idioma.
static func muestra(c: Color, lado := 14) -> Texture2D:
	var img := Image.create_empty(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.05))
	img.fill_rect(Rect2i(1, 1, lado - 2, lado - 2), c)
	return ImageTexture.create_from_image(img)
