class_name Books
extends RefCounted
## Книги и бумаги станции — читаются в руках (BookUI). Только лор: на механику не влияют
## (код сейфа — из дневника Голубева, это часть тайника).
## style: &"hand" — от руки (почерк), &"type" — машинопись, &"print" — типография, &"news" — газета.
## marks: &"secret" — штамп «секретно», &"frost" — иней на страницах, &"burnt" — опалённый край.
## Страница — строка; «|» в начале строки — заголовок/подпись крупнее.

const DATA := {
	&"bragin": {
		"style": &"hand", "marks": [], "cover": Color(0.32, 0.22, 0.14),
		"title": ["Дневник А. С. Брагина, 1961", "A. S. Bragin's diary, 1961"],
		"ru": [
			"|Брагин А. С.\n|станция «Кедр», 1961\n\nНачальство велело вести записи «для себя». Записываю для себя. Привезли на ГТТ, разгрузились, водитель уехал, не попив чаю. Говорит, на Лозьве к ночи не останавливаются. Станция новая, пахнет краской и смолой. Печь тянет.",
			"8 октября. Первая сводка ушла в 00:00. Свердловск принял, похвалил за чистый эфир. В 03:10 стрелки на щите дёрнулись все разом, как будто по полу кто-то ударил кувалдой снизу. Барограф чиркнул до края. Записал: «помеха».",
			"11 октября. Опять 03:10. Опять снизу. Взял лом, простучал пол в жилой. Под половицами пусто, а стук отвечает. Я стукнул два раза — снизу два. Я три — снизу три. Решил выкопать подпол. Если там вода или пустота — надо знать.",
			"19 октября. Подпол вырыл. Земля мёрзлая на штык, дальше — сухая, тёплая. Тёплая, в октябре, на Северном Урале. Банки с огурцами поставил туда — не мёрзнут. Это хорошо. Стук тише, но теперь он не отвечает. Теперь он начинает первым.",
			"2 ноября. Свердловск сказал: «Кедр, сводки не прерывать ни при каких условиях». Я спросил — почему. Ответили: «приказ». В ту ночь я проспал сводку на сорок минут. Проснулся от того, что в подполе кто-то поднимался по ступенькам. Ступенек у меня три. Он дошёл до второй.",
			"Я заколотил крышку изнутри дома гвоздями-двухсотками. Сверху поставил сундук. Сундук теперь не трогать.\n\nЕсли ты читаешь это в подполе — значит, сундук уже трогали. Тогда слушай: передавай. Всегда передавай. Пока говоришь ты — оно молчит.",
		],
		"en": [
			"|Bragin A. S.\n|Kedr station, 1961\n\nThe bosses told me to keep notes \"for myself\". So, for myself. Brought here by tracked carrier, unloaded, the driver left without his tea. Says on the Lozva you don't stop after dark. The station is new, smells of paint and pitch. The stove draws well.",
			"8 October. First report went out at 00:00. Sverdlovsk took it, praised the clean air. At 03:10 every needle on the panel jumped at once, as if someone hit the floor from below with a sledgehammer. The barograph scratched to the edge. Wrote it down: \"interference\".",
			"11 October. 03:10 again. From below again. Took a crowbar, tapped the floor in the living room. Empty under the boards, yet the knocking answers. I knocked twice — twice from below. Three times — three from below. Decided to dig a cellar. If it's water or a hollow — I need to know.",
			"19 October. Dug the cellar. Frozen for one spade's depth, then dry and warm. Warm, in October, in the North Urals. Put the pickle jars down there — they don't freeze. That's good. The knocking is quieter, but it no longer answers. Now it starts first.",
			"2 November. Sverdlovsk said: \"Kedr, do not interrupt the reports under any circumstances.\" I asked why. They said: \"orders\". That night I overslept a report by forty minutes. Woke because someone in the cellar was climbing the steps. I have three steps. It got to the second.",
			"I nailed the lid shut from inside the house with two-hundred-millimetre nails. Put the trunk on top. The trunk is not to be touched now.\n\nIf you are reading this in the cellar, the trunk has already been moved. Then listen: transmit. Always transmit. While you are speaking, it stays quiet.",
		],
	},
	&"golubev": {
		"style": &"hand", "marks": [&"frost"], "cover": Color(0.18, 0.26, 0.3),
		"title": ["Дневник А. А. Голубева, 1979", "A. A. Golubev's diary, 1979"],
		"ru": [
			"|Голубев А. А.\n|вахта 1979\n\n14 ноября. Сменил Пастухова — точнее, его место. Самого Пастухова никто не видел с весны, вещи его на станции, валенки у печи. В корпусе мне отвели кабинет у восточной стены. Окно заколочено. Говорят, «чтобы не дуло».",
			"20 ноября. Окно заколочено не от ветра. За досками — не улица. Я сегодня поддел одну доску: там темно и тепло, и пахнет моей квартирой в Ивделе. Духами Тамары. Прибил доску обратно.",
			"27 ноября. Сейф в кабинете перекодировал на Надин день рождения — двадцать второе июля. Пусть хоть что-то здесь будет её. Внутри отчёт, который мне нельзя было читать. Я прочитал. Теперь понятно, зачем нас держат по одному.",
			"3 декабря. Свердловск по рации называет меня Пастуховым. Я поправляю — они не слышат. Вчера в 03:10 сам себе продиктовал сводку. Голос был мой, а я молчал. Тамара пишет, что я звонил ей в октябре. Я в октябре был в Ивделе, у неё на кухне. Значит, звонил не я.",
			"7 декабря. Я заложу эту комнату. Здесь всё моё: стол, чай, календарь. Пусть оно думает, что я здесь. Кирпич возьму из котельной, раствор на снегу схватится. Если меня не будет — не открывайте. Если откроете — не садитесь за стол. Стул тёплый.",
			"8 декабря, 03:09\n\nОно ходит по коридору и зовёт меня Надиным голосом. Папа, папа, открой, я замёрзла. Я знаю, что это не она. Я знаю. Я сейчас допишу и\n\n\n\n(дальше — только иней на странице)",
		],
		"en": [
			"|Golubev A. A.\n|watch of 1979\n\n14 November. Relieved Pastukhov — or rather, took his place. Nobody has seen Pastukhov since spring; his things are here, his felt boots by the stove. In the building they gave me the office by the east wall. The window is boarded up. \"Against the draught\", they say.",
			"20 November. The window isn't boarded against the wind. Behind the boards there is no outside. Today I prised one board loose: it is dark and warm behind it, and it smells of my flat in Ivdel. Of Tamara's perfume. I nailed the board back.",
			"27 November. Reset the office safe to Nadya's birthday — the twenty-second of July. Let at least something here be hers. Inside is a report I was not supposed to read. I read it. Now I understand why they keep us here one at a time.",
			"3 December. Sverdlovsk calls me Pastukhov over the radio. I correct them — they don't hear. Yesterday at 03:10 I dictated a report to myself. The voice was mine, and I was silent. Tamara writes that I phoned her in October. In October I was in Ivdel, in her kitchen. So it wasn't me who phoned.",
			"7 December. I am going to wall this room up. Everything here is mine: the desk, the tea, the calendar. Let it think I'm here. I'll take bricks from the boiler room; mortar sets fast on snow. If I'm gone, don't open it. If you do, don't sit at the desk. The chair is warm.",
			"8 December, 03:09\n\nIt walks the corridor calling me in Nadya's voice. Daddy, daddy, open up, I'm cold. I know it isn't her. I know. I'll just finish this and\n\n\n\n(the rest of the page is only frost)",
		],
	},
	&"vahta": {
		"style": &"hand", "marks": [], "cover": Color(0.3, 0.12, 0.1),
		"title": ["Вахтенный журнал корпуса (выдержки)", "Building watch log (excerpts)"],
		"ru": [
			"|ВАХТЕННЫЙ ЖУРНАЛ\n|корпус ст. «Кедр-7», т. 4\n\n12.03.1964. Шар-пилот ушёл в облачность на 400 м. Теодолитом взял две точки, потом шар пошёл вниз против ветра. Списал на ошибку наблюдения. — Ходырев",
			"02.04.1964. Шар опять опустился. Сел у ограды площадки. Внутри оболочки — иней изнутри и отпечаток ладони. Маленькой. — Ходырев\n\n05.04.1964. — Ходырев\n\n06.04.1964. — Ходырев\n\n(дальше подписи одна за другой, без записей, до конца страницы)",
			"14.09.1969. Заступил Пастухов Г. И. Предыдущий дежурный выбыл. Вещи переданы по описи: валенки 1 пара, ватник 1, шапка 1, ложка 1. Ложек в ящике шесть. — Пастухов",
			"01.02.1974. Ерёмина Т. В. Пишу карандашом — ручки в корпусе все сломаны пополам. Аккуратно, по шву, будто кто-то пытался посмотреть, что внутри. В архиве пахнет мокрой шерстью. Собаки на станции нет.",
			"19.11.1981. Семёнов. Корпус на ночь не оставляю без света. Если дизель встал — в корпус не заходить до утра, сводку передать из дома по данным с площадки. Кто в темноте стоит в аппаратной у пульта — не дежурный.",
			"07.12.1982. Лазарев.\n\n07.12.1982. Лазарев.\n\n07.12.1982. Лазарев.\n\n(одна и та же запись, одной рукой, на всю страницу — и на следующей, и дальше)",
		],
		"en": [
			"|WATCH LOG\n|building, Kedr-7, vol. 4\n\n12.03.1964. Pilot balloon went into the cloud at 400 m. Took two points with the theodolite, then the balloon came down against the wind. Put it down to an observation error. — Khodyrev",
			"02.04.1964. The balloon came down again. Landed by the plot fence. Inside the envelope — frost on the inside and a handprint. A small one. — Khodyrev\n\n05.04.1964. — Khodyrev\n\n06.04.1964. — Khodyrev\n\n(signatures one after another, no entries, to the bottom of the page)",
			"14.09.1969. Pastukhov G. I. on duty. Previous operator removed. Belongings handed over by inventory: felt boots 1 pair, quilted jacket 1, hat 1, spoon 1. There are six spoons in the drawer. — Pastukhov",
			"01.02.1974. Eryomina T. V. Writing in pencil — every pen in the building is snapped in half. Neatly, along the seam, as if someone wanted to see what was inside. The archive smells of wet wool. There is no dog at the station.",
			"19.11.1981. Semyonov. I never leave the building dark overnight. If the diesel stops, don't enter the building until morning; send the report from the house using the plot readings. Whoever stands in the dark by the panel in the instrument room is not the duty officer.",
			"07.12.1982. Lazarev.\n\n07.12.1982. Lazarev.\n\n07.12.1982. Lazarev.\n\n(the same entry, in the same hand, over the whole page — and the next one, and on)",
		],
	},
	&"permyakov": {
		"style": &"print", "marks": [], "cover": Color(0.25, 0.28, 0.2),
		"title": ["Н. Пермяков. Поверья верховий Лозьвы", "N. Permyakov. Beliefs of the upper Lozva"],
		"ru": [
			"|Н. ПЕРМЯКОВ\n|ПОВЕРЬЯ ВЕРХОВИЙ ЛОЗЬВЫ\n|Записки этнографа. Свердловск, 1931\n\nСобрано среди манси и русских старожилов от Ивделя до перевала. Записано со слов, без поправок. Многое рассказчики просили не печатать. Печатаю, потому что они умерли.",
			"|ЫРКА\n\nНочной дух, «тот, кто окликает». Ходит по тайге после заката, зовёт голосами знакомых. Кто отзовётся — тот его. Не любит огня и железа: «пока у печи — не тронет». На порог дома не ступает, если в доме говорят. Старики: «молчащий дом он считает пустым».",
			"|ПОДМЕНЫШ (у русских — «двойник»)\n\nПриходит под видом своего — сына, соседа, ушедшего охотника. Стучит, просит открыть. Узнать можно: не знает того, что знал бы живой; шея длиннее, чем помнишь; глаза не моргают. Манси: «спроси его о том, о чём вы говорили вдвоём, — он ответит твоими же словами».",
			"|ЖЕРДЯЙ\n\nВысокий, тонкий, «в полторы ели». Стоит на кромке леса и смотрит в окна. Ничего не делает, пока на него не смотришь долго. Кто долго смотрел — у того «вытягивается дорога»: идёт домой и не доходит. Совет один — не смотреть, задёрнуть окно, не выходить.",
			"|СУСЕДКО\n\nДомовой, хозяин избы. Добрый, если кормить: корку хлеба на печь, и не браниться в доме. Обиженный — ходит босиком по ночам, прячет вещи, давит на грудь. Кто живёт один, тот с суседком должен «договориться», иначе тот уйдёт — и дом станет пустым для всех, кто снаружи.",
			"|ПОЛУНОЧНИЦА · ОБМИРАЛО · МАТЬ ИЗ ПРОРУБИ\n\nПолуночница садится на грудь спящему, не даёт ни крикнуть, ни встать; спасение — проснуться самому. Обмирало стучит в дом и притворяется мёртвым под дверью; откроешь — он «оживает». Мать из проруби зовёт сына голосом матери из-подо льда. Ни одному не отвечать.\n\n|Последнее\n\nВсе рассказчики говорили одно: «у Нави на Лозьве есть ухо». Где оно — не сказали. Показали на север, за перевал.",
		],
		"en": [
			"|N. PERMYAKOV\n|BELIEFS OF THE UPPER LOZVA\n|An ethnographer's notes. Sverdlovsk, 1931\n\nCollected among the Mansi and old Russian settlers from Ivdel to the pass. Written down as told, without corrections. Many tellers asked me not to print this. I print it because they have died.",
			"|YRKA\n\nA night spirit, \"the one who calls out\". Walks the taiga after sunset calling in the voices of people you know. Whoever answers is his. Dislikes fire and iron: \"by the stove he won't touch you\". Won't step on a threshold if people are talking inside. The old ones: \"a silent house he counts as empty\".",
			"|THE CHANGELING (the Russians say \"the double\")\n\nComes in the shape of one of your own — a son, a neighbour, a hunter who went out. Knocks, asks to be let in. You can tell: it doesn't know what the living one would know; its neck is longer than you remember; its eyes don't blink. The Mansi: \"ask it what the two of you spoke of alone — it will answer with your own words\".",
			"|ZHERDYAI\n\nTall and thin, \"a spruce and a half\". Stands at the edge of the forest looking into the windows. Does nothing until you look at it for long. Whoever looked long has their \"road stretched\": they walk home and never arrive. One piece of advice — don't look, cover the window, don't go out.",
			"|SUSEDKO\n\nThe house spirit, master of the hut. Kind if fed: a crust of bread on the stove, and no cursing in the house. When offended, walks barefoot at night, hides things, presses on your chest. Whoever lives alone must \"come to terms\" with the susedko, or it leaves — and the house becomes empty to everyone outside.",
			"|THE MIDNIGHT HAG · OBMIRALO · THE MOTHER UNDER THE ICE\n\nThe midnight hag sits on a sleeper's chest, won't let them cry out or rise; the only escape is to wake yourself. Obmiralo knocks and plays dead outside the door; open it and he \"comes back to life\". The mother under the ice calls her son in his mother's voice from beneath the ice. Answer none of them.\n\n|Lastly\n\nEvery teller said the same: \"Nav has an ear on the Lozva\". Where it is, they didn't say. They pointed north, past the pass.",
		],
	},
	&"order": {
		"style": &"type", "marks": [&"secret"], "cover": Color(0.55, 0.5, 0.38),
		"title": ["Приказ в/ч 03110 № 17-сс", "Unit 03110 Order No. 17-ss"],
		"ru": [
			"|СОВЕРШЕННО СЕКРЕТНО\n|Экз. № 2\n\nВОЙСКОВАЯ ЧАСТЬ 03110\nПРИКАЗ № 17-сс\nг. Свердловск-44, 14 августа 1961 г.\n\nО порядке несения дежурства на точке «Кедр».\n\n1. Точку «Кедр» считать гражданской метеостанцией 2-го разряда. Изделие «Отзвук-2» — оборудованием гидрометслужбы.",
			"2. На точке содержать одного (1) дежурного. Двух и более дежурных одновременно не содержать (см. отчёт по испытаниям 1961 г., п. 4: «при двух операторах изделие выбирает»).\n\n3. Сводку с точки принимать в 00:00 и 02:00 круглогодично. При перерыве свыше шести часов точку считать вскрытой.",
			"4. Дежурного об изделии не информировать. Документы изделия в здании корпуса не хранить.\n\n5. Замену дежурного производить по мере выбытия. Вещи выбывшего на точке оставлять: изделие «привыкает».\n\n6. Радиообмен с дежурным после 03:00 не вести. Передачи с точки после 03:00 не принимать и не подтверждать.",
			"|Командир в/ч 03110\n|полковник ____________ (подпись неразборчива)\n\n(на обороте, карандашом, почерк Семёнова)\n\nПункт 6 — это не про нас. Это про то, кто будет говорить нашим голосом после трёх. Они знали с первого дня.",
		],
		"en": [
			"|TOP SECRET\n|Copy No. 2\n\nMILITARY UNIT 03110\nORDER No. 17-ss\nSverdlovsk-44, 14 August 1961\n\nOn the procedure of duty at the Kedr site.\n\n1. The Kedr site is to be considered a class II civilian weather station. Device \"Otzvuk-2\" is to be considered weather-service equipment.",
			"2. Keep one (1) operator at the site. Do not keep two or more operators at the same time (see the 1961 test report, item 4: \"with two operators the device chooses\").\n\n3. Receive the report from the site at 00:00 and 02:00 all year round. After a break of more than six hours, consider the site breached.",
			"4. The operator is not to be informed about the device. Device documents are not to be kept in the building.\n\n5. Replace the operator as they drop out. Leave the belongings of a removed operator at the site: the device \"gets used to them\".\n\n6. Hold no radio exchange with the operator after 03:00. Do not receive or acknowledge transmissions from the site after 03:00.",
			"|Commander, Unit 03110\n|Colonel ____________ (signature illegible)\n\n(on the back, in pencil, Semyonov's hand)\n\nItem 6 isn't about us. It's about whoever will be speaking in our voices after three. They knew from day one.",
		],
	},
	&"report": {
		"style": &"type", "marks": [&"secret", &"burnt"], "cover": Color(0.5, 0.46, 0.36),
		"title": ["Отчёт об испытаниях «Отзвук-2»", "Otzvuk-2 test report"],
		"ru": [
			"|СОВ. СЕКРЕТНО\n|ОТЧЁТ об испытаниях изделия «Отзвук-2»\n|точка «Кедр», июль — сентябрь 1961 г.\n\n1. Цель: установить природу устойчивого ответного сигнала из-под точки и возможность его использования для дальней связи.",
			"2. Изделие (приёмник-ретранслятор) установлено на месте культового сооружения местного населения (кольцо столбов). Ответный сигнал принят в первую же ночь в 03:10 по местному. Сигнал содержит речь. Речь повторяет переговоры операторов за последние сутки.",
			"3. 14.08 оператор Курочкин В. П. в 03:10 ответил на сигнал голосом. С 03:12 связь с Курочкиным утрачена. С 15.08 в эфире на частоте изделия регулярно звучит голос Курочкина, ведущий радиообмен по расписанию станции. Тело не обнаружено.",
			"4. При двух операторах на точке изделие «выбирает» одного (см. п. 3). При одном — не выбирает, пока оператор регулярно передаёт сводку. Предположение: передача сводки воспринимается изделием как «присутствие», и ответная активность остаётся «по ту сторону».",
			"5. Вывод: изделие пригодно как средство приёма сигналов с той стороны при условии постоянного присутствия одного оператора-«маяка». Рекомендуется продолжить.\n\n(дальше страница обгорела; читается только)\n\n...голосом оператора можно вести обмен, но сам оператор после этого...",
		],
		"en": [
			"|TOP SECRET\n|REPORT on the tests of device \"Otzvuk-2\"\n|Kedr site, July — September 1961\n\n1. Purpose: to establish the nature of the stable answering signal from beneath the site and whether it can be used for long-range communication.",
			"2. The device (receiver-repeater) was installed on the site of a cult structure of the local population (a ring of posts). The answering signal was received on the very first night at 03:10 local time. The signal contains speech. The speech repeats the operators' exchanges of the previous day.",
			"3. On 14.08 operator Kurochkin V. P. answered the signal by voice at 03:10. Contact with Kurochkin was lost from 03:12. Since 15.08 Kurochkin's voice is regularly heard on the device frequency, conducting radio exchange to the station schedule. The body has not been found.",
			"4. With two operators on site, the device \"chooses\" one (see item 3). With one, it does not choose as long as the operator transmits reports regularly. Assumption: the device perceives the report as \"presence\", and the answering activity stays \"on the other side\".",
			"5. Conclusion: the device is suitable for receiving signals from the other side, provided one \"beacon\" operator is constantly present. Recommended to continue.\n\n(beyond this the page is burnt; only this is legible)\n\n...exchange can be conducted in the operator's voice, but the operator himself afterwards...",
		],
	},
	&"personnel": {
		"style": &"type", "marks": [&"secret"], "cover": Color(0.45, 0.42, 0.34),
		"title": ["Подписки о неразглашении", "Non-disclosure undertakings"],
		"ru": [
			"|ПОДПИСКА\n|о неразглашении сведений, составляющих государственную тайну\n\nЯ, нижеподписавшийся, дежурный техник точки «Кедр», обязуюсь не разглашать...\n\nБрагин А. С. — подпись\nХодырев Н. Н. — подпись\nПастухов Г. И. — подпись",
			"Ерёмина Т. В. — подпись\nГолубев А. А. — подпись\nСеменов В. П. — подпись\nЛазарев В. А. — подпись\n\n(все подписи — одной рукой. Чем ниже, тем ровнее.)",
			"Мальцев В. — \n\n(строка для подписи пустая. Под ней карандашом, тем же почерком:)\n\nподпишет сам.",
		],
		"en": [
			"|UNDERTAKING\n|not to disclose information constituting a state secret\n\nI, the undersigned, duty technician of the Kedr site, undertake not to disclose...\n\nBragin A. S. — signature\nKhodyrev N. N. — signature\nPastukhov G. I. — signature",
			"Eryomina T. V. — signature\nGolubev A. A. — signature\nSemyonov V. P. — signature\nLazarev V. A. — signature\n\n(every signature is in the same hand. The lower they go, the neater they get.)",
			"Mal'tsev V. — \n\n(the signature line is empty. Beneath it, in pencil, in the same hand:)\n\nwill sign himself.",
		],
	},
	&"nastavlenie": {
		"style": &"print", "marks": [], "cover": Color(0.2, 0.3, 0.42),
		"title": ["Наставление гидрометстанциям, вып. 3", "Manual for weather stations, issue 3"],
		"ru": [
			"|НАСТАВЛЕНИЕ\n|гидрометеорологическим станциям и постам\n|Выпуск 3, часть I. Гидрометеоиздат, Ленинград, 1969\n\n§ 1. Наблюдения производятся в установленные сроки. Перенос срока не допускается.\n\n(на полях, карандашом:) даже если стучат.",
			"§ 14. Психрометрическая будка открывается с северной стороны, чтобы солнце не попадало на термометры. Наблюдатель не должен касаться резервуаров руками и дышать на термометры.\n\n(на полях:) Если термометр показывает тридцать шесть и шесть — дышит не наблюдатель.",
			"§ 27. Снегомерная рейка устанавливается вертикально, вдали от построек. Отсчёт производится с точностью до 1 см у самой рейки.\n\n(на полях, другой рукой:) Утром у рейки следы. Наши. Только носками к рейке, и вокруг — ни одного обратного.",
			"§ 52. В случае прекращения связи наблюдатель продолжает наблюдения и записывает их в книжку КМ-1 для последующей передачи.\n\n(на полях, крупно, Семёнов:) НЕ ПРЕКРАЩАЙ. ЕСЛИ НЕКОМУ ПЕРЕДАТЬ — ПЕРЕДАВАЙ В ПУСТОЙ ЭФИР.",
		],
		"en": [
			"|MANUAL\n|for hydrometeorological stations and posts\n|Issue 3, part I. Gidrometeoizdat, Leningrad, 1969\n\n§ 1. Observations are made at the set times. Moving an observation time is not permitted.\n\n(in the margin, in pencil:) even if they're knocking.",
			"§ 14. The instrument screen opens on its north side so the sun does not fall on the thermometers. The observer must not touch the bulbs or breathe on the thermometers.\n\n(in the margin:) If the thermometer reads thirty-six point six, it isn't the observer breathing.",
			"§ 27. The snow stake is set vertically, away from buildings. Readings are taken to 1 cm at the stake itself.\n\n(in the margin, another hand:) In the morning there are footprints by the stake. Ours. Only toes towards the stake, and not one leading back.",
			"§ 52. If communication stops, the observer continues observations and records them in the KM-1 book for later transmission.\n\n(in the margin, large, Semyonov:) DON'T STOP. IF THERE'S NO ONE TO SEND TO — SEND INTO THE EMPTY AIR.",
		],
	},
	&"gazeta": {
		"style": &"news", "marks": [], "cover": Color(0.82, 0.78, 0.68),
		"title": ["«Уральский рабочий», 10 ноября 1983", "Uralsky Rabochy, 10 November 1983"],
		"ru": [
			"|УРАЛЬСКИЙ РАБОЧИЙ\n|№ 258 (19 314) · четверг, 10 ноября 1983 года\n\nВЫСОКИЕ РУБЕЖИ ПЯТИЛЕТКИ. Лесозаготовители Ивдельского леспромхоза досрочно выполнили план десятого месяца...\n\nПОГОДА. На севере области — снег, метель, до −38°.",
			"|ПРОИСШЕСТВИЯ\n\nВ Ивдельском районе продолжаются поиски геологов партии «Таёжная-4» (нач. Белов С. И.), не вышедших на связь с 3 ноября. Последний сеанс: «Идём на сигнал, у нас всё в порядке». Вертолёт не смог подняться из-за метели.",
			"|ОБЪЯВЛЕНИЯ\n\nУтерян рюкзак брезентовый. Нашедшего просят вернуть.\n\nИщу брата, Курочкина Валентина Павловича, 1931 г. р., метеоролога. В 1961 г. уехал на Северный Урал по распределению. Последнее письмо — из Ивделя. Если вы слышали его голос — напишите.\n\n(последнее объявление обведено карандашом)",
		],
		"en": [
			"|URALSKY RABOCHY\n|No. 258 (19 314) · Thursday, 10 November 1983\n\nNEW HEIGHTS OF THE FIVE-YEAR PLAN. Loggers of the Ivdel timber enterprise have fulfilled the ten-month plan ahead of schedule...\n\nWEATHER. North of the region — snow, blizzard, down to −38°.",
			"|INCIDENTS\n\nIn the Ivdel district the search continues for the geologists of the Taiga-4 party (head S. I. Belov), out of contact since 3 November. Last session: \"Heading for the signal, all is well.\" The helicopter could not take off because of the blizzard.",
			"|NOTICES\n\nLost: a canvas rucksack. The finder is asked to return it.\n\nLooking for my brother, Valentin Pavlovich Kurochkin, born 1931, meteorologist. In 1961 he was posted to the North Urals. His last letter came from Ivdel. If you have heard his voice — please write.\n\n(the last notice is circled in pencil)",
		],
	},
	&"pismo": {
		"style": &"hand", "marks": [], "cover": Color(0.85, 0.82, 0.74),
		"title": ["Письмо Тамары Голубевой", "Letter from Tamara Golubeva"],
		"ru": [
			"|Ивдель, 2 декабря 1979\n\nСаша, здравствуй.\n\nНадя спрашивает каждый вечер, когда папа приедет. Я говорю — весной. Она рисует станцию: домик, вышка и ты в окне. Ещё рисует кого-то высокого у леса. Говорит, ты сам рассказал ей про него по телефону.",
			"Саша, ты звонил в октябре в три часа ночи. Говорил долго, ласково, называл меня по-мамину, Томушкой, — так ты меня не зовёшь уже лет десять. Спросил, какая у нас дверь, на какой замок закрываем. Я сказала. Потом ты замолчал и дышал в трубку до утра.\n\nСаша, это был ты?",
			"Если не ты — напиши мне только одно слово, то, которое знаем мы двое. Я не открою никому, пока не получу.\n\nЦелую. Твоя Т.\n\n(ответа нет. Конверт так и не отправлен — он лежит здесь, на станции, с маркой и адресом. Почерк на адресе — твой.)",
		],
		"en": [
			"|Ivdel, 2 December 1979\n\nSasha, hello.\n\nNadya asks every evening when Daddy is coming. I say — in spring. She draws the station: a little house, a tower, and you in the window. She also draws someone tall by the forest. She says you told her about him yourself on the phone.",
			"Sasha, you phoned in October at three in the morning. You talked a long time, tenderly, called me Tomushka like my mother did — you haven't called me that for ten years. You asked what our door is like, what lock we use. I told you. Then you went quiet and breathed into the receiver until morning.\n\nSasha, was that you?",
			"If it wasn't — write me just one word, the one only the two of us know. I won't open the door to anyone until I get it.\n\nKisses. Your T.\n\n(no reply. The envelope was never sent — it lies here, at the station, stamped and addressed. The handwriting on the address is yours.)",
		],
	},
	&"krossvord": {
		"style": &"print", "marks": [], "cover": Color(0.8, 0.76, 0.66),
		"title": ["Кроссворд из «Огонька»", "Crossword from Ogonyok"],
		"ru": [
			"|КРОССВОРД\n|«Огонёк», № 44, 1983\n\nПо горизонтали: 1. Прибор для измерения давления (8). 4. Северный олень (5). 7. Сигнал бедствия (3). 9. Тот, кто стучит (?)...\n\nВписано карандашом: 1. БАРОГРАФ. 4. ХОРЕЙ. 7. SOS.",
			"По вертикали: 2. Устройство для приёма радиосигналов (8). 3. Время суток (4). 5. Имя дежурного (4).\n\nВписано: 2. ПРИЁМНИК. 3. НОЧЬ. 5. ВИТЯ.\n\n(«Имени дежурного» в кроссворде нет. В журнале этот вопрос — номер 5 — про реку в Сибири.)",
			"(внизу, в клетках, которых нет в сетке, тем же карандашом:)\n\nО Т К Р О Й\n\n(клетки дорисованы от руки. Карандаш вдавлен так, что прорвал бумагу.)",
		],
		"en": [
			"|CROSSWORD\n|Ogonyok, No. 44, 1983\n\nAcross: 1. Instrument for measuring pressure (9). 4. Reindeer-herder's pole (5). 7. Distress signal (3). 9. The one who knocks (?)...\n\nPencilled in: 1. BAROGRAPH. 4. KHOREI. 7. SOS.",
			"Down: 2. Device for receiving radio signals (8). 3. Time of day (5). 5. Duty officer's name (4).\n\nPencilled in: 2. RECEIVER. 3. NIGHT. 5. VITYA.\n\n(There is no \"duty officer's name\" clue in this crossword. In the magazine, clue 5 is about a river in Siberia.)",
			"(below, in squares that aren't part of the grid, in the same pencil:)\n\nO P E N  U P\n\n(the squares are drawn in by hand. The pencil is pressed so hard it has torn the paper.)",
		],
	},
	&"semenov_photo": {
		"style": &"hand", "marks": [], "cover": Color(0.7, 0.66, 0.58),
		"title": ["Фотография и записка Семёнова", "Semyonov's photo and note"],
		"ru": [
			"|(Фотокарточка 6×9, любительская.)\n\nСтанция зимой, снято с площадки. В окне жилой — человек в ватнике, машет рукой. На обороте: «12.11.1982. Снимал я. В доме никого не было».",
			"|(Записка, сложенная вчетверо, за панелью.)\n\nЕсли нашёл — значит, ты тоже простукивал стены. Хорошо. Значит, ты ещё сам.\n\nПанелей с пустотой в доме три. Одна — эта. Вторая — под половиком в жилой, там подпол Брагина, не открывай ночью. Третью я не нашёл. Но слышал, как в ней дышат.\n\n— В. С.",
		],
		"en": [
			"|(A 6×9 snapshot, amateur.)\n\nThe station in winter, taken from the plot. In the living-room window — a man in a quilted jacket, waving. On the back: \"12.11.1982. I took this. There was nobody in the house.\"",
			"|(A note folded in four, behind the panel.)\n\nIf you found this, you've been tapping the walls too. Good. That means you're still yourself.\n\nThere are three hollow panels in the house. One is this. The second is under the rug in the living room — Bragin's cellar, don't open it at night. The third I never found. But I heard it breathing.\n\n— V. S.",
		],
	},
	&"eremina": {
		"style": &"hand", "marks": [], "cover": Color(0.6, 0.5, 0.52),
		"title": ["Письма Т. В. Ерёминой (не отправлены)", "T. V. Eryomina's letters (never sent)"],
		"ru": [
			"|Мамочка!\n\nЯ на станции третий месяц. Тут хорошо, тихо, только радио. Пишу тебе каждую неделю, но вертолёт письма не берёт: говорят, «с этой точки почту не принимаем». Так что складываю их в коробку на чердаке, отдам сама.",
			"Мама, сегодня ты звонила. То есть кто-то звонил твоим голосом и пел мне «Спи, моя радость». Ты мне её никогда не пела. Ты пела «Баю-баюшки». Я положила трубку. А колыбельная продолжалась в рации — тихо, на 8320.",
			"Мама, если я не вернусь весной, не верь, если кто-то придёт и скажет, что он от меня. Не открывай. Даже если это буду я.\n\nТвоя Таня.\n\n(внизу коробки — детская варежка. Одна.)",
		],
		"en": [
			"|Mummy!\n\nThis is my third month at the station. It's nice, quiet, just the radio. I write to you every week, but the helicopter won't take the letters: \"we don't accept post from this site\", they say. So I keep them in a box in the attic and I'll bring them myself.",
			"Mum, you phoned today. I mean, someone phoned in your voice and sang me \"Sleep, my joy\". You never sang me that one. You sang \"Bayu-bayushki\". I hung up. And the lullaby went on in the radio — quietly, on 8320.",
			"Mum, if I don't come back in spring, don't believe anyone who comes and says he's from me. Don't open the door. Even if it's me.\n\nYour Tanya.\n\n(at the bottom of the box — a child's mitten. Just one.)",
		],
	},
}

## Порядок для «Дела» и счёта прочитанного
const ORDER: Array[StringName] = [&"bragin", &"vahta", &"golubev", &"pismo", &"eremina", &"semenov_photo",
	&"permyakov", &"nastavlenie", &"gazeta", &"krossvord", &"order", &"report", &"personnel"]


static func title(id: StringName) -> String:
	var d: Dictionary = DATA.get(id, {})
	var t: Array = d.get("title", ["?", "?"])
	return t[1] if Settings.language == "en" else t[0]


static func pages(id: StringName) -> Array:
	var d: Dictionary = DATA.get(id, {})
	return d.get("en" if Settings.language == "en" else "ru", [])


static func is_read(id: StringName) -> bool:
	return Game.has_flag("read_" + String(id))


static func mark_read(id: StringName) -> void:
	if not is_read(id):
		Game.set_flag("read_" + String(id), true)
		SaveGame.write()


static func read_count() -> int:
	var n := 0
	for id in ORDER:
		if is_read(id):
			n += 1
	return n
