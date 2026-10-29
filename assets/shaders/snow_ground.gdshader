shader_type spatial;
// Снег двора: как ps1.gdshader (снап вершин, мировая текстура, крупный слой против повторов),
// плюс заструги — ветровые волны в нормали (видны в косом свете фонаря и луны), плюс блеск наста:
// редкие «кристаллы» со своей микронормалью вспыхивают в луче, когда угол совпал.
render_mode blend_mix, depth_draw_opaque, cull_back;

global uniform float ps1_snap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tex_scale = 3.0;
uniform float macro = 0.55;
uniform vec2 wind_dir = vec2(0.8, 0.6);     // заструги вытянуты поперёк ветра
uniform float sastrugi = 0.35;
uniform float glitter = 1.0;

varying vec3 wpos;
varying vec3 wnrm;        // нормаль рельефа: на склонах сопок свет ложится по склону
varying vec3 v_spark;      // xyz — случайная микронормаль кристалла (вид), 0 — не кристалл
varying float v_is_spark;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec3 t = texture(tex, uv / tex_scale).rgb * 1.35;
	float big = dot(texture(tex, uv / (tex_scale * 7.3) + vec2(0.37, 0.71)).rgb, vec3(0.333));
	t *= mix(1.0, big, macro);

	// Заструги: волны поперёк ветра, с изгибами шума; дают наклон нормали (свет ложится полосами)
	vec2 wd = normalize(wind_dir);
	vec2 cross_d = vec2(-wd.y, wd.x);
	float bend = vnoise(uv * 0.08) * 6.0;
	float ph = dot(uv, wd) * 1.35 + bend + vnoise(uv * 0.5) * 1.5;
	float amp = sastrugi * smoothstep(0.25, 0.75, vnoise(uv * 0.05 + 3.0));
	float slope = cos(ph) * amp;
	vec3 n_world = normalize(wnrm + vec3(wd.x * slope, 0.0, wd.y * slope) + vec3(cross_d.x, 0.0, cross_d.y) * slope * 0.2);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float crest = smoothstep(0.6, 1.0, sin(ph)) * amp;
	ALBEDO = albedo.rgb * t * (1.0 + crest * 0.25);
	ROUGHNESS = 1.0;

	// Кристаллы наста: ~0.7 % клеток 3×3 см, у каждой своя наклонённая микронормаль
	vec2 cell = floor(uv * 32.0);
	float h = hash2(cell);
	v_is_spark = step(0.993, h) * glitter
		* (1.0 - smoothstep(5.0, 12.0, length(wpos - CAMERA_POSITION_WORLD)));   // искры видны только у ног, вдали — не «конфетти»
	vec3 rnd = vec3(hash2(cell + 17.0), 1.6, hash2(cell + 41.0)) - vec3(0.5, 0.0, 0.5);
	v_spark = normalize((VIEW_MATRIX * vec4(normalize(rnd), 0.0)).xyz);
}

void light() {
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	if (v_is_spark > 0.5) {
		float s = pow(max(dot(reflect(-LIGHT, v_spark), VIEW), 0.0), 140.0);
		SPECULAR_LIGHT += s * 5.0 * ATTENUATION * LIGHT_COLOR;
	}
}
