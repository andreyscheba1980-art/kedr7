# Дев-лог v1.40.2 — «Глубинный психосоматический хоррор: Deep Phobia Engine» (Itch.io Major update)

Охватывает обновление v1.40.2: 4-осевой вектор страхов ($\vec{\Phi}$), биометрический анализ подсознательных триггеров игрока (клаустрофобия против агорафобии, фонофобия против скотофобии), психосоматические искажения восприятия (`PsychosomaticFX`), туннельное зрение, инфразвуковой гул открытой тайги, слуховая парейдолия и периферийные силуэты.

---

**Title (EN):** Kedr-7 v1.40.2: The Deep Phobia Engine — Psychosomatic Perception & Fear Vectors

> **Developer's Note:**
> Version **1.40.2** implements the "Deep Phobia Engine" — an advanced psychological horror subsystem that probes each player's subconscious fear profile and dynamically alters sensory reality without relying on cheap Hollywood jump scares.
> 
> The game no longer treats all players equally: by sampling involuntary biometric reactions, the simulation maps your personal $\Phi$-Vector across 4 continuous psychological axes and exploits your exact vulnerabilities.

### 1. The 4-Axis $\Phi$-Vector & Biometric Profiling:
- **Spatial Axis ($\Phi_{\text{spatial}} \in [-1.0, +1.0]$):**
  - *Claustrophobia ($-1.0$):* Detected by rapid sprint exits from confined spaces (sub-station cellar, bunker, darkroom, vestibule, attic), reluctance to close doors behind, and corner-fleeing reflexes.
  - *Agoraphobia ($+1.0$):* Detected by fence/wall hugging in the yard, panic sprints back to station walls upon tension rises, and refusal to venture deep into the open blizzard.
- **Sensory Axis ($\Phi_{\text{sensory}} \in [-1.0, +1.0]$):**
  - *Phonophobia ($-1.0$):* Evaluates the involuntary *Audio Freeze Reflex* (abrupt deceleration from $>1.8$ to $<0.2$ m/s within 0.35s when ambient snaps or tension jumps occur, followed by careful listening micro-rotations).
  - *Scotophobia ($+1.0$):* Evaluates frantic camera saccades in darkness and obsessive dynamo flashlight cranking above 82% charge.
- **Autonomy Axis ($\Phi_{\text{autonomy}} \in [0.0, 1.0]$):**
  - Tracks paranoia of losing control: repeated testing of locked doors, peepholes, and stove dampers.
- **Isolation Axis ($\Phi_{\text{isolation}} \in [0.0, 1.0]$):**
  - Measures dependency on human presence: lingering by the radio receiver and clinging to the dog Naida.

### 2. Psychosomatic Perceptual Distortions (`PsychosomaticFX`):
- **Claustrophobic Manifestations:**
  - *Dynamic FOV Compression:* Entering tight rooms subtly constricts camera FOV by up to $-12^\circ$, creating suffocating tunnel vision.
  - *Acoustic Vacuum:* Ambient wind creaks fade into a low muffled rumble while the meteorologist's own racing heartbeat dominates the soundscape.
  - *Stamina Choke:* Trying to sprint in confined spaces drains $+35\%$ more stamina as panic tightens the chest.
  - *Hesitation Latch:* Door latches occasionally stick with a metallic creak for 0.35s, inducing the fear of being trapped inside.
- **Agoraphobic Manifestations:**
  - *Sub-Bass Infrasound Drone:* In the vast open taiga ($>35\text{m}$ from station), an oppressive low-frequency drone ($28-45\text{ Hz}$) subtly creeps into the audio spectrum, creating primal dread under the infinite frozen sky.
  - *Nightmare Snow Drag:* In distant snowfields, steps feel sluggish ($-12\%$ speed dampening), recreating the classic nightmare sensation of running in place.
  - *Flanking Ghost Steps:* At a 40-meter perimeter in the whiteout, phantom footsteps pace parallel to your trajectory.
- **Phonophobic Manifestations:**
  - *The 6th Footstep:* Stopping after a run outside triggers an asynchronous delayed crunching step right behind your back ($1.35\text{m}$ distance).
  - *Auditory Pareidolia:* Quiet, indistinct whispers are delicately woven into wind gusts and radio static at the threshold of hearing.
- **Scotophobic Manifestations:**
  - *Peripheral Shadow Silhouettes:* Faint humanoid shadow figures appear at the extreme edges of vision ($55^\circ-72^\circ$ off-center); the moment you turn to inspect them directly, they instantaneously dissolve into the dark air.
  - *Canopy Eyeshine Mirages:* Pairs of retroreflective glints peer down from the high spruces, blinking and vanishing when illuminated by the direct flashlight beam.

---

**Заголовок (RU):** Кедр-7 v1.40.2: «Глубинный психосоматический хоррор: Deep Phobia Engine»

> **Важное примечание разработчика:**
> В версии **1.40.2** реализована глубокая архитектурная система психосоматического ужаса — **Deep Phobia Engine**. Игра больше не использует типовые скрипты: она незаметно считывает ваши подсознательные рефлексы и проецирует персонализированные искажения восприятия прямо в физиологию дежурного.
> 
> Никаких дешёвых скримеров: игра искажает ткань реальности, эксплуатируя именно те триггеры, которых боитесь лично вы.

### 1. 4-осевой вектор фобий ($\vec{\Phi}$) и биометрический анализ:
- **Ось пространства ($\Phi_{\text{spatial}}$ от $-1.0$ до $+1.0$):**
  - *Клаустрофобия ($-1.0$):* Фиксирует стремительный побег спринтом из тесных помещений (подпол, бункер, КУНГ, тамбур, чердак, сарай), нежелание прикрывать за собой двери и панику в тупиках.
  - *Агорафобия ($+1.0$):* Фиксирует прижимание к стенам станции и забору, паническое бегство к дому при малейшем росте напряжения и страх перед открытой целиной.
- **Ось восприятия ($\Phi_{\text{sensory}}$ от $-1.0$ до $+1.0$):**
  - *Фонофобия ($-1.0$):* Оценивает непроизвольный *акустический стоп-рефлекс* (мгновенный сброс скорости с $>1.8$ до $<0.2$ м/с за 0.35 секунды при звуках веток или скачках напряжения с последующим замиранием и прислушиванием).
  - *Скотофобия ($+1.0$):* Оценивает судорожные саккады взгляда в темноте и маниакальное подкручивание жучка-фонарика при заряде выше 82%.
- **Ось автономии ($\Phi_{\text{autonomy}}$ от $0.0$ до $1.0$):**
  - Паранойя заклинивших механизмов: многократная проверка запертых дверей, глазка и заслонок печи.
- **Ось изоляции ($\Phi_{\text{isolation}}$ от $0.0$ до $1.0$):**
  - Зависимость от человеческого присутствия: нежелание отходить от радиоприёмника и привязанность к собаке Найде.

### 2. Психосоматические искажения реальности (`PsychosomaticFX`):
- **Проявления Клаустрофобии:**
  - *Динамическое сжатие FOV:* В тесных комнатах угол обзора плавно сужается на величину до $-12^\circ$ (эффект туннельного зрения и удушья).
  - *Акустический вакуум:* Внешний мир приглушается, а в ушах начинает гулко пульсировать собственное сердце.
  - *Удушающий расход выносливости:* Попытка бежать в замкнутом пространстве расходует на $+35\%$ больше сил.
  - *Залипающий засов:* Двери метеостанции на долю секунды клинит с глухим металлическим стуком, создавая панику запертой ловушки.
- **Проявления Агорафобии:**
  - *Инфразвуковой рокот под открытым небом:* В тайге дальше 35 метров от дома плавно нарастает низкочастотный гул в голове ($28-45\text{ Гц}$), вызывающий животный ужас перед открытым небом.
  - *Кошмарный вязкий снег:* Вдали от ориентиров шаг замедляется на $12\%$, воссоздавая ощущение бессильного бега из ночных кошмаров.
  - *Фланговые шаги в буране:* На дистанции 40 метров сквозь метель звучат шаги, крадущиеся параллельно курсу игрока.
- **Проявления Фонофобии:**
  - *Запоздалый 6-й шаг:* При остановке после бега на улице прямо за спиной (в $1.4\text{ м}$) раздаётся чёткий хруст снега с задержкой 0.35 секунды.
  - *Слуховая парейдолия:* В шорохе ветра и шуме радиоэфира начинают мерещиться шёпоты и обрывки фраз на грани слухового порога.
- **Проявления Скотофобии:**
  - *Периферийные силуэты:* В боковом поле зрения ($55^\circ-72^\circ$) на секунду проявляется тёмный силуэт; стоит повернуть голову и посмотреть прямо на него — он мгновенно растворяется в морозном воздухе.
  - *Отблески глаз в ветвях:* Высоко на елях на секунду вспыхивают две желтоватые точки отраженного света, исчезающие при наведении прямого луча фонаря.

---

### Сборка и совместимость:
- Полная обратная совместимость с сохранениями v1.40.0 и v1.40.1.
- Все 20 контрольных сценариев и автотестов успешно пройдены.
- Готовый релиз собран в `build/Kedr7_v1.40.2/Kedr7.exe` и упакован в архив `build/Kedr7_v1.40.2_windows.zip`.
