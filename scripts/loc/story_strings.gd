class_name StoryStrings
extends RefCounted
## Строки сюжетного патча 1.54: сеансы связи с выбором, флешбэки Семёнова, переписанные заветы.
## Loc.t ищет здесь, если ключа нет в Strings.S.

const S := {
	# --- Сеансы связи ---------------------------------------------------------
	&"talk.call_zoya": ["РАЦИЯ: — Кедр-7, Кедр-7, ответьте Свердловску. Приём.", "RADIO: \"Kedr-7, Kedr-7, Sverdlovsk calling. Over.\""],
	&"talk.call_mikh": ["РАЦИЯ: — Кедр-семь, Витёк... Михалыч на связи. Ответь, а?", "RADIO: \"Kedr-seven, Vitya... Mikhalych here. Pick up, will you?\""],
	&"talk.goal": ["Вызов по рации — подойти к Р-250 и ответить", "A call on the radio — go to the R-250 and answer"],
	&"talk.missed": ["Рация замолчала. Не дождались.", "The radio falls silent. They gave up waiting."],
	&"talk.silent": ["[ промолчать ]", "[ stay silent ]"],
	&"talk.hint": ["[1] [2] [3] или мышь — ответить", "[1] [2] [3] or mouse — reply"],
	&"talk.you": ["ВИКТОР: %s", "VIKTOR: %s"],
	&"talk.mikh": ["МИХАЛЫЧ", "MIKHALYCH"],

	# Пролог — Михалыч с дороги
	&"t0.l1": ["МИХАЛЫЧ: — Витёк, приём. Михалыч. Я у брода, дальше лёд держит. Ну как, дошёл? Печь взялась?", "MIKHALYCH: \"Vitya, come in. Mikhalych. I'm at the ford, the ice holds from here. Well, did you make it? Stove going?\""],
	&"t0.l2": ["МИХАЛЫЧ: — Ты это... Если ночью что почудится — ты мне скажи. Я по утрам на связи.", "MIKHALYCH: \"Listen... if something seems off at night — tell me. I'm on the air in the mornings.\""],
	&"t0.c1": ["«Дошёл. Тепло. Спасибо, Михалыч.»", "\"Made it. It's warm. Thanks, Mikhalych.\""],
	&"t0.c2": ["«Дошёл. На обочине стоял человек. Ты его видел?»", "\"Made it. There was a man on the roadside. Did you see him?\""],
	&"t0.c3": ["«Всё нормально. Сам разберусь.»", "\"Everything's fine. I'll manage.\""],
	&"t0.r1": ["МИХАЛЫЧ: — Ну и добро. Дверь на засов. Кто бы ни стучал — до утра не открывай. Даже мне.", "MIKHALYCH: \"Good then. Bolt the door. Whoever knocks — don't open till morning. Not even for me.\""],
	&"t0.r2": ["МИХАЛЫЧ: — (долгая пауза) Не было там никого, Витёк. Я не останавливался. Дверь на засов — и спи.", "MIKHALYCH: \"(a long pause) There was no one there, Vitya. I didn't stop. Bolt the door and sleep.\""],
	&"t0.r3": ["МИХАЛЫЧ: — Все так говорят. Ну, бывай. Дверь только на засов.", "MIKHALYCH: \"They all say that. Well, take care. Just bolt the door.\""],
	&"t0.rs": ["МИХАЛЫЧ: — Спит уже, что ли... Ну спи. Засов только.", "MIKHALYCH: \"Asleep already... Sleep then. Just the bolt.\""],

	# Ночь 1 — Зоя
	&"t1.l1": ["ЗОЯ: — Витя, это Зоя, диспетчерская. Как первая ночь? Ничего не беспокоит?", "ZOYA: \"Vitya, it's Zoya, dispatch. How's the first night? Anything bothering you?\""],
	&"t1.c1": ["«Свист в лесу. И рация сама ловит чужие голоса.»", "\"Whistling in the woods. And the radio picks up voices by itself.\""],
	&"t1.c2": ["«Всё штатно.»", "\"All nominal.\""],
	&"t1.c3": ["«А где Семёнов? Мне сказали — по болезни.»", "\"Where's Semyonov? They told me he was ill.\""],
	&"t1.r1": ["ЗОЯ: — Это эфир, Витя, на перевале бывает. Пиши в журнал всё, что странно. Я читаю. Правда читаю.", "ZOYA: \"That's the air up on the pass, Vitya, it happens. Write down anything strange in the log. I read it. I really do.\""],
	&"t1.r2": ["ЗОЯ: — Ну и хорошо. Семёнов тоже всегда говорил: «штатно». До сводки.", "ZOYA: \"Good. Semyonov always said 'nominal' too. Until the report.\""],
	&"t1.r3": ["ЗОЯ: — (пауза) По болезни. Так в приказе. Витя... ты сводки вовремя давай, ладно? До связи.", "ZOYA: \"(pause) Ill. That's what the order says. Vitya... send your reports on time, all right? Out.\""],
	&"t1.rs": ["ЗОЯ: — Кедр-7? Не слышу вас... Ладно. До сводки.", "ZOYA: \"Kedr-7? Can't hear you... All right. Until the report.\""],

	# Ночь 2 — Михалыч
	&"t2.l1": ["МИХАЛЫЧ: — Витёк, это Михалыч, с Ивделя. Ну как ты там? Дверь держишь?", "MIKHALYCH: \"Vitya, it's Mikhalych, from Ivdel. How are you doing? Keeping the door shut?\""],
	&"t2.c1": ["«Держу. Ночью по крыше кто-то ходил.»", "\"I am. Something walked on the roof last night.\""],
	&"t2.c2": ["«Нормально, Михалыч. Скучно.»", "\"Fine, Mikhalych. Boring.\""],
	&"t2.c3": ["«А Семёнов — тоже держал?»", "\"Did Semyonov keep it shut?\""],
	&"t2.r1": ["МИХАЛЫЧ: — По крыше... (долго молчит) Ты это. Не лазь смотреть. Утром глянешь — следов не будет. Не будет, понял?", "MIKHALYCH: \"On the roof... (a long silence) Listen. Don't go up to look. In the morning there won't be any tracks. There won't. Got it?\""],
	&"t2.r2": ["МИХАЛЫЧ: — Скучно — это хорошо, Витёк. Скучно — значит, живой.", "MIKHALYCH: \"Boring is good, Vitya. Boring means alive.\""],
	&"t2.r3": ["МИХАЛЫЧ: — ...Семёнов открыл. Всё, связь кончается. Держи дверь.", "MIKHALYCH: \"...Semyonov opened it. That's it, the line's going. Keep it shut.\""],
	&"t2.rs": ["МИХАЛЫЧ: — Спит, что ли... Ну спи. Только дверь.", "MIKHALYCH: \"Asleep, are you... Sleep then. Just the door.\""],

	# Ночь 3 — Зоя
	&"t3.l1": ["ЗОЯ: — Витя, на всякий случай. Если в эфире будут приказы — проверяй пароль. «Бирюса». Повтори.", "ZOYA: \"Vitya, just in case. If you get orders on the air, check the password. 'Biryusa'. Repeat it.\""],
	&"t3.c1": ["«Бирюса.»", "\"Biryusa.\""],
	&"t3.c2": ["«А кто ещё может мне приказывать?»", "\"Who else could be giving me orders?\""],
	&"t3.c3": ["«Зоя, мне кажется, сводки уходят не к вам.»", "\"Zoya, I think the reports aren't going to you.\""],
	&"t3.r1": ["ЗОЯ: — Молодец. Без «Бирюсы» — это не мы. Что бы ни говорили и каким бы голосом.", "ZOYA: \"Good. Without 'Biryusa' it isn't us. Whatever they say, whatever voice they use.\""],
	&"t3.r2": ["ЗОЯ: — ...Не телефонный разговор, Витя. Просто проверяй.", "ZOYA: \"...Not over the radio, Vitya. Just check.\""],
	&"t3.r3": ["ЗОЯ: — (шорох бумаги) Сводки за прошлую зиму у меня есть. Все в срок. Только Семёнова уже месяц как не было... Проверяй пароль.", "ZOYA: \"(paper rustling) I have last winter's reports. All on time. Except Semyonov had been gone a month by then... Check the password.\""],
	&"t3.rs": ["ЗОЯ: — Кедр-7? Пароль — «Бирюса». Если слышишь — запомни.", "ZOYA: \"Kedr-7? The password is 'Biryusa'. If you can hear me, remember it.\""],

	# Ночь 4 — Михалыч (доверяет)
	&"t4a.l1": ["МИХАЛЫЧ: — Витёк, слушай сюда. Если я тебе когда ночью покажусь — у двери, на дороге, где угодно...", "MIKHALYCH: \"Vitya, listen to me. If I ever show up at night — at the door, on the road, anywhere...\""],
	&"t4a.l2": ["МИХАЛЫЧ: — ...спроси, как звали мою собаку. Пират. Я не забуду. А оно — не знает.", "MIKHALYCH: \"...ask me what my dog was called. Pirat. I won't forget. And it doesn't know.\""],
	&"t4a.c1": ["«Понял. Пират.»", "\"Got it. Pirat.\""],
	&"t4a.c2": ["«Михалыч, ты что-то знаешь. Что здесь было?»", "\"Mikhalych, you know something. What happened here?\""],
	&"t4a.r1": ["МИХАЛЫЧ: — Вот и молодец. Ночью я не езжу. Запомни это тоже.", "MIKHALYCH: \"Good lad. I don't drive at night. Remember that too.\""],
	&"t4a.r2": ["МИХАЛЫЧ: — Я троих туда возил, Витёк. Обратно — никого. Пират. Запомнил?", "MIKHALYCH: \"I've driven three of them up there, Vitya. Brought none back. Pirat. Got it?\""],
	&"t4a.rs": ["МИХАЛЫЧ: — Пират, Витёк. Пират. Слышишь — запомни.", "MIKHALYCH: \"Pirat, Vitya. Pirat. If you can hear me, remember it.\""],
	# Ночь 4 — Михалыч (не доверяет)
	&"t4b.l1": ["МИХАЛЫЧ: — Ну как ты, Витёк? Живой?", "MIKHALYCH: \"How are you, Vitya? Alive?\""],
	&"t4b.c1": ["«Михалыч, у меня по избе следы ходят. Босые.»", "\"Mikhalych, there are footprints walking around the house. Bare feet.\""],
	&"t4b.c2": ["«Живой.»", "\"Alive.\""],
	&"t4b.r1": ["МИХАЛЫЧ: — (тихо) Босые... Тогда слушай. Если я ночью покажусь — спроси, как звали мою собаку. Пират. Оно не знает.", "MIKHALYCH: \"(quietly) Bare feet... Then listen. If I show up at night, ask what my dog was called. Pirat. It doesn't know.\""],
	&"t4b.r2": ["МИХАЛЫЧ: — Ну живи. Живи, Витёк.", "MIKHALYCH: \"Then keep living. Keep living, Vitya.\""],
	&"t4b.rs": ["МИХАЛЫЧ: — Молчишь... Ну, дело твоё.", "MIKHALYCH: \"Not talking... Your call.\""],

	# Ночь 5 — Зоя
	&"t5.l1": ["ЗОЯ: — Витя, Ветров спрашивает: высылать борт после смены или досидишь до конца вахты?", "ZOYA: \"Vitya, Vetrov's asking: should we send a helicopter after the shift, or will you see out the watch?\""],
	&"t5.l1h": ["ЗОЯ: — Витя, я твои записи в журнале читала. Ветрову показала. Он спрашивает: высылать борт?", "ZOYA: \"Vitya, I read your log entries. I showed them to Vetrov. He's asking: should we send a helicopter?\""],
	&"t5.c1": ["«Высылайте. Здесь что-то не так.»", "\"Send it. Something is wrong here.\""],
	&"t5.c2": ["«Досижу.»", "\"I'll see it out.\""],
	&"t5.r1": ["ЗОЯ: — Записала. Борт после смены, если погода даст. Продержись, Витя.", "ZOYA: \"Noted. A helicopter after the shift, if the weather allows. Hold on, Vitya.\""],
	&"t5.r2": ["ЗОЯ: — (пауза) Ты как Семёнов. Он тоже сказал — досижу.", "ZOYA: \"(pause) You sound like Semyonov. He said he'd see it out too.\""],
	&"t5.rs": ["ЗОЯ: — Кедр-7? Ладно... Ветрову скажу — связи нет.", "ZOYA: \"Kedr-7? All right... I'll tell Vetrov there's no contact.\""],

	# Ночь 6 — Михалыч (настоящий, днём ещё был на связи)
	&"t6.l1": ["МИХАЛЫЧ: — Витёк, у вас метель. Я на Ивделе стою, никуда не еду. Запомни: сегодня я НЕ еду.", "MIKHALYCH: \"Vitya, you've got a blizzard up there. I'm parked in Ivdel, not going anywhere. Remember: tonight I am NOT driving.\""],
	&"t6.c1": ["«Понял. Ты не едешь.»", "\"Got it. You're not driving.\""],
	&"t6.c2": ["«Михалыч... а если это сейчас тоже не ты?»", "\"Mikhalych... what if this isn't you either?\""],
	&"t6.r1": ["МИХАЛЫЧ: — Вот. Увидишь фары — это не я.", "MIKHALYCH: \"Right. If you see headlights, it isn't me.\""],
	&"t6.r2": ["МИХАЛЫЧ: — (смеётся, потом нет) Пират, Витёк. Моего звали Пират. Проверь.", "MIKHALYCH: \"(laughs, then stops) Pirat, Vitya. Mine was called Pirat. Check me.\""],
	&"t6.rs": ["МИХАЛЫЧ: — Не еду я сегодня. Слышишь? Не еду.", "MIKHALYCH: \"I'm not driving tonight. Hear me? Not driving.\""],

	# Ночь 7 — Зоя (или то, что говорит её голосом)
	&"t7.l1h": ["ЗОЯ: — Витя... У меня тут запись. Твоим голосом. «Свист в лесу. Рация сама ловит голоса». Сегодняшняя. Ты её ещё не передавал.", "ZOYA: \"Vitya... I have a recording here. In your voice. 'Whistling in the woods. The radio picks up voices.' It's from tonight. You haven't sent it yet.\""],
	&"t7.l1q": ["ЗОЯ: — Кедр-7, всё штатно. Всё штатно. Всё штатно. Это ведь ты так говорил, Витя? Каждую ночь.", "ZOYA: \"Kedr-7, all nominal. All nominal. All nominal. That's what you said, isn't it, Vitya? Every night.\""],
	&"t7.c1": ["«Зоя, это не я.»", "\"Zoya, that isn't me.\""],
	&"t7.c2": ["«Пароль, Зоя. Скажи пароль.»", "\"The password, Zoya. Say the password.\""],
	&"t7.r1": ["ЗОЯ: — Я знаю, Витя. Знаю. (тихо) Его тоже не было, а сводки шли.", "ZOYA: \"I know, Vitya. I know. (quietly) He was gone too, and the reports kept coming.\""],
	&"t7.r2": ["ЗОЯ: — Бирюса, Витя. Бирюса. (голос сползает ниже, медленнее) Би-рю-у-уса...", "ZOYA: \"Biryusa, Vitya. Biryusa. (the voice sinks lower, slower) Bi-ryu-u-usa...\""],
	&"t7.rs": ["ЗОЯ: — (шум) ...Витя? Ты ещё там?", "ZOYA: \"(static) ...Vitya? Are you still there?\""],

	# Ночь 6 — проверка двойника на фарах
	&"talk.ask_dog": ["«Михалыч! Как звали твою собаку?»", "\"Mikhalych! What was your dog's name?\""],
	&"talk.dog_wrong": ["ГОЛОС ИЗ МЕТЕЛИ: — ...Найда.", "VOICE FROM THE BLIZZARD: \"...Naida.\""],
	&"talk.dog_after": ["(Пират. Его звали Пират. Найда — собака Семёнова. Это не он.)", "(Pirat. His name was Pirat. Naida was Semyonov's dog. That isn't him.)"],
	&"talk.dog_gone": ["Фары гаснут. Из метели — долгий, обиженный вой. Потом ничего.", "The headlights go out. A long, wounded howl from the blizzard. Then nothing."],

	# Дневные находки (1.55)
	&"find1.a": ["(К двери сарая — босые следы. Свежие. Пока я был внутри.)", "(Bare footprints to the shed door. Fresh. While I was inside.)"],
	&"find1.b": ["(Они кончаются у порога. Обратно — ни одного.)", "(They end at the threshold. Not one leading back.)"],
	&"find2.a": ["«Зорька» в углу играет колыбельную. Батарей в ней нет с пятьдесят восьмого года.", "The Zorka in the corner is playing a lullaby. There haven't been batteries in it since fifty-eight."],
	&"find2.b": ["(Мама пела её мне. Её никто больше не знает.)", "(Mum used to sing it to me. Nobody else knows it.)"],
	&"find3.a": ["(Отсюда видно станцию. Крыльцо. Свет.)", "(The station is visible from here. The porch. The light.)"],
	&"find3.b": ["(Три раза. Как Михалыч сигналит. В доме никого нет. Рубильник — у двери.)", "(Three times. Like Mikhalych signals. There's nobody in the house. The switch is by the door.)"],
	&"find4.a": ["Подо льдом что-то прошло. Длинное. Против течения.", "Something passed under the ice. Long. Against the current."],
	&"find4.b": ["(В озере нет течения.)", "(There is no current in this lake.)"],
	&"find5.a": ["Люк наверху захлопнулся. И открылся сам — медленно, со скрипом.", "The hatch above slammed shut. And opened by itself — slowly, creaking."],
	&"find5.b": ["(Ветер. Это ветер. Люк весит сорок килограммов.)", "(The wind. It's the wind. The hatch weighs forty kilos.)"],
	&"find6.a": ["От навеса в лес уходит лыжня. Свежая. А лыжи Семёнова — у меня в руках.", "A ski track runs from the shack into the woods. Fresh. And Semyonov's skis are in my hands."],
	&"find6.b": ["(И рядом — босые. Шаг в шаг. Кто-то шёл с ним. Или вёл его.)", "(And beside it — bare feet. Step for step. Someone walked with him. Or led him.)"],

	# Кода концовок (1.55)
	&"coda.mikh": ["Утром Михалыч приехал, как обещал. Долго стоял у крыльца. Стучать не стал.", "In the morning Mikhalych came, as he'd promised. He stood by the porch a long time. He didn't knock."],
	&"coda.heli": ["В 09:40 над перевалом прошёл борт. Сесть не смог: видимость ноль. Зоя записала: «станция не отвечает».", "At 09:40 a helicopter passed over the pass. It couldn't land: zero visibility. Zoya wrote: 'station not responding'."],
	&"coda.double": ["У зимника нашли следы вездехода. Гусеницы шли в тайгу и обрывались. Рядом — собачьи, к станции.", "By the winter road they found crawler tracks. They ran into the taiga and stopped dead. Beside them — a dog's, leading to the station."],

	# Дело №83-М
	&"case.talk_honest": ["— На сеансах связи дежурный докладывал о происшествиях: %d раз.", "— During radio sessions the duty officer reported incidents: %d times."],
	&"case.talk_quiet": ["— На сеансах связи дежурный докладывал: «всё штатно» (%d раз).", "— During radio sessions the duty officer reported 'all nominal' (%d times)."],
	&"case.talk_missed": ["— На вызов диспетчера не отвечал: %d раз.", "— Did not answer the dispatcher's call: %d times."],
	&"case.heli": ["— 18.11 дежурный запросил борт. Вылет отменён: нелётная погода.", "— On 18.11 the duty officer requested a helicopter. Flight cancelled: no-fly weather."],
	&"case.double": ["— Со слов дежурного, опознал «двойника» водителя по контрольному вопросу.", "— According to the duty officer, he identified the driver's 'double' with a test question."],
	&"case.covenants": ["— В тетради дежурных отмечено ложных правил: %d из %d.", "— False rules marked in the duty notebook: %d of %d."],

	# --- Флешбэки «Семёнов, 1982» ---------------------------------------------
	&"fb.skip": ["[Esc] — пропустить воспоминание", "[Esc] — skip the memory"],
	&"fb.card.1": ["СЕМЁНОВ\n\n2 декабря 1982\nНочь первая", "SEMYONOV\n\nDecember 2, 1982\nThe first night"],
	&"fb.card.2": ["СЕМЁНОВ\n\n9 декабря 1982\nСтук", "SEMYONOV\n\nDecember 9, 1982\nThe knocking"],
	&"fb.card.3": ["СЕМЁНОВ\n\n14 декабря 1982\nЦифры", "SEMYONOV\n\nDecember 14, 1982\nThe numbers"],
	&"fb.card.4": ["СЕМЁНОВ\n\n19 декабря 1982\nПриказ", "SEMYONOV\n\nDecember 19, 1982\nThe order"],
	&"fb.card.5": ["СЕМЁНОВ\n\n23 декабря 1982\nПод полом", "SEMYONOV\n\nDecember 23, 1982\nUnder the floor"],
	&"fb.card.6": ["СЕМЁНОВ\n\n27 декабря 1982\nГость", "SEMYONOV\n\nDecember 27, 1982\nThe guest"],
	&"fb.after": ["Виктор просыпается. Сон был чужой — и слишком подробный.", "Viktor wakes up. The dream was someone else's — and far too detailed."],

	# 1 — Заступление
	&"fb1.g1": ["Записать правило в тетрадь дежурных (стол у окна)", "Write a rule in the duty notebook (the table by the window)"],
	&"fb1.t1": ["СЕМЁНОВ: (Брагин писал, Пастухов писал. Значит, и мне. «Свет уходя гаси...»)", "SEMYONOV: (Bragin wrote here, Pastukhov wrote here. So I will too. 'Turn off the light when you leave...')"],
	&"fb1.t2": ["Из леса — свист. Долгий, на одной ноте.", "A whistle from the woods. Long, on a single note."],
	&"fb1.g2": ["Посмотреть в окно", "Look out of the window"],
	&"fb1.t3": ["СЕМЁНОВ: (У опушки стоит человек. Без фонаря. Просто стоит и смотрит на дом.)", "SEMYONOV: (There's a man standing at the edge of the trees. No lamp. He just stands there looking at the house.)"],
	&"fb1.t4": ["СЕМЁНОВ: (...ближе. Он стал ближе. Я не видел, как он шёл.)", "SEMYONOV: (...closer. He's closer. I didn't see him move.)"],

	# 2 — Стук
	&"fb2.t1": ["Три удара в дверь. Пауза. Три удара.", "Three knocks on the door. A pause. Three knocks."],
	&"fb2.v1": ["ГОЛОС ЗА ДВЕРЬЮ: — Семёнов, открой. Это Брагин. Замёрз я, Валя.", "VOICE BEHIND THE DOOR: \"Semyonov, open up. It's Bragin. I'm freezing, Valya.\""],
	&"fb2.t2": ["СЕМЁНОВ: (Брагин. В списке дежурных напротив него с шестьдесят первого стоит «выбыл». Двадцать лет назад.)", "SEMYONOV: (Bragin. On the duty roster his name has said 'left' since sixty-one. Twenty years ago.)"],
	&"fb2.g1": ["Посмотреть в глазок (тамбур)", "Look through the peephole (the vestibule)"],
	&"fb2.t3": ["СЕМЁНОВ: (Пусто. Ровный снег. Ни одного следа.)", "SEMYONOV: (Empty. Smooth snow. Not a single footprint.)"],
	&"fb2.t4": ["Три удара. Изнутри. Из комнаты за спиной.", "Three knocks. From inside. From the room behind you."],

	# 3 — Цифры
	&"fb3.g1": ["Сесть к рации: цифровая станция на 5310", "Sit at the radio: the numbers station on 5310"],
	&"fb3.t1": ["РАЦИЯ: — ...ноль-семь... один-четыре... один-один... восемь-три...", "RADIO: \"...zero-seven... one-four... one-one... eight-three...\""],
	&"fb3.t2": ["СЕМЁНОВ: (Шифроблокнот. Группа за группой. Это не метеокод. Это фамилия.)", "SEMYONOV: (The cipher pad. Group by group. This isn't weather code. It's a surname.)"],
	&"fb3.t3": ["В блокноте его рукой: «ОРЕХОВ В. 14.11.83 ЗАСТУПАЕТ».", "In the pad, in his hand: 'OREKHOV V. 14.11.83 TAKES THE WATCH'."],
	&"fb3.t5": ["РАЦИЯ (голосом Семёнова): — Принято, Кедр-7. Конец связи.", "RADIO (in Semyonov's own voice): \"Copy, Kedr-7. Out.\""],
	&"fb.clock": ["СЕМЁНОВ · 1982", "SEMYONOV · 1982"],
	&"fb6.g4": ["Уйти в метель (крыльцо)", "Walk out into the blizzard (the porch)"],
	&"fb3.t4": ["СЕМЁНОВ: (Кто такой Орехов? Восемьдесят третий — это через год.)", "SEMYONOV: (Who is Orekhov? Eighty-three — that's a year from now.)"],

	# 4 — Приказ
	&"fb4.t1": ["РАЦИЯ: — Кедр-7, Большая Земля. Немедленно выйти к мачте, проверить оттяжки. Подтвердите.", "RADIO: \"Kedr-7, Mainland. Go to the mast immediately, check the guy wires. Confirm.\""],
	&"fb4.t2": ["СЕМЁНОВ: (Без пароля. Голос — Зои. Зоя никогда так не говорит.)", "SEMYONOV: (No password. Zoya's voice. Zoya never talks like that.)"],
	&"fb4.g1": ["Выйти на крыльцо", "Step out onto the porch"],
	&"fb4.t3": ["СЕМЁНОВ: (Следы. К дому, от леса. Сорок третий размер. Мои валенки — сорок третьего.)", "SEMYONOV: (Footprints. To the house, from the forest. Size 43. My felt boots are a 43.)"],
	&"fb4.v1": ["ШЁПОТ ЗА СПИНОЙ: — Не оборачивайся, Валя.", "A WHISPER BEHIND YOU: \"Don't turn around, Valya.\""],

	# 5 — Под полом
	&"fb5.g1": ["Кладовая: под полом гудит", "The storeroom: something hums under the floor"],
	&"fb5.t1": ["Из щели в половицах торчит шнур. На конце — наушники. Тёплые.", "A cord sticks out of a crack in the floorboards. Headphones on the end. Warm ones."],
	&"fb5.g2": ["Надеть наушники (E)", "Put on the headphones (E)"],
	&"fb5.v1": ["В НАУШНИКАХ: — ...Кедр-7 для Большой Земли. Дежурный Орехов. Минус двадцать восемь, ветер северо-западный...", "IN THE HEADPHONES: \"...Kedr-7 to Mainland. Duty officer Orekhov. Minus twenty-eight, wind north-westerly...\""],
	&"fb5.t2": ["СЕМЁНОВ: (Тот же Орехов. Он передаёт сводку. Из-под пола. Из следующего года.)", "SEMYONOV: (That Orekhov again. He's sending a report. From under the floor. From next year.)"],
	&"fb5.v2": ["В НАУШНИКАХ: — ...Семёнов? Это ты? Я слышу, как ты дышишь.", "IN THE HEADPHONES: \"...Semyonov? Is that you? I can hear you breathing.\""],

	# 6 — Гость
	&"fb6.t1": ["Стучат. Тихо, вежливо. Как стучит человек, который знает, что ему откроют.", "Knocking. Quiet, polite. The way someone knocks when they know they'll be let in."],
	&"fb6.g1": ["Посмотреть в глазок", "Look through the peephole"],
	&"fb6.t2": ["СЕМЁНОВ: (Молодой. В ватнике. Лицо... это его лицо. Орехов. Он уже здесь.)", "SEMYONOV: (Young. In a quilted jacket. The face... it's his face. Orekhov. He's already here.)"],
	&"fb6.g2": ["Отодвинуть засов (E)", "Draw back the bolt (E)"],
	&"fb6.t3": ["СЕМЁНОВ: (Я устал, Найда. Пусть греется. Пусть он будет дежурным.)", "SEMYONOV: (I'm tired, Naida. Let him warm up. Let him be the duty officer.)"],
	&"fb6.t4": ["Гость проходит мимо. Ложится на твою кровать. Лицом к стене.", "The guest walks past. Lies down on your bed. Face to the wall."],
	&"fb6.g3": ["Последняя запись в тетради (стол)", "The last entry in the notebook (the table)"],
	&"fb6.t5": ["Рукой Семёнова: «Оно не причинит вреда, если впустить погреться к огню».", "In Semyonov's hand: 'It won't harm you if you let it in to warm up by the fire.'"],
	&"fb6.t6": ["СЕМЁНОВ: (Теперь — в метель. Не оборачиваться.)", "SEMYONOV: (Now — into the blizzard. Don't turn around.)"],

	# --- Заветы: переписанные и новые записи ----------------------------------
	&"cov.new_entry": ["В тетради заветов — новая запись. Вчера её не было. [Tab]", "A new entry in the covenants notebook. It wasn't there yesterday. [Tab]"],
	&"cov.rewritten": ["В тетради заветов кто-то исправил правило. Чужой рукой. [Tab]", "Someone has corrected a rule in the covenants notebook. In another hand. [Tab]"],
	&"cov.new_tag": ["— НОВОЕ —", "— NEW —"],
	&"cov.edited_tag": ["(исправлено другой рукой)", "(corrected in another hand)"],
	&"cov.trap_seen": ["(Нет. Это не правило. Это приглашение.)", "(No. That isn't a rule. It's an invitation.)"],
	&"ach.liar_book": ["Не верь тетради", "Don't Trust the Notebook"],
	&"ach.liar_book.d": ["Отметить все ложные заветы, вписанные чужой рукой", "Mark every false covenant written in another hand"],
	&"ach.pirat": ["Пират", "Pirat"],
	&"ach.pirat.d": ["Разоблачить двойника контрольным вопросом", "Expose a double with a test question"],
	&"ach.semenov": ["Чужая память", "Someone Else's Memory"],
	&"ach.semenov.d": ["Прожить все шесть ночей Семёнова", "Live through all six of Semyonov's nights"],
}
