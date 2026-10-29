shader_type spatial;
// Существа и люди: цвет вершин × оттенок × пиксельная текстура в координатах модели
// (не мира — иначе текстура «едет» по бегущему существу). Рисуем обе стороны.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform float use_tex = 0.0;
uniform float tex_scale = 0.35;
uniform float emission = 0.0;   // лёгкое свечение кожи — чтобы бледное лицо читалось в темноте
uniform float eye_glow = 0.0;   // фосфорный блеск глаз только при прямом попадании луча фонаря
uniform float alpha_scissor = 0.0; // отсечение прозрачности для лохмотьев ватника
uniform float gain = 1.0;          // предметы (Props): в тон запечённым стенам, иначе мебель — чёрные коробки

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = albedo.rgb * COLOR.rgb;
	if (use_tex > 0.5) {
		vec3 n = abs(onrm);
		vec2 uv = n.y > n.x && n.y > n.z ? opos.xz : (n.x > n.z ? opos.zy : opos.xy);
		vec4 t = texture(tex, uv / tex_scale);
		c *= t.rgb;
		if (alpha_scissor > 0.1 && t.a < 0.45) {
			discard;
		}
	}
	ALBEDO = min(c * gain, vec3(1.0));
	ROUGHNESS = 1.0;
	// Базовое свечение кожи + фосфорный блеск глаз в луче фонарика
	EMISSION = c * emission + vec3(0.65, 0.95, 0.45) * eye_glow * COLOR.g;
}
