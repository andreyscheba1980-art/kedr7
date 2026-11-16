shader_type spatial;
// Иней на стекле: растёт от краёв к центру, когда дом остывает (coverage 0..1), и тает, когда печь горит.
// R текстуры — «очередь» зарастания (0 у края, 1 в центре, с шумом), G — прожилки-папоротник.
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert, specular_disabled;

uniform sampler2D frost_tex : filter_linear_mipmap;
uniform float coverage = 0.25;
uniform vec3 tint : source_color = vec3(0.82, 0.9, 1.0);
uniform vec2 clear_center = vec2(-1.0);   // точка, протёртая рукавом
uniform float clear_radius = 0.0;

void fragment() {
	vec4 t = texture(frost_tex, UV);
	float a = smoothstep(t.r - 0.07, t.r + 0.02, coverage);
	a *= mix(0.5, 1.0, t.g);
	if (clear_radius > 0.0) {
		a *= smoothstep(clear_radius, clear_radius + 0.06, distance(UV, clear_center));
	}
	ALBEDO = tint;
	ALPHA = a * 0.9;
	ROUGHNESS = 0.6;
	EMISSION = vec3(0.05, 0.07, 0.1) * a;   // чуть подсвечен — видно и в тёмной комнате
}
