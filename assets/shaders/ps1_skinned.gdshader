shader_type spatial;
// Существа со скелетом (модели из Блендера): запечённая текстура по UV, дрожание вершин как у PS1.
// Скиннинг Godot применяет до vertex(), поэтому снап работает по уже согнутой позе.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float emission = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = albedo.rgb * texture(tex, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	EMISSION = c * emission;
}
