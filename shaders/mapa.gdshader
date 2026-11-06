shader_type canvas_item;
render_mode blend_disabled;

// Mapa político/físico de TellMAP.
// TEXTURE (la del Sprite2D) = color del terreno.
// tex_relieve: R = sombreado (0,5 = llano), G = distancia con signo a la costa (0,5 = costa, >0,5 agua; 4 valores por
// píxel), B = ríos, A = distancia mar adentro (0..255 px).
// tex_unidades: índice de unidad en RG8. tex_lut: valor de cada unidad en RG8 (0 = sin dato). tex_paleta: color por valor.

uniform sampler2D tex_unidades : filter_nearest, repeat_disable;
uniform sampler2D tex_relieve : filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_lut : filter_nearest, repeat_disable;
uniform sampler2D tex_paleta : filter_nearest, repeat_disable;

uniform vec2 tam_mapa = vec2(8192.0, 4016.0);
uniform int lut_ancho = 256;
uniform int paleta_ancho = 1024;

// 0 = político, 1 = terreno, 2 = capa temática (religión, cultura, idioma)
uniform int modo = 0;
uniform int valor_hover = -1;
uniform int valor_sel = -1;
// Modos de capa: un valor mayor que valor_tenue es la versión tenue de (valor - valor_tenue), para las unidades sin
// entidad política registrada ese año. 0 = no se usa (modo político).
uniform int valor_tenue = 0;
uniform int unidad_sel = 0;
uniform int unidad_hover = 0;
uniform float intensidad = 0.66;

uniform bool relieve = true;
uniform bool brillo_borde = true;
uniform bool papel = true;
uniform bool olas = true;
uniform bool agua_animada = false;
uniform int muestras = 8;

uniform vec3 mar_profundo : source_color = vec3(0.075, 0.15, 0.215);
uniform vec3 mar_costa : source_color = vec3(0.22, 0.38, 0.44);
uniform vec3 linea_costa : source_color = vec3(0.09, 0.10, 0.11);
uniform vec3 color_rio : source_color = vec3(0.20, 0.36, 0.45);
uniform vec3 color_papel : source_color = vec3(0.92, 0.85, 0.70);
uniform vec3 color_seleccion : source_color = vec3(0.98, 0.84, 0.45);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

int unidad_en(vec2 uv) {
	ivec2 p = clamp(ivec2(uv * tam_mapa), ivec2(0), ivec2(tam_mapa) - ivec2(1));
	vec2 rg = texelFetch(tex_unidades, p, 0).rg;
	return int(rg.r * 255.0 + 0.5) + int(rg.g * 255.0 + 0.5) * 256;
}

int unidad_texel(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(tam_mapa) - ivec2(1));
	vec2 rg = texelFetch(tex_unidades, p, 0).rg;
	return int(rg.r * 255.0 + 0.5) + int(rg.g * 255.0 + 0.5) * 256;
}

int valor_crudo(int u) {
	vec2 rg = texelFetch(tex_lut, ivec2(u % lut_ancho, u / lut_ancho), 0).rg;
	return int(rg.r * 255.0 + 0.5) + int(rg.g * 255.0 + 0.5) * 256;
}

// El valor de la unidad sin la marca de tenue: así la selección y los bordes tratan igual a toda la familia.
int valor_de(int u) {
	int v = valor_crudo(u);
	return (valor_tenue > 0 && v > valor_tenue) ? v - valor_tenue : v;
}

vec3 color_de(int v) {
	return texelFetch(tex_paleta, ivec2(v % paleta_ancho, v / paleta_ancho), 0).rgb;
}

void fragment() {
	vec2 uv = UV;
	vec2 texel = uv * tam_mapa;
	// Texeles del mapa por píxel de pantalla: >1 lejos, <1 cerca.
	float px = max(fwidth(texel.x), 1e-4);

	vec4 rel = texture(tex_relieve, uv);
	float sd = (rel.g - 0.5) * 255.0 / 4.0;
	float aa = max(px * 0.7, 0.3);
	float es_tierra = 1.0 - smoothstep(-aa, aa, sd);

	// ---------------------------------------------------------------- Agua
	vec3 agua = mix(mar_costa, mar_profundo, smoothstep(0.0, 0.6, rel.a));
	agua = mix(agua, mar_costa * 1.18, exp(-max(sd, 0.0) / 3.5) * 0.4);
	float n = ruido(texel * 0.0035) * 0.6 + ruido(texel * 0.018) * 0.4;
	agua *= 0.92 + 0.14 * n;
	if (olas) {
		float t = agua_animada ? TIME * 0.9 : 0.0;
		float paso = 5.5;
		float d = abs(fract((sd - t) / paso) - 0.5) * paso;
		float linea = 1.0 - smoothstep(0.0, max(px * 0.9, 0.35), d);
		float atenua = smoothstep(30.0, 6.0, sd) * smoothstep(1.5, 3.5, sd) * smoothstep(3.5, 1.4, px);
		agua = mix(agua, agua * 1.25 + vec3(0.02, 0.03, 0.03), linea * atenua * 0.55);
	}

	// ---------------------------------------------------------------- Tierra
	vec3 ter = texture(TEXTURE, uv).rgb;
	// Detalle procedural: de cerca la textura del terreno se estira; un grano suave le devuelve textura.
	float cerca = 1.0 - smoothstep(0.25, 0.9, px);
	if (cerca > 0.0) {
		float det = ruido(texel * 1.7) * 0.5 + ruido(texel * 4.3) * 0.3 + ruido(texel * 11.0) * 0.2;
		ter *= 1.0 + (det - 0.5) * 0.16 * cerca;
	}
	float hs = relieve ? clamp(mix(1.0, rel.r * 2.0, 0.7), 0.4, 1.5) : 1.0;
	vec3 tierra = ter * hs;
	// Ríos: de lejos, la máscara suavizada (ríos finos); de cerca, su borde nítido.
	float an_rio = max(fwidth(rel.b) * 0.75, 0.02);
	float rio_nitido = smoothstep(0.42 - an_rio, 0.42 + an_rio, rel.b);
	float rio = mix(rio_nitido, rel.b, smoothstep(0.5, 1.4, px)) * (1.0 - smoothstep(2.5, 9.0, px));
	tierra = mix(tierra, color_rio * mix(1.0, hs, 0.3), rio * 0.85);

	// De cerca (menos de un texel por píxel), la unidad sale del voto ponderado de los cuatro texels vecinos, como en
	// una interpolación bilineal: los bordes dejan de ser escalones del ráster y pasan a ser curvas suaves. El margen
	// entre la ganadora y la segunda, dividido por dos, es la distancia al borde en texels; con eso se trazan las
	// líneas con un grosor fijo en pantalla.
	float cerca_b = 1.0 - smoothstep(0.55, 0.95, px);
	int u = 0;
	float marg_u = 9.0;
	float marg_v = 9.0;
	float w_sel_u = 0.0;
	float w_sel_v = 0.0;
	float w_hover = 0.0;
	// La unidad de tierra con más peso entre los cuatro texels: en la costa, donde el ráster dice agua pero el
	// relieve dice tierra, se usa esta en vez de buscar vecinos enteros (que dejaba la costa escalonada).
	int u_tierra = 0;
	if (cerca_b > 0.5) {
		vec2 tp = texel - 0.5;
		vec2 fl = floor(tp);
		vec2 fr = tp - fl;
		ivec2 ib = ivec2(fl);
		int us[4];
		int vs[4];
		float ws[4];
		us[0] = unidad_texel(ib);
		us[1] = unidad_texel(ib + ivec2(1, 0));
		us[2] = unidad_texel(ib + ivec2(0, 1));
		us[3] = unidad_texel(ib + ivec2(1, 1));
		ws[0] = (1.0 - fr.x) * (1.0 - fr.y);
		ws[1] = fr.x * (1.0 - fr.y);
		ws[2] = (1.0 - fr.x) * fr.y;
		ws[3] = fr.x * fr.y;
		for (int i = 0; i < 4; i++) {
			vs[i] = us[i] > 0 ? valor_de(us[i]) : -1;
		}
		float mejor = -1.0;
		for (int i = 0; i < 4; i++) {
			float w = 0.0;
			for (int j = 0; j < 4; j++) {
				w += us[j] == us[i] ? ws[j] : 0.0;
			}
			if (w > mejor) {
				mejor = w;
				u = us[i];
			}
		}
		float mejor_tierra = 0.0;
		for (int i = 0; i < 4; i++) {
			if (us[i] > 0 && ws[i] > mejor_tierra) {
				mejor_tierra = ws[i];
				u_tierra = us[i];
			}
		}
		int vu = u > 0 ? valor_de(u) : -1;
		float w_u = 0.0;
		float w_v = 0.0;
		float otra_u = 0.0;
		float otro_v = 0.0;
		for (int i = 0; i < 4; i++) {
			float wu = 0.0;
			float wv = 0.0;
			for (int j = 0; j < 4; j++) {
				wu += us[j] == us[i] ? ws[j] : 0.0;
				wv += vs[j] == vs[i] ? ws[j] : 0.0;
			}
			if (us[i] == u) {
				w_u = wu;
			} else if (us[i] > 0) {
				otra_u = max(otra_u, wu);
			}
			if (vs[i] == vu) {
				w_v = wv;
			} else if (vs[i] >= 0) {
				otro_v = max(otro_v, wv);
			}
			w_sel_u += us[i] == unidad_sel ? ws[i] : 0.0;
			w_hover += us[i] == unidad_hover ? ws[i] : 0.0;
			w_sel_v += vs[i] == valor_sel ? ws[i] : 0.0;
		}
		marg_u = otra_u > 0.0 ? w_u - otra_u : 9.0;
		marg_v = otro_v > 0.0 ? w_v - otro_v : 9.0;
	} else {
		u = unidad_en(uv);
	}
	if (u == 0 && sd < 2.0 && u_tierra > 0) {
		u = u_tierra;
	} else if (u == 0 && sd < 2.0) {
		// Franja costera donde el borde suave de la costa y el ráster de unidades no coinciden.
		vec2 d1 = vec2(1.2) / tam_mapa;
		int a = unidad_en(uv + vec2(d1.x, 0.0));
		int b = unidad_en(uv - vec2(d1.x, 0.0));
		int c = unidad_en(uv + vec2(0.0, d1.y));
		int e = unidad_en(uv - vec2(0.0, d1.y));
		u = max(max(a, b), max(c, e));
	}
	int v = u > 0 ? valor_de(u) : 0;
	bool tenue = valor_tenue > 0 && u > 0 && valor_crudo(u) > valor_tenue;

	vec3 pc = vec3(0.0);
	if (v > 0 && modo != 1) {
		pc = color_de(v);
		float k = intensidad * mix(0.5, 1.0, smoothstep(0.5, 3.0, px));
		if (tenue) {
			// Sin entidad política registrada: rayado fino del color de la familia (en la diagonal opuesta al de
			// «sin datos»), para que se distinga aunque el color se parezca al del terreno.
			float raya = step(0.62, fract((FRAGCOORD.x - FRAGCOORD.y) / 6.0));
			k *= mix(0.12, 0.75, raya);
		}
		vec3 pintado = pc * (relieve ? clamp(mix(1.0, rel.r * 2.0, 0.5), 0.55, 1.3) : 1.0);
		tierra = mix(tierra, pintado, k);
		tierra = mix(tierra, color_rio, rio * 0.5);
	} else if (modo == 0 && u > 0) {
		float g = dot(tierra, vec3(0.299, 0.587, 0.114));
		tierra = mix(tierra, vec3(g) * vec3(1.02, 0.99, 0.93), 0.4) * 0.94;
	} else if (modo == 2 && u > 0) {
		float g = dot(tierra, vec3(0.299, 0.587, 0.114));
		float rayado = step(0.5, fract((FRAGCOORD.x + FRAGCOORD.y) / 9.0));
		tierra = mix(vec3(g), vec3(g) * 0.82, rayado * 0.6);
	}

	// ---------------------------------------------------------------- Bordes
	if (u > 0) {
		float f_pais = 0.0;
		float f_prov = 0.0;
		float f_sel_u = 0.0;
		float f_sel_v = 0.0;
		float f_hover = 0.0;
		float r1 = max(1.25 * px, 0.55);
		float b_pais = 0.0;
		float b_prov = 0.0;
		float b_sel_u = 0.0;
		float b_sel_v = 0.0;
		float b_hover = 0.0;
		bool en_sel = u == unidad_sel;
		bool en_hover = u == unidad_hover;
		for (int i = 0; i < (cerca_b < 1.0 ? muestras : 0); i++) {
			float ang = 6.2831853 * (float(i) + 0.5) / float(muestras);
			vec2 o = vec2(cos(ang), sin(ang)) * r1 / tam_mapa;
			int nu = unidad_en(uv + o);
			if (nu == 0 || nu == u) {
				continue;
			}
			b_prov += 1.0;
			int nv = valor_de(nu);
			if (nv != v) {
				b_pais += 1.0;
			}
			if (en_sel != (nu == unidad_sel)) {
				b_sel_u += 1.0;
			}
			if (en_hover != (nu == unidad_hover)) {
				b_hover += 1.0;
			}
			if ((v == valor_sel) != (nv == valor_sel)) {
				b_sel_v += 1.0;
			}
		}
		float m = float(muestras);
		f_pais = smoothstep(0.0, 0.3, b_pais / m);
		f_prov = smoothstep(0.0, 0.3, b_prov / m);
		f_sel_v = smoothstep(0.0, 0.3, b_sel_v / m);
		f_hover = smoothstep(0.0, 0.35, b_hover / m);
		f_sel_u = smoothstep(0.0, 0.35, b_sel_u / m);
		if (cerca_b > 0.5) {
			// Líneas de grosor fijo en pantalla a partir de la distancia al borde (en texels). La selección y el
			// mouse solo trazan línea si el borde cae dentro de los cuatro texels.
			float hw = 0.85 * px;
			float aa = 0.55 * px;
			float n_pais = 1.0 - smoothstep(hw - aa, hw + aa, marg_v * 0.5);
			float n_prov = 1.0 - smoothstep(hw - aa, hw + aa, marg_u * 0.5);
			float hs_sel = hw * 1.5;
			float n_sel_v = (w_sel_v > 0.0 && w_sel_v < 1.0) ? 1.0 - smoothstep(hs_sel - aa, hs_sel + aa, abs(w_sel_v - 0.5)) : 0.0;
			float n_sel_u = (w_sel_u > 0.0 && w_sel_u < 1.0) ? 1.0 - smoothstep(hs_sel - aa, hs_sel + aa, abs(w_sel_u - 0.5)) : 0.0;
			float n_hover = (w_hover > 0.0 && w_hover < 1.0) ? 1.0 - smoothstep(hw - aa, hw + aa, abs(w_hover - 0.5)) : 0.0;
			float c = cerca_b < 1.0 ? (cerca_b - 0.5) * 2.0 : 1.0;
			f_pais = mix(f_pais, n_pais, c);
			f_prov = mix(f_prov, n_prov, c);
			f_sel_v = mix(f_sel_v, n_sel_v, c);
			f_sel_u = mix(f_sel_u, n_sel_u, c);
			f_hover = mix(f_hover, n_hover, c);
		}
		f_prov *= (1.0 - smoothstep(0.45, 1.1, px)) * (v > 0 ? 0.22 : 0.0);
		vec3 oscuro = (v > 0 && modo != 1) ? pc * 0.32 : vec3(0.12, 0.11, 0.1);
		tierra = mix(tierra, oscuro, f_prov);
		float fuerza_pais = modo == 1 ? 0.35 : 0.9;
		if (v > 0 || modo == 1) {
			tierra = mix(tierra, oscuro, f_pais * fuerza_pais);
		}

		if (brillo_borde && v > 0 && modo != 1) {
			// Brillo interior junto a la frontera, como en los mapas pintados a mano.
			float r3 = max(5.5 * px, 2.0);
			float cerca = 0.0;
			for (int i = 0; i < 8; i++) {
				float ang = 6.2831853 * (float(i) + 0.25) / 8.0;
				int nu = unidad_en(uv + vec2(cos(ang), sin(ang)) * r3 / tam_mapa);
				if (nu != 0 && nu != u && valor_de(nu) != v) {
					cerca += 1.0;
				}
			}
			// De cerca el brillo saldría en bloques (muestrea texels enteros): se apaga a medida que los bordes se
			// vuelven nítidos.
			float brillo = smoothstep(0.0, 0.5, cerca / 8.0) * (1.0 - f_pais) * (1.0 - cerca_b * 0.85);
			tierra = mix(tierra, pc * 1.15 + 0.05, brillo * 0.35);
		}

		if (v == valor_hover && v > 0) {
			tierra += vec3(0.05);
		}
		if (v == valor_sel && v > 0) {
			tierra = mix(tierra, tierra * 1.1 + 0.03, 0.9);
			tierra = mix(tierra, color_seleccion, f_sel_v * 0.85);
		}
		if (unidad_hover > 0) {
			tierra = mix(tierra, vec3(1.0, 0.97, 0.88), f_hover * 0.45);
		}
		if (unidad_sel > 0) {
			tierra = mix(tierra, color_seleccion, f_sel_u);
		}
	}

	// ---------------------------------------------------------------- Composición
	vec3 col = mix(agua, tierra, es_tierra);
	float costa = 1.0 - smoothstep(0.0, max(px * 0.9, 0.45), abs(sd));
	col = mix(col, linea_costa, costa * 0.6);

	if (papel) {
		// Lejos, el mapa se vuelve una lámina de papel; cerca, solo un grano leve.
		float manchas = ruido(texel * 0.0016) * 0.6 + ruido(texel * 0.007) * 0.4;
		float lejos = smoothstep(1.5, 8.0, px);
		col = mix(col, col * color_papel * 1.12, lejos * 0.35);
		col *= 1.0 + (manchas - 0.5) * 0.08 * lejos;
		col *= 1.0 + (hash(floor(FRAGCOORD.xy)) - 0.5) * 0.035;
	}
	COLOR = vec4(col, 1.0);
}
