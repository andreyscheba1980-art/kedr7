shader_type spatial;
// Иней на стекле: растёт от краёв к центру, когда дом остывает (coverage 0..1), и тает, когда печь горит.
// R текстуры — «очередь» зарастания (0 у края, 1 в центре, с шумом), G — прожилки-папоротник.
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert, specular_disabled;

uniform sampler2D frost_tex : filter_linear_mipmap;
uniform float coverage = 0.25;
uniform vec3 tint : source_color = vec3(0.82, 0.9, 1.0);
uniform vec2 clear_center = vec2(-1.0);   // точка, протёртая рукавом
uniform float clear_radius = 0.0;
uniform float hand_reveal : hint_range(0.0, 1.0) = 0.0;   // отпечаток ладони снаружи при сильном холоде
uniform vec2 hand_uv = vec2(0.54, 0.46);

float _ellipse(vec2 p, vec2 c, vec2 r, float ang) {
	vec2 d = p - c;
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 q = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) / r;
	return 1.0 - smoothstep(0.65, 1.08, length(q));
}

float _hand_mask(vec2 uv) {
	vec2 p = (uv - hand_uv) * vec2(1.0, 1.15);
	float m = 0.0;
	// Ладонь и основание кисти
	m = max(m, _ellipse(p, vec2(0.0, 0.055), vec2(0.068, 0.072), 0.06));
	// Пять растопыренных пальцев, прижатых снаружи к стеклу
	m = max(m, _ellipse(p, vec2(-0.088, 0.015), vec2(0.022, 0.058), 0.62));
	m = max(m, _ellipse(p, vec2(-0.044, -0.068), vec2(0.017, 0.066), 0.22));
	m = max(m, _ellipse(p, vec2(-0.002, -0.084), vec2(0.017, 0.074), 0.02));
	m = max(m, _ellipse(p, vec2(0.038, -0.072), vec2(0.016, 0.068), -0.16));
	m = max(m, _ellipse(p, vec2(0.072, -0.044), vec2(0.014, 0.052), -0.34));
	return clamp(m, 0.0, 1.0);
}

void fragment() {
	vec4 t = texture(frost_tex, UV);
	float a = smoothstep(t.r - 0.07, t.r + 0.02, coverage);
	a *= mix(0.5, 1.0, t.g);
	if (clear_radius > 0.0) {
		a *= smoothstep(clear_radius, clear_radius + 0.06, distance(UV, clear_center));
	}
	vec3 col = tint;
	vec3 em = vec3(0.05, 0.07, 0.1) * a;
	if (hand_reveal > 0.01) {
		float hm = _hand_mask(UV) * hand_reveal;
		// В месте прижатия ладони снаружи иней подтаивает в тёмный влажный силуэт с белой кромкой
		float rim = smoothstep(0.18, 0.45, hm) * (1.0 - smoothstep(0.55, 0.85, hm));
		a = mix(a, max(a * 0.24, 0.14), hm * 0.85);
		col = mix(col, vec3(0.28, 0.34, 0.44), hm * 0.65);
		col += vec3(0.22, 0.26, 0.32) * rim;
		em += vec3(0.08, 0.10, 0.14) * rim;
	}
	ALBEDO = col;
	ALPHA = a * 0.9;
	ROUGHNESS = 0.6;
	EMISSION = em;   // чуть подсвечен — видно и в тёмной комнате
}
