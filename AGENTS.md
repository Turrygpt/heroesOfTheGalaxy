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
| `tools/ship_buildings_regression.gd` | каталог верфей, цены, отрисовка и недельный прирост |

Отладочные скриншоты (сохраняют PNG в `user://`):

```bash
./Godot_v4.7.1-stable_win64_console.exe --path . res://tools/MapShot.tscn -- map.png 8 8 1.0 1001
```

`tools/BattleShot.tscn` — то же самое для тактического боя.

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
                 ship_configs/ — пусто, каталог редактора кораблей
assets/          спрайты (+ .import — генерируются Godot, не редактировать руками)
build/, .godot/  генерируемое, в .gitignore
```

### Скрипты по зонам ответственности

**Автозагрузки** (`project.godot [autoload]`):
- `scripts/hero_roster.gd` — `HeroRoster`: словарь героев между сценами,
  сигналы `hero_experience_gained` / `hero_leveled_up`, сейв в `user://heroes.json`.
- `scripts/ship_editor.gd` — `ShipEditor`: внутриигровой редактор хардпоинтов
  корабля, **открывается по F8**, всегда в дереве, но скрыт.
- `scripts/procedural_sfx.gd` — `ProceduralSfx`: звуки боя генерируются кодом
  (шум + синус в `AudioStreamWAV`, никаких аудиофайлов в assets нет), кешируются
  по `(тип, hull)`. `play_move/play_shot/play_destroyed(unit, delay)` — масштаб
  громкости/тона берётся из `hull` отряда, крупные корабли звучат мощнее.

**Глобальная карта:**

| Файл | Роль |
|---|---|
| `space_strategy_map.gd` (~1500) | ядро: сетка 64×64, ход дня, движение по A*, ресурсы, генерация карты, запуск боёв, фоновая музыка (`_start_music/pause_music/resume_music`) |
| `space_obstacles.gd` / `space_obstacle_renderer.gd` | геометрия препятствий (общая для карты, навигации и миникарты) и её отрисовка |
| `guardian_defs.gd` / `guardian_overlay.gd` | составы нейтральных стражей и их иконки |
| `map_object_defs.gd` / `map_object_overlay.gd` | объекты приключений (обелиски, университет, сундуки) и плейсхолдер-иконки |
| `route_overlay.gd`, `production_overlay.gd`, `strategic_minimap.gd` | отрисовка маршрута, подписи месторождений, миникарта |
| `strategic_main.gd` | обёртка точки входа, **сбрасывает состояние планеты** — см. §6 |

**Тактический бой:**

| Файл | Роль |
|---|---|
| `tactical_battle.gd` (~1550) | вся боёвка: гексы, очередь ходов, урон, ИИ, протоколы, отрисовка |
| `tactical_battle_hud.gd` | HUD боя, сигналы `end_turn_requested` / `restart_requested` / `return_requested` |
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
| `unit_defs.gd` | общий справочник кораблей: и покупаемые юниты, и составы стражей |

---

## 3. Потоки сцен

```
StrategicMain (_enter_tree: HumanPlanetState.reset_to_default)
  └── SpaceStrategyMap
        ├── _open_human_planet()      → HumanPlanetScreen как child, карта на паузе
        │     └── close_requested     → _close_human_planet() → _sync_human_planet_state()
        ├── _open_guardian_battle()   → TacticalBattle с реальными флотами
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
```

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
| Гексовая геометрия (расстояния, LoS, пути) | `tactical_battle.gd:782–890` — cube-координаты |
| Заклинания-протоколы | `hero_protocols.gd:PROTOCOLS` + применение в `tactical_battle.gd:_cast_protocol` (≈990) |
| Опыт за бой | `battle_rewards.gd:ship_value()` |
| Прокачка героя, навыки | `hero_defs.gd` (данные) + `hero.gd:roll_level_up / apply_level_up` |
| Звуки боя (движение/выстрел/уничтожение) | `procedural_sfx.gd` (синтез) + вызовы в `tactical_battle.gd:_start_unit_move / _attack_unit` |
| Генерация карты (месторождения, препятствия, объекты) | `space_strategy_map.gd:_generate_*` (≈1276–1440) |
| Сила стражей от удалённости | `space_strategy_map.gd:_guardian_template_for_distance` (≈717) + `guardian_defs.gd:TEMPLATES` |
| Новый объект приключений | `map_object_defs.gd:KINDS` + `SPAWN_COUNT` + обработчик `_trigger_*` в `space_strategy_map.gd` (≈1113–1275) |
| Ход дня, доход, недельный прирост | `space_strategy_map.gd:_end_day` (≈520) + `human_planet_state.gd:apply_weekly_growth` |
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

---

## 7. Конвенции

- Комментарии и весь пользовательский текст — **на русском**. Doc-комментарий
  `##` в начале файла объясняет назначение модуля; сохраняй этот стиль.
- Отступы — **табы** (стандарт GDScript). Типизация обязательна: `-> void`,
  `var x := ...`, `Array[Dictionary]`.
- Справочники (`*_defs.gd`) — `class_name X extends RefCounted`, только
  константы и `static func`. Состояние туда не кладут.
- Оверлеи (`*_overlay.gd`) — `Node2D`, читают состояние **прямо из родителя**,
  собственных данных не держат.
- Многие UI-окна строятся кодом (`CanvasLayer` + `setup()`), а не в .tscn — так
  сделаны диалог уровня, окно итогов боя, книга протоколов.
- Числовые константы выносятся наверх файла как `const` с комментарием, зачем
  подобрано именно это значение.

---

## 8. Чего в проекте пока нет

Мультиплеера, сохранения кампании целиком, второй играбельной расы (орки есть
как владелец планеты, но без контента), локализации. Звук: процедурный боевой
SFX (`procedural_sfx.gd`) и три фоновые темы с плавным кроссфейдом между собой
(`AudioStreamPlayer` + `Tween` на `volume_db`, длительность перехода —
`MUSIC_FADE_DURATION`/`BATTLE_MUSIC_FADE_DURATION` в соответствующем файле):

| Экран | Трек | Где живёт |
|---|---|---|
| Глобальная карта | `music/Starlit Echoes (Main Theme).mp3` | `space_strategy_map.gd:_start_music/pause_music/resume_music` |
| Тактический бой | `music/Market Pulse (Fight Rhythm Mix).mp3` | `tactical_battle.gd:_start_music/_fade_out_and_release_music` |
| Экран планеты людей | `music/Human Castle.mp3` | `human_planet_screen.gd:_start_music/fade_out_music` |

При входе в бой/на планету затухает музыка карты (`pause_music()`), при
выходе — плавно возвращается (`resume_music()`); трек уходящего экрана в это
время фейдится сам через свою `fade_out_music`/`_fade_out_and_release_music`,
которая **переносит `AudioStreamPlayer` в `get_tree().root`** перед
`queue_free()` родительской сцены — иначе `Tween` вместе с ним умрёт
недоиграв. Озвучки UI по-прежнему нет.
`data/ship_configs/` пустой — редактор кораблей (F8) ещё ничего не сохранял.
