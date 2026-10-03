"""Собирает авторскую раскладку второй миссии и обзорную карту."""

from __future__ import annotations

import json
import math
import random
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "data/campaign/saturn_mission_v1.json"
PREVIEW = ROOT / "data/campaign/saturn_mission_overview.png"
SIZE = 64
SEED = 270926


def _object(key: str, kind: str, name: str, cell: tuple[int, int], size: int,
            stage: int, **extra: object) -> dict:
    return {"id": key, "kind": kind, "name": name, "cell": list(cell),
            "size": size, "stage": stage, **extra}


OBJECTS = [
    _object("clan_1_station", "pirate_clan_station", "Военные доки Ржавых Клыков", (13, 12), 4, 1,
            texture="res://assets/planets/stations/pirate/pirate_clan_1.png", role="corvette_unlock"),
    _object("clan_2_station", "pirate_clan_station", "Военные доки Ночной Вуали", (29, 20), 4, 2,
            texture="res://assets/planets/stations/pirate/pirate_clan_2.png", role="frigate_destroyer_unlock"),
    _object("clan_3_station", "pirate_clan_station", "Большая верфь третьего клана", (40, 35), 4, 3,
            texture="res://assets/planets/stations/pirate/pirate_clan_3.png", role="cruiser_archive"),
    _object("clan_4_station", "pirate_clan_station", "Тяжёлая верфь четвёртого клана", (50, 49), 4, 4,
            texture="res://assets/planets/stations/pirate/pirate_clan_4.png", role="final_clan"),
    _object("tethys", "saturn_moon", "Тефия", (25, 17), 3, 2,
            texture="res://assets/planets/saturn/tethys.png", role="player_moon_base"),
    _object("rhea", "saturn_moon", "Рея", (21, 45), 3, 2,
            texture="res://assets/planets/saturn/rhea.png", role="optional_colony"),
    _object("titan", "saturn_moon", "Титан", (8, 49), 4, 2,
            texture="res://assets/planets/saturn/titan.png", role="resource_region"),
    _object("dione", "saturn_moon", "Диона", (40, 51), 3, 3,
            texture="res://assets/planets/saturn/dione.png", role="outer_moon"),
    _object("iapetus", "saturn_moon", "Япет", (39, 7), 3, 3,
            texture="res://assets/planets/saturn/iapetus.png", role="distant_recon"),
    _object("enceladus", "saturn_moon", "Энцелад", (54, 11), 4, 5,
            texture="res://assets/planets/saturn/enceladus.png", role="aurora_s2"),
    _object("aurora_e7", "aurora_complex", "Комплекс «Аврора-S2» · объект E-7", (55, 18), 3, 5,
            texture="res://assets/map_objects/archive_station.png", unlock_after="clan_4_station"),
    _object("aurora_gate", "sealed_gate", "Закрытый фарватер Энцелада", (50, 34), 2, 5,
            texture="res://assets/map_objects/observation_tower.png", unlock_after="clan_4_station"),
    _object("first_wreck", "derelict_ship", "Обломки экспедиции", (7, 13), 1, 0),
    _object("first_cache", "resource_cache", "Аварийный контейнер", (9, 18), 1, 0),
    _object("clan_1_salvage", "cargo_container", "Захваченный груз", (17, 10), 1, 1),
    _object("first_relay", "observation_tower", "Пост связи первого клана", (18, 18), 2, 1),
    _object("ice_lab", "upgrade_lab", "Полевая лаборатория", (18, 28), 2, 2),
    _object("tethys_wreck", "derelict_station", "Разбитый перерабатывающий комплекс", (31, 27), 2, 2),
    _object("tethys_market", "trading_post", "Лунный торговый пост", (28, 31), 2, 2),
    _object("rhea_mine_hub", "weekly_resource_hub", "Добывающий узел Реи", (24, 51), 2, 2,
            resource_name="Руда", amount=3),
    _object("titan_supply", "weekly_credit_terminal", "Склад Титана", (13, 52), 2, 2),
    _object("rhea_observatory", "stellar_observatory", "Обсерватория Реи", (28, 45), 2, 2),
    _object("iapetus_buoy", "emergency_buoy", "Дальний маяк Япета", (43, 11), 1, 3),
    _object("clan_3_logs", "archive_station", "Архив большой верфи", (44, 39), 2, 3,
            clue="aurora_s2"),
    _object("clan_3_shipyard", "weekly_shipyard", "Трофейная верфь", (38, 42), 2, 3,
            ship_tier=4, ship_count=2),
    _object("dione_cache", "smuggler_cache", "Схрон Дионы", (36, 55), 1, 3),
    _object("clan_4_archive", "archive_station", "Журнал AURORA / SATURN DIVISION", (55, 49), 2, 4,
            clue="object_e7"),
    _object("clan_4_reactor", "weekly_resource_hub", "Реактор тяжёлой верфи", (47, 54), 2, 4,
            resource_name="Энергокристаллы", amount=2),
    _object("enceladus_relay", "knowledge_relay", "Зашифрованный ретранслятор", (59, 21), 1, 5),
]


PRODUCTION = [
    ("clan1_food", (10, 21), "Продукты", 1, "Станционный гидропонный модуль", ""),
    ("clan1_ore", (19, 11), "Руда", 1, "Добыча из обломков колец", ""),
    ("clan1_fuel", (17, 24), "Топливо", 1, "Склад переработанного топлива", "weak"),
    ("clan1_data", (10, 30), "Научные данные", 1, "Исследовательский маяк", "weak"),
    ("tethys_food", (25, 27), "Продукты", 2, "Лунная ферма", "medium"),
    ("tethys_ore", (33, 18), "Руда", 2, "Шахта Тефии", "medium"),
    ("tethys_fuel", (33, 32), "Топливо", 2, "Изотопный сепаратор", "strong"),
    ("tethys_data", (29, 38), "Научные данные", 2, "Лунная лаборатория", "medium"),
    ("rhea_energy", (17, 50), "Энергокристаллы", 2, "Реактор Реи", "strong"),
    ("titan_fuel", (6, 55), "Топливо", 2, "Переработка углеводородов Титана", "medium"),
    ("clan3_ore", (40, 29), "Руда", 3, "Астероидная шахта", "heavy"),
    ("clan3_isotopes", (43, 44), "Радиоизотопы", 3, "Изотопная фабрика", "heavy"),
    ("dione_fuel", (36, 49), "Топливо", 3, "Заправочная станция Дионы", "heavy"),
    ("clan4_energy", (54, 43), "Энергокристаллы", 4, "Энергоблок тяжёлой верфи", "elite"),
    ("clan4_isotopes", (57, 55), "Радиоизотопы", 4, "Военный реактор", "elite"),
    ("enceladus_data", (58, 16), "Научные данные", 5, "Данные объекта E-7", "capital"),
]


GUARDIANS = [
    ("clan_1_fleet", (15, 17), "medium", "Флот первого клана", 1, "clan_1_station"),
    ("clan_2_fleet", (31, 24), "strong", "Флот второго клана", 2, "clan_2_station"),
    ("clan_3_fleet", (42, 39), "elite", "Флот третьего клана", 3, "clan_3_station"),
    ("clan_4_fleet", (52, 53), "capital", "Линкоры четвёртого клана", 4, "clan_4_station"),
]


REGIONS = [
    {"name": "ПОДЛЁТ К САТУРНУ", "cell": [6, 5], "color": "8bbde0"},
    {"name": "ВНУТРЕННЕЕ КОЛЬЦО", "cell": [18, 7], "color": "c9b391"},
    {"name": "ТЕФИЯ · ВТОРОЙ КЛАН", "cell": [27, 13], "color": "a7c8da"},
    {"name": "БОЛЬШАЯ ВЕРФЬ", "cell": [39, 27], "color": "d89080"},
    {"name": "ТЯЖЁЛАЯ ВЕРФЬ", "cell": [50, 43], "color": "dd776c"},
    {"name": "СЕКТОР ЭНЦЕЛАДА", "cell": [51, 5], "color": "91d8e8"},
]

PRODUCTION_TEXTURES = {
    "Продукты": "res://assets/buildings/production/orbital_agrofarm.png",
    "Руда": "res://assets/buildings/production/ore.png",
    "Научные данные": "res://assets/buildings/production/science.png",
    "Энергокристаллы": "res://assets/buildings/production/crystals.png",
    "Топливо": "res://assets/buildings/production/fuel.png",
    "Радиоизотопы": "res://assets/buildings/production/isotopes.png",
}


def _terrain() -> list[list[str]]:
    grid = [["#" for _ in range(SIZE)] for _ in range(SIZE)]

    def clear_disc(x: float, y: float, radius: float) -> None:
        for cy in range(max(1, int(y - radius) - 1), min(63, int(y + radius) + 2)):
            for cx in range(max(1, int(x - radius) - 1), min(63, int(x + radius) + 2)):
                if math.hypot(cx - x, cy - y) <= radius:
                    grid[cy][cx] = "."

    def clear_link(start: tuple[float, float], end: tuple[float, float], width: float) -> None:
        steps = max(1, int(math.dist(start, end) * 3))
        for step in range(steps + 1):
            t = step / steps
            clear_disc(start[0] + (end[0] - start[0]) * t,
                       start[1] + (end[1] - start[1]) * t, width)

    # Главный поход: четыре области кланов и единственный дальний подход к E-7.
    routes = [
        (2.2, [(4, 9), (10, 10), (15, 14), (19, 18), (23, 20)]),
        (1.5, [(23, 20), (27, 22), (31, 22)]),
        (2.0, [(31, 22), (35, 27), (35, 31)]),
        (1.4, [(35, 31), (39, 34), (42, 37)]),
        (2.0, [(42, 37), (46, 40)]),
        (1.4, [(46, 40), (49, 45), (52, 51)]),
        (1.8, [(52, 51), (58, 46), (58, 40)]),
        (1.2, [(58, 40), (52, 35), (55, 28)]),
        (1.8, [(55, 28), (57, 21), (56, 13)]),
        # Южная дуга через Титан и Рею возвращается к большой верфи.
        (1.8, [(15, 14), (11, 22), (9, 29), (15, 35), (22, 45)]),
        (2.0, [(22, 45), (10, 51)]),
        (1.5, [(22, 45), (29, 42), (42, 37)]),
        # Северный обход Япета и боковой путь через Диону.
        (1.8, [(31, 22), (30, 14), (40, 9), (44, 21), (42, 37)]),
        (1.7, [(42, 37), (40, 45), (42, 52), (52, 51)]),
        (1.4, [(52, 51), (59, 56), (60, 47), (58, 40)]),
    ]
    for width, points in routes:
        for start, end in zip(points, points[1:]):
            clear_link(start, end, width)
    # Постройки получают небольшие площадки и короткие подходы от сети путей.
    reserved = [(4, 9, 1)]
    reserved += [(o["cell"][0], o["cell"][1], o["size"]) for o in OBJECTS]
    reserved += [(x, y, 2) for _, (x, y), *_ in PRODUCTION]
    reserved += [(x, y, 1) for _, (x, y), *_ in GUARDIANS]
    for x, y, size in reserved:
        center = (x + size / 2, y + size / 2)
        nearest = min(((cx, cy) for cy in range(1, 63) for cx in range(1, 63)
                       if grid[cy][cx] == "."),
                      key=lambda cell: math.dist(center, cell))
        clear_link(center, nearest, 1.1)
        clear_disc(*center, max(2.6, size * 0.9 + 1.3))
        for cy in range(y, y + size):
            for cx in range(x, x + size):
                grid[cy][cx] = "."
    # Ледяная аномалия лежит вне фарватера, сохраняя отдельный цвет Энцелада.
    for y in range(7, 31):
        for x in range(49, 63):
            if grid[y][x] == "#" and ((x - 57) ** 2 / 80 + (y - 17) ** 2 / 180) < 1:
                grid[y][x] = "!"
    return grid


def _reachable(grid: list[list[str]], origin: tuple[int, int]) -> set[tuple[int, int]]:
    seen = {origin}
    queue = deque([origin])
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cell = (x + dx, y + dy)
            if cell in seen or not (0 < cell[0] < 63 and 0 < cell[1] < 63):
                continue
            if grid[cell[1]][cell[0]] != ".":
                continue
            seen.add(cell)
            queue.append(cell)
    return seen


def _obstacle_features(grid: list[list[str]]) -> list[dict]:
    """Передаёт ледяные пояса в формат композиционного рендера случайной карты."""
    cold_regions = [
        ("ice_tethys", (27, 20), 12),
        ("ice_rhea", (22, 46), 11),
        ("ice_dione", (41, 51), 10),
        ("ice_enceladus", (56, 15), 13),
    ]

    def region_for(x: int, y: int) -> tuple[str, str]:
        distances = [(math.dist((x, y), center), name, radius)
                     for name, center, radius in cold_regions]
        distance, name, radius = min(distances)
        return ("ice", name) if distance <= radius else ("", "rings")

    seen: set[tuple[int, int]] = set()
    features = []
    for symbol, kind in (("#", "asteroid_field"), ("!", "nebula")):
        for y in range(1, 63):
            for x in range(1, 63):
                if grid[y][x] != symbol or (x, y) in seen:
                    continue
                biome, sector = region_for(x, y)
                cells = []
                queue = deque([(x, y)])
                seen.add((x, y))
                while queue:
                    cx, cy = queue.popleft()
                    cells.append([cx, cy])
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if not (0 < nx < 63 and 0 < ny < 63):
                            continue
                        if (grid[ny][nx] == symbol and (nx, ny) not in seen
                                and region_for(nx, ny) == (biome, sector)):
                            seen.add((nx, ny))
                            queue.append((nx, ny))
                left = min(cell[0] for cell in cells)
                top = min(cell[1] for cell in cells)
                right = max(cell[0] for cell in cells)
                bottom = max(cell[1] for cell in cells)
                features.append({
                    "id": f"obstacle_feature_{len(features) + 1}", "kind": kind,
                    "biome": biome, "sector": sector, "cells": cells,
                    "rect": [left, top, right - left + 1, bottom - top + 1],
                    "passages": [], "seed": SEED + len(features) * 101,
                })
    return features


def _place_supplies(grid: list[list[str]]) -> list[dict]:
    """Добыча вдоль готовых путей не расширяет коридоры и не перекрывает здания."""
    rng = random.Random(SEED)
    occupied = set()
    for x, y, size in ([(o["cell"][0], o["cell"][1], o["size"]) for o in OBJECTS]
                       + [(x, y, 2) for _, (x, y), *_ in PRODUCTION]
                       + [(x, y, 1) for _, (x, y), *_ in GUARDIANS]):
        occupied.update((cx, cy) for cx in range(x - 1, x + size + 1)
                        for cy in range(y - 1, y + size + 1))
    candidates = [(x, y) for y in range(2, 62) for x in range(2, 62)
                  if grid[y][x] == "." and (x, y) not in occupied
                  and math.dist((x, y), (4, 9)) > 2]
    rng.shuffle(candidates)
    result = []
    resources = list(PRODUCTION_TEXTURES)
    def sector(cell):
        x, y = cell
        if x >= 50 and y < 34:
            return 5
        if x < 23 and y < 34:
            return 1
        if x < 35:
            return 2
        return 3 if x < 48 else 4

    # Запас по районам сохраняется, но грузы не образуют кольца вокруг старта.
    for stage, quota in {1: 12, 2: 12, 3: 10, 4: 8, 5: 6}.items():
        placed = 0
        pool = [c for c in candidates if sector(c) == stage]
        resource_bag = resources * 2
        rng.shuffle(resource_bag)
        for cell in pool:
            spacing = rng.uniform(2.0, 4.2)
            if any(math.dist(cell, o["cell"]) < spacing for o in result):
                continue
            if placed == quota:
                break
            artifact = placed == quota - 1 or (stage == 3 and placed == quota - 2)
            result.append(_object(f"supply_{stage}_{placed + 1:02}", "artifact_cache" if artifact else "resource_cache",
                                  "Контейнер с артефактом" if artifact else "Дрейфующий груз", cell, 1, stage,
                                  **({} if artifact else {"resource_name": resource_bag[placed],
                                                         "amount": rng.randint(3, 10 + stage * 2)})))
            placed += 1
        assert placed == quota, (stage, placed, quota)
    return result


def _validate(data: dict) -> None:
    occupied: dict[tuple[int, int], str] = {}
    for category in ("objects", "production", "guardians"):
        for item in data[category]:
            x, y = item["cell"]
            size = int(item.get("size", 1))
            for cy in range(y, y + size):
                for cx in range(x, x + size):
                    assert 0 < cx < 63 and 0 < cy < 63, item["id"]
                    assert data["terrain"][cy][cx] == ".", item["id"]
                    key = (cx, cy)
                    assert key not in occupied, f"{item['id']} пересекает {occupied.get(key)}"
                    occupied[key] = item["id"]
    reach = _reachable([list(row) for row in data["terrain"]], tuple(data["player_start"]))
    for item in data["objects"] + data["production"] + data["guardians"]:
        assert tuple(item["cell"]) in reach, f"Недоступен {item['id']}"
    for item in data["production"]:
        assert (ROOT / item["texture"].replace("res://", "")).exists(), item["id"]
    assert len(data["pirate_spawns"]) == 4
    assert len({spawn["station_id"] for spawn in data["pirate_spawns"]}) == 4
    for transition in data["transitions"]:
        x, y = transition["cell"]
        assert data["terrain"][y][x] == ".", transition["id"]
    blocked = {(x, y) for y, row in enumerate(data["terrain"])
               for x, symbol in enumerate(row)
               if symbol in {"#", "!"} and 0 < x < 63 and 0 < y < 63}
    feature_cells = {tuple(cell) for feature in data["obstacle_features"]
                     for cell in feature["cells"]}
    assert blocked == feature_cells, "Ледяные области не совпадают с проходимостью"


def _draw(data: dict) -> None:
    tile = 18
    width = height = SIZE * tile
    image = Image.new("RGB", (width, height), (11, 19, 33))
    d = ImageDraw.Draw(image)
    colors = {".": (13, 23, 42), "#": (71, 81, 96), "!": (42, 84, 102)}
    for y, row in enumerate(data["terrain"]):
        for x, symbol in enumerate(row):
            d.rectangle((x * tile, y * tile, (x + 1) * tile - 1, (y + 1) * tile - 1),
                        fill=colors[symbol])
    saturn = ROOT / data["background"].replace("res://", "")
    if saturn.exists():
        backdrop = Image.open(saturn).convert("RGB")
        backdrop.thumbnail((560, 560))
        opacity = backdrop.convert("L").point(lambda value: min(36, value // 6))
        backdrop.putalpha(opacity)
        image.paste(backdrop, (470, 185), backdrop)
    for site in data["production"]:
        x, y = site["cell"]
        d.ellipse((x * tile, y * tile, (x + 2) * tile, (y + 2) * tile),
                  fill=(34, 137, 127), outline=(156, 226, 193), width=2)
    for guardian in data["guardians"]:
        x, y = guardian["cell"]
        d.ellipse((x * tile + 3, y * tile + 3, x * tile + 15, y * tile + 15),
                  fill=(227, 102, 80))
    font_path = Path(r"C:\Windows\Fonts\arial.ttf")
    font = ImageFont.truetype(font_path, 17) if font_path.exists() else ImageFont.load_default()
    small_font = ImageFont.truetype(font_path, 14) if font_path.exists() else ImageFont.load_default()
    for obj in data["objects"]:
        x, y = obj["cell"]
        size = obj["size"]
        color = ((166, 52, 44) if obj["kind"] == "pirate_clan_station" else
                 (160, 185, 205) if obj["kind"] == "saturn_moon" else (100, 145, 179))
        d.rounded_rectangle((x * tile, y * tile, (x + size) * tile, (y + size) * tile),
                            radius=7, fill=color, outline=(235, 242, 245), width=2)
        if obj.get("texture"):
            source = ROOT / obj["texture"].replace("res://", "")
            if source.exists():
                sprite = Image.open(source).convert("RGBA")
                if obj["kind"] == "saturn_moon":
                    # Генератор отдал луны на чёрном фоне; скрываем фон в обзоре.
                    alpha = sprite.convert("L").point(lambda value: 255 if value > 8 else 0)
                    sprite.putalpha(alpha.filter(ImageFilter.GaussianBlur(2)))
                sprite.thumbnail((size * tile - 6, size * tile - 6))
                image.paste(sprite, (x * tile + (size * tile - sprite.width) // 2,
                                     y * tile + (size * tile - sprite.height) // 2), sprite)
        if obj["kind"] == "pirate_clan_station":
            d.text((x * tile + 4, y * tile + 3), str(obj["stage"]), font=font,
                   fill="white", stroke_width=2, stroke_fill="black")
        if obj["kind"] in {"pirate_clan_station", "saturn_moon", "aurora_complex"}:
            label = obj["name"]
            if obj["kind"] == "pirate_clan_station":
                label = f"КЛАН {obj['stage']}"
            d.text((x * tile, (y + size) * tile + 2), label, font=small_font,
                   fill="white", stroke_width=2, stroke_fill="black")
    x, y = data["player_start"]
    d.polygon(((x * tile + 9, y * tile - 4), (x * tile + 20, y * tile + 17),
               (x * tile - 2, y * tile + 17)), fill=(76, 176, 249))
    image.save(PREVIEW)


def main() -> None:
    terrain = _terrain()
    data = {
        "id": "saturn_mission_v1", "title": "Миссия 2 — Система Сатурна", "seed": SEED,
        "revision": 4, "player_start": [4, 9], "home_base_at_start": None,
        "background": "res://assets/space/far_planets/saturn_parallax.png",
        "legend": {"#": "Плотный пояс обломков", ".": "Свободный космос",
                   "!": "Ледяная аномалия, непроходимая"},
        "terrain": ["".join(row) for row in terrain],
        "obstacle_features": _obstacle_features(terrain),
        "regions": REGIONS,
        "objectives": [
            {"id": "capture_clan_1", "target": "clan_1_station", "unlocks": ["station_city", "fighter_yard"]},
            {"id": "capture_clan_2", "target": "clan_2_station", "unlocks": ["gunship_yard", "corvette_yard"]},
            {"id": "capture_clan_3", "target": "clan_3_station", "unlocks": ["frigate_yard", "destroyer_yard", "aurora_clue"]},
            {"id": "capture_clan_4", "target": "clan_4_station", "unlocks": ["cruiser_yard", "enceladus_route"]},
            {"id": "reach_aurora_e7", "target": "aurora_e7", "requires": ["capture_clan_4"]},
        ],
        "transitions": [
            {"id": "inner_ring_passage", "cell": [23, 20], "from_stage": 1, "to_stage": 2},
            {"id": "tethys_outer_passage", "cell": [35, 31], "from_stage": 2, "to_stage": 3},
            {"id": "heavy_yard_passage", "cell": [48, 44], "from_stage": 3, "to_stage": 4},
            {"id": "enceladus_passage", "cell": [53, 35], "from_stage": 4, "to_stage": 5,
             "unlock_after": "clan_4_station"},
        ],
        "objects": OBJECTS + _place_supplies(terrain),
        "production": [
            {"id": key, "cell": list(cell), "size": 2, "resource": resource,
             "sector": stage, "name": role, "role": role,
             "texture": PRODUCTION_TEXTURES[resource], "guard_template": guard}
            for key, cell, resource, stage, role, guard in PRODUCTION
        ],
        "guardians": [
            {"id": key, "cell": list(cell), "template": template, "name": name,
             "stage": stage, "protects": protects, "aggro_radius": 1}
            for key, cell, template, name, stage, protects in GUARDIANS
        ],
        "pirate_spawns": [
            {"id": f"clan_{stage}_spawn", "cell": list(cell), "station_id": protects,
             "guardian_id": key, "fleet_template": template}
            for key, cell, template, _name, stage, protects in GUARDIANS
        ],
        "slow_zones": [
            {"id": "ice_drift", "center": [56, 28], "radius": 3},
            {"id": "titan_haze", "center": [12, 46], "radius": 2},
        ],
    }
    _validate(data)
    DEST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _draw(data)
    print(f"{DEST}: {len(data['objects'])} объектов, {len(PRODUCTION)} производств, "
          f"{len(GUARDIANS)} флотов. Обзор: {PREVIEW}")


if __name__ == "__main__":
    main()
