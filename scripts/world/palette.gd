class_name Palette
extends RefCounted
## Общие материалы. Твёрдые поверхности — PS1-шейдер (дрожание вершин + пиксельные текстуры в мировых
## координатах), свечения и стекло — обычные материалы. Всё кэшируется и делится между узлами.

const PS1_SHADER := "res://assets/shaders/ps1.gdshader"
const TEX_DIR := "res://assets/textures/"

const COLORS := {
	&"wall": Color(0.33, 0.37, 0.32),      # советская масляная краска
	&"floor": Color(0.18, 0.14, 0.10),     # тёмный тёсаный пол (без оранжевого сока)
	&"ceiling": Color(0.40, 0.38, 0.35),
	&"snow": Color(0.48, 0.58, 0.68),      # холодный сине-серый снег тайги
	&"drift": Color(0.44, 0.53, 0.63),
	&"wood": Color(0.20, 0.16, 0.12),      # заветренная тёмная сибирская сосна
	&"plank": Color(0.17, 0.14, 0.11),
	&"weathered": Color(0.42, 0.38, 0.33),  # серые выветренные доски лодочного сарая
	&"log_round": Color(0.36, 0.26, 0.19),   # круглые брёвна сруба
	&"log_end": Color(0.62, 0.48, 0.33),     # торцы брёвен — светлый срез
	&"trim_paint": Color(0.34, 0.5, 0.54),   # выцветшая голубая краска наличников
	&"log": Color(0.27, 0.2, 0.15),        # тёмные брёвна сруба (чуть светлее — в тени луны стены не должны сливаться с ночью)
	&"dark": Color(0.06, 0.06, 0.06),
	&"metal": Color(0.25, 0.27, 0.28),
	&"radio": Color(0.22, 0.27, 0.23),
	&"white": Color(0.78, 0.78, 0.74),
	&"tree": Color(0.05, 0.08, 0.06),
	&"bark": Color(0.12, 0.09, 0.07),
	&"red": Color(0.5, 0.06, 0.04),
	&"cloth": Color(0.28, 0.3, 0.38),
	&"stove": Color(0.56, 0.53, 0.49),
	&"rope": Color(0.45, 0.4, 0.3),
	&"ice": Color(0.7, 0.8, 0.88),
	&"canister": Color(0.25, 0.32, 0.18),
	&"paper": Color(0.82, 0.78, 0.66),
	&"vehicle": Color(0.27, 0.33, 0.24),
	&"skin": Color(0.42, 0.42, 0.4),
	&"concrete": Color(0.4, 0.4, 0.38),
	&"lake": Color(0.42, 0.5, 0.58),
	&"water": Color(0.01, 0.02, 0.03),
	&"rust": Color(0.48, 0.22, 0.12),
}

## Текстура и сколько метров на один её повтор.
const TEXTURES := {
	&"wall": ["tex_plaster.png", 1.6],
	&"ceiling": ["tex_plaster.png", 2.0],
	&"floor": ["tex_planks.png", 1.2],
	&"plank": ["tex_planks.png", 1.0],
	&"weathered": ["tex_planks.png", 1.1],
	&"wood": ["tex_wood.png", 0.8],
	&"log": ["tex_logs.png", 1.2],
	&"log_round": ["tex_bark.png", 0.9],
	&"log_end": ["tex_wood.png", 0.35],
	&"trim_paint": ["tex_planks.png", 0.8],
	&"snow": ["tex_snow.png", 3.0],
	&"drift": ["tex_snow.png", 3.0],
	&"tree": ["tex_needles.png", 1.5],
	&"bark": ["tex_bark.png", 0.6],
	&"metal": ["tex_metal.png", 0.8],
	&"stove": ["tex_stove.png", 0.8],
	&"concrete": ["tex_concrete.png", 1.6],
	&"lake": ["tex_snow.png", 5.0],
	&"cloth": ["tex_cloth.png", 0.8],
	&"fur": ["tex_fur.png", 0.6],
	&"skin": ["tex_skin.png", 0.8],
	&"rust": ["tex_rust.png", 0.8],
}

## Крупная вариация поверх тайла (та же текстура в ~7 раз крупнее) — гасит повторы на больших площадях.
const MACRO := {
	&"snow": 0.55, &"drift": 0.55, &"lake": 0.45, &"wall": 0.3, &"ceiling": 0.3,
	&"concrete": 0.4, &"floor": 0.2, &"plank": 0.15, &"weathered": 0.3, &"tree": 0.35,
}

const GLOWS := {
	&"amber": Color(1.0, 0.62, 0.2),
	&"bulb": Color(1.0, 0.92, 0.75),
	&"red": Color(1.0, 0.1, 0.05),
	&"eyes": Color(0.95, 0.9, 0.7),
	&"white": Color(0.92, 0.94, 0.98),
}

static var _cache: Dictionary = {}


static func m(key: StringName) -> Material:
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	if key == &"wall":
		# Стены дома: панель + полоса + побелка, в жилой комнате — сруб (assets/shaders/house_wall.gdshader)
		mat.shader = load("res://assets/shaders/house_wall.gdshader")
		mat.set_shader_parameter(&"tex", load(TEX_DIR + "tex_plaster.png"))
		_cache[key] = mat
		return mat
	mat.shader = load(PS1_SHADER)
	mat.set_shader_parameter(&"albedo", COLORS.get(key, Color.MAGENTA))
	if TEXTURES.has(key):
		var t: Array = TEXTURES[key]
		mat.set_shader_parameter(&"tex", load(TEX_DIR + String(t[0])))
		mat.set_shader_parameter(&"use_tex", 1.0)
		mat.set_shader_parameter(&"tex_scale", float(t[1]))
		mat.set_shader_parameter(&"macro", float(MACRO.get(key, 0.0)))
	if key == &"floor":
		mat.render_priority = 1
	_cache[key] = mat
	return mat


## Светящийся (unshaded) материал. no_fog — пробивает туман (глаза в темноте леса).
static func glow(key: StringName, no_fog := false) -> StandardMaterial3D:
	var ck := StringName("glow_%s_%s" % [key, no_fog])
	if _cache.has(ck):
		return _cache[ck]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = GLOWS.get(key, Color.MAGENTA)
	mat.disable_fog = no_fog
	_cache[ck] = mat
	return mat


static func glass() -> StandardMaterial3D:
	if _cache.has(&"glass"):
		return _cache[&"glass"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.65, 0.75, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	_cache[&"glass"] = mat
	return mat
