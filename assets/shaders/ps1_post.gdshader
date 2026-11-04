shader_type canvas_item;
// Постобработка мира: яркость, легкая хроматическая аберрация к краям кадра,
// мягкое свечение ярких ламп (halation), плёночное зерно, виньетка и сплит-тонирование.
// квантизация цвета и упорядоченный дизеринг 4×4 — только в PS1-режиме.

global uniform float ps1_post;
global uniform float brightness;
uniform float levels = 32.0;
uniform float dither_amount = 0.5;   // меньше — узор дизеринга не «едет» вместе с камерой
uniform float grain = 0.045;
uniform float cold = 0.22;     // холодные тени: ночь уходит в синеву, тёплый свет остаётся тёплым
uniform float vignette = 0.38;
uniform float chromatic = 0.0032; // ретро-аберрация по краям линзы CRT

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 q = UV - 0.5;
	float d2 = dot(q, q);

	// Оптическая дисперсия линзы CRT: края кадра дают тонкую кайму без замыливания центра
	float ca = chromatic * d2;
	float r = texture(TEXTURE, UV + q * ca).r;
	float g = texture(TEXTURE, UV).g;
	float b = texture(TEXTURE, UV - q * ca).b;
	vec3 col = vec3(r, g, b) * brightness;

	// Сплит-тон: тени холоднее, светлое не трогаем.
	float l0 = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, col * vec3(0.82, 0.94, 1.16), cold * (1.0 - smoothstep(0.05, 0.5, l0)));

	// Мягкое свечение (halation) ярких огней (фонарь, окно, пламя, маяк)
	float bloom = max(0.0, l0 - 0.72);
	col += vec3(bloom * 0.14, bloom * 0.10, bloom * 0.04);

	// Советский анаморфный горизонтальный стрик (линзы «Гелиос»/«Индустар» от фар ГТ-Т, маяка, огня, ракетницы)
	vec3 streak = vec3(0.0);
	const float STREAK_OFFSETS[5] = float[5](0.0035, 0.008, 0.015, 0.024, 0.036);
	const float STREAK_WEIGHTS[5] = float[5](0.32, 0.25, 0.19, 0.14, 0.10);
	for (int i = 0; i < 5; i++) {
		float dx = STREAK_OFFSETS[i];
		float w = STREAK_WEIGHTS[i];
		vec3 s_l = texture(TEXTURE, UV - vec2(dx, 0.0)).rgb * brightness;
		vec3 s_r = texture(TEXTURE, UV + vec2(dx, 0.0)).rgb * brightness;
		float lum_l = dot(s_l, vec3(0.299, 0.587, 0.114));
		float lum_r = dot(s_r, vec3(0.299, 0.587, 0.114));
		float b_l = max(0.0, lum_l - 0.80);
		float b_r = max(0.0, lum_r - 0.80);
		streak += (s_l * b_l + s_r * b_r) * w;
	}
	col += streak * vec3(0.13, 0.16, 0.24);

	// Виньетка: края кадра темнее — взгляд тянет в центр, углы комнаты тонут.
	col *= 1.0 - vignette * smoothstep(0.25, 0.85, d2 * 2.2);

	// Зерно: сильнее в тенях, почти не видно на светлом снегу.
	float n = hash12(FRAGCOORD.xy + fract(TIME * 7.13) * 977.0) - 0.5;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col += n * grain * (1.2 - lum);

	if (ps1_post > 0.5) {
		ivec2 p = ivec2(UV * vec2(textureSize(TEXTURE, 0))) % 4;
		float bayer = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither_amount;
		col = floor(col * levels + bayer + 0.5) / levels;
	}

	COLOR = vec4(col, 1.0);
}
