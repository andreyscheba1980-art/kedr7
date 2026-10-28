shader_type canvas_item;
// Аутентичный шейдер построчной термопечати советского фототелеграфа «Нева-МТ» (ИСЗ «Метеор-2»):
// Квантование до 16 градаций серого, горизонтальный джиттер строк, аналоговый шум,
// построчная протяжка ленты (progress) и бегущая светящаяся термоголовка (head).

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float levels = 16.0;
uniform float noise_amt = 0.08;
uniform float jitter = 0.003;
uniform bool ir_mode = false;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * 240.0);
	// Горизонтальный микро-дрейф строк и джиттер барабана
	uv.x += (h(vec2(row, floor(TIME * 8.0))) - 0.5) * jitter;
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Считывание яркости из текстуры термоснимка
	vec4 src = texture(TEXTURE, uv);
	float g = src.r;

	// ИК-режим: инверсия яркости и усиление контраста холодных ядер
	if (ir_mode) {
		g = 1.0 - g;
	}

	// Аналоговый шум термобумаги
	g += (h(uv * vec2(320.0, 240.0) + fract(TIME * 2.0)) - 0.5) * noise_amt;

	// Квантование до 16 градаций серого (ГОСТ советского фототелеграфа)
	g = floor(clamp(g, 0.0, 1.0) * levels + 0.5) / levels;

	// Построчное появление снимка сверху вниз (протяжка термоголовки)
	float shown = step(uv.y, progress);
	float head = (progress < 0.999) ? (smoothstep(progress - 0.018, progress, uv.y) * shown) : 0.0;

	// Палитра советской электрохимической термобумаги
	// Обычный спектр: тёмно-коричневые/графитовые чернила на бумаге
	// ИК-спектр: тёмно-синий/индиго фон с ярко-голубыми/белыми тепловыми зонами
	vec3 dark_tone = ir_mode ? vec3(0.05, 0.08, 0.15) : vec3(0.12, 0.09, 0.07);
	vec3 light_tone = ir_mode ? vec3(0.85, 0.92, 1.00) : vec3(0.84, 0.80, 0.70);
	vec3 paper = mix(dark_tone, light_tone, g);

	// Нераспечатанная часть ленты — чистая рулонная термобумага
	vec3 blank_paper = ir_mode ? vec3(0.07, 0.09, 0.12) : vec3(0.74, 0.70, 0.60);
	vec3 out_col = mix(blank_paper, paper, shown);

	// Свечение горячей термоголовки в точке протяжки
	vec3 head_glow = ir_mode ? vec3(0.5, 0.8, 1.0) : vec3(1.0, 0.72, 0.30);
	out_col += head_glow * head * 0.40;

	// Микроструктура строк термопечати (горизонтальная линовка)
	float scanline = sin(uv.y * 240.0 * 3.14159) * 0.5 + 0.5;
	out_col *= 0.94 + 0.06 * scanline;

	COLOR = vec4(out_col, 1.0);
}
