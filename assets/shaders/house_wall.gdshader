shader_type spatial;
// Стены дома: как на советских станциях — снизу крашеная масляной краской панель с полосой,
// сверху побелка; в жилой комнате (x < 3.5) — бревенчатые стены. Всё по мировым координатам,
// поэтому одна правка материала меняет весь дом. PS1-снап и трипланар — как в ps1.gdshader.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float tex_scale = 1.6;
uniform vec3 panel_col : source_color = vec3(0.24, 0.33, 0.33);
uniform vec3 stripe_col : source_color = vec3(0.36, 0.13, 0.1);
uniform vec3 white_col : source_color = vec3(0.54, 0.53, 0.48);
uniform vec3 log_col : source_color = vec3(0.42, 0.29, 0.18);
uniform float panel_h = 1.15;
uniform float log_x = 3.5;

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
	vec3 n = abs(wnrm);
	vec2 uv;
	if (n.y > n.x && n.y > n.z) {
		uv = wpos.xz;
	} else if (n.x > n.z) {
		uv = vec2(wpos.z, -wpos.y);
	} else {
		uv = vec2(wpos.x, -wpos.y);
	}
	vec3 t = texture(tex, uv / tex_scale).rgb * 1.35;
	float grain = dot(t, vec3(0.333));
	vec3 c;
	if (n.y > 0.5) {
		c = white_col * t;                                   // торцы и верх блоков
	} else if (wpos.x < log_x && wpos.z > -0.2) {
		// Сруб: брёвна по 24 см, тёмные пазы с паклей, каждое бревно чуть своего тона
		float band = wpos.y / 0.24;
		float f = fract(band);
		float round_k = 0.62 + 0.38 * sin(f * 3.14159);
		float seam = smoothstep(0.0, 0.07, f) * smoothstep(1.0, 0.93, f);
		float tone = 0.88 + 0.12 * fract(sin(floor(band) * 12.9898) * 43758.5453);
		c = log_col * tone * round_k * mix(0.35, 1.0, seam) * mix(0.8, 1.15, grain);
	} else if (wpos.y < panel_h) {
		c = panel_col * t;
	} else if (wpos.y < panel_h + 0.045) {
		c = stripe_col * t;
	} else {
		// Побелка не ровная: разводы и пятна (текстура штукатурки), потёки сверху вниз,
		// копоть под потолком и серость у панели — стена старая, а не «пластик»
		float streak = texture(tex, vec2(uv.x * 0.37, uv.y * 0.05) / tex_scale).r;
		float soot = smoothstep(2.0, 2.55, wpos.y) * 0.25;
		float low = (1.0 - smoothstep(panel_h, panel_h + 0.5, wpos.y)) * 0.12;
		c = white_col * mix(0.62, 1.08, grain) * mix(0.9, 1.04, streak) * (1.0 - soot - low);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
