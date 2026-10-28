shader_type canvas_item;
// Спектрограмма магнитофона: бегущий шум по частотам (низ — низкие), полоса пропускания ярче,
// чем выше clarity, тем меньше шума.

uniform float low_cut = 0.0;
uniform float high_cut = 1.0;
uniform float clarity = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float f = 1.0 - UV.y;
	vec2 cell = floor(vec2(UV.x * 160.0 + TIME * 40.0, UV.y * 90.0));
	float n = hash(cell) * (0.6 + 0.4 * hash(cell + 17.0));
	float band = step(low_cut, f) * step(f, high_cut);
	float noise = n * mix(0.18, 1.0, band) * (1.0 - clarity * 0.75);
	vec3 col = mix(vec3(0.02, 0.05, 0.03), vec3(0.35, 1.0, 0.55), noise);
	float grid = step(0.98, fract(f * 8.0)) * 0.15;
	COLOR = vec4(col + grid, 1.0);
}
