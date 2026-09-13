# -*- coding: utf-8 -*-
"""Генератор плейсхолдер-спрайтов новой нейтральной фракции "Стражи Древних"
(см. data/art_generation_prompts.md §3) — редкие опасные стражи в глухих
углах карты, не играбельная сторона, три ранга: sentinel/warden/colossus.

Настоящий арт заменит эти файлы позже — формат подобран так, чтобы подмена
не потребовала правок кода:

* корабли смотрят ВЛЕВО (как любой корабль, см. tactical_battle._draw_unit:
  "All source ships face left"), region в unit_defs.gd = весь холст;
* холст растёт с рангом, как у орков (см. tools/make_orc_placeholders.py).

Запуск:  python tools/make_ancient_placeholders.py
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIP_DIR = os.path.join(ROOT, "assets", "ships", "ancient")

INK = (12, 14, 24, 255)
HULL = (196, 200, 214, 255)
HULL_DARK = (120, 126, 148, 255)
VIOLET = (110, 64, 200, 255)
TEAL = (94, 214, 199, 255)
CORE = (226, 240, 255, 255)

# Ранг -> размер холста и число граней корпуса — крупнее ранг, крупнее и
# "тяжелее" читается силуэт, как у остальных фракций.
SHIP_CANVAS = {
	5: (1200, 500),
	6: (1200, 560),
	7: (1200, 620),
}


def _shard(draw, points, fill, width=6):
	draw.polygon(points, fill=fill, outline=INK)
	draw.line(list(points) + [points[0]], fill=INK, width=width, joint="curve")


def draw_ship(tier):
	"""Корабль-конструкт носом влево: гранёный кристаллический корпус вместо
	панельной обшивки людей/орков, светящиеся разломы вдоль граней."""
	width, height = SHIP_CANVAS[tier]
	image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cy = height / 2.0
	nose = width * 0.03
	stern = width * 0.95
	half = height * (0.26 + 0.03 * (tier - 5))

	# Корпус — вытянутый гранёный кристалл, острый нос, скошенная корма.
	hull_points = [
		(nose, cy),
		(width * 0.20, cy - half * 0.55),
		(width * 0.46, cy - half * 0.92),
		(width * 0.74, cy - half),
		(stern, cy - half * 0.45),
		(width * 0.99, cy),
		(stern, cy + half * 0.45),
		(width * 0.74, cy + half),
		(width * 0.46, cy + half * 0.92),
		(width * 0.20, cy + half * 0.55),
	]
	_shard(draw, hull_points, HULL, width=6)

	# Верхняя/нижняя грани светлее и темнее — читается объём кристалла.
	_shard(draw, [
		(width * 0.24, cy - half * 0.48),
		(width * 0.48, cy - half * 0.80),
		(width * 0.76, cy - half * 0.86),
		(width * 0.90, cy - half * 0.30),
		(width * 0.30, cy - half * 0.14),
	], HULL_DARK, width=4)
	_shard(draw, [
		(width * 0.30, cy + half * 0.16),
		(width * 0.90, cy + half * 0.30),
		(width * 0.76, cy + half * 0.86),
		(width * 0.48, cy + half * 0.80),
		(width * 0.24, cy + half * 0.48),
	], HULL_DARK, width=4)

	# Светящиеся разломы вдоль корпуса — число растёт с рангом.
	for index in range(1 + (tier - 5)):
		offset = half * (0.30 + 0.30 * index)
		x0 = width * (0.30 + 0.12 * index)
		x1 = width * (0.62 + 0.10 * index)
		for sign in (-1, 1):
			draw.line([(x0, cy + sign * offset * 0.5), (x1, cy + sign * offset)],
				fill=TEAL, width=6, joint="curve")

	# Ядро — фокальная точка конструкта, светится тем ярче, чем выше ранг.
	core_r = height * (0.09 + 0.01 * (tier - 5))
	draw.ellipse([width * 0.50 - core_r, cy - core_r, width * 0.50 + core_r, cy + core_r],
		fill=VIOLET, outline=INK, width=5)
	inner_r = core_r * 0.5
	draw.ellipse([width * 0.50 - inner_r, cy - inner_r, width * 0.50 + inner_r, cy + inner_r],
		fill=CORE, outline=None)

	# Кормовые дюзы — холодное тил-свечение вместо огня.
	nozzles = 2 + (tier - 5)
	for index in range(nozzles):
		span = half * 1.10
		ny = cy - span * 0.5 + span * (index + 0.5) / nozzles
		draw.rounded_rectangle(
			[width * 0.94, ny - height * 0.035, width * 0.995, ny + height * 0.035],
			radius=height * 0.018, fill=TEAL, outline=INK, width=3,
		)

	draw.line(list(hull_points) + [hull_points[0]], fill=VIOLET, width=4, joint="curve")
	return image


def main():
	os.makedirs(SHIP_DIR, exist_ok=True)
	written = []
	for tier in (5, 6, 7):
		path = os.path.join(SHIP_DIR, "tier_%d.png" % tier)
		draw_ship(tier).save(path)
		written.append(path)
	for path in written:
		print(os.path.relpath(path, ROOT).replace("\\", "/"))


if __name__ == "__main__":
	main()
