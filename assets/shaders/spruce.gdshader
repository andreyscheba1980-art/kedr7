shader_type spatial;
// Ели: цвет — из вершин (снег на ярусах, тёмная хвоя по краю), плоские грани.
// Ветер качает дерево: чем выше вершина, тем сильнее; у каждой ели своя фаза.
// lod_near > 0: ближе этого расстояния ель рисует карточный двойник (SpruceMesh.near) — эта сжимается в точку.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float wind;
uniform float srgb_decode = 0.0;
uniform float lod_near = 0.0;

void vertex() {
	vec3 root_w = MODEL_MATRIX[3].xyz;
	float hh = max(VERTEX.y, 0.0);
	float kk = hh * hh * 0.0045 * (0.25 + wind * 1.25);
	float ph = root_w.x * 0.37 + root_w.z * 0.23;
	float sw = sin(TIME * (0.8 + wind * 1.4) + ph) + 0.35 * sin(TIME * (2.1 + wind * 2.0) + ph * 1.7);
	VERTEX.x += sw * kk;
	VERTEX.z += sw * kk * 0.55;
	if (lod_near > 0.0 && distance(CAMERA_POSITION_WORLD, root_w) < lod_near) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (srgb_decode > 0.5) {
		c = mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
