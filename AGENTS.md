# Heroes of the Galaxy — карта проекта для ИИ-агентов

Космическая стратегия в духе HoMM3: глобальная карта с героем-командующим,
пошаговый гексовый бой, экран планеты со стройкой и наймом.
**Godot 4.7 / GDScript, весь код и комментарии — на русском.**

Этот файл — навигационная карта. Читай его вместо того, чтобы грепать весь
репозиторий: ниже сказано, в каком файле лежит какая механика, какие структуры
данных ходят между модулями и где спрятаны грабли.

---

## 1. Запуск и проверки

Движок лежит прямо в репозитории (`Godot_v4.7.1-stable_win64.exe`, в .gitignore).

```bash
./Godot_v4.7.1-stable_win64_console.exe --path .
```

Тесты — обычные скрипты `SceneTree`, запускаются headless и пишут ошибки через
`push_error`, код выхода ненулевой при падении:

```bash
./Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/test_tactical_battle.gd
```

| Скрипт | Что проверяет |
|---|---|
| `tools/test_tactical_battle.gd` | сборка боя из `UNIT_BLUEPRINTS`, стеки, стороны |
| `tools/test_hero_progression.gd` | опыт, уровни, навыки, протоколы, награда, сохранение |
| `tools/test_game_settings.gd` | шины громкости, mute на нуле, сохранение настроек |
| `tools/ship_buildings_regression.gd` | каталог верфей, цены, отрисовка и недельный прирост |
| `tools/test_orc_ai.gd` | каталог орков, экономика и ход ИИ, автобой, оборона базы, итоги боёв, сейв |
| `tools/test_battle_tactics.gd` | гибель активного отряда от ответки не вешает ход, выход из окружения |

Отладочные скриншоты (сохраняют PNG в `user://`):

```bash
./Godot_v4.7.1-stable_win64_console.exe --path . res://tools/MapShot.tscn -- map.png 8 8 1.0 1001
```

`tools/BattleShot.tscn` — то же самое для тактического боя; второй аргумент
`orc` ставит против землян флот орков.

`tools/debug_orc_turns.gd` — не тест, а прогон 40 солов за ИИ орков с печатью
казны, стройки, найма и перемещений вождя. Запускать при правке порогов в
`orc_ai.gd`.

`tools/debug_map_objects.gd` — сводка раскладки карты: сколько объектов и
стражей какого вида реально встало, где стоят стражи с наградой.

**Диагноз баланса и что с ним делать — `data/balance_plan.md`.** Там же
оговорка про то, почему по одному прогону измерителя судить нельзя.

`tools/balance_sim.gd` — балансовый измеритель: потолок опыта на карте, дуэль
фракций ранг-в-ранг, зависимость «перевес по силе → реальный исход», прогон
кампании на 120 солов и финальное столкновение. Бои считаются НАСТОЯЩИМ
движком боя в режиме быстрого расчёта. Запускать после любой правки статов,
цен, недельного прироста или порогов ИИ.

Плейсхолдер-спрайты орков (корабли, здания, портрет вождя) генерируются
скриптом, а не рисуются руками — заменять файлы можно, не трогая код:

```bash
python tools/make_orc_placeholders.py
```

Веб-сборка: пресет `Web` в `export_presets.cfg`, вывод в `build/web/` (не в гите).

---

## 2. Карта репозитория

```
scenes/          4 сцены — вся структура узлов
  StrategicMain.tscn      точка входа (project.godot: run/main_scene)
  SpaceStrategyMap.tscn   глобальная карта + HUD
  TacticalBattle.tscn     пустой Node2D, всё строится кодом
  HumanPlanetScreen.tscn  экран планеты (много узлов, @onready в скрипте)

scripts/         вся логика
tools/           тесты и отладочные съёмщики скриншотов
data/            human_planet_buildings.json — раскладка зданий на планете
                 balance_plan.md — измеренный диагноз баланса и план правок
                 pirate_balance.md — как посчитаны составы пиратов
                 ship_configs/ — пусто, каталог редактора кораблей
assets/          спрайты (+ .import — генерируются Godot, не редактировать руками)
build/, .godot/  генерируемое, в .gitignore
```

### Скрипты по зонам ответственности

**Автозагрузки** (`project.godot [autoload]`):
- `scripts/game_settings.gd` — `GameSettings`: шины Master/Music/SFX, громкость
  (0–100), меню паузы по Esc (сохранить / в меню / выход).
  Сейв настроек в `user://settings.json`. Музыкальные плееры вешаются через
  `attach_music()` (шина Music, звучат на паузе).
- `scripts/hero_roster.gd` — `HeroRoster`: словарь героев между сценами,
  сигналы `hero_experience_gained` / `hero_leveled_up`, сейв в `user://heroes.json`.
- `scripts/ship_editor.gd` — `ShipEditor`: внутриигровой редактор хардпоинтов
  корабля, **открывается по F8**, всегда в дереве, но скрыт.
- `scripts/procedural_sfx.gd` — `ProceduralSfx`: звуки боя генерируются кодом
  (шум + синус в `AudioStreamWAV`, никаких аудиофайлов в assets нет), кешируются
  по `(тип, hull)`. `play_move/play_shot/play_destroyed(unit, delay)` — масштаб
  громкости/тона берётся из `hull` отряда, крупные корабли звучат мощнее.
  Плееры на шине `SFX`.

**Глобальная карта:**

| Файл | Роль |
|---|---|
| `space_strategy_map.gd` (~1500) | ядро: сетка 64×64, ход дня, движение по A*, ресурсы, генерация карты, запуск боёв, фоновая музыка (`_start_music/pause_music/resume_music`) |
| `space_obstacles.gd` / `space_obstacle_renderer.gd` | геометрия препятствий (общая для карты, навигации и миникарты) и её отрисовка |
| `guardian_defs.gd` / `guardian_overlay.gd` | составы нейтральных стражей (пираты и торговые конвои) и их иконки |
| `map_object_defs.gd` / `map_object_overlay.gd` | объекты приключений (обелиски, университет, сундуки) и плейсхолдер-иконки |
| `route_overlay.gd`, `production_overlay.gd`, `strategic_minimap.gd` | отрисовка маршрута, подписи месторождений, миникарта |
| `strategic_main.gd` | обёртка точки входа, **сбрасывает состояние планеты** — см. §6 |

**Тактический бой:**

| Файл | Роль |
|---|---|
| `tactical_battle.gd` (~1550) | вся боёвка: гексы, очередь ходов, урон, ИИ, протоколы, отрисовка, параллакс-фон |
| `tactical_battle_hud.gd` | минимальный HUD боя — одна полоса снизу (раунд/ход + 3 кнопки), сигналы `end_turn_requested` / `return_requested` |
| `protocol_book_hud.gd` | модальная «книга протоколов» (аналог книги заклинаний) |
| `battle_rewards.gd` | ценность корабля и расчёт опыта за бой |
| `battle_results_dialog.gd` | окно итогов боя |

**Герои:**

| Файл | Роль |
|---|---|
| `hero_defs.gd` | справочник: статы, таблица опыта, классы, навыки, ранги протоколов. Только данные и чистые функции |
| `hero.gd` | состояние одного героя: `class_name Hero`, опыт/уровни/навыки/армия |
| `hero_protocols.gd` | боевые заклинания: школы, эффекты, стоимость энергии |
| `hero_level_up_dialog.gd`, `skill_academy_dialog.gd` | окна прокачки и «университета» |

**Планета:**

| Файл | Роль |
|---|---|
| `human_planet_screen.gd` (~1500) | экран планеты: стройка, найм, гарнизон, биржа, редактор раскладки зданий |
| `human_planet_state.gd` | единственная точка чтения/записи `user://human_planet_state.json` |
| `unit_defs.gd` | общий справочник кораблей: и покупаемые юниты, и составы стражей. `get_unit()` отдаёт и орочьи корабли (см. ниже) |

**Орки — искусственный противник (сторона 2):**

| Файл | Роль |
|---|---|
| `orc_defs.gd` | каталог фракции: 10 кораблей (ранги I–V × обычный/элитный), постройки базы, их спрайты. Только данные и чистые функции |
| `orc_ai.gd` | `class_name OrcAI`: экономика, стройка, недельный прирост, наём, выбор целей и дневной перелёт вождя, автобой со стражами |
| `orc_base_overlay.gd` | постройки базы вокруг планеты орков; узел создаётся кодом в `_setup_orc_ai`, а не в .tscn |

**Оценка силы флота** — `fleet_power.gd` (`class_name FleetPower`). Отдельная
от `battle_rewards.gd:ship_value` метрика: `ship_value` отвечает «сколько
опыта стоит корабль», `FleetPower.ship_strength` — «насколько он силён в
бою». Вторая нужна потому, что бой подчиняется квадратичному закону, и по
линейной `ship_value` рой истребителей выглядит сильнее отряда эсминцев, хотя
проигрывает ему всухую. По `FleetPower` считают прогноз перед боем
(`battle_preview_dialog.gd`) и все пороги ИИ (`orc_ai.gd`).

Флот вождя — это `army` героя `orc_warlord` из `HeroRoster`, поэтому бой, опыт
и сейв героев работают без отдельного кода. Экономика и позиция вождя живут в
полях `OrcAI` и уезжают в сейв кампании словарём `orc_ai` (`to_dict`/`from_dict`).

---

## 3. Потоки сцен

```
StrategicMain (_enter_tree: HumanPlanetState.reset_to_default)
  └── SpaceStrategyMap
        ├── _open_human_planet()      → HumanPlanetScreen как child, карта на паузе
        │     └── close_requested     → _close_human_planet() → _sync_human_planet_state()
        ├── _open_guardian_battle()   → TacticalBattle с реальными флотами
        ├── _end_day()                → _run_orc_turn() — ход ИИ орков сразу
        │     └── бой с игроком       → TacticalBattle, ход доигрывается
        │                               в _resolve_orc_battle
        └── _open_tactical_battle()   → TacticalBattle с отладочным составом
```

`_swap_to_battle()` (`space_strategy_map.gd:268`) — важный узел: бой становится
`current_scene`, карта прячется и переводится в `PROCESS_MODE_DISABLED`,
а ссылки на неё живут в полях боя `return_scene` / `return_map` /
`return_process_mode`. Возврат — `tactical_battle.gd:_return_to_map()`.

Конфигурация боя передаётся **полями инстанса до `add_child`**, не сигналами:

```gdscript
battle.player_units_override = player_fleet   # Array[Dictionary]
battle.enemy_units_override  = enemy_fleet
battle.guardian_index        = index          # -1 = отладочный бой
battle.orc_battle_kind       = "hero"         # "" = бой не с орками
```

`orc_battle_kind` — бой с фракцией орков: `"hero"` (столкновение флотов),
`"planet"` (орки штурмуют планету игрока), `"orc_planet"` (игрок штурмует базу
орков). Итог разбирает `space_strategy_map.gd:_resolve_orc_battle`, как
`guardian_index` разбирает `_resolve_guardian_battle`.

Пустые override сохраняют старое поведение — фиксированный состав
`UNIT_BLUEPRINTS`. Так же тесты и `BattleShot.tscn` запускают сцену напрямую.

---

## 4. Где что менять

| Задача | Куда идти |
|---|---|
| Баланс кораблей (hull/attack/damage/move/range/initiative) | `unit_defs.gd:UNITS` — и `tactical_battle.gd:UNIT_BLUEPRINTS` для отладочного боя |
| Цены и недельный прирост юнитов | `unit_defs.gd` — поля `cost`, `weekly_growth` |
| Формула урона, добивание стеков | `tactical_battle.gd:_damage_multiplier / _roll_stack_damage / _casualties_for` (≈403–443) |
| Очередь ходов и раунды | `tactical_battle.gd:_rebuild_turn_order / _advance_turn / _begin_round` (≈444–530) |
| ИИ противника в бою | `tactical_battle.gd:_run_enemy_turn / _best_target_for / _best_enemy_move_cell` (≈530–630) |
| Выбор клетки для манёвра (окружение) | `tactical_battle.gd:_move_cell_score` + веса `MOVE_SCORE_*`, `SURROUNDED_LIMIT` |
| Ответный залп (только в упор, раз за раунд) | `tactical_battle.gd:_attack_unit` — условие `distance <= 1 and not target["retaliated"]` |
| Гексовая геометрия (расстояния, LoS, пути) | `tactical_battle.gd:_offset_to_cube / _cube_to_offset / _hex_neighbors / _hex_line` — острая вершина, cube-координаты "odd-r" (смещаются нечётные РЯДЫ, не колонки) |
| Мультиклеточные корабли (IV+ ранг — 2 клетки по горизонтали) | `tactical_battle.gd:MULTI_CELL_MIN_TIER` + `_footprint_cells / _footprint_for_move / _footprint_valid / _secondary_cell` |
| Параллакс и фоновая декорация боя (планета/луна/туманность) | `tactical_battle.gd:PARALLAX_LAYERS` + `_draw_background / _update_parallax_target`; декорации — `assets/space/backdrops/` (см. `README.md` там же, промт для генерации — §9 ниже) |
| Выхлоп двигателей (цвет по стороне/фракции) | `tactical_battle.gd:_draw_engine_exhaust / _engine_color` — игрок синий (`PLAYER_COLOR`), орки красный (`ENEMY_COLOR`), торговцы/пираты жёлтый (`NEUTRAL_ENGINE_COLOR`); рисуется в локальных координатах корабля до текстуры, так что зеркальный `draw_set_transform` для игрока (см. §7a) сам разворачивает хвост на нужную сторону |
| Заклинания-протоколы | `hero_protocols.gd:PROTOCOLS` + применение в `tactical_battle.gd:_cast_protocol` (≈990) |
| Опыт за бой | `battle_rewards.gd:ship_value()` |
| Прокачка героя, навыки | `hero_defs.gd` (данные, `MAX_SKILL_SLOTS = 6`) + `hero.gd:roll_level_up / apply_level_up` |
| Звуки боя (движение/выстрел/уничтожение) | `procedural_sfx.gd` (синтез) + вызовы в `tactical_battle.gd:_start_unit_move / _attack_unit` |
| Громкость, меню паузы по Esc (сейв/выход) | `game_settings.gd` |
| Генерация карты (месторождения, препятствия, объекты) | `space_strategy_map.gd:_generate_*` (≈1276–1440) |
| Сила стражей от удалённости | `space_strategy_map.gd:_threat_distance / _guardian_template_for_distance` + `guardian_defs.gd:TEMPLATES` |
| Красный курс, если маршрут упирается в стража | `route_overlay.gd:_first_guardian_index / _draw_danger_marker` — хвост пути после первой живой охраняемой клетки красный и пунктирный, сама клетка обведена кольцом; источник опасности тот же `guardian_at`, что и в `space_strategy_map.gd:_check_guardian_encounter` |
| Баланс орочьих кораблей | `orc_defs.gd:UNITS` — множители фракции в шапке файла |
| Постройки и цены базы орков | `orc_defs.gd:BUILDING_DEFS` + порядок стройки `orc_ai.gd:BUILD_PRIORITY` |
| Агрессивность и осторожность ИИ | `orc_ai.gd` — `ASSAULT_POWER_RATIO`, `GUARDIAN_ATTACK_RATIO`, `AUTO_BATTLE_ATTRITION`, `REGROUP_GARRISON_RATIO` |
| Ход компьютера, бои с орками, конец кампании | `space_strategy_map.gd:_run_orc_turn / _resolve_orc_battle / campaign_outcome` |
| Оценка силы флота (прогноз и пороги ИИ) | `fleet_power.gd` — НЕ `battle_rewards.gd:ship_value`, тот только про опыт |
| Объекты в углах карты и их трофей | `map_object_defs.gd:CORNER_LAYOUT` + `_generate_corner_objects` и `TREASURE_*` в `space_strategy_map.gd` |
| Постоянный HUD боя (раунд/ход, три кнопки) | `tactical_battle_hud.gd:_build_bottom_bar` — намеренно минимальный, карта занимает почти весь экран (см. §7b) |
| Новый объект приключений | `map_object_defs.gd:KINDS` + `SPAWN_COUNT` + обработчик `_trigger_*` в `space_strategy_map.gd` (≈1113–1275) |
| Ход дня, доход, недельный прирост | `space_strategy_map.gd:_end_day` (≈520) + `human_planet_state.gd:apply_weekly_growth` |
| Бонус форта к приросту (+25/+50/+100%) | `human_planet_state.gd:FORT_GROWTH_BONUS_BY_LEVEL` — общий для обеих фракций |
| С чем герой остаётся после поражения | `space_strategy_map.gd:RETREAT_ARMY` и `orc_ai.gd:RESPAWN_ARMY` — правило одинаковое |
| Новое здание | `human_planet_screen.gd:BUILDING_CATALOG` + `BUILDING_DEFS` (строки 10–95), спрайт в `assets/planet_surface/human/` |
| Найм / гарнизон / передача флота герою | `human_planet_screen.gd:1025–1230` |
| Биржа ресурсов | `human_planet_screen.gd:756–935` + `RESOURCE_SELL_RATE`, `EXCHANGE_BUY_MARKUP` |

Номера строк — ориентировочные, проверяй грепом по имени функции.

---

## 5. Структуры данных

**Отряд (стек) — общий формат для боя, найма и стражей.**
Собирается через `unit_defs.gd:make_blueprint(unit_id, count, cell, side)` и
совпадает по форме с `tactical_battle.gd:UNIT_BLUEPRINTS`:

```gdscript
{
  "cell": Vector2i, "side": 1|2, "count": int, "tier": int,
  "label": String, "role": String,
  "hull": int,                             # прочность ОДНОГО корабля
  "attack": int, "defense": int,
  "damage_min": int, "damage_max": int,    # урон ОДНОГО корабля
  "move": int, "range": int, "initiative": int,
  "sprite_width": float, "texture": Texture2D, "region": Rect2,
}
```

В бою добавляются рантайм-поля (`hp` = `count * hull`, эффекты и т.д.);
`_stack_count(unit)` возвращает число живых кораблей в пачке.

**Армия героя** — `hero.army`: `{unit_id: count}`, ключи из `unit_defs.gd:UNITS`.

**Ресурсы** — словарь с русскими ключами (это же ключи в JSON-сейвах и в `cost`):
`Продукты`, `Руда`, `Научные данные`, `Энергокристаллы`, `Топливо`, `Радиоизотопы`.
Кредиты хранятся отдельным полем `player_one_credits`.

**Поле боя:** 15×9 гексов, `HEX_RADIUS = 48`. Сторона 1 — игрок (слева),
сторона 2 — враг. Стартовые клетки — `SIDE1_CELLS` / `SIDE2_CELLS`.

**Глобальная карта:** 64×64 клетки по `CELL_SIZE = 96`, `MOVEMENT_POINTS_PER_DAY = 10`.
Родная планета — `(6,6)`, вражеская — `(57,57)`.

### Сейвы (все в `user://`, вне репозитория)

| Файл | Кто пишет |
|---|---|
| `user://heroes.json` | `hero_roster.gd` |
| `user://human_planet_state.json` | **только** `human_planet_state.gd` |
| `user://settings.json` | `game_settings.gd` |

Не читай и не пиши `human_planet_state.json` мимо `HumanPlanetState` — через него
ходят и экран планеты, и карта, иначе состояние разъезжается.

---

## 6. Грабли

1. **`StrategicMain._enter_tree()` вызывает `HumanPlanetState.reset_to_default()`** —
   каждый запуск главной сцены стирает прогресс планеты. Это сделано осознанно
   (сейчас это точка входа «новой игры»), но при отладке сохранений запускай
   `SpaceStrategyMap.tscn` напрямую.
2. **`map_seed = 1001`** (`@export` в `space_strategy_map.gd`) — карта
   детерминирована. `0` = случайная раскладка при каждом запуске. Не меняй сид
   ради «фикса» бага генерации — сначала воспроизведи на текущем.
3. **`open_tactical_when_run_directly`** — если открыть `SpaceStrategyMap.tscn`
   как главную сцену, она сразу прыгнет в бой. Выключай флаг для отладки карты.
4. **Характеристики кораблей продублированы** в `unit_defs.gd:UNITS` и
   `tactical_battle.gd:UNIT_BLUEPRINTS` (второе — только отладочный состав).
   Правя баланс, проверь оба места.
5. **Стражи с наградой живут в массиве `guardians`, а не в `map_objects`** —
   пиратская база, заброшенная верфь/станция рисуются `guardian_overlay.gd`,
   потому что лежат в том же массиве, что обычные пираты и торговцы.
6. **`.import`-файлы генерирует Godot.** Их изменения в `git status` — шум от
   запуска редактора, руками не трогать.
7. **`tactical_battle.gd` кеширует** центры гексов и расстояния
   (`hex_center_cache`, `path_distance_cache`) — после изменения геометрии поля
   или препятствий кеши надо инвалидировать.
8. **Esc открывает меню настроек** (`game_settings.gd`), а не закрывает экран
   планеты. Вложенные окна (книга протоколов, прицел заклинания, редактор
   зданий, F8-редактор корабля) перехватывают Esc раньше и закрываются сами.
9. **Корабли орков лежат в `orc_defs.gd`, а не в `unit_defs.gd`**, но
   `UnitDefs.get_unit()` отдаёт и их. Значит, `UnitDefs.UNITS[id]` напрямую
   индексировать нельзя — только через `get_unit()`, иначе орочий id уронит код.
10. **Пояс угрозы стража считается от БЛИЖАЙШЕЙ планеты**
   (`space_strategy_map.gd:_threat_distance`), а не от людской. Иначе вокруг
   базы орков стоят флагманские флоты и ИИ не может расширяться вообще.
11. **Две метрики силы, не путать.** `BattleRewards.ship_value` — только для
   опыта и наград. Для «кто кого» — `FleetPower.ship_strength`. Подстановка
   одной вместо другой ломает и прогноз игроку, и решения ИИ.
12. **`CampaignSave.VERSION = 2`.** Старые сейвы (с героем `pirate_captain`,
   без блока `orc_ai`) не грузятся — это ожидаемо, не баг.

---

## 7. Конвенции

- Комментарии и весь пользовательский текст — **на русском**. Doc-комментарий
  `##` в начале файла объясняет назначение модуля; сохраняй этот стиль.
- Отступы — **табы** (стандарт GDScript). Типизация обязательна: `-> void`,
  `var x := ...`, `Array[Dictionary]`.
- Справочники (`*_defs.gd`) — `class_name X extends RefCounted`, только
  константы и `static func`. Состояние туда не кладут.
- Свежий `class_name` не виден до пересканирования проекта редактором, поэтому
  в автозагрузках и в скриптах, которые грузятся headless, ссылайся на новые
  классы явным `preload` (см. `const OrcAI := preload(...)` в `hero_roster.gd`).
- Оверлеи (`*_overlay.gd`) — `Node2D`, читают состояние **прямо из родителя**,
  собственных данных не держат.
- Многие UI-окна строятся кодом (`CanvasLayer` + `setup()`), а не в .tscn — так
  сделаны диалог уровня, окно итогов боя, книга протоколов.
- Числовые константы выносятся наверх файла как `const` с комментарием, зачем
  подобрано именно это значение.

---

## 6a. Правила, общие для обеих сторон

Их легко разъехать по невнимательности, поэтому они вынесены отдельно:

* **Прирост от форта** — `HumanPlanetState.FORT_GROWTH_BONUS_BY_LEVEL`
  (`+25/+50/+100%` по уровням I/II/III). Орочий ИИ считает свой прирост этой
  же функцией `scaled_weekly_growth`, отдельной таблицы у него нет.
* **Флот после поражения** — один корабль I ранга у обеих сторон:
  `space_strategy_map.gd:RETREAT_ARMY` (`interceptor`) и
  `orc_ai.gd:RESPAWN_ARMY` (`ork_fighter`). Разница только в сроке: герой
  игрока доступен сразу, вождь орков возвращается через
  `OrcAI.HERO_RESPAWN_DAYS` солов, зато сразу забирает гарнизон логов.
* **Оценка силы флота** — `FleetPower`, а не `BattleRewards.ship_value`.

---

## 7a. Манёвр в бою

Как в HoMM3: направление, с которого наносится удар, не даёт ни бонуса к
урону, ни штрафа обороняющемуся, и никак не рисуется на пачках. У бонуса за
заход в тыл (курс `unit["facing"]`, тыловая дуга, `REAR_DAMAGE_BONUS`,
`_draw_rear_arc`) была своя механика в этом проекте, но её убрали — это было
собственное решение, не из первоисточника, и оно не стоило накладок с новой
гексовой геометрией (см. §7b: хитбокс и картинка расходились у пачек IV+
ранга). Спрайт по-прежнему только зеркалится по стороне (земляне/враг,
`_draw_unit`) — покадрового разворота нет и не было.

ИИ выбирает клетку одной оценкой `_move_cell_score`: держать цель в дальности
залпа и не стоять в клещах. Разрывать дистанцию он не пытается — единственная
причина уйти — окружение (`SURROUNDED_LIMIT` соседей и больше). Направление
подхода к цели оценку никак не меняет. Инерции/импульса в бою нет сознательно.

**Грабли:**
1. Если убрать приоритет сближения (`MOVE_SCORE_APPROACH`) при «стрелять
   неоткуда», обе стороны начинают пятиться друг от друга и бой не
   заканчивается никогда — это уже случалось.
2. `orc_ai.gd:GUARDIAN_ATTACK_RATIO` (1.6) поднимали именно из-за резкости боя
   от бонуса за тыл — после его удаления порог стоит перепроверить через
   `tools/balance_sim.gd` (раздел 1c), возможно, прежние ×1.3 снова достаточно.

---

## 7b. Экран боя: минимальный HUD и фон

Карта боя должна занимать почти весь экран — весь постоянный HUD сведён к
одной тонкой полосе снизу (`tactical_battle_hud.gd:_build_bottom_bar`):
раунд/чей ход одной строкой + три кнопки (автобитва, сбежать в замок,
завершить ход). Никаких портретов командиров, состава флота или характеристик
активного отряда с постоянным показом больше нет — число кораблей в пачке
видно прямо на карте, подписью под каждым отрядом (`_draw_stack_badge`).
Полная карточка характеристик (урон, манёвр, дальность, инициатива, эффекты)
не висит постоянно — всплывает у курсора после `HOVER_TOOLTIP_DELAY` (2 с)
наведения на пачку, любую, свою или вражескую (`_tick_battle` копит
`hover_timer`, рисует `_draw_unit_tooltip`). Короткая строка в HUD-подсказке
(`_hover_hint`) при этом видна сразу, но только пока активна своя пачка.

Размер и позиция самой сетки — `tactical_battle.gd:GRID_SIDE_MARGIN /
GRID_TOP_MARGIN / GRID_BOTTOM_RESERVED` в `_grid_origin()`. `GRID_BOTTOM_RESERVED`
продублирован из высоты нижней полосы HUD (`tactical_battle_hud.gd:BAR_HEIGHT
+ BAR_MARGIN*2`) — если меняешь высоту полосы, поправь и это число, иначе
сетка налезет на кнопки.

**Гекс острой вершиной, ряды — ровная горизонталь.** До того гекс был плоской
вершиной со смещением по колонкам (соседний ряд зигзагом). Теперь — offset
"odd-r": смещаются нечётные РЯДЫ, и ряд центров гексов — прямая линия, как в
HoMM3. Меняет это не только отрисовку: `_offset_to_cube/_cube_to_offset`
(и всё, что на них стоит — дистанции, соседство, LoS, патфайндинг) пересчитаны
под новую схему. `CUBE_DIRECTIONS` не менялся — кубическая система координат
одна и та же для любой ориентации гекса, меняется только offset↔cube.

**Корабли IV+ ранга занимают 2 клетки по горизонтали, строго по РЯДУ**
(`MULTI_CELL_MIN_TIER`). "Нос" — `unit["cell"]`, "корма" — `cell.x+1` у стороны
1 и `cell.x-1` у стороны 2 (`_secondary_cell`), всегда, независимо от того,
откуда пачка пришла на эту клетку. Раньше корма считалась по курсу последнего
перелёта (`unit["facing"]`, см. §7a — этого поля больше нет) и после
диагонального манёвра съезжала по диагонали, а спрайт всё равно рисуется
ровным горизонтальным прямоугольником (`_draw_unit`) — хитбокс и картинка
расходились, клик по видимому корпусу мог промахиваться. Все проверки
занятости клетки (`_unit_at_cell`, ход, обстрел, генерация препятствий)
учитывают обе клетки — см. `_footprint_cells/_footprint_valid`.

**Грабли:**
1. Клик по собственной клетке (и "носу", и "корме") — не манёвр и не цель для
   атаки, это разбирается через `active_unit_index` в
   `_handle_cell_click`/`_can_move_to`; без этой развилки корабль не может
   шагнуть вперёд на клетку, которая уже его собственный хвост.
2. У `_hex_points` есть `inset` (зазор на сетке между гексами для картинки) —
   для проверки клика (`_cell_at_position`) он должен быть 0, иначе на стыке
   двух клеток остаётся мёртвая полоса, не принадлежащая ни одному гексу.
   Ровно туда попадает центр корабля IV+ ранга (`_footprint_center` рисует его
   между двумя клетками) — с ненулевым inset клик по центру длинного корпуса
   не срабатывал вообще.

**Параллакс фона.** Камера в бою неподвижна, поэтому слои фона едут не за
камерой, а за курсором мыши (`_update_parallax_target`, сглаживание —
`parallax_offset` в `_tick_battle`). `tactical_backdrop.png` — неподвижный
самый дальний слой, дальше три тайловых слоя по нарастающей "strength"
(`PARALLAX_LAYERS`): `parallax_stars_far` → `parallax_nebula_mid` →
`parallax_dust_near`. Все три уже лежат в `assets/space/`, изначально
подготовлены про запас и до этой правки нигде не использовались.

**Фоновая декорация (планета/луна/туманность).** Не обязательный элемент и не
на каждый бой (`BACKDROP_OBJECT_CHANCE`) — `_pick_backdrop_object()` при
старте боя сканирует `assets/space/backdrops/` (см. `README.md` там же) и,
если папка не пуста, с некоторым шансом берёт случайный PNG, случайный угол
экрана и масштаб. Ничего не ломается, если папка пуста — фичи без ассетов
просто не видно. Промт для генерации таких PNG (стиль — как у
`assets/planets/human.png`: painterly/полу-реалистичный рендер планеты,
прозрачный фон, драматичный боковой свет, тонкий атмосферный ободок,
насыщенные цвета, ничего лишнего в кадре):

> Digital painting of a [gas giant / rocky airless moon / ice planet / glowing
> nebula cloud], viewed head-on and centered in frame, dramatic rim lighting
> from one side, rich saturated colors, subtle atmospheric glow at the limb,
> semi-realistic painterly sci-fi art style, high detail, square 1:1
> composition, fully transparent background (no stars, no vignette, no
> ground, no other objects), no text, no logos, no ships, no UI elements.

Меняй только первую скобку под конкретный вариант (можно сделать несколько
файлов — газовый гигант, ледяная луна, туманность без сферы вообще, и т.д.),
остальной промт держит стиль в одном ключе с уже существующими ассетами.
Готовые PNG класть в `assets/space/backdrops/` — код подхватит их сам, без
правок кода.

---

## 8. Чего в проекте пока нет

Мультиплеера и локализации. Орки — полноценный противник под управлением ИИ
(`orc_ai.gd`), но **не играбельная раса**: у их базы нет экрана планеты, стройку
и наём ведёт код, спрайты боевых кораблей, зданий и портрет вождя — всё ещё
плейсхолдеры (`tools/make_orc_placeholders.py`); флагман на карте
(`assets/hero_ships/orc.png`, `space_strategy_map.gd:ORC_HERO_SHIP_TEXTURE`) —
уже настоящий арт. Звук: процедурный боевой
SFX (`procedural_sfx.gd`, шина `SFX`) и фоновая музыка на 4 экранах с плавным
кроссфейдом между собой (`AudioStreamPlayer` на шине `Music` через `GameSettings.attach_music`
+ `Tween` на `volume_db` плеера, длительность перехода —
`MUSIC_FADE_DURATION`/`BATTLE_MUSIC_FADE_DURATION` в соответствующем файле).
Громкость шин (общая/музыка/эффекты) крутится в меню по Esc и не мешает фейдам:

| Экран | Трек | Где живёт |
|---|---|---|
| Главное меню | случайный из `music/main_menu/` | `main_menu.gd:_start_music` |
| Глобальная карта | случайный из `music/map/` | `space_strategy_map.gd:_start_music/pause_music/resume_music` |
| Тактический бой | случайный из `music/battle/` | `tactical_battle.gd:_start_music/_fade_out_and_release_music` |
| Экран планеты людей | `music/Human Castle.mp3` | `human_planet_screen.gd:_start_music/fade_out_music` |

Все экраны, кроме планеты людей, берут трек не жёстко зашитым: код сканирует
папку (`music/main_menu/`, `music/map/` или `music/battle/`, см. `README.md`
в каждой) и берёт случайный mp3 при входе на экран. Карта и бой поверх этого
ещё и кроссфейдят громкость уже выбранного трека между собой при переходе
карта↔бой (`MUSIC_FADE_DURATION`/`BATTLE_MUSIC_FADE_DURATION`) — сам выбор
трека кроссфейд не трогает, он происходит один раз при входе. У меню фейдов
нет вовсе. Пустая папка нигде не ломает экран — просто нет музыки
(`pause_music`/`resume_music` в `space_strategy_map.gd` это тоже учитывают
через `is_instance_valid(music_player)`).

Тот же приём и у фона главного меню: `main_menu.gd:MENU_BACKGROUNDS_DIR`
(`assets/ui/main_menu_backgrounds/`, см. `README.md` там же) — случайная
картинка на весь экран вместо старого плоского цвета со звёздами (тот
остаётся как фолбэк, если папка пуста). Название игры нарисовано прямо на
картинке — отдельным `Label` с текстом заголовка оно не дублируется.

При входе в бой/на планету затухает музыка карты (`pause_music()`), при
выходе — плавно возвращается (`resume_music()`); трек уходящего экрана в это
время фейдится сам через свою `fade_out_music`/`_fade_out_and_release_music`,
которая **переносит `AudioStreamPlayer` в `get_tree().root`** перед
`queue_free()` родительской сцены — иначе `Tween` вместе с ним умрёт
недоиграв. Озвучки UI по-прежнему нет.
`data/ship_configs/` пустой — редактор кораблей (F8) ещё ничего не сохранял.
