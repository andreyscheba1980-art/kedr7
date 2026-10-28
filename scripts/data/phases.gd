class_name Phases
extends RefCounted
## Данные фаз: ночи и дни. Время — минуты от base_hour (ночь — от 20:00, день — от 14:00).
## Пулы испугов задаются в самих ScareDef (поле nights); здесь — темп, ресурсы, Ырка, сигналы, финалы.

const NIGHTS := {
	1: {
		"start_min": 120,              ## 22:00
		"reports": [240, 360],         ## 00:00, 02:00 (после трёх Большой Земле не отвечают)
		"min_per_sec": 0.45,           ## 22:00 → 06:00 ≈ 18 минут
		"base_rate": 0.38, "peak": 62.0, "max_hard": 0,
		"yrka_max": 2,                 ## 0 — нет, 1 — свист, 2 — шаги, 3 — глаза, 4 — погоня
		"antenna_ice": false,
		"signals": [&"mainland", &"buzzer", &"numbers"],
		"gen_start": 80.0, "stove_start": 70.0, "canisters": 3,
		"first_blizzard": 300.0,
		"finale": &"",
		"radio_ghost": 300,            ## 01:00 — рация сама ловит голос Семёнова (фирменная сцена ночи 1)
	},
	2: {
		"start_min": 120,
		"reports": [240, 360],
		"min_per_sec": 0.45,
		"base_rate": 0.52, "peak": 56.0, "max_hard": 1,
		"yrka_max": 3,  ## ночь 2: зов и глаза, но без погони — урок правил
		"antenna_ice": false,
		"signals": [&"mainland", &"buzzer", &"numbers", &"semenov", &"morse"],
		"gen_start": 65.0, "stove_start": 55.0, "canisters": 3,
		"first_blizzard": 200.0,
		"finale": &"",
		"roof_steps": 330,             ## 01:30 — кто-то ходит по крыше (фирменная сцена ночи 2)
	},
	3: {
		"start_min": 120,
		"reports": [240, 360],
		"min_per_sec": 0.45,
		"base_rate": 0.6, "peak": 55.0, "max_hard": 2,
		"yrka_max": 4,
		"antenna_ice": true,
		"signals": [&"mainland", &"buzzer", &"code", &"semenov", &"morse", &"lullaby", &"alone"],
		"gen_start": 55.0, "stove_start": 45.0, "canisters": 4,
		"first_blizzard": 150.0,
		"finale": &"door_knock",       ## 05:00 — стук в дверь. Откроешь — смерть, переждёшь — утро
		"roll_call": 330,              ## 01:30 — перекличка: за Кедр-7 отвечает кто-то другой (фирменная сцена)
		"orders": [[290, &"real_report"], [445, &"fake_report"]],   ## учит паролю: настоящий — с «Бирюсой», ложный — без
	},
	4: {
		"start_min": 120,
		"reports": [240, 360],
		"min_per_sec": 0.45,
		"base_rate": 0.62, "peak": 55.0, "max_hard": 2,
		"yrka_max": 4,
		"antenna_ice": false,
		"signals": [&"mainland", &"numbers", &"mother", &"morse", &"alone", &"code"],
		"gen_start": 60.0, "stove_start": 50.0, "canisters": 4,
		"first_blizzard": 200.0,
		"finale": &"",
		"knocks": [200, 330],          ## Обмирало у двери (минуты смены)
		"false_order": 438,            ## 03:18, сразу после удара 03:10 — «Большая Земля» велит идти к мачте (правило 2)
		"footprints": 250,             ## после 00:10 — пока ты на улице, по избе проходят босые следы (фирменная сцена)
		"orders": [[265, &"real_check"]],
	},
	5: {
		"start_min": 120,
		"reports": [240, 360],
		"min_per_sec": 0.45,
		"base_rate": 0.66, "peak": 54.0, "max_hard": 2,
		"yrka_max": 4,
		"antenna_ice": true,
		"signals": [&"mainland", &"roll", &"otzvuk", &"lullaby", &"alone", &"code"],
		"gen_start": 70.0, "stove_start": 45.0, "canisters": 3,
		"first_blizzard": 150.0,
		"finale": &"",
		"knocks": [380],
		"gen_break": 250,              ## 00:10 — генератор ломается, нужны инструменты
		"paralysis": 470,              ## 03:50 — Полуночница
		"underfloor": 448,             ## 03:28, после удара 03:10 — гул и стук под полом, снизу — твоя же сводка (фирменная сцена)
		"orders": [[225, &"real_report"], [340, &"fake_door_wrong"]],   ## ложный — до трёх и с «Бирюзой»
	},
	6: {
		"start_min": 120,
		"reports": [240, 360],
		"min_per_sec": 0.45,
		"base_rate": 0.72, "peak": 52.0, "max_hard": 3,
		"yrka_max": 4,
		"antenna_ice": true,
		"signals": [&"mainland", &"mother", &"roll", &"otzvuk", &"semenov", &"alone", &"code"],
		"gen_start": 55.0, "stove_start": 40.0, "canisters": 3,
		"first_blizzard": 100.0,
		"finale": &"",
		"knocks": [170, 300, 450],
		"door_blow": 360,              ## 02:00 — дверь распахивает ветром, Ырка может войти
		"yrka_house": true,
		"lights": 400,                 ## 02:40 — фары у зимника, Михалыч зовёт из метели (фирменная сцена)
		"orders": [[230, &"real_check"], [275, &"fake_report_wrong"]],
	},
	7: {
		"start_min": 120,
		"reports": [240],
		"min_per_sec": 0.45,
		"base_rate": 0.75, "peak": 52.0, "max_hard": 3,
		"yrka_max": 4,
		"antenna_ice": false,
		"signals": [&"mainland", &"mother", &"roll", &"otzvuk", &"echo", &"alone"],
		"gen_start": 65.0, "stove_start": 55.0, "canisters": 3,
		"first_blizzard": 220.0,
		"finale": &"choice",           ## с 03:00 — зов; выбрать: ответить, сжечь, уйти
		"knocks": [300],
		"yrka_house": true,
		"orders": [[300, &"fake_report_clean"]],   ## пароль верный, но эфир мёртвый и слова — как запись
	},
}

const DAYS := {
	0: {"prologue": true, "start_min": 0, "end_min": 0, "dusk_end_min": 0, "min_per_sec": 0.0},
	1: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18}, ## 14:00 → 17:30 (20 мин) + до 18:30 сумерки
	2: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18},
	3: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18},
	4: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18},
	5: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18},
	6: {"prologue": false, "start_min": 0, "end_min": 210, "dusk_end_min": 270, "min_per_sec": 0.18},
}

const LAST_NIGHT := 7


static func night(n: int) -> Dictionary:
	return NIGHTS.get(n, NIGHTS[LAST_NIGHT])


static func day(n: int) -> Dictionary:
	return DAYS.get(n, DAYS[1])
