shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Бесшовная натоптанная тропа (gl_compatibility):
// В режиме blend_mix с мягкой альфой и depth_bias тропа не мерцает (z-fighting)
// и не превращается в черные полосы, а цвет гармонирует с зимней тенью снега.
uniform vec3 rut_tint : source_color = vec3(0.42, 0.48, 0.58);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float depth_bias = 0.028;

varying float v_cam_dist;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	// Лёгкий сдвиг к камере в view-space — полностью устраняет z-fighting в gl_compatibility
	vec4 vpos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist = max(length(vpos.xyz), 0.001);
	v_cam_dist = dist;
	float pull = min(depth_bias + 0.0012 * dist, dist * 0.25);
	vpos.xyz += (-vpos.xyz / dist) * pull;
	POSITION = PROJECTION_MATRIX * vpos;
}

void fragment() {
	// UV.x: 0..1 поперёк тропы; UV.y: метры вдоль тропы
	float edge = abs(UV.x - 0.5) * 2.0;
	// Неровный снежный край + две мягкие колеи от валенок по центру
	float n_edge = hash21(floor(vec2(UV.x * 10.0, UV.y * 2.6))) * 0.22;
	float mask = (1.0 - smoothstep(0.35 - n_edge, 1.0, edge)) * COLOR.a;
	// Продольные вмятины от шагов вдоль оси тропы
	float step_grain = 0.82 + 0.18 * hash21(floor(vec2(UV.x * 8.0, UV.y * 3.5)));
	float rut = 1.0 - 0.18 * smoothstep(0.0, 0.35, abs(abs(UV.x - 0.5) - 0.16));
	float dist_fade = 1.0 - smoothstep(22.0, 52.0, v_cam_dist);
	float k = clamp(mask * strength * step_grain * rut * dist_fade, 0.0, 1.0);
	ALBEDO = rut_tint;
	ALPHA = k;
}
