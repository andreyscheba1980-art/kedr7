shader_type spatial;
// Объёмный конус света фонаря (рассеяние света в морозном воздухе, взвеси и метели)
// Additive-блендинг добавляет мягкий тёплый свет в темноте, френель убирает полигональные грани.
render_mode blend_add, cull_disabled, unshaded, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 beam_color : source_color = vec3(1.0, 0.94, 0.82);
uniform float intensity : hint_range(0.0, 1.0) = 0.16;
uniform float z_far = 7.5;
uniform float z_near = 0.15;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	// Мягкий френель: к краям конуса луч плавно тает, не создавая жестких полигональных рёбер
	vec3 v_dir = normalize(VIEW);
	vec3 n_dir = normalize(v_nrm);
	float fresnel = pow(clamp(1.0 - abs(dot(n_dir, v_dir)), 0.0, 1.0), 1.6);
	
	// Осевой спад вдоль луча (от линзы фонаря вдаль)
	float dist = -v_pos.z;
	float span = z_far - z_near;
	float t = clamp((dist - z_near) / span, 0.0, 1.0);
	float falloff = (1.0 - t) * (1.0 - t);
	
	// Мягкое появление у самого стекла (чтобы не слепило перед глазами)
	float near_fade = smoothstep(z_near, z_near + 0.35, dist);
	
	float a = intensity * fresnel * falloff * near_fade;
	ALBEDO = beam_color;
	ALPHA = clamp(a, 0.0, 1.0);
}

