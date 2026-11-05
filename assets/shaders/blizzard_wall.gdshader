shader_type spatial;
// Стена бурана: кольцо вокруг станции, видна только с наветренной стороны — белёсая, клубится,
// снизу плотная, кверху тает. Чем ближе подходит (amount ↑), тем гуще.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform float amount = 0.0;
uniform float wind_angle = 0.0;     // откуда идёт буран (азимут в радианах, по UV.x кольца)
uniform vec3 tint : source_color = vec3(0.42, 0.47, 0.56);

varying float ang;

void vertex() {
	ang = atan(VERTEX.x, -VERTEX.z);    // 0 — север (−Z), по часовой — восток
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float facing = cos(ang - wind_angle);
	float side = smoothstep(-0.45, 0.45, facing);
	float h = UV.y;                                    // 0 — верх, 1 — низ (CylinderMesh)
	float vert = smoothstep(0.0, 0.75, h);
	vec2 q = vec2(UV.x * 60.0, h * 6.0);
	float n = vnoise(q + vec2(TIME * 0.35, -TIME * 0.9)) * 0.6 + vnoise(q * 2.3 + vec2(-TIME * 0.6, -TIME * 1.6)) * 0.4;
	float a = side * vert * (0.35 + 0.65 * n) * amount;
	ALBEDO = tint * (0.85 + 0.3 * n);
	ALPHA = clamp(a, 0.0, 0.92);
}
