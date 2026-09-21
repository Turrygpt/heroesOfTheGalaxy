# Heroes of the Galaxy — карта проекта для ИИ-агентов

Космическая стратегия в духе HoMM3: глобальная карта с героем-командующим,
пошаговый гексовый бой, экран планеты со стройкой и наймом.
**Godot 4.7 / GDScript, весь код и комментарии — на русском.**

Этот файл — навигационная карта и точка входа. Читай его вместо того, чтобы
грепать весь репозиторий: ниже сказано, в каком файле лежит какая механика,
какие грабли где закопаны и куда идти за подробностями.

**Первая миссия кампании (16.09.2026):** кнопка «Новая игра» загружает фиксированную
карту `data/campaign/mars_demo_v1.json` через `scripts/campaign_mission_map.gd`.
Замысел, квестовые идентификаторы и ограничения — `data/campaign/README.md`.
Сид этой миссии — `160926`; геометрия задана явно в JSON. Рендер опасных областей —
`scripts/campaign_terrain_renderer.gd`, проверка — `tools/test_campaign_map.gd`,
снимок — `tools/campaign_map_shot.gd`. Старое описание процедурной генерации ниже
относится к случайным и прежним картам. Новые квесты привязывать к `mission_id`.

## Подробности вынесены — открывай только нужное

Этот файл держится коротким специально: его читают в начале каждой задачи,
поэтому всё, что нужно не всегда, лежит рядом отдельными файлами.

| Файл | Когда открывать |
|---|---|
| `docs/battle_screen.md` | правишь `tactical_battle.gd` / `tactical_battle_hud.gd`: манёвр, гексовая геометрия, мультиклеточные корабли, HUD, параллакс и фон |
| `docs/map_screen.md` | правишь HUD глобальной карты, пределы камеры, миникарту |
| `docs/data_formats.md` | нужен формат отряда, армии героя, ресурсов или список сейвов |
| `docs/audio.md` | трогаешь музыку экранов, кроссфейды, SFX, слоёный фон меню |
| `docs/tools.md` | нужны снимки экрана, отладочные прогоны, балансовый измеритель, генерация плейсхолдеров |
| `data/balance_plan.md` | диагноз баланса и план правок |
| `data/campaign/README.md` | квесты и ограничения первой миссии |

## Как дёшево читать большие файлы

Три файла заметно больше остальных: `space_strategy_map.gd` (~3400 строк),
`tactical_battle.gd` (~3200), `human_planet_screen.gd` (~2800). Читать их
целиком почти никогда не нужно — сначала оглавление, потом кусок:

```bash
grep -n '^func \|^const \|^var ' scripts/space_strategy_map.gd   # оглавление
sed -n '913,1006p' scripts/space_strategy_map.gd                  # нужный кусок
```

Раздел «4. Где что менять» ниже уже говорит, какую функцию искать.

---

## 1. Запуск и проверки

Движок лежит прямо в репозитории (`Godot_v4.7.1-stable_win64.exe`, в .gitignore).

```bash
./Godot_v4.7.1-stable_win64_console.exe --path .
```

Тесты — обычные скрипты `SceneTree`, запускаются headless и пишут ошибки через
`push_error`, код выхода ненулевой при падении. Все сразу:

```bash
sh tools/run_tests.sh              # все тесты
sh tools/run_tests.sh orc battle   # только те, чьё имя содержит orc или battle
```

Движок скрипт ищет сам (переменная `GODOT`, `godot` в PATH, `Godot_v*.exe` в
корне). Один тест по отдельности:

```bash
./Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/test_tactical_battle.gd
```

| Скрипт | Что проверяет |
|---|---|
| `tools/test_tactical_battle.gd` | сборка боя из `UNIT_BLUEPRINTS`, стеки, стороны |
| `tools/test_battle_tactics.gd` | выбор цели и клетки боевым ИИ, выход из окружения, гибель активного отряда от ответки не вешает ход |
| `tools/test_auto_battle.gd` | автобитва, переключение управления, быстрый расчёт без записи сейвов |
| `tools/test_battle_cinematic_fx.gd` | синхронизация попаданий и протоколов; `--capture` снимает витрину эффектов |
| `tools/test_hero_progression.gd` | опыт, уровни, навыки, протоколы, награда, сохранение |
| `tools/test_orc_ai.gd` | каталог орков, экономика и ход ИИ, автобой, оборона базы, итоги боёв, сейв |
| `tools/test_pirate_balance.gd` | семь тиров пиратов: формулы, рост угрозы, размещение, пробные автобои |
| `tools/test_campaign_map.gd` | авторская миссия: доступность, горловина, сохранение, повторяемость |
| `tools/test_campaign_story.gd` | квесты: порядок событий, дипломатия, одноразовые награды, сейв |
| `tools/test_campaign_save.gd` | сквозное сохранение карты, загрузка, полный сброс новой игры |
| `tools/test_campaign_playthrough.gd` | сквозное прохождение демо-миссии от новой игры до эпилога |
| `tools/test_random_campaign_layout.gd` | разные сиды дают разные пояса, обязательные точки остаются доступны |
| `tools/test_random_sectors.gd` | регионы случайной карты: все темы, воспроизводимость, сохранение, геометрия |
| `tools/test_random_biome_sectors.gd` | секторы с собственной композицией (лёд, токсичный, высокотемпературный): арт, проходимость не меняется |
| `tools/test_planet_turn_persistence.gd` | недельное сохранение не стирает здания |
| `tools/test_trading_post.gd` | склад торгового поста: запас, списание, недельный прирост |
| `tools/test_trading_posts.gd` | фиксированная нейтральная расстановка торговых постов |
| `tools/test_trading_post_modal.gd` | окно торгового поста на карте: закрытие биржи возвращает управление |
| `tools/ship_buildings_regression.gd` | каталог верфей, цены, отрисовка и недельный прирост |
| `tools/test_game_settings.gd` | шины громкости, mute на нуле, сохранение настроек |
| `tools/test_main_menu.gd` | меню в отдельном профиле: редактор, настройки, переход и возврат |
| `tools/test_intro_video.gd` | интро-ролик: включён в "Новой игре", играет, пропускается; без файла игра всё равно стартует |

Снимки экрана, отладочные прогоны (`debug_orc_turns.gd`, `debug_map_objects.gd`),
балансовый измеритель `balance_sim.gd`, генерация плейсхолдеров и сборка игры
(`tools/build_game.sh`, интро-ролик) — `docs/tools.md`.

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
| `space_strategy_map.gd` (~3400) | ядро: сетка 64×64, ход дня, движение по A*, ресурсы, запуск боёв, фоновая музыка (`_start_music/pause_music/resume_music`) |
| `adventure_map_generator.gd` (~660) | **генератор случайной карты**: девять тематических областей, препятствия (гряды, поля обломков, непроходимые туманности), экономика у обеих планет, цели похода, охрана и схроны. Карта строится открытой — см. §7e |
| `map_generation.gd` (~1000) | склад для генераторов: `add_guardian`, `add_map_object`, `add_object_guardian`, нейтральные планеты, трофеи. Пишет прямо в поля карты, создаётся в `space_strategy_map.gd` как `map_generation`. Его собственные `generate_*` остались от прежнего генератора случайной карты и больше не вызываются |
| `space_obstacles.gd` / `space_obstacle_renderer.gd` | геометрия препятствий (общая для карты, навигации и миникарты) и её отрисовка |
| `random_sector_defs.gd` / `random_sector_renderer.gd` | девять тематических районов случайной карты и редкие акценты поверх них |
| `biome_sector_defs.gd` / `biome_sector_renderer.gd` | арт и композиция секторов с собственной сборкой (лёд, токсичный, высокотемпературный): поток обломков, газ, завихрения, взорванная планета — см. §7d |
| `guardian_defs.gd` / `guardian_overlay.gd` | составы нейтральных стражей (пираты и торговые конвои) и их иконки |
| `map_object_defs.gd` / `map_object_overlay.gd` | объекты приключений (обелиски, университет, сундуки) и плейсхолдер-иконки |
| `route_overlay.gd`, `production_overlay.gd`, `strategic_minimap.gd` | отрисовка маршрута, подписи месторождений, миникарта |
| `strategic_main.gd` | обёртка точки входа, **сбрасывает состояние планеты** — см. §6 |

**Тактический бой:**

| Файл | Роль |
|---|---|
| `tactical_battle.gd` (~3200) | вся боёвка: гексы, очередь ходов, урон, ИИ, протоколы, отрисовка, параллакс-фон |
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
| `human_planet_screen.gd` (~2800) | экран планеты: стройка, найм, гарнизон, биржа, редактор раскладки зданий |
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
| Реплики сюжетных сцен первой миссии | `campaign_story_defs.gd:DIALOGUES` — координаты контрактных целей в текст не зашивают, ставят подстановку (`{convoy_targets}`, `{cruiser_target}`, `{pirate_targets}`, `{pirate_base}`) и разбирают её в `campaign_story.gd:_resolved_lines` |
| Порядок сюжетных сцен, реакция баз фракций, старт боя из диалога | `campaign_story.gd:enqueue / _process / play / visit` — база Лиги и база Ридуса отвечают диалогом (`_visit_stein_base` / `_visit_ridus_base` возвращают `true` и подавляют карточку объекта из `_trigger_info`) |
| Генерация карты (месторождения, препятствия, объекты) | `map_generation.gd` — точки входа `generate_production_sites / generate_obstacles / generate_guardians / generate_map_objects`, зовутся из `space_strategy_map.gd:_ready` |
| Темы районов случайной карты (девять секторов) | `random_sector_defs.gd:assign_regions` — зовётся из `map_generation.gd:generate_obstacles` |
| Секторы случайной карты со своей композицией: ледяной, токсичный и высокотемпературный (поток обломков, газ, завихрения, взорванная планета) | `biome_sector_renderer.gd` (+ профили в `biome_sector_defs.gd`), узлы `IceSector`/`ToxicSector`/`VolcanicSector` создаются в `space_obstacle_renderer.gd:_ready`; палитра газа — каналы маски `biome_mask` в `campaign_terrain_renderer.gd` и `shaders/campaign_hazards.gdshader` — см. §7d |
| Декорации дальнего космоса (кометы с хвостами/искрами/струями, далёкие планеты) | `space_decorations.gd` — константы `COMET_*` в шапке; анимация идёт от поля `time`, которое копит `tick_comets` |
| Область карты и то, что HUD её не перекрывает | `space_strategy_map.gd:_update_camera_limits / _clamp_camera_position / _camera_position_for` — пределы камеры расширены за край карты на полосы HUD (см. §7c) |
| Сила стражей от удалённости | `space_strategy_map.gd:_threat_distance / _guardian_template_for_distance` + `guardian_defs.gd:TEMPLATES` |
| Красный курс, если маршрут упирается в стража | `route_overlay.gd:_first_guardian_index / _draw_danger_marker` — хвост пути после первой живой охраняемой клетки красный и пунктирный, сама клетка обведена кольцом; источник опасности тот же `guardian_at`, что и в `space_strategy_map.gd:_check_guardian_encounter` |
| Баланс орочьих кораблей | `orc_defs.gd:UNITS` — множители фракции в шапке файла |
| Постройки и цены базы орков | `orc_defs.gd:BUILDING_DEFS` + порядок стройки `orc_ai.gd:BUILD_PRIORITY` |
| Агрессивность и осторожность ИИ | `orc_ai.gd` — `ASSAULT_POWER_RATIO`, `HUNT_POWER_RATIO`/`HUNT_RANGE`, `GUARDIAN_ATTACK_RATIO`, `AUTO_BATTLE_ATTRITION`, `REGROUP_GARRISON_RATIO` |
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

Формат отряда (стека), армия героя, ресурсы, размеры поля боя и карты, список
файлов сейвов — `docs/data_formats.md`.

Одно правило держи в голове и не открывая его: `user://human_planet_state.json`
читает и пишет **только** `human_planet_state.gd`. Мимо него не ходи — через
него работают и экран планеты, и карта, иначе состояние разъезжается.

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
13. **`await node.ready` после `add_child` не разрешается никогда.** `add_child`
   прогоняет `_ready` синхронно, сигнал к моменту `await` уже отправлен, и
   корутина висит вечно вместе с недостроенным окном. Так вставал торговый пост
   (`_open_trading_post`): в `space_modal_mode` экран прячет всю разметку
   планеты, поэтому без биржи из него нельзя было даже выйти. После `add_child`
   узел готов — зови метод напрямую.
14. **Нетипизированный `const`-массив нельзя передать в параметр `Array[String]`.**
   Вызов падает в рантайме и **обрывает функцию с середины**: так `play()`
   ставил `busy = true`, глушил процесс карты и умирал на подстановке
   координат — начальный диалог Ридуса вешал игру насмерть. Константы-списки
   объявляй с типом: `const IDS: Array[String] = [...]`.
15. **Сцена, которая заканчивается боем, начинает его из `finished`, а не из
   `update_progress`.** `enqueue` помечает сцену увиденной СРАЗУ, поэтому
   условие «`has_seen` и бой не начат» срабатывает ещё до показа реплик. Бой
   тогда открывался поверх живого диалога: `_swap_to_battle` глушит процесс
   карты, а диалог — её `CanvasLayer`-ребёнок, и он оставался на экране
   замороженным (засада Ковальски). Проверять надо факт показа: id в
   `story_state.history` и уже не в `pending`.

16. **Тест, который ждёт смену сцены, считает ВРЕМЯ, а не кадры.** Переход из
   меню грузит `StrategicMain` фоново (`load_threaded_request`), и на медленной
   машине сцена приезжает секунд за десять. Фиксированный бюджет кадров тут
   врёт: 600 кадров headless проходят за четыре секунды, и тест падал на ровном
   месте — сцена была ещё в пути, а не сломана. Ждать надо до дедлайна по
   `Time.get_ticks_msec()`, как это делают `test_main_menu.gd` и
   `test_campaign_playthrough.gd`.

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
* **Флот после поражения** — один корабль I ранга у обеих сторон, сразу же,
  без паузы: `space_strategy_map.gd:RETREAT_ARMY` (`interceptor`) и
  `orc_ai.gd:RESPAWN_ARMY` (`ork_fighter`, см. `kill_hero`). Вождь орков
  забирает накопленный гарнизон логов на следующем ходу ИИ, как обычно —
  через `_reinforce_hero`, а не разовым бонусом при возрождении.
* **Оценка силы флота** — `FleetPower`, а не `BattleRewards.ship_value`.

---

## 7a–7c. Экраны: подробности

* **Бой** — манёвр и почему убрали бонус за тыл, минимальный HUD, гексовая
  геометрия «odd-r», мультиклеточные корабли IV+ ранга, параллакс и фоновая
  декорация: `docs/battle_screen.md`.
* **Глобальная карта** — почему HUD не перекрывает поле и как пределы камеры
  зависят от зума: `docs/map_screen.md`.
* **Биомы случайной карты** — ледяной, токсичный и высокотемпературный
  секторы: композиция потока обломков поверх неизменной геометрии,
  `biome_sector_renderer.gd`, профили в `biome_sector_defs.gd` и правило
  «крупное только на непроходимой клетке»: `docs/map_screen.md`.

---

## 8. Чего в проекте пока нет

Мультиплеера и локализации. Орки — полноценный противник под управлением ИИ
(`orc_ai.gd`), но **не играбельная раса**: у их базы нет экрана планеты, стройку
и наём ведёт код, спрайты боевых кораблей, зданий и портрет вождя — всё ещё
плейсхолдеры (`tools/make_orc_placeholders.py`); флагман на карте
(`assets/hero_ships/orc.png`, `space_strategy_map.gd:ORC_HERO_SHIP_TEXTURE`) —
уже настоящий арт. Озвучки UI нет. `data/ship_configs/` пустой — редактор
кораблей (F8) ещё ничего не сохранял.

Что со звуком и музыкой уже есть — `docs/audio.md`.
