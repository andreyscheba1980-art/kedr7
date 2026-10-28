shader_type spatial;
// Ореол лампы в морозном воздухе: мягкое круглое пятно, всегда лицом к камере.
// Раньше это была текстура с прозрачными краями — на части видеокарт альфа текстуры терялась
// и ореол рисовался квадратом. Теперь круг считается прямо в шейдере, без текстуры.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 col : source_color = vec4(1.0, 0.7, 0.4, 0.55);
uniform float strength = 1.0;   // 0 — погашен (код плавно гасит вместе с лампой)

void vertex() {
	// Биллборд: поворот как у камеры, позиция — от узла
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = a * a * (3.0 - 2.0 * a);          // мягкий край, без ступеньки
	// Затухание — прямо в цвете: в GL Compatibility сложение может игнорировать альфу
	// (из-за этого старый ореол и был квадратом), а так результат одинаков при любой схеме.
	ALBEDO = col.rgb * (col.a * a * strength);
	ALPHA = 1.0;
}
