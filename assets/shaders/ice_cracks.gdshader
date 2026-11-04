shader_type spatial;
// Трещины по наледи растут от центра: R текстуры — линия, G — «когда» она появляется (0 — сразу,
// 1 — последней). grow 0..1 открывает их по очереди; свежий край трещины светится.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D tex : filter_linear_mipmap;   // без source_color: G — данные, не цвет
uniform float grow = 0.0;
uniform vec3 line_color : source_color = vec3(0.62, 0.74, 0.86);

void fragment() {
	vec4 t = texture(tex, UV);
	float when = t.g;
	float open = smoothstep(when - 0.02, when, grow);
	float fresh = smoothstep(when + 0.06, when, grow) * open;
	ALBEDO = line_color * (1.0 + fresh * 1.5);
	ALPHA = t.r * open;
}
