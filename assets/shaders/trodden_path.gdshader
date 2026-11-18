shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec3 col : source_color = vec3(0.30, 0.37, 0.46);
uniform float alpha = 0.45;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += NORMAL * (0.008 + 0.0007 * length(vp));   // против z-fighting
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = col * COLOR.rgb;
	ALPHA = alpha * COLOR.a * (1.0 - smoothstep(0.35, 1.0, d));
}
