# -*- coding: utf-8 -*-
"""Генератор плейсхолдер-спрайтов орочьей фракции.

Рисует 10 кораблей (5 рангов x обычный/элитный), корабль вождя для карты и
здания орочьей базы. Настоящий арт заменит эти файлы позже — форматы и
пропорции подобраны так, чтобы подмена не потребовала правок в коде:

* корабли смотрят ВЛЕВО (см. tactical_battle._draw_unit: "All source ships
  face left"), region в orc_defs.gd = весь холст;
* корабль вождя смотрит ВВЕРХ (см. SHIP_SOURCE_ANGLE в space_strategy_map.gd);
* здания — квадрат 1254x1254, как у людей (assets/planet_surface/human).

Запуск:  python tools/make_orc_placeholders.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIP_DIR = os.path.join(ROOT, "assets", "ships", "orc")
BUILDING_DIR = os.path.join(ROOT, "assets", "planet_surface", "orc")
HERO_DIR = os.path.join(ROOT, "assets", "hero_ships")
PORTRAIT_DIR = os.path.join(ROOT, "assets", "heroes")

INK = (20, 26, 18, 255)
HULL = (74, 107, 50, 255)
HULL_DARK = (48, 71, 33, 255)
HULL_LIGHT = (104, 140, 70, 255)
RUST = (138, 58, 30, 255)
GOLD = (200, 149, 42, 255)
GLOW = (255, 122, 42, 255)
BONE = (222, 214, 186, 255)
STEEL = (86, 92, 96, 255)
EYE = (196, 48, 36, 255)

# Ранг -> размер холста. Крупные корабли заметно "толще", как и у землян
# (сравни region в unit_defs.gd: истребитель 3.4:1, эсминец 2.2:1).
SHIP_CANVAS = {
	1: (1200, 400),
	2: (1200, 450),
	3: (1200, 500),
	4: (1200, 560),
	5: (1200, 620),
}


def _font(size):
	for name in ("arialbd.ttf", "arial.ttf", "seguisb.ttf", "DejaVuSans-Bold.ttf"):
		try:
			return ImageFont.truetype(name, size)
		except OSError:
			continue
	return ImageFont.load_default()


def _plate(draw, points, fill, width=6):
	draw.polygon(points, fill=fill, outline=INK)
	draw.line(list(points) + [points[0]], fill=INK, width=width, joint="curve")


def draw_ship(tier, elite):
	"""Корабль носом влево: клиновидный корпус, бивни-тараны, дюзы справа."""
	width, height = SHIP_CANVAS[tier]
	image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cy = height / 2.0
	nose = width * 0.04
	stern = width * 0.93
	half = height * (0.30 + 0.03 * tier)

	hull_points = [
		(nose, cy),
		(width * 0.22, cy - half * 0.72),
		(width * 0.55, cy - half),
		(stern, cy - half * 0.78),
		(width * 0.98, cy - half * 0.30),
		(width * 0.98, cy + half * 0.30),
		(stern, cy + half * 0.78),
		(width * 0.55, cy + half),
		(width * 0.22, cy + half * 0.72),
	]
	_plate(draw, hull_points, HULL)

	# Верхняя бронеплита светлее, брюхо темнее — так читается объём.
	_plate(draw, [
		(width * 0.26, cy - half * 0.60),
		(width * 0.56, cy - half * 0.84),
		(width * 0.86, cy - half * 0.64),
		(width * 0.84, cy - half * 0.16),
		(width * 0.30, cy - half * 0.18),
	], HULL_LIGHT, width=4)
	_plate(draw, [
		(width * 0.28, cy + half * 0.22),
		(width * 0.84, cy + half * 0.20),
		(width * 0.86, cy + half * 0.66),
		(width * 0.54, cy + half * 0.88),
		(width * 0.26, cy + half * 0.62),
	], HULL_DARK, width=4)

	# Число бивней растёт с рангом — силуэт различим даже в мелком масштабе.
	for index in range(1 + tier // 2):
		offset = half * (0.30 + 0.26 * index)
		for sign in (-1, 1):
			base_y = cy + sign * offset
			_plate(draw, [
				(width * 0.16, base_y),
				(width * 0.015, base_y + sign * half * 0.10),
				(width * 0.24, base_y + sign * half * 0.20),
			], BONE, width=3)

	# Орудийные блистеры: у орков оружие крупнее корпуса.
	for sign in (-1, 1):
		gun_y = cy + sign * half * 0.72
		draw.rounded_rectangle(
			[width * 0.46, gun_y - height * 0.045, width * 0.78, gun_y + height * 0.045],
			radius=height * 0.03, fill=RUST, outline=INK, width=4,
		)
		draw.rectangle(
			[width * 0.30, gun_y - height * 0.018, width * 0.50, gun_y + height * 0.018],
			fill=STEEL, outline=INK, width=3,
		)

	nozzles = 3 if elite else 2
	for index in range(nozzles):
		span = half * 1.30
		ny = cy - span * 0.5 + span * (index + 0.5) / nozzles
		draw.rounded_rectangle(
			[width * 0.90, ny - height * 0.05, width * 0.995, ny + height * 0.05],
			radius=height * 0.02, fill=GLOW if elite else RUST, outline=INK, width=4,
		)

	if elite:
		# Элита отличается золотой окантовкой и гребнем; ранг по-прежнему
		# читается по размеру корпуса и числу бивней.
		draw.line(list(hull_points) + [hull_points[0]], fill=GOLD, width=7, joint="curve")
		for index in range(4):
			x = width * (0.34 + 0.13 * index)
			_plate(draw, [
				(x, cy - half * 0.86),
				(x + width * 0.030, cy - half * 1.20),
				(x + width * 0.060, cy - half * 0.86),
			], GOLD, width=3)

	draw.ellipse(
		[width * 0.20, cy - height * 0.075, width * 0.34, cy + height * 0.075],
		fill=EYE, outline=INK, width=5,
	)
	return image


def draw_hero_ship():
	"""Флагман вождя для глобальной карты: носом ВВЕРХ, квадратный холст."""
	size = 518
	image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cx = size / 2.0
	silhouette = [
		(cx, size * 0.04),
		(cx + size * 0.20, size * 0.34),
		(cx + size * 0.30, size * 0.78),
		(cx + size * 0.12, size * 0.94),
		(cx - size * 0.12, size * 0.94),
		(cx - size * 0.30, size * 0.78),
		(cx - size * 0.20, size * 0.34),
	]
	_plate(draw, silhouette, HULL, width=8)
	_plate(draw, [
		(cx, size * 0.16),
		(cx + size * 0.14, size * 0.42),
		(cx + size * 0.10, size * 0.74),
		(cx - size * 0.10, size * 0.74),
		(cx - size * 0.14, size * 0.42),
	], HULL_LIGHT, width=5)
	for sign in (-1, 1):
		_plate(draw, [
			(cx + sign * size * 0.19, size * 0.36),
			(cx + sign * size * 0.44, size * 0.52),
			(cx + sign * size * 0.28, size * 0.72),
		], RUST, width=5)
		draw.rounded_rectangle(
			[cx + sign * size * 0.16 - size * 0.05, size * 0.86,
			 cx + sign * size * 0.16 + size * 0.05, size * 0.98],
			radius=size * 0.02, fill=GLOW, outline=INK, width=5,
		)
	draw.ellipse(
		[cx - size * 0.075, size * 0.30, cx + size * 0.075, size * 0.44],
		fill=EYE, outline=INK, width=6,
	)
	draw.line(silhouette + [silhouette[0]], fill=GOLD, width=6, joint="curve")
	return image


def draw_commander_portrait():
	"""Портрет вождя для панели стороны 2 в бою (см. tactical_battle_hud.gd).
	Размер совпадает с плиткой атласа героев — 512x490."""
	width, height = 512, 490
	image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	# Плечи и голова — грубый силуэт, чтобы плейсхолдер читался как портрет.
	_plate(draw, [
		(width * 0.10, height), (width * 0.20, height * 0.62),
		(width * 0.80, height * 0.62), (width * 0.90, height),
	], (58, 52, 44, 255), width=7)
	_plate(draw, [
		(width * 0.30, height * 0.66), (width * 0.28, height * 0.26),
		(width * 0.50, height * 0.12), (width * 0.72, height * 0.26),
		(width * 0.70, height * 0.66),
	], HULL, width=7)
	# Бивни.
	for sign in (-1, 1):
		_plate(draw, [
			(width * (0.50 + sign * 0.10), height * 0.56),
			(width * (0.50 + sign * 0.16), height * 0.36),
			(width * (0.50 + sign * 0.05), height * 0.56),
		], BONE, width=4)
	for sign in (-1, 1):
		draw.ellipse([
			width * (0.50 + sign * 0.19) - width * 0.06, height * 0.36,
			width * (0.50 + sign * 0.19) + width * 0.06, height * 0.46,
		], fill=EYE, outline=INK, width=5)
	# Наплечники и шлем-обод.
	for sign in (-1, 1):
		_plate(draw, [
			(width * (0.50 + sign * 0.20), height * 0.66),
			(width * (0.50 + sign * 0.42), height * 0.74),
			(width * (0.50 + sign * 0.34), height * 0.94),
			(width * (0.50 + sign * 0.18), height * 0.88),
		], RUST, width=6)
	draw.rectangle([width * 0.26, height * 0.20, width * 0.74, height * 0.30],
				   fill=GOLD, outline=INK, width=6)
	return image


# kind -> (подпись, акцентный цвет, число башен-шипов)
BUILDING_STYLE = {
	"townhall": ("ШАТЁР", (200, 149, 42), 3),
	"fort": ("ФОРТ", (138, 58, 30), 4),
	"fighter_yard": ("ЛОГОВО I", (104, 160, 84), 1),
	"gunship_yard": ("ЛОГОВО II", (96, 148, 120), 2),
	"corvette_yard": ("ЛОГОВО III", (92, 130, 168), 2),
	"frigate_yard": ("ЛОГОВО IV", (140, 108, 176), 3),
	"destroyer_yard": ("ЛОГОВО V", (196, 88, 72), 3),
}
ROMAN = ["I", "II", "III", "IV"]
BUILDING_MAX_LEVEL = {"townhall": 4, "fort": 3}
# Ранг логова уже стоит в подписи, второй уровень — это элитная модель
# (см. orc_defs.gd), поэтому у ангаров вместо цифры уровня метка ЭЛИТА.
YARD_LEVEL_SUFFIX = ["", " ЭЛИТА"]


def draw_building(kind, level):
	"""Квадратный плейсхолдер: скала-основание, корпус, шипы, ранг цифрой."""
	size = 1254
	caption, accent, towers = BUILDING_STYLE[kind]
	accent_rgba = accent + (255,)
	image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)

	_plate(draw, [
		(size * 0.08, size * 0.90), (size * 0.18, size * 0.74),
		(size * 0.82, size * 0.74), (size * 0.92, size * 0.90),
	], (58, 52, 44, 255), width=8)

	# Корпус растёт вверх с уровнем постройки.
	body_top = size * (0.52 - 0.06 * (level - 1))
	_plate(draw, [
		(size * 0.20, size * 0.76), (size * 0.26, body_top),
		(size * 0.74, body_top), (size * 0.80, size * 0.76),
	], HULL, width=8)
	draw.rectangle(
		[size * 0.28, body_top + size * 0.06, size * 0.72, body_top + size * 0.16],
		fill=HULL_DARK, outline=INK, width=6,
	)

	for index in range(towers):
		x = size * (0.30 + 0.40 * (index + 0.5) / towers)
		spike_h = size * (0.10 + 0.035 * level)
		_plate(draw, [
			(x - size * 0.045, body_top),
			(x, body_top - spike_h),
			(x + size * 0.045, body_top),
		], accent_rgba, width=6)

	draw.line([(size * 0.83, size * 0.74), (size * 0.83, size * 0.26)],
			  fill=(40, 34, 28, 255), width=12)
	_plate(draw, [
		(size * 0.83, size * 0.28), (size * 0.83, size * 0.44), (size * 0.62, size * 0.36),
	], EYE, width=6)

	for row in range(2):
		for column in range(4):
			x = size * (0.32 + 0.11 * column)
			y = body_top + size * (0.20 + 0.08 * row)
			if y > size * 0.70:
				continue
			draw.ellipse([x, y, x + size * 0.045, y + size * 0.045],
						 fill=GLOW, outline=INK, width=4)

	if kind in BUILDING_MAX_LEVEL:
		label = "%s %s" % (caption, ROMAN[min(level - 1, 3)])
	else:
		label = caption + YARD_LEVEL_SUFFIX[min(level - 1, 1)]
	font = _font(int(size * 0.062))
	box = draw.textbbox((0, 0), label, font=font)
	x = (size - (box[2] - box[0])) / 2.0
	draw.text((x + 4, size * 0.905 + 4), label, font=font, fill=(10, 12, 10, 220))
	draw.text((x, size * 0.905), label, font=font, fill=(231, 240, 245, 255))
	return image


def main():
	for directory in (SHIP_DIR, BUILDING_DIR, HERO_DIR, PORTRAIT_DIR):
		os.makedirs(directory, exist_ok=True)
	written = []
	for tier in range(1, 6):
		for elite in (False, True):
			name = "tier_%d_elite.png" % tier if elite else "tier_%d.png" % tier
			path = os.path.join(SHIP_DIR, name)
			draw_ship(tier, elite).save(path)
			written.append(path)
	hero_path = os.path.join(HERO_DIR, "orc.png")
	draw_hero_ship().save(hero_path)
	written.append(hero_path)
	portrait_path = os.path.join(PORTRAIT_DIR, "orc_commander.png")
	draw_commander_portrait().save(portrait_path)
	written.append(portrait_path)
	for kind in BUILDING_STYLE:
		for level in range(1, BUILDING_MAX_LEVEL.get(kind, 2) + 1):
			path = os.path.join(BUILDING_DIR, "%s%d.png" % (kind, level))
			draw_building(kind, level).save(path)
			written.append(path)
	for path in written:
		print(os.path.relpath(path, ROOT).replace("\\", "/"))


if __name__ == "__main__":
	main()
