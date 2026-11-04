shader_type spatial;
// Ель вблизи: лапы-карточки с хвоей и снежные шапки поверх (атлас 2×2, альфа-срез).
// Цвет вершины — тон яруса; ветер качает лапы сильнее у кончиков (UV.x в пределах клетки атласа).
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_disabled;

global uniform float wind;
global uniform float ps1_snap;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float lod_far = 0.0;   // > 0: дальше этого ель рисует гранёный двойник (SpruceMesh.mesh)

varying float tipk;
varying float snowk;      // 1 — снежная шапка (клетка атласа справа сверху), 0 — хвоя
varying vec3 spark_n;
varying float spark;

void vertex() {
	vec3 root_w = MODEL_MATRIX[3].xyz;
	float hh = max(VERTEX.y, 0.0);
	float kk = hh * hh * 0.0045 * (0.25 + wind * 1.25);
	float ph = root_w.x * 0.37 + root_w.z * 0.23;
	float sw = sin(TIME * (0.8 + wind * 1.4) + ph) + 0.35 * sin(TIME * (2.1 + wind * 2.0) + ph * 1.7);
	tipk = fract(UV.x * 2.0);
	// кончики лап вздрагивают отдельно от ствола
	float flick = sin(TIME * (2.6 + wind * 3.0) + ph * 3.1 + VERTEX.y * 2.3) * tipk * tipk * 0.05 * (0.3 + wind);
	VERTEX.x += sw * kk + flick;
	VERTEX.z += sw * kk * 0.55 + flick * 0.6;
	VERTEX.y += flick * 0.5;
	if (lod_far > 0.0 && distance(CAMERA_POSITION_WORLD, root_w) > lod_far) {
		VERTEX = vec3(0.0);
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(atlas, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 1.0;
	// изнанка лапы темнее — снизу под ель свет почти не попадает
	if (!FRONT_FACING) { ALBEDO *= 0.6; }
	snowk = step(0.5, UV.x) * step(UV.y, 0.5);
	// искры наста на шапках: редкие клетки со своей микронормалью
	vec2 cell = floor(UV * 420.0);
	spark = step(0.985, hash2(cell)) * snowk;
	spark_n = normalize((VIEW_MATRIX * vec4(normalize(vec3(hash2(cell + 7.0) - 0.5, 1.4, hash2(cell + 19.0) - 0.5)), 0.0)).xyz);
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	// мягкое «обёрнутое» освещение: лапа — не плоскость, свет заходит и с краёв
	DIFFUSE_LIGHT += clamp(nl * 0.7 + 0.3, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	// хвоя на просвет: против солнца/фонаря края лап светятся зеленовато-золотым
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * (1.0 - snowk);
	DIFFUSE_LIGHT += back * vec3(0.55, 0.75, 0.35) * 0.55 * ATTENUATION * LIGHT_COLOR / PI;
	if (spark > 0.5) {
		SPECULAR_LIGHT += pow(max(dot(reflect(-LIGHT, spark_n), VIEW), 0.0), 120.0) * 4.0 * ATTENUATION * LIGHT_COLOR;
	}
}
