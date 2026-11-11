shader_type spatial;
// Стена бурана: кольцо вокруг станции, видна только с наветренной стороны — белёсая, клубится,
// снизу плотная, кверху тает. Чем ближе подходит (amount ↑), тем гуще.
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

uniform float amount = 0.0;
uniform float wind_angle = 0.0;     // откуда идёт буран (азимут в радианах, по UV.x кольца)
uniform vec3 tint : source_color = vec3(0.42, 0.47, 0.56);

varying float ang;

void vertex() {
	ang = atan(VERTEX.x, -VERTEX.z);    // 0 — север (−Z), по часовой — восток
}

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

void fragment() {
	float facing = cos(ang - wind_angle);
	float side = smoothstep(-0.45, 0.45, facing);
	float h = UV.y;                                    // 0 — верх, 1 — низ (CylinderMesh)
	float vert = smoothstep(0.0, 0.75, h);
	vec2 cdir = vec2(sin(ang), cos(ang));
	vec3 q1 = vec3(cdir * 6.0, h * 6.0) + vec3(TIME * 0.25, TIME * 0.2, -TIME * 0.9);
	vec3 q2 = vec3(cdir.yx * 12.0, h * 10.0) + vec3(-TIME * 0.4, -TIME * 0.3, -TIME * 1.6);
	float n = vnoise3(q1) * 0.6 + vnoise3(q2) * 0.4;
	float a = side * vert * (0.35 + 0.65 * n) * amount;
	ALBEDO = tint * (0.85 + 0.3 * n);
	ALPHA = clamp(a, 0.0, 0.92);
}
