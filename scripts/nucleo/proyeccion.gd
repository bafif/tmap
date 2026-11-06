class_name Proyeccion
## Proyección cilíndrica de Miller recortada, la misma que usa el pipeline (`tools/pipeline/comun.py`).
## Los valores reales se cargan de `data/mapa/politico.json` al arrancar.

static var ancho := 8192
static var alto := 4016
static var lat_norte := 83.0
static var lat_sur := -57.0


static func configurar(p: Dictionary) -> void:
	ancho = int(p.get("ancho", ancho))
	alto = int(p.get("alto", alto))
	lat_norte = float(p.get("lat_norte", lat_norte))
	lat_sur = float(p.get("lat_sur", lat_sur))


static func miller_y(lat: float) -> float:
	var phi := deg_to_rad(clampf(lat, -89.9, 89.9))
	return 1.25 * log(tan(PI / 4.0 + 0.4 * phi))


static func miller_lat(y: float) -> float:
	return rad_to_deg(2.5 * atan(exp(0.8 * y)) - 0.625 * PI)


## Longitud/latitud (grados) a píxel del mapa.
static func a_px(lon: float, lat: float) -> Vector2:
	var yn := miller_y(lat_norte)
	var ys := miller_y(lat_sur)
	return Vector2((lon + 180.0) / 360.0 * ancho, (yn - miller_y(lat)) / (yn - ys) * alto)


## Píxel del mapa a Vector2(lon, lat).
static func a_lonlat(px: Vector2) -> Vector2:
	var yn := miller_y(lat_norte)
	var ys := miller_y(lat_sur)
	return Vector2(px.x / ancho * 360.0 - 180.0, miller_lat(yn - px.y / alto * (yn - ys)))


## Kilómetros por píxel (horizontal, vertical) a una latitud dada.
static func km_por_px(lat: float) -> Vector2:
	var yn := miller_y(lat_norte)
	var ys := miller_y(lat_sur)
	var kx := 40075.0 * cos(deg_to_rad(lat)) / ancho
	var ky := 6371.0 * (yn - ys) / alto * cos(deg_to_rad(0.8 * lat))
	return Vector2(kx, ky)


static func texto_coordenadas(lonlat: Vector2) -> String:
	var lat := "%.1f° %s" % [absf(lonlat.y), "N" if lonlat.y >= 0 else "S"]
	var lon := "%.1f° %s" % [absf(lonlat.x), "E" if lonlat.x >= 0 else "O"]
	return (lat + " · " + lon).replace(".", ",")
