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
		"min_night": 5
	}
]


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
}


static func author(e: Dictionary) -> String:
	return String(e.get("author", "")) if Loc.lang == "ru" or not EN.has(e.get("id", "")) else String(EN[e["id"]][0])


static func text(e: Dictionary) -> String:
	return String(e.get("text", "")) if Loc.lang == "ru" or not EN.has(e.get("id", "")) else String(EN[e["id"]][1])
