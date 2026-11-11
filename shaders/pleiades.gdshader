shader_type canvas_item;
// Puntos de los lugares de Pleiades: un MultiMesh con todos, en una sola llamada de dibujo. Cada instancia lleva en
// INSTANCE_CUSTOM sus años (desde, hasta); las que no existen en `anio` se achican a nada. `escala` (1 / zoom) los
// deja del mismo tamaño en pantalla a cualquier acercamiento.

uniform float anio = 0.0;
uniform float escala = 1.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform vec4 borde : source_color = vec4(0.06, 0.05, 0.04, 0.9);

varying float visible;

void vertex() {
	visible = (anio >= INSTANCE_CUSTOM.x && anio <= INSTANCE_CUSTOM.y) ? 1.0 : 0.0;
	VERTEX *= escala * visible;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float dentro = 1.0 - smoothstep(0.9, 1.0, r);
	float centro = 1.0 - smoothstep(0.55, 0.68, r);
	vec4 c = mix(borde, vec4(COLOR.rgb, 1.0), centro);
	COLOR = vec4(c.rgb, c.a * dentro * alfa * visible);
}
