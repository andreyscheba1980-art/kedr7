shader_type spatial;
// Руки от первого лица и предмет в руках: глубина сжимается к ближней плоскости, поэтому руки
// всегда перед миром (не уходят в стены), а между собой сортируются как обычно. Цвет вершин ×
// текстура в координатах модели, как у существ; собственное свечение — чтобы руки читались в темноте.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;
uniform float depth_scale = 0.02;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float use_tex = 0.0;
uniform float tex_scale = 0.35;
uniform float emission = 0.0;
// Модели из Блендера: запечённая текстура по UV (цвет × AO) вместо триплана
uniform sampler2D uv_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float use_uv = 0.0;
uniform float uv_gain = 1.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

void fragment() {
	vec3 c = albedo.rgb * COLOR.rgb;
	if (use_uv > 0.5) {
		c = albedo.rgb * texture(uv_tex, UV).rgb * uv_gain;
	} else if (use_tex > 0.5) {
		vec3 n = abs(onrm);
		vec2 uv = n.y > n.x && n.y > n.z ? opos.xz : (n.x > n.z ? opos.zy : opos.xy);
		c *= texture(tex, uv / tex_scale).rgb;
	}
	ALBEDO = c;
	DEPTH = 1.0 - (1.0 - FRAGCOORD.z) * depth_scale;   // обратная глубина: 1 — ближняя плоскость
	ROUGHNESS = 1.0;
	EMISSION = c * emission;
}
