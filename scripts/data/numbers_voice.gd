class_name NumbersVoice
extends RefCounted
## Голос цифровых станций (Victoria): из слов num_* собираются фразы для «numbers», «code» и «control».
## Если нужного слова нет в assets/voice, сигнал звучит по-старому (numbers_loop.ogg).

const DIGIT := ["num_0", "num_1", "num_2", "num_3", "num_4", "num_5", "num_6", "num_7", "num_8", "num_9"]
## Фрагменты «numbers» — те же, что в субтитрах sig.numbers.1..3. Фраза без хоть одного слова пропускается.
const NUMBERS_LINES := [["num_7", "num_0", "num_4"], ["num_kedr", "num_kedr", "num_7"], ["num_1", "num_1", "num_9", "num_0"]]
const GAP_WORD := 0.32
const GAP_GROUP := 0.85
const MAX_PARTS := 64

static var _cache: Dictionary = {}


## Озвученный поток для сигнала или null — тогда используется stream из Signals.
static func stream_for(id: StringName) -> AudioStream:
	match id:
		&"numbers":
			if not _cache.has(id):
				_cache[id] = _numbers()
			return _cache[id]
		&"code":
			var key := "code_" + Settings.language
			if not _cache.has(key):
				_cache[key] = _code(Signals.code_groups(Settings.language))
			return _cache[key]
		&"control":
			if Game.tasks != null and Game.tasks.control_group != "":
				return _control(Game.tasks.control_group)
	return null


static func stream_or_default(id: StringName) -> AudioStream:
	var s := stream_for(id)
	return s if s != null else AudioDirector.cached_stream(String(Signals.get_def(id)["stream"]))


## Цифры, для которых есть голос (контрольная группа задания берётся только из них).
static func digit_pool() -> Array[int]:
	var out: Array[int] = []
	for d in 10:
		if Voice.has(StringName(DIGIT[d])):
			out.append(d)
	return out


static func _numbers() -> AudioStream:
	var seq: Array = []
	for line: Array in NUMBERS_LINES:
		if _all(line):
			seq.append(line)
	if seq.is_empty():
		return null
	var head: Array = ["num_attention"] if Voice.has(&"num_attention") else []
	return _build(head, seq, 2.5)


static func _code(groups: PackedStringArray) -> AudioStream:
	var seq := _digit_groups(groups)
	if seq.is_empty() or not _all(["num_attention", "num_groups"]):
		return null
	# Повтор не влезает в плейлист (до 64 частей), да и шифровка длинная — один проход.
	return _build(["num_attention", "num_groups"], seq, 3.0)


static func _control(group: String) -> AudioStream:
	var seq := _digit_groups(PackedStringArray([group.replace("-", "")]))
	if seq.is_empty() or not _all(["num_groups", "num_repeat"]):
		return null
	return _build(["num_groups"], [seq[0], ["num_repeat"], seq[0]], 3.0)


## "0417" → [["num_0","num_4","num_1","num_7"]]; пустой массив, если какой-то цифры нет.
static func _digit_groups(groups: PackedStringArray) -> Array:
	var out: Array = []
	for g in groups:
		var words: Array = []
		for ch in g:
			if ch < "0" or ch > "9":
				continue
			words.append(DIGIT[int(ch)])
		if not _all(words):
			return []
		out.append(words)
	return out


static func _all(words: Array) -> bool:
	for w in words:
		if not Voice.has(StringName(w)):
			return false
	return true


## head — вступление, groups — группы слов: внутри группы короткая пауза, между группами длинная.
static func _build(head: Array, groups: Array, tail: float) -> AudioStream:
	var parts: Array[AudioStream] = [_silence(0.6)]
	for w in head:
		parts.append(load(Voice.path(StringName(w))) as AudioStream)
		parts.append(_silence(GAP_GROUP))
	for g: Array in groups:
		for i in g.size():
			parts.append(load(Voice.path(StringName(g[i]))) as AudioStream)
			parts.append(_silence(GAP_WORD if i < g.size() - 1 else GAP_GROUP))
	parts.append(_silence(tail))
	if parts.size() > MAX_PARTS:
		parts.resize(MAX_PARTS)
	var pl := AudioStreamPlaylist.new()
	pl.loop = false
	pl.fade_time = 0.0
	pl.stream_count = parts.size()
	for i in parts.size():
		pl.set_list_stream(i, parts[i])
	return pl


static func _silence(sec: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	var d := PackedByteArray()
	d.resize(int(sec * 22050.0) * 2)
	w.data = d
	return w
