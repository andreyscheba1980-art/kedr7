shader_type spatial;
render_mode unshaded;

uniform float tune : hint_range(0.0, 1.0) = 0.0;   // 1 = точно на частоте

void fragment() {
	vec2 p = UV - 0.5;
	float ang = abs(atan(p.x, -p.y));                // 0 вверху
	float wedge = mix(1.35, 0.06, tune);             // тень сужается при точной настройке
	float lit = step(ang, PI - wedge * 0.5);         // светящийся сектор
	float r = smoothstep(0.5, 0.42, length(p));
	vec3 g = mix(vec3(0.02, 0.1, 0.05), vec3(0.3, 1.0, 0.45), lit);
	ALBEDO = g;
	EMISSION = g * (1.0 + 1.5 * tune);
	ALPHA = r;
}
