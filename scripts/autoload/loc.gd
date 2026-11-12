extends Node
## Локализация RU/EN. Строки лежат в Strings.S (scripts/loc/strings.gd): ключ → [ru, en].
## Так они попадают в экспорт без отдельного импорта и правятся в одном месте.

signal language_changed

const LANGS: Array[String] = ["ru", "en"]
const StringsClass = preload("res://scripts/loc/strings.gd")

var lang := "ru"
var _idx := 0


func set_language(l: String) -> void:
	if not LANGS.has(l) or l == lang:
		return
	lang = l
	_idx = LANGS.find(l)
	language_changed.emit()


## Строка по ключу. args — подстановка через % (как у String).
func t(key: StringName, args: Array = []) -> String:
	var entry: Variant = StringsClass.S.get(key)
	if entry == null:
		entry = StoryStrings.S.get(key)   # сюжетный патч 1.54 — отдельным словарём
	if entry == null:
		push_warning("Loc: нет строки '%s'" % key)
		return String(key)
	var pair: Array = entry
	var s: String = String(pair[_idx]) if _idx < pair.size() else ""
	if s == "" and pair.size() > 0:
		s = String(pair[0])
	s = s if args.is_empty() else s % args
	if not Settings.keybinds.is_empty() and s.contains("["):
		s = _real_keys(s)
	return s


## Клавиши в подсказках — те, что выбрал игрок (Настройки → Клавиши): «[E]» → «[F]», если «действие» на F.
## Трогаем только переназначенные действия и только внутри квадратных скобок.
const _KEY_TOKENS := {"E": &"interact", "F": &"flashlight", "Q": &"crank", "G": &"drop", "Tab": &"tasks", "M": &"map",
	"B": &"codebook", "R": &"transmit", "T": &"record", "V": &"flare", "J": &"intercepts", "C": &"coop_talk",
	"Space": &"hold_breath", "Пробел": &"hold_breath", "Shift": &"sprint", "H": &"whistle"}
var _key_re: RegEx


func _real_keys(s: String) -> String:
	if _key_re == null:
		_key_re = RegEx.create_from_string("\\[([^\\]]{1,20})\\]")
	var out := ""
	var last := 0
	for m in _key_re.search_all(s):
		out += s.substr(last, m.get_start() - last)
		var inner := m.get_string(1)
		var parts := inner.split(" ")
		for i in range(parts.size()):
			var tok := parts[i]
			if _KEY_TOKENS.has(tok) and Settings.keybinds.has(String(_KEY_TOKENS[tok])):
				parts[i] = OS.get_keycode_string(int(Settings.keybinds[String(_KEY_TOKENS[tok])]) as Key)
		out += "[" + " ".join(parts) + "]"
		last = m.get_end()
	return out + s.substr(last)


func has_key(key: StringName) -> bool:
	return StringsClass.S.has(key) or StoryStrings.S.has(key)


## Пара прямо в коде: Loc.p("Закрыть", "Close"). Для разовых строк интерфейса, которым не нужен ключ.
## Пара запоминается — при смене языка уже показанный текст переводится на лету (см. retranslate).
var _pairs: Dictionary = {}   ## текст на любом языке → [ru, en]


func p(ru: String, en: String) -> String:
	if not _pairs.has(ru):
		var pair := [ru, en]
		_pairs[ru] = pair
		_pairs[en] = pair
	return ru if _idx == 0 else en


## Смена языка посреди игры: подписи, кнопки, 3D-таблички и подсказки предметов, созданные раньше,
## переводятся по обратному словарю (строки таблицы + все пары Loc.p). Окна с подстановками
## (%d, %s) перерисовываются сами — они обновляют текст каждый кадр или при открытии.
var _rev_built := false


func _ready() -> void:
	language_changed.connect(_on_language_changed)


func _build_rev() -> void:
	_rev_built = true
	for k: StringName in StringsClass.S:
		var pair: Array = StringsClass.S[k]
		for s: Variant in pair:
			if s is String and not (s as String).contains("%") and not _pairs.has(s):
				_pairs[s] = pair


func _on_language_changed() -> void:
	if not _rev_built:
		_build_rev()
	var tree := get_tree()
	if tree != null and tree.root != null:
		retranslate(tree.root)
		for c: Node in tree.get_nodes_in_group(&"lang_redraw"):
			if c is CanvasItem:
				(c as CanvasItem).queue_redraw()
			var vp := c.get_parent() as SubViewport
			if vp != null:
				vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _swap(s: String) -> String:
	var pair: Variant = _pairs.get(s)
	if pair == null:
		return s
	var arr: Array = pair
	return String(arr[_idx]) if _idx < arr.size() else s


func retranslate(root: Node) -> void:
	for n: Node in root.find_children("*", "", true, false):
		if n is Label or n is Button or n is RichTextLabel or n is Label3D:
			var cur: String = n.get(&"text")
			var nw := _swap(cur)
			if nw != cur:
				n.set(&"text", nw)
		elif n is Interactable:
			var it := n as Interactable
			it.prompt = _swap(it.prompt)
		if n.has_method(&"on_language_changed"):
			n.call(&"on_language_changed")
