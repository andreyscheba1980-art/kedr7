shader_type spatial;
// Готовые CC0-модели (Kenney, KayKit) в стиле игры: их палитра приглушается и темнеет,
// поверх — пиксельная «грязь» из наших текстур в мировых координатах, чтобы яркий мультяшный
// реквизит не выпадал из обшарпанной советской станции. Вершины — с PS1-дрожью, как у всего мира.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float use_tex = 0.0;
uniform sampler2D grime : source_color, filter_nearest, repeat_enable;
uniform float use_grime = 0.0;
uniform float grime_scale = 0.6;
uniform float saturation = 0.6;
uniform float value = 0.5;
uniform float emission = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_tex > 0.5) {
		c *= texture(tex, UV).rgb;
	}
	if (use_grime > 0.0) {
		vec3 n = abs(wnrm);
		vec2 uv = n.y > n.x && n.y > n.z ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
		float l = dot(texture(grime, uv / grime_scale).rgb, vec3(0.333));
		c *= mix(1.0, 0.55 + l * 0.9, use_grime);
	}
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(lum), c, saturation);
	c = pow(c, vec3(1.4)) * value;   // пастель мультяшных паков темнеет сильнее, чем тёмные цвета
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * emission;
}
