# Структуры данных и сейвы

Из `AGENTS.md` сюда ушёл раздел 5 — форматы, которые ходят между модулями.

---

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

Общий снимок `user://campaign.save` пишет `campaign_save.gd`. На случайной
карте он дополнительно хранит `random_hero_states` (клетка, остаток хода,
недельный бонус и фракция каждого героя) и `random_active_hero_id`. Сами
характеристики и флоты героев находятся в словаре `heroes` этого снимка.

При чтении прежних сохранений `faction_save_migration.gd` переводит старые
идентификаторы противника в фракцию марсианских бандитов. Сохраняются опыт,
флот, слоты, гарнизон, верфи, остаток найма и положение на карте. Новые снимки
используют только актуальные идентификаторы; сбрасывать кампанию не требуется.

Не читай и не пиши `human_planet_state.json` мимо `HumanPlanetState` — через него
ходят и экран планеты, и карта, иначе состояние разъезжается.

---

