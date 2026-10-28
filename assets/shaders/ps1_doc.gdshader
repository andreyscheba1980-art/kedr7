shader_type canvas_item;
// Аутентичный PS1-дизеринг и пикселизация для интерфейсов приборов и журналов:
// Приводит 2D-интерфейс к единой низкополигональной сетке мира (пиксель-в-пиксель с игрой).

uniform float pixel_size = 2.0;         // 2x пиксели для аутентичного PS1 масштаба
uniform float levels = 32.0;
uniform float dither_amount = 0.40;
uniform float grain = 0.035;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 grid_uv = floor(UV * (tex_size / pixel_size)) / (tex_size / pixel_size);

	vec4 col = texture(TEXTURE, grid_uv);

	// Зерно бумаги и пленки
	float n = hash12(FRAGCOORD.xy + fract(TIME * 4.0) * 811.0) - 0.5;
	col.rgb += n * grain;

	// Упорядоченный дизеринг Байера 4×4
	ivec2 p = ivec2(FRAGCOORD.xy / pixel_size) % 4;
	float bayer = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither_amount;
	col.rgb = floor(col.rgb * levels + bayer + 0.5) / levels;

	COLOR = col;
}
