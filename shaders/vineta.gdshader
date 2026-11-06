shader_type canvas_item;
// Viñeta suave sobre el mapa: oscurece apenas los bordes de la pantalla para concentrar la mirada.

uniform float fuerza = 0.42;
uniform vec3 tinte : source_color = vec3(0.04, 0.035, 0.03);

void fragment() {
	vec2 p = SCREEN_UV - 0.5;
	p.x *= 1.35;
	float d = length(p);
	float a = smoothstep(0.38, 0.85, d) * fuerza;
	COLOR = vec4(tinte, a);
}
