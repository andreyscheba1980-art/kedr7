shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.008;
uniform float speed : hint_range(0.1, 5.0) = 2.2;

void fragment() {
	vec2 uv = SCREEN_UV;
	// Восходящие конвективные потоки горячего воздуха над плитой печи
	float wave1 = sin(uv.y * 45.0 - TIME * speed * 3.5 + uv.x * 25.0);
	float wave2 = cos(uv.y * 70.0 - TIME * speed * 5.0 - uv.x * 18.0);

	// Мягкое угасание к краям плоскости без резких границ
	vec2 edge = smoothstep(vec2(0.0), vec2(0.25), UV) * (1.0 - smoothstep(vec2(0.75), vec2(1.0), UV));
	float mask = edge.x * edge.y;

	// Тепловой шлейф затухает по мере подъёма вверх
	float fade = clamp(1.2 - UV.y * 1.1, 0.0, 1.0);

	vec2 offset = vec2(wave1 + wave2 * 0.4, wave2 - wave1 * 0.3) * distortion_strength * mask * fade;
	vec4 sc = texture(screen_tex, uv + offset);
	ALBEDO = sc.rgb;
}

