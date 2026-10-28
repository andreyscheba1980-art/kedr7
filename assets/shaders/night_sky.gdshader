shader_type sky;
// Ночное небо тайги: светящийся бирюзовый горизонт, тёмный индиго в зените, луна (по направлению
// лунного света), звёзды и два слоя гранёных горных хребтов — дальний светлее, ближний темнее.
// Всё — функция направления взгляда, без геометрии: горы «на бесконечности», не дают параллакса.

uniform vec3 top_color : source_color = vec3(0.012, 0.03, 0.065);
uniform vec3 horizon_color : source_color = vec3(0.13, 0.27, 0.34);
uniform vec3 below_color : source_color = vec3(0.03, 0.06, 0.08);
uniform vec3 far_ridge : source_color = vec3(0.075, 0.15, 0.2);
uniform vec3 near_ridge : source_color = vec3(0.035, 0.07, 0.1);
uniform vec3 moon_color : source_color = vec3(0.85, 0.92, 1.0);
uniform float moon_size = 0.9991;      // косинус углового радиуса диска
uniform float star_amount = 1.0;
uniform float cloud_amount = 0.5;       // 1 — метель, неба почти не видно
uniform float aurora = 0.0;             // северное сияние: 0 — нет, 1 — во всё небо (ясные ночи)
uniform vec3 aurora_tint : source_color = vec3(0.2, 0.95, 0.55);
uniform vec3 aurora_top : source_color = vec3(0.45, 0.25, 0.6);   // верх шторы — лиловый

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Плавный «значный» шум 0..1 — для волнистого края и лучей сияния.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float e = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

// Треугольная волна: гранёные склоны вместо синусоидальных холмов.
float tri(float x) {
	return abs(fract(x) - 0.5) * 2.0;
}

float ridge(float az, float base, float amp, float seed) {
	float h = 0.0;
	h += tri(az * 0.55 + seed) * 1.0;
	h += tri(az * 1.7 + seed * 2.3) * 0.45;
	h += tri(az * 4.1 + seed * 5.1) * 0.18;
	return base + amp * h / 1.63;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	float az = atan(d.x, d.z) / 6.2831853 * 6.0;
	vec3 col = mix(horizon_color, top_color, pow(smoothstep(-0.02, 0.75, el), 0.7));

	// Звёзды: редкие, тусклее у горизонта и в метель.
	vec3 sp = d * 220.0;
	vec3 cell = floor(sp);
	float h = hash(cell);
	if (h > 0.9965) {
		float dist = length(fract(sp) - 0.5);
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		col += vec3(0.55, 0.62, 0.75) * smoothstep(0.32, 0.0, dist) * tw * star_amount
			* smoothstep(0.08, 0.35, el) * (1.0 - cloud_amount);
	}

	// Луна: диск + два ореола (узкий и широкий), видна сквозь лёгкую дымку.
	if (LIGHT0_ENABLED) {
		float m = dot(d, LIGHT0_DIRECTION);
		float vis = 1.0 - cloud_amount * 0.75;
		col += moon_color * smoothstep(moon_size - 0.00012, moon_size, m) * 1.2 * vis;
		col += moon_color * pow(max(m, 0.0), 500.0) * 0.45 * vis;
		col += horizon_color * pow(max(m, 0.0), 10.0) * 0.8 * vis;
	}

	// Северное сияние: не кольцо вокруг горизонта, а одна-две «шторы» на севере. Нижний край —
	// резкий и волнистый (шум), вверх свет тает и уходит из зелёного в лиловый; лучи — шумом, не синусом.
	if (aurora > 0.001 && el > 0.02) {
		float ang = atan(d.x, -d.z);                      // 0 — север, ±π — юг (там сияния нет)
		float sector = smoothstep(-0.15, 0.75, cos(ang));
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float u = ang * 1.5 + fi * 2.7;
			float wig = (vnoise(vec2(u * 1.2 + TIME * 0.025, fi * 7.0)) - 0.5) * 0.16
				+ (vnoise(vec2(u * 4.5 - TIME * 0.04, fi * 3.0 + 11.0)) - 0.5) * 0.05;
			float base = 0.2 + fi * 0.09 + wig;
			float hgt = el - base;
			float bottom = smoothstep(-0.012, 0.018, hgt);
			float top = exp(-max(hgt, 0.0) * (3.6 + fi * 2.5));
			float r = vnoise(vec2(u * 26.0, TIME * 0.12 + fi * 9.0));
			float rays = 0.35 + 0.65 * r * r;
			float fold = smoothstep(0.25, 0.85, vnoise(vec2(u * 1.7 - TIME * 0.015, 5.0 + fi * 4.0)));
			float a = bottom * top * rays * fold;
			vec3 c = mix(aurora_tint, aurora_top, smoothstep(0.03, 0.22, hgt));
			acc += c * a * (1.0 - fi * 0.35);
		}
		col += acc * aurora * 0.42 * sector * (1.0 - cloud_amount) * smoothstep(0.02, 0.12, el);
	}

	// Хребты: дальний — в дымке почти цвета горизонта, ближний — темнее.
	float r1 = ridge(az, 0.035, 0.11, 0.3);
	float r2 = ridge(az + 1.37, 0.0, 0.075, 1.9);
	if (el < r1) {
		col = mix(far_ridge, horizon_color, 0.35 * smoothstep(0.0, r1, el));
	}
	if (el < r2) {
		col = near_ridge;
	}
	if (el < -0.01) {
		col = mix(near_ridge, below_color, smoothstep(-0.01, -0.2, el));
	}
	// Метель: всё небо затягивает мутью цвета горизонта.
	col = mix(col, horizon_color * 0.85, cloud_amount * 0.55);
	COLOR = col;
}
