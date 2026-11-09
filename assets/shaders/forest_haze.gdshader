shader_type spatial;
// Морозная дымка между рядами елей: открытые цилиндры вокруг станции. Густая у земли, тает кверху,
// рвётся по кругу шумом, исчезает вблизи камеры (не видно «стены», когда проходишь сквозь слой).
// Слои на разном радиусе дают лесу глубину: дальние ели тонут в лунном молоке ступенями.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 haze_col : source_color = vec3(0.1, 0.17, 0.22);
uniform float strength = 0.35;
uniform float height = 9.0;

varying vec3 wpos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(wpos.y / height, 0.0, 1.0);
	float vert = (1.0 - h) * (1.0 - h);
	vec2 cdir = normalize(vec2(wpos.x - 20.0, wpos.z + 5.0));
	vec3 np1 = vec3(cdir * 3.5, wpos.y * 0.18) + vec3(TIME * 0.01, TIME * 0.008, 0.0);
	vec3 np2 = vec3(cdir.yx * 7.0, wpos.y * 0.35) - vec3(TIME * 0.006, TIME * 0.005, 0.0);
	float rag = (vnoise3(np1) * 0.6 + vnoise3(np2) * 0.4) * 0.6 + 0.4;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near_fade = smoothstep(6.0, 22.0, dist);
	ALBEDO = haze_col;
	ALPHA = strength * vert * rag * near_fade;
}
