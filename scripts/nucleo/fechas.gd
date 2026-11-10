class_name Fechas
## Años históricos: enteros, negativos antes de Cristo y sin año 0 (el 1 a. C. es -1 y el 1 d. C. es 1).
## Los textos salen en el idioma de la app: «1350 a. C.» o «1350 BC», «siglo V a. C.» o «5th century BC».

const ROMANOS := [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
	[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]


## Texto corto de un año: «1350 a. C.», «476 d. C.», «1810».
static func texto(anio: int) -> String:
	if anio < 0:
		return Idioma.t("%s a. C.") % _miles(-anio)
	if anio < 1000:
		return Idioma.t("%d d. C.") % anio
	return str(anio)


## Rango de años con el formato más corto que no sea ambiguo.
static func rango(desde: int, hasta: int) -> String:
	if desde == hasta:
		return texto(desde)
	if desde < 0 and hasta < 0:
		return Idioma.t("%s–%s a. C.") % [_miles(-desde), _miles(-hasta)]
	return "%s – %s" % [texto(desde), texto(hasta)]


static func siglo(anio: int) -> String:
	var s := maxi(int(ceil(abs(anio) / 100.0)), 1)
	if Idioma.ingles():
		return "%s century%s" % [Idioma.ordinal_en(s), " BC" if anio < 0 else ""]
	return "siglo %s%s" % [romano(s), " a. C." if anio < 0 else ""]


static func romano(n: int) -> String:
	var out := ""
	for par in ROMANOS:
		while n >= par[0]:
			out += par[1]
			n -= par[0]
	return out


## Corrige un año para que nunca sea 0: si se viene desde abajo pasa a 1, si no a -1.
static func normalizar(anio: int, previo: int = 0) -> int:
	if anio != 0:
		return anio
	return 1 if previo < 0 else -1


## Diferencia en años entre dos fechas históricas, descontando el año 0 inexistente.
static func distancia(a: int, b: int) -> int:
	var d := b - a
	if a < 0 and b > 0:
		d -= 1
	elif a > 0 and b < 0:
		d += 1
	return d


## Suma años saltando el 0.
static func sumar(anio: int, delta: int) -> int:
	var r := anio + delta
	if anio < 0 and r >= 0:
		r += 1
	elif anio > 0 and r <= 0:
		r -= 1
	return r


static func _miles(n: int) -> String:
	return str(n) if n < 10000 else Idioma.miles(n)
