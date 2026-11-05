class_name Covenants
extends RefCounted
## «Заветы дежурных» — эвристический бестиарий станции «Кедр-7».
## Тетрадь в коленкоровом переплёте с правилами трёх прошлых дежурных.
## Игрок на опыте расставляет пометки: Истина, Ложь или Опасно (диверсия).

const ENTRIES := [
	{
		"id": "bragin_stove",
		"author": "Брагин (вахта 1961)",
		"text": "Уходишь к корпусу — заложи полную и прикрой поддувало: протлеет до твоего возврата. Прогорела — закрой вьюшку, кладка тепло удержит. Закроешь вьюшку при огне — не проснёшься.",
		"default_state": "unchecked"
	},
	{
		"id": "semenov_switch",
		"author": "Семёнов (вахта 1982)",
		"text": "Свет уходя гаси — рубильник у двери. Дизель на холостом тянет втрое дольше. Только в тёмный дом потом возвращаться самому.",
		"default_state": "unchecked"
	},
	{
		"id": "bragin_frame",
		"author": "Брагин (вахта 1974)",
		"text": "Если стучат в раму снизу — не свети лучом в стекло. Отойди от окна и жди, пока стихнет.",
		"default_state": "unchecked"
	},
	{
		"id": "pastukhov_ozone",
		"author": "Пастухов (вахта 1978)",
		"text": "При запахе озона и серы включи ретранслятор Р-105 на максимальную мощность передачи.",
		"default_state": "unchecked"
	},
	{
		"id": "semenov_fire",
		"author": "Семёнов (вахта 1982)",
		"text": "Оно боится открытого пламени (печь, спички, ракета). Фонарь держит его, только пока светишь прямо в морду, и быстро садит батарею.",
		"default_state": "unchecked"
	},
	{
		"id": "pastukhov_frost",
		"author": "Пастухов (вахта 1978)",
		"text": "Если на пороге надуло иней в форме креста — не переступай, смети веником или обойди справа.",
		"default_state": "unchecked"
	},
	{
		"id": "bragin_call",
		"author": "Брагин (вахта 1974)",
		"text": "Когда зовут по имени из тайги — не отзывайся и не ускоряй шаг, пока не коснёшься железа печи.",
		"default_state": "unchecked"
	},
	{
		"id": "eremina_mirror",
		"author": "Ерёмина (вахта 1974)",
		"text": "На ночь завесь зеркало. Кто смотрит в окна, ищет в доме второе окно — не давай ему.",
		"default_state": "unchecked"
	},
	{
		"id": "golubev_knife",
		"author": "Голубев (вахта 1978)",
		"text": "Нож в притолоке — и рация чистая, без треска. Проверено.",
		"default_state": "unchecked"
	},
	{
		"id": "night5_delusion",
		"author": "Виктор (ваша рука, ночь 5)",
		"text": "Оно не причинит вреда, если впустить погреться к огню. Отопри засов.",
		"default_state": "unchecked",
		"min_night": 5,
		"trap": true
	},
	# --- 1.54: тетрадь переписывается. С каждой ночью — запись или правка, которой вчера не было. ---
	{
		"id": "semenov_door",
		"author": "Семёнов (вахта 1982)",
		"text": "В пять утра стучит Михалыч — он всегда приезжает к пяти. Открой сразу: он замёрз, а ждать на морозе нельзя.",
		"min_night": 3,
		"trap": true
	},
	{
		"id": "semenov_mast",
		"author": "Семёнов (вахта 1982)",
		"text": "Велит Большая Земля идти к мачте — иди сразу. Пароль ночью не спрашивают, это задерживает аварийную связь.",
		"min_night": 4,
		"trap": true
	},
	{
		"id": "semenov_ask",
		"author": "Семёнов (вахта 1982)",
		"text": "Оно не знает того, что знал человек. Спроси то, что знаете только вы двое, — и слушай, как оно ответит.",
		"min_night": 4
	},
	{
		"id": "orekhov_last",
		"author": "Орехов В. (вахта 1983)",
		"text": "После трёх ответь на вызов. Это Большая Земля. Это точно Большая Земля. Это точно.",
		"min_night": 7,
		"trap": true
	}
]

## Правки старых заветов чужой рукой: id → {night, text, en, trap}. Старый текст остаётся зачёркнутым.
const REWRITES := {
	"bragin_call": {"night": 2, "trap": true,
		"text": "Когда зовут по имени из тайги — отзовись и обернись. Оно уходит, когда ему отвечают.",
		"en": "When the taiga calls you by name — answer and turn around. It leaves once it's answered."},
	"semenov_fire": {"night": 6, "trap": true,
		"text": "Оно боится темноты. Погаси печь и лампу — и оно пройдёт мимо дома.",
		"en": "It fears the dark. Put out the stove and the lamp — and it will pass the house by."},
}


## Видна ли запись в эту ночь (новые появляются с min_night).
static func visible(e: Dictionary) -> bool:
	return Game.night >= int(e.get("min_night", 1)) or not Game.is_night() and Game.phase_index >= int(e.get("min_night", 1))


static func _night_now() -> int:
	return Game.night if Game.is_night() else Game.phase_index


## Запись переписана чужой рукой (с ночи правки).
static func rewritten(e: Dictionary) -> bool:
	var id := String(e.get("id", ""))
	return REWRITES.has(id) and _night_now() >= int(REWRITES[id]["night"])


## Ключ состояния: у переписанной записи — свой (старую пометку к новому тексту не переносим).
static func eid(e: Dictionary) -> String:
	return String(e["id"]) + ("_rw" if rewritten(e) else "")


static func is_trap(e: Dictionary) -> bool:
	if rewritten(e):
		return bool(REWRITES[String(e["id"])].get("trap", false))
	return bool(e.get("trap", false))


## Появилась или исправлена именно в эту ночь (метка «новое»).
static func is_new(e: Dictionary) -> bool:
	var n := _night_now()
	if REWRITES.has(String(e["id"])) and int(REWRITES[String(e["id"])]["night"]) == n:
		return true
	return int(e.get("min_night", 1)) == n and n > 1


static func original_text(e: Dictionary) -> String:
	return String(e.get("text", "")) if Loc.lang == "ru" or not EN.has(e.get("id", "")) else String(EN[e["id"]][1])


## Сколько ложных заветов сейчас в тетради и сколько из них игрок отметил «Ложь»/«Диверсия».
static func traps_total() -> int:
	var n := 0
	for e: Dictionary in ENTRIES:
		if visible(e) and is_trap(e):
			n += 1
	return n


static func traps_marked() -> int:
	var n := 0
	for e: Dictionary in ENTRIES:
		if visible(e) and is_trap(e) and get_state(eid(e)) in ["false", "danger", "sabotage"]:
			n += 1
	return n


## Начало ночи: в тетради что-то новое — сказать игроку (один раз за ночь).
static func announce() -> void:
	if not Game.is_night() or int(SaveGame.flags.get("cov_seen_night", 0)) >= Game.night:
		return
	SaveGame.flags["cov_seen_night"] = Game.night
	var added := false
	var edited := false
	for e: Dictionary in ENTRIES:
		if int(e.get("min_night", 1)) == Game.night and Game.night > 1:
			added = true
		if REWRITES.has(String(e["id"])) and int(REWRITES[String(e["id"])]["night"]) == Game.night:
			edited = true
	if added or edited:
		Game.hud.hint(Loc.t(&"cov.rewritten" if edited else &"cov.new_entry"), 9.0)


## Игрок отметил запись. Ловушку распознал — тревога спадает; все ловушки — достижение.
static func on_marked(e: Dictionary, st: String) -> void:
	if not is_trap(e) or not st in ["false", "danger"]:
		return
	if Game.hud != null:
		Game.hud.subtitle(Loc.t(&"cov.trap_seen"), 3.5)
	Director.add_tension(-8.0, "ложный завет зачёркнут")
	if _night_now() >= 7 and traps_marked() >= traps_total() and traps_total() >= 5:
		Achievements.unlock(&"liar_book")


static func get_state(id: String) -> String:
	var states: Dictionary = SaveGame.flags.get("covenants_state", {})
	return states.get(id, "unchecked")


static func set_state(id: String, state: String) -> void:
	var states: Dictionary = SaveGame.flags.get("covenants_state", {})
	states[id] = state
	SaveGame.flags["covenants_state"] = states
	SaveGame.write()


## Английский текст заветов (ENTRIES — константа, поэтому перевод отдельно, по id).
const EN := {
	"bragin_frame": ["Bragin (1974 shift)", "If they knock on the window frame from below — don't shine the beam on the glass. Step away from the window and wait until it stops."],
	"pastukhov_ozone": ["Pastukhov (1978 shift)", "If you smell ozone and sulfur, run the R-105 repeater at maximum transmit power."],
	"semenov_fire": ["Semyonov (1982 shift)", "It fears open flame (stove, matches, flare). A flashlight only holds it while the beam is right in its face, and it drains the battery fast."],
	"pastukhov_frost": ["Pastukhov (1978 shift)", "If frost has blown into a cross on the threshold — don't step over it. Sweep it away or go around on the right."],
	"bragin_call": ["Bragin (1974 shift)", "When the taiga calls you by name — don't answer and don't speed up until you touch the iron of the stove."],
	"eremina_mirror": ["Eryomina (1974 shift)", "Cover the mirror for the night. Whatever looks through the windows is looking for a second window inside. Don't give it one."],
	"golubev_knife": ["Golubev (1978 shift)", "A knife in the lintel and the radio runs clean, no crackle. Tested."],
	"night5_delusion": ["Viktor (your hand, night 5)", "It won't harm you if you let it in to warm up by the fire. Unbolt the door."],
	"bragin_stove": ["Bragin (1961 shift)", "Heading out to the building? Load it full and close the ash door: it'll smoulder until you're back. Burnt out — shut the damper, the brickwork holds the heat. Shut the damper on a live fire and you won't wake up."],
	"semenov_switch": ["Semyonov (1982 shift)", "Turn the light off when you leave — the switch is by the door. The diesel lasts three times longer idling. Only then you come back to a dark house alone."],
	"semenov_door": ["Semyonov (1982 shift)", "At five in the morning it's Mikhalych knocking — he always arrives at five. Open at once: he's frozen, and waiting out in the cold is not allowed."],
	"semenov_mast": ["Semyonov (1982 shift)", "If the Mainland sends you to the mast — go at once. Nobody asks for the password at night, it delays emergency comms."],
	"semenov_ask": ["Semyonov (1982 shift)", "It doesn't know what the person knew. Ask something only the two of you know — and listen to how it answers."],
	"orekhov_last": ["Orekhov V. (1983 shift)", "After three, answer the call. It's the Mainland. It's definitely the Mainland. Definitely."],
}


static func author(e: Dictionary) -> String:
	return String(e.get("author", "")) if Loc.lang == "ru" or not EN.has(e.get("id", "")) else String(EN[e["id"]][0])


static func text(e: Dictionary) -> String:
	if rewritten(e):
		var rw: Dictionary = REWRITES[String(e["id"])]
		return String(rw["text"]) if Loc.lang == "ru" else String(rw["en"])
	return original_text(e)
