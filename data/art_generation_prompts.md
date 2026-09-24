# Промты для генерации арта — насыщение карты

Готовые тексты для картиночной генерации (Midjourney/SDXL/DALL-E — любая).
Разбито по категориям ассетов, у каждой — свои технические требования,
подсмотренные в уже существующих файлах проекта. Сохранённый PNG клади
ровно по указанному пути — движок подхватывает текстуру автоматически, без
правок кода (см. комментарий в шапке `scripts/map_object_defs.gd`:
"Арт пока плейсхолдер" — просто заменяешь файл).

---

## 0. Общие правила по категориям

**Объекты приключений на карте** (маяки, станции, тайники — то, что стоит
прямо на гексах глобальной карты, `assets/map_objects/`): это космос, а не
суша — **никаких наземных построек**. Не "здание, которое висит в вакууме"
(стены, крыша, дверь — то, что не имеет смысла без гравитации и атмосферы), а
настоящая орбитальная конструкция: модульная станция на фермах, с
стыковочными кольцами/рукавами, солнечными панелями, антеннами и
двигательными блоками, свободно висящая в пустоте — либо инсталляция,
буквально закреплённая на астероиде/обломке скалы (посадочные опоры,
крепёжные тросы, врезанные в породу модули). Ракурс 3/4 сверху (как иконка
юнита в стратегии), один объект по центру кадра, **прозрачный фон**, без
земли и без постамента (если это не астероид — тогда сам астероид является
частью объекта, а не землёй под ним), без текста и надписей. Разрешение не
критично — движок сам вписывает текстуру в клетку по большей стороне
(`map_object_overlay.gd`), ориентируйся на квадратный кадр 768×768–1024×1024.

**Корабли** (`assets/ships/...`): фотореалистичный 3D-рендер, камера строго
перпендикулярна продольной оси корпуса — **чистый ортографический вид сбоку
(profile/elevation), без малейшего наклона или перспективы**, силуэт корабля
читается плоско, как чертёж, а не под три четверти и не сверху/снизу. **Нос
корабля смотрит влево**, чёрный фон (не прозрачный — так сделаны все
существующие корабли людей и орков), детальная панельная обшивка, турели/
орудия, свечение окон и дюз акцентным цветом фракции.

**Планеты на стратегической карте** (`assets/planets/`): целая сфера
планеты, фотореалистичный рендер под спутниковый снимок, драматичный боковой
свет, **прозрачный фон**, квадратная композиция 1:1.

**Фон тактического боя** (`assets/space/backdrops/`) — отдельный, уже
описанный промт лежит в `AGENTS.md` (раздел про параллакс), сюда его не
дублирую — стиль другой (painterly, не фотореализм).

Цветовая палитра фракций (чтобы новый арт не спорил с уже готовым):
- **Земляне** — светлый металл, синие акценты (`assets/ships/human_new/*`).
- **Орки** — тёмный металл, агрессивный красный (`ENEMY_COLOR` в коде).
- **Пираты** — ржавый тёмный металл, красно-оранжевые огни, черепа/шипы
  (см. `assets/map_objects/pirate_base.png`).
- **Торговцы/нейтралы** — жёлтый акцент (`NEUTRAL_ENGINE_COLOR`).
- **Стражи Древних** (см. §3) — холодный бело-фиолетово-бирюзовый
  (`ANCIENT_ENGINE_COLOR` в коде), уже используется в бою, чтобы конструкт
  на карте и миникарте сразу читался как четвёртый, ни на кого не похожий
  силуэт.

---

## 1. Новые объекты карты — уже добавлены в код, ждут арта

Эти семь объектов уже прописаны в `scripts/map_object_defs.gd` и реально
расставляются генератором карты (проверено `tools/debug_map_objects.gd`).
Сейчас вместо картинки рисуется цветной кружок с глифом — как только положишь
PNG по пути, кружок заменится сам.

**Заброшенный пост прослушки** — `assets/map_objects/listening_post.png`
> A small derelict sci-fi relay station bolted onto a jagged chunk of rock —
> a tiny asteroid with mining anchors and support struts driven into its
> surface, carrying a cracked dish antenna array and a cluster of dark hull
> modules with faint blue emergency lights still flickering, damaged and
> abandoned, cold desaturated grey-blue metal, the asteroid itself is part
> of the object (not ground beneath it), semi-realistic 3D render, 3/4
> top-down angle, fully transparent background, no text, no UI, single
> object centered in frame.

**Тайник контрабандистов** — `assets/map_objects/smuggler_cache.png`
> A hidden smuggler's cargo cache floating free in space: a cluster of dark
> unmarked shipping containers and crates magnetically clamped together with
> makeshift armor plating and a small thruster pod, dim warning lights in
> dull orange-red, scratched serial numbers painted over, no station hull
> around it — just the clamped container cluster itself, sci-fi
> semi-realistic 3D render, 3/4 top-down angle, fully transparent
> background, no text, no UI, single object centered in frame.

**Ветеранский форпост** — `assets/map_objects/veteran_outpost.png`
> A small fortified orbital training station for veteran pilots: a compact
> modular hull on structural trusses with docking clamps holding a single
> light fighter, external practice turrets, solar panel wings, warm green
> status lights, sturdy human-faction light metal hull with blue trim, no
> walls or roof — reads as a station module free-floating in space, not a
> building, semi-realistic 3D render, 3/4 top-down angle, fully transparent
> background, no text, no UI, single object centered in frame.

**Боевой симулятор** — `assets/map_objects/combat_simulator.png`
> A sci-fi combat simulation station in orbit: a spherical holographic
> training rig held by a light structural frame with solar panels and
> a docking arm, glowing blue holographic ship silhouettes projected
> inside the sphere, clean human-faction metal hull, no walls or roof —
> an open orbital rig, not a building, semi-realistic 3D render, 3/4
> top-down angle, fully transparent background, no text, no UI, single
> object centered in frame.

**Разбившийся зонд-разведчик** — `assets/map_objects/crashed_probe.png`
> A small crashed sci-fi survey probe tumbling in space, cracked outer
> shell with one bent solar panel still deployed and a broken thruster
> pod, a faint golden glow leaking from an exposed artifact-like core
> inside, semi-realistic 3D render, 3/4 top-down angle, fully transparent
> background, no text, no UI, single object centered in frame.

**Плавучие обломки** — `assets/map_objects/flotsam_wreck.png`
> A small tumbling cluster of spaceship debris and hull fragments held
> loosely together by torn cabling, neutral grey scorched metal, no
> faction markings, semi-realistic 3D render, 3/4 top-down angle, fully
> transparent background, no text, no UI, single object centered in frame.

---

## 2. Патрульные корабли — механика уже есть, не хватает узнаваемости

`_generate_patrols` в `space_strategy_map.gd` уже расставляет по карте 8
мобильных "патрулей" (зоны контроля радиусом 9 клеток вокруг кластеров
месторождений) — они через одного пиратские и торговые и используют
обычные `assets/ships/pirates/` и `assets/ships/traders/`. То есть
патрули на карте уже есть, просто визуально неотличимы от обычной охраны
месторождения — нет отдельного "вот это патруль, а не просто пост".
Если хочется, чтобы они правда читались отдельным слоем (как бродячие
отряды в HoMM3), самый дешёвый путь — не новая механика, а новый silhouette:

**Патрульный корвет (нейтральный)** — на будущее, для отдельной иконки
патруля на карте (не для тактического боя):
> A compact autonomous sci-fi patrol corvette, twin scanner arrays and a
> rotating sensor dish on top, pale neutral grey-yellow hull, camera locked
> exactly perpendicular to the hull's long axis — orthographic side
> elevation, zero perspective tilt, flat profile silhouette, nose to the
> left, black background, semi-realistic 3D render, no text, no UI.

---

## 3. Новая фракция — "Стражи Древних" (лёгкий вариант уже в коде)

В лоре уже была зацепка: угловой объект `void_vault` называется "Схрон
Древних" — древняя раса уже упомянута, просто никак не материализована.
Вместо пятой сущности с нуля — достроили то, что уже подвешено в тексте:
пробуждённые сторожевые конструкты Древних, охраняющие дальний космос.

Лёгкий вариант **уже реализован в коде** (не фракция игрока, не ИИ-ход, не
база — редкий и опасный нейтральный противник, в духе HoMM3-нейтралов вроде
драконов/фениксов):

- Три новых корабля-стража — `ancient_sentinel` (V ранг), `ancient_warden`
  (VI), `ancient_colossus` (VII) — в `unit_defs.gd`, заметно крепче и
  больнее пиратов того же ранга (`damage_factor` 1.15).
- Три шаблона отряда в `guardian_defs.gd`: `ancient_outpost` (4 часовых),
  `ancient_stronghold` (3 часовых + 3 хранителя), `ancient_colossus_guard`
  (4 хранителя + 1 колосс).
- Новый объект карты `ancient_relic` ("Реликварий Древних",
  `map_object_defs.gd`) — в отличие от `void_vault` НЕ привязан к углам,
  расставлен по всей дальней части карты (`SPAWN_COUNT: 3`), охрана —
  `ancient_stronghold`.
- Бой с ними корректно подписан отдельной фракцией в HUD ("СТРАЖИ ДРЕВНИХ",
  не "ПИРАТЫ") и красится в бою собственным холодным фиолетовым цветом
  двигателей (`tactical_battle.gd:ANCIENT_ENGINE_COLOR`), а не общим жёлтым
  нейтральным — чтобы в бою сразу читалось "это не пираты".

Сейчас у всех трёх кораблей плейсхолдер-арт (`tools/make_ancient_placeholders.py`,
кристаллический силуэт, нос влево, холодный бело-фиолетово-бирюзовый —
процедурная заглушка по образцу `tools/make_orc_placeholders.py`). Промты
для настоящего арта — ниже, заменяют ровно эти файлы без правок кода.

**`assets/ships/ancient/tier_5.png`** (Страж-часовой, V ранг)
> A small ancient alien guardian drone ship, faceted crystalline hull,
> glowing violet-teal energy core visible through translucent armor
> plates, no visible windows, camera locked exactly perpendicular to the
> hull's long axis — orthographic side elevation, zero perspective tilt,
> flat profile silhouette, nose to the left, black background,
> semi-realistic 3D render, no text, no UI.

**`assets/ships/ancient/tier_6.png`** (Страж-хранитель, VI ранг)
> A mid-size ancient alien guardian warship, angular faceted crystalline
> hull architecture unlike any human engineering, a larger glowing
> violet-teal core at its center with energy seams branching along the
> plating, no visible windows or cockpit, camera locked exactly
> perpendicular to the hull's long axis — orthographic side elevation,
> zero perspective tilt, flat profile silhouette, nose to the left, black
> background, semi-realistic 3D render, no text, no UI.

**`assets/ships/ancient/tier_7.png`** (Страж-колосс, VII ранг)
> A massive ancient alien guardian warship, geometric crystalline hull
> architecture unlike any human engineering, cold white and violet-teal
> glowing energy seams running along sharp angular plating, a dominant
> glowing core at its heart, no visible windows or cockpit, camera locked
> exactly perpendicular to the hull's long axis — orthographic side
> elevation, zero perspective tilt, flat profile silhouette, nose to the
> left, black background, semi-realistic 3D render, no text, no UI.

**`assets/map_objects/ancient_relic.png`** (Реликварий Древних — объект карты)
> A small ancient alien relic installation embedded directly into a jagged
> fragment of rock drifting in space — dark angular crystalline shards
> grown out of the asteroid itself around a glowing violet-teal artifact
> core, faint energy motes drifting around it, the rock fragment is part of
> the object, not ground beneath it, semi-realistic 3D render, 3/4 top-down
> angle, fully transparent background, no text, no UI, single object
> centered in frame.

Если позже захочется дорастить это до полноценной третьей играбельной
стороны (своя база, экономика, ход ИИ — модуль уровня `orc_ai.gd`,
недели работы, не часы), этим двум промтам это тоже пригодится:

**Планета/база Древних (для стратегической карты, если возьмём полный вариант)**
> A dead alien world entirely covered in dark angular crystalline
> structures, faint violet-teal bioluminescent glow along deep fracture
> lines across the surface, no clouds, no water, ominous and ancient,
> photorealistic satellite-view planet render, dramatic rim lighting,
> fully transparent background, square 1:1 composition, no text, no ships.

**Флагман-герой Древних (если возьмём полный вариант)**
> A massive ancient alien guardian flagship, geometric crystalline hull,
> cold white and violet-teal glowing energy seams, no visible windows or
> cockpit, square composition, nose pointing up, transparent background,
> semi-realistic 3D render, no text, no UI.

---

## Орбитальные станции случайной карты (ImageGen)

Общий финальный запрос для набора: `stylized-concept`, изометрия 3/4,
детализированный полуреалистичный игровой спрайт, тёмная сталь, синий корпус,
латунные детали и голубые огни. Станция **свободно висит в космосе**;
видны нижний корпус, подвесные модули и маневровые двигатели. Настоящий
прозрачный фон, один объект целиком в кадре. Без грунта, пола, фундамента,
лестниц, наземной площадки, планеты, надписей и рамки.

- `weekly_shipyard.png` — верфь в форме подковообразного стыковочного кольца,
  с собираемым истребителем, роботизированными манипуляторами и движителями
  под подвешенной сборочной люлькой.
- `weekly_resource_hub.png` — перерабатывающий модуль с двумя манипуляторами,
  удерживающими кристалл и руду; контейнеры подвешены снизу, под корпусом
  работают маневровые двигатели.
- `weekly_credit_terminal.png` — защищённый орбитальный банковский узел с
  золотистым светящимся хранилищем, двумя боковыми капсулами и двигателями
  под герметичным круглым корпусом.
- `impulse_station.png` — ускоритель из трёх магнитных плавников, центральной
  энергетической катушки, яркого голубого потока и малого силового модуля
  под открытым кольцом.
- `observation_tower.png` — компактная обзорная станция с голубой сканирующей
  тарелкой и антенной; снизу заострённый приборный модуль и небольшие
  маневровые двигатели.

## Как пополнять этот список дальше

Формат один и тот же: назвать объект/корабль, взять шаблон из
соответствующего раздела §0, подставить конкретику. Новый пункт для
`map_object_defs.gd` не требует новой логики в `space_strategy_map.gd`,
если использует уже существующий `family` (`loot`, `artifact`, `info`,
`stat_boost`, `hero_xp`, `guardian_reward`, `obelisk`, `university`,
`beacon`, `teleport`, `quest`) — просто данные плюс арт.
