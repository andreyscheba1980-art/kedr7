# Дев-лог v1.40.0 — для itch (Devlog → New post, тип Major update)

Охватывает обновление v1.40.0: глобальное расширение карты, исправление всех построек станции, навигацию снегохода «Буран», систему наград за исследование и 4 новые мистические локации.

---

**Title (EN):** Kedr-7 v1.40.0: Buran navigation, the Time Horizon and mysteries of the deep

> **Developer's Note:**
> Version **1.40.0** represents a near-final blueprint of what the full release of **Kedr-7** will look, sound, and feel like. The core foundation is now fully in place: the sprawling snowy Ural taiga, expeditions aboard the Buran snowmobile, tense night shifts inside the lonely weather station, authentic Soviet analog instrumentation, and deep anomalous exploration.
> 
> However, active development is still ongoing ahead of the full release: specific mechanics, survival balancing (cold and fuel consumption), entity behaviors, and instrument interfaces are subject to further tweaking, polish, and changes based on your feedback and playtest impressions. Your thoughts are essential to shaping the final experience — please share your feedback and observations in the comments!

**Buran navigation: you won't get lost in the taiga anymore.**
- **ARK-9 Analog Radio Compass:** Mounted right on the handlebars of the Buran snowmobile. Its physical needle continuously points back toward the Kedr-7 station beacon. An integrated 6E1P "magic eye" vacuum tube pulses and vibrates when approaching geomagnetic and spatial anomalies.
- **Dynamic Snow Tracks:** The Buran now carves a 3-ribbon track into the snow behind it (a central wide tread imprint and two smooth ski ruts) buffered for 350 meters. When blinded by a blizzard, you can turn around and follow your own trail home.
- **Reflective Road Stakes:** Every 38 meters along all four winter road cuts (to the tower, drill rig, logging camp, and southern route), wooden snow stakes with cataphotes now flare brightly in the headlight beam.

**Exploration rewards & survival economy.**
Exploring remote points of interest now yields crucial survival gear:
- **Geologist's Sheepskin Coat:** Found in the logging camp's enterable KUNG trailer. Reduces outdoor cold rate by 35%, making extended expeditions feasible.
- **Safari Variator Belt:** Sourced from the frozen skidder tractor. Boosts the snowmobile's traction and top speed through deep snow crust by +35%.
- **Infrared Film (Tasma / Svema I-840):** Rare film cartridge for the Zenit-E camera. Developing it in the station darkroom and inspecting frames under the 8× optical loupe exposes hidden thermal and otherworldly specters.
- **Collectible Audio Tapes:** "Dubov's Field Journal" and "Special Comm-17". Playable on the Vesna-306 tape deck, featuring hidden voice layers and Morse frequency ciphers for the R-250M radio receiver.
- **Field Fuel & Batteries:** A-76 petrol canisters for the stove and Buran tank, plus dry Saturn battery cells to restore flashlight charge to 100%.

**Four new anomalous POIs.**
- **POI 11 — Abandoned Permafrost Mine ("Time Horizon-40"):** Far eastern ravine `(145, -140)`. Decoville mine tracks, derailed iron ore cart, larch timbers, and ancient icicles. Inside the portal, time itself dilates: the day timer slows down to 35%, the radio compass needle trembles, and infrasound echoes from the collapsed adit.
- **POI 12 — Frozen TDT-55 Skidder in Devil's Ravine:** Western creek `(-150, 45)`. An orange logging tractor embedded in river ice. The radio inside its frostbitten cab spontaneously comes alive, transmitting eerie Morse code and static-laced murmurs.
- **POI 13 — Hilltop Radar Geodome ("Air Defense Dome"):** Northern ridge `(-140, -135)`. A fractured radio-transparent dome enclosing a giant parabolic wireframe radar antenna. Standing at its acoustic focal point concentrates distant forest whispers from miles away.
- **POI 14 — Superdeep Borehole SG-4 ("Voice of the Abyss"):** Southern plateau `(55, 195)`. A concrete wellhead sealed with a 16-bolt heavy blind flange, an acoustic listening tube, pegged pressure gauges, and quartz core boxes. Deep seismic groans rise from the crust.

**Station and structure overhauls.**
- **Meteo Tower & Staircase:** Completely sealed the tower shaft south wall and upper ceiling transitions. Ascending the stairs no longer reveals any void or detached walls.
- **Station Interior Polish:** Relocated the darkroom safety lamp onto the wall directly above the chemical developing trays (clearing the doorway), and installed an authentic Soviet fire shield under the tower stairs (framed red board, steel crowbar, pike pole, axe, conical bucket, and sandbox).
- **Driller's Balok & Logging Camp KUNG:** Completely transformed into warm, enterable cabins with functional doors, amber kerosene lamp glow, interior furniture, loot, and handwritten lore notes.
- **Special Comm Bunker:** Added a heavy steel hatch clank sound upon ladder climbing and 3D dripping water ambient.

**Seamless Save Migration & Anti-Stuck Safeguards:**
- **Automatic Legacy Save Importer:** Upgrading from previous versions now seamlessly carries over your progression. The game automatically searches adjacent version folders and AppData locations for older saves and upgrades them safely, creating a pristine backup (`save_legacy_backup.json`).
- **Safe Spawn & Anti-Stuck Protection:** With over a dozen structures remodeled and new interiors built, loaded saves ensure the player begins their shift inside the warm station house (`Station.SPAWN`) near the stove and radio. An active physics sweep automatically verifies the player's torso is clear of geometry, preventing any clipping or getting stuck in modified terrain.

**Major Performance & FPS Optimizations:**
- **Snowmobile Trail MultiMesh:** Replaced over 1,000 individually allocated mesh instances with a high-performance single-draw-call `MultiMesh` ring buffer. Riding the Buran no longer degrades frame rate over time.
- **Static Batching Overhaul:** Whitelisted 600+ static dressing props (station lore, lab apparatus, field props) into combined spatial chunks, dramatically reducing CPU/GPU driver overhead.
- **Shadow Performance:** Disabled heavy alpha-scissor shadow calculations on distant billboard trees for Medium and Low quality presets, ensuring a stable 60 FPS on mid-range PCs and laptops.

Press **F9** at any moment in-game to generate a bug report. Feedback is welcome in the comments!

---

**Заголовок (RU):** Кедр-7 v1.40.0: навигация «Бурана», Шурф Времени и тайны глубин

> **Важное примечание разработчика:**
> Версия **1.40.0** — это уже очень близкий, почти финальный срез того, как будет выглядеть, звучать и играться релизная версия «Кедра-7». Основной скелет проекта уже собран: открытая заснеженная тайга, выезды на «Буране», рутинные и пугающие ночные дежурства, советские аналоговые приборы и исследование аномалий вышли на проектный уровень качества.
> 
> Тем не менее, игра всё ещё находится в активной разработке перед релизом: отдельные механики, тонкий баланс замерзания и расхода топлива, поведение ночных сущностей и взаимодействие с аппаратурой могут полироваться, перенастраиваться и меняться на основе ваших отзывов и прохождений. Нам критически важно знать ваши ощущения — пишите в комментариях всё, что понравилось, показалось сложным, пугающим или неудобным!

**Навигация на «Буране»: теперь в тайге не заблудиться.**
- **Аналоговый радиокомпас АРК-9:** Установлен прямо на руле «Бурана». Его физическая стрелка непрерывно пеленгует радиомаяк станции «Кедр-7». В корпус вмонтирован светящийся индикатор — лампа 6Е1П («магический глаз»), лепестки которой нервно вибрируют и сужаются вблизи аномалий.
- **Буранный след в снегу:** Снегоход оставляет за собой глубокую трёхполосную колею — широкий след центральной гусеницы и две лыжни по бокам. В буран и пургу всегда можно развернуться и выйти домой по собственной лыжне.
- **Снегомерные вешки с катафотами:** Вдоль всех четырёх зимников через каждые 38 метров установлены деревянные вешки со световозвращателями, ярко вспыхивающими в луче фары снегохода.

**Экономика наград и выживание.**
Исследование дальних точек теперь даёт реальные преимущества для выживания:
- **Овчинный тулуп геолога:** Висит на крючке в открываемом КУНГе лесорубов. Снижает скорость замерзания на открытом воздухе на 35%.
- **Ремень вариатора «Сафари»:** Снимается с замёрзшего трактора-трелёвочника. Увеличивает скорость и тягу «Бурана» по целине на +35%.
- **Инфракрасная фотоплёнка («Тасма / Свема И-840»):** Редкая кассета для «Зенита-Е». При проявке в фотокомнате и изучении негативов под 8× лупой проявляет тепловые силуэты и скрытые спектральные феномены.
- **Магнитные ленты для магнитофона «Весна-306»:** «Полевой дневник Дубова» и «Спецсвязь-17». Обе записи содержат скрытый звуковой слой и частотные шифровки для радиоприёмника Р-250М.
- **Топливо и сухие батареи:** Канистры бензина А-76 для печи и бака снегохода, а также элементы «Сатурн», восстанавливающие 100% заряда фонаря.

**Четыре новые аномальные точки интереса (POI).**
- **POI 11 — Заброшенная ледяная штольня («Шурф Времени» / Горизонт-40):** Восточный распадок `(145, -140)`. Лиственничные оклады, дековилька, сошедшая чугунная вагонетка и древние сосульки. В устье штольни замедляется само течение времени (таймер дня замедляется до 35%), сбивается стрелка компаса, а из забоя доносится инфразвук.
- **POI 12 — Вмёрзший трелёвочник ТДТ-55 в Чёртовой пади:** Западный лог `(-150, 45)`. Оранжевый гусеничный трактор, намертво вросший в речной лёд. В запертой кабине сам по себе оживает радиоприёмник, передающий морзянку и тихий монотонный шёпот.
- **POI 13 — Белый Шар РЛС на вершине сопки («Купол ПВО»):** Северная высота `(-140, -135)`. Растрескавшийся купол, скрывающий огромную параболическую сетчатую антенну. Акустический фокус тарелки собирает и усиливает звуки со всей округи.
- **POI 14 — Сверхглубокая скважина СГ-4 («Голос Бездны»):** Южное плато `(55, 195)`. Заглушенный 16 массивными болтами фланец, волновод прослушки недр, керновые ящики и манометр с зашкалившей стрелкой. Из глубины земли доносятся тектонические вздохи и глухой рокот.

**Ремонт станции и построек.**
- **Метеовышка и лестничный марш:** Наглухо зашита южная стена шахты башни и потолочные примыкания. При подъёме по лестнице больше нет никаких дыр в геометрии, зазоров и открытого неба.
- **Интерьер корпуса:** Красный неактиничный фонарь фотолаборатории убран из дверного проёма и аккуратно смонтирован на стене над столом с кюветами. Под лестницей башни установлен аутентичный пожарный щит в белой рамке (лом, багор, топор, конусное ведро и ящик с песком).
- **Буровой балок и КУНГ лесоповала:** Превращены в тёплые убежища с открываемыми дверями, светом керосинки, мебелью, записками и полезным снаряжением.
- **Бункер спецсвязи:** Добавлен звук захлопывающегося люка и атмосферный стерео-эффект капели грунтовых вод.

**Бесшовный перенос сохранений и защита от застреваний:**
- **Автоматический импорт сохранений:** При обновлении со старых версий прогресс переносится автоматически. Игра сама сканирует соседние папки предыдущих сборок и системный AppData, бережно обновляет формат файла и сохраняет резервную копию (`save_legacy_backup.json`).
- **Безопасный спавн на метеостанции:** Поскольку геометрия станции и тайги была значительно переработана, загрузка перенесённых сохранений автоматически начинает смену внутри тёплого жилого корпуса у печи и радиоприёмника. Активная физическая проверка коллизий гарантирует, что игрок ни при каких обстоятельствах не застрянет в обновлённых стенах или складках рельефа.

**Глобальная оптимизация производительности и FPS:**
- **След снегохода через MultiMesh:** Вместо спавна сотен отдельных мешей след «Бурана» переведён на аппаратный циклический MultiMesh (1 draw call вместо 1050). Просадки FPS при длительных поездках полностью устранены.
- **Пакетный батчинг статических объектов:** Включено объединение в общие сетки для более чем 600 предметов окружения (детализация комнат, аппаратура, посты наблюдения), сняв колоссальную нагрузку с видеокарты и процессора.
- **Оптимизация теней хвои:** Отключен расчёт тяжелых теней от альфа-карт дальних елей на профилях качества Medium и Low для стабильных 60 кадров/сек на ноутбуках.

Клавиша **F9** в любой момент сохраняет отчёт об ошибке. Пишите отзывы и наблюдения в комментариях!
