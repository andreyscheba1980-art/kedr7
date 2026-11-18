shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.7);
uniform float intensity = 1.0;
uniform float sharp = 2.5;

void vertex() {
	// Billboard: поворот лицом к камере
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - smoothstep(0.0, 1.0, d), 0.0, 1.0), sharp);
	ALBEDO = tint * (a * intensity);
	ALPHA = a;
}
