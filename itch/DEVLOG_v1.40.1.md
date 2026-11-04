# Дев-лог v1.40.1 — «Живой разум тайги» (Itch.io Major update)

Охватывает обновление v1.40.1: революционная система адаптивного интеллекта (Behavior Tree & Player Profiler), обучение хищника (Ырки), осада метеостанции с саботажем генератора, свежие утренние следы босых ног и динамическая тактика охоты.

---

**Title (EN):** Kedr-7 v1.40.1: The Living Taiga — Adaptive Hunter AI & Station Siege

> **Developer's Note:**
> Version **1.40.1** introduces a major breakthrough in horror design: entities in the Ural wilderness are no longer driven by scripted timers. The creature now possesses its own adaptive "brain", actively profiles your playstyle, exploits your psychological vulnerabilities, and learns how to counter your defenses.
> 
> Whether you hide inside the warm station, sprint in panic, or cold-bloodedly explore the deep anomalies, the hunter adapts its strategy specifically to you.

**Adaptive Player Profiler:**
- **Psychological Profiling:** A silent background analyzer evaluates your behavior in real time:
  - *Panic Index:* Tracks erratic camera jerks, flashlight flickering, and unwarranted sprinting outside.
  - *Shelter Bias:* Measures the ratio of time spent inside vs. outside, and how quickly you barricade doors.
  - *Tactical Discipline:* Analyzes flare usage, rule observance, and route predictability.
- **Dynamic Archetypes:** Classifies the meteorologist into one of three behavioral profiles:
  - **The Turtler:** Reluctant to leave the house, clings to the stove and radio.
  - **The Panicker:** Easily startled, wastes stamina and flashlight battery at every branch snap.
  - **The Cold-Blooded Explorer:** Boldly navigates the taiga, saves light, knows the survival rules.

**Hunter's Brain & Adaptive Tactics:**
- **The Siege Tactic (against Turtlers):**
  - *Generator Sabotage:* If you refuse to leave the warm house, the creature stalks the yard and violently rips off the generator drive belt. Power cuts out, heating dies, and you are forced outside into pitch darkness to restart the engine.
  - *Window Harassment:* Claws slowly scrape along the frosted glass panes, shaking the camera and cracking the wooden frames.
- **The Attrition Tactic (against Panickers):**
  - *Gaslighting Sounds:* Peripheral branch snaps and snow crunches from deceptive angles induce false alarms.
  - *The Strike of Exhaustion:* The hunter waits until your flashlight battery drops below 18% or stamina is depleted before launching its fatal sprint.
- **The Ambush Tactic (against Explorers):**
  - *Silent Stalking:* Warning whistles and growls are completely suppressed.
  - *POI Cut-Off:* When you enter isolated locations (Mine Horizon-40, Logging KUNG, Radar Dome, Superdeep SG-4), the hunter maneuvers to ambush you at the narrow exit.

**Creature Learning & Counter-Play:**
- **Flashlight Adaptation:**
  - *Encounter 1:* The beam blinds and repels the creature normally.
  - *Encounter 2:* The creature raises its clawed arm over its eyes to shield its face, enduring the light longer and continuing to advance.
  - *Encounter 3+:* The creature weaves and dodges sideways, slipping out of your beam.
- **Flare Memory:**
  - Repelling the hunter with a signal flare on the same night no longer sends it miles away. It retreats only 35 meters and sets up an interception ambush on your trail home.

**Visual & Environmental Horror:**
- **Morning Barefoot Footprints:**
  - Following a night of stalking or siege, morning reveals deep, realistic barefoot human tracks in the sub-zero snow crust circling the house, peering into windows, and leading from the dark taiga.

---

**Заголовок (RU):** Кедр-7 v1.40.1: «Живой разум тайги» — Адаптивный ИИ и Осада станции

> **Важное примечание разработчика:**
> В обновлении **1.40.1** хоррор-составляющая игры выходит на принципиально новый уровень. Сущности в уральской тайге больше не подчиняются жестким скриптам и таймерам. Хищник обрёл собственный адаптивный «мозг»: он изучает ваш стиль игры, вычисляет ваши страхи и слабости, адаптирует тактику охоты и учится обходить вашу защиту.
> 
> Прячетесь ли вы в тёплом доме, паникуете при каждом шорохе или хладнокровно исследуете глухие аномалии — игра подстроится лично под вас.

**Скрытый профилировщик игрока (Player Profiler):**
- **Анализ психотипа в реальном времени:**
  - *Индекс паники:* Отслеживает резкие рывки камеры, нервное щёлканье фонариком и неоправданный бег на морозе.
  - *Фактор затворничества:* Замеряет долю времени в доме и скорость запирания дверей на засов.
  - *Осторожность и ресурсы:* Учитывает расход ракет, батарей и соблюдение правил Семёнова.
- **Три игровых архетипа:**
  - **Затворник:** Сидит у печи и радиостанции, боится выходить в ночь.
  - **Паникёр:** Пугается каждого звука, выжигает батарею фонаря и быстро выбивается из сил.
  - **Хладнокровный исследователь:** Уверенно уходит в глухую тайгу, экономит ресурсы и помнит правила.

**Адаптивные стратегии хищника (Hunter's Brain):**
- **Тактика «Осада» (против Затворников):**
  - *Диверсия на генераторе:* Если долго не выходить наружу, Ырка прокрадётся в будку дизеля и сорвёт ремень. Свет погаснет, дом начнёт выстывать, и игроку придётся в темноте идти заводить дизель.
  - *Скрежет в окна:* Когти скоблят по обледенелому стеклу, раскачивая рамы и нагнетая напряжение.
- **Тактика «Игра на истощение» (против Паникёров):**
  - *Ложные шорохи:* Хруст веток и снега на периферии провоцирует игрока тратить патроны и силы.
  - *Удар в момент бессилия:* Тварь выжидает, пока заряд фонаря опустится ниже 18% или иссякнет шкала бега, и лишь затем срывается в погоню.
- **Тактика «Бесшумная засада» (против Хладнокровных):**
  - *Отключение предупреждений:* Тварь не свистит и не рычит заранее.
  - *Блокировка выхода:* При входе в узкие локации (Шурф, КУНГ, Купол РЛС, Скважина СГ-4) хищник тихо занимает позицию у выхода.

**Обучение хищника и контр-меры:**
- **Привыкание к свету фонаря:**
  - *1-й контакт:* Свет ослепляет и прогоняет тварь.
  - *2-й контакт:* Тварь прикрывает лицо когтистой лапой, дольше выдерживая луч и сокращая дистанцию.
  - *3-й контакт:* Тварь петляет зигзагами, сбивая прицел фонаря.
- **Память на сигнальные ракеты:**
  - Повторный выстрел ракетой не обращает тварь в бегство — она отступает всего на 35 метров и устраивает засаду на обратном пути к дому.

**Свежие следы босых ног на снегу:**
- Утром после ночной осады вокруг жилого корпуса появляются цепочки глубоких босых следов, подходящих вплотную к окнам и уходящих в чащу.
