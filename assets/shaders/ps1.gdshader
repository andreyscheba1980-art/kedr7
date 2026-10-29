shader_type spatial;
// PS1-вид: дрожание вершин (снап к сетке экрана) и мировой «трипланар» без смешивания —
// текстуры не растягиваются на больших блоках и остаются пиксельными.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

global uniform float ps1_snap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float use_tex = 0.0;
uniform float tex_scale = 1.0;
uniform float macro = 0.0;     // доля «крупного» слоя: ломает видимые повторы тайла

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// POSITION пишем всегда: если шейдер задаёт его хоть в одной ветке, Godot перестаёт
	// считать позицию сам, и вершины без записи улетают в ноль.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// Снапаем только вершины перед камерой: вершины за спиной при обрезке тащат за собой
	// весь треугольник, и текстура «плывёт» вместе с игроком.
	if (ps1_snap > 0.0 && clip.w > 1.0) {
		vec2 grid = vec2(ps1_snap, ps1_snap * 0.5625);
		clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (use_tex > 0.5) {
		vec3 n = abs(wnrm);
		vec2 uv;
		if (n.y > n.x && n.y > n.z) {
			uv = wpos.xz;
		} else if (n.x > n.z) {
			uv = vec2(wpos.z, -wpos.y);
		} else {
			uv = vec2(wpos.x, -wpos.y);
		}
		vec3 t = texture(tex, uv / tex_scale).rgb * 1.35;   // текстуры тёмные сами по себе — без подъёма дом проваливается в черноту
		if (macro > 0.0) {
			// Тот же рисунок в 7.3 раза крупнее и со сдвигом: размывает сетку повторов.
			float big = dot(texture(tex, uv / (tex_scale * 7.3) + vec2(0.37, 0.71)).rgb, vec3(0.333));
			t *= mix(1.0, big, macro);
		}
		c *= t;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
