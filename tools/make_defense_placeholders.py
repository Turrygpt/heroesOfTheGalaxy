# -*- coding: utf-8 -*-
"""Генератор плейсхолдеров для орбитальной обороны форта и двух нейтральных
планет (торговая станция и пиратская твердыня). Настоящий арт нарисует
пользователь позже по промтам из AGENTS.md — форматы и пропорции подобраны
так, чтобы подмена не потребовала правок в коде:

* orbital_platform.png — станция смотрит носом ВЛЕВО, как любой корабль
  (см. tactical_battle._draw_unit), region = весь холст;
* trading.png / pirate.png — квадратные сферы планет, тот же формат, что
  assets/planets/human.png и bandit.png (см. space_strategy_map.gd:human_planet).

Запуск:  python tools/make_defense_placeholders.py
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIP_DIR = os.path.join(ROOT, "assets", "ships", "human_new")
PLANET_DIR = os.path.join(ROOT, "assets", "planets")

INK = (14, 20, 26, 255)


def draw_orbital_platform():
	"""Стационарная орбитальная батарея: кольцевая станция с двумя орудиями,
	смотрящими вдоль оси корпуса (влево/вправо) — направление станции не
	имеет значения, орудия бьют в обе стороны."""
	width, height = 1200, 500
	image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cx, cy = width * 0.5, height * 0.5

	hull_light = (196, 206, 216, 255)
	hull = (120, 134, 150, 255)
	hull_dark = (72, 84, 98, 255)
	gold = (223, 168, 58, 255)
	glow = (86, 214, 255, 255)

	# Кольцо станции.
	ring_r = height * 0.46
	draw.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r], fill=hull, outline=INK, width=8)
	inner_r = ring_r * 0.62
	draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=(0, 0, 0, 0), outline=hull_dark, width=14)
	core_r = ring_r * 0.40
	draw.ellipse([cx - core_r, cy - core_r, cx + core_r, cy + core_r], fill=hull_light, outline=INK, width=6)
	draw.ellipse([cx - core_r * 0.45, cy - core_r * 0.45, cx + core_r * 0.45, cy + core_r * 0.45],
				 fill=glow, outline=INK, width=5)

	# Радиальные фермы, держащие кольцо.
	for angle_deg in range(0, 360, 45):
		angle = math.radians(angle_deg)
		x1, y1 = cx + math.cos(angle) * core_r, cy + math.sin(angle) * core_r
		x2, y2 = cx + math.cos(angle) * inner_r, cy + math.sin(angle) * inner_r
		draw.line([(x1, y1), (x2, y2)], fill=hull_dark, width=10)

	# Два орудийных ствола вдоль горизонтали — станция стреляет в обе стороны.
	for sign in (-1, 1):
		barrel_x0 = cx + sign * ring_r * 0.85
		barrel_x1 = cx + sign * (width * 0.5 - width * 0.02)
		draw.rounded_rectangle(
			[min(barrel_x0, barrel_x1), cy - height * 0.05, max(barrel_x0, barrel_x1), cy + height * 0.05],
			radius=height * 0.03, fill=hull, outline=INK, width=6,
		)
		draw.rounded_rectangle(
			[min(barrel_x0, barrel_x1), cy - height * 0.022, max(barrel_x0, barrel_x1), cy + height * 0.022],
			radius=height * 0.012, fill=hull_dark, outline=INK, width=3,
		)
		tip_x = cx + sign * (width * 0.5 - width * 0.015)
		draw.ellipse([tip_x - height * 0.05, cy - height * 0.05, tip_x + height * 0.05, cy + height * 0.05],
					 fill=gold, outline=INK, width=5)

	# Солнечные панели сверху/снизу — читаемый силуэт станции, а не корабля.
	for sign in (-1, 1):
		panel_y = cy + sign * ring_r * 0.95
		draw.rectangle(
			[cx - width * 0.16, panel_y - height * 0.05, cx + width * 0.16, panel_y + height * 0.05],
			fill=hull_dark, outline=gold, width=5,
		)
	return image


def draw_wall_segment():
	"""Один сегмент орбитальной стены: высокий вертикальный энергетический
	столб. Холст нарочно портретный (не квадратный, как у кораблей) — рендер
	масштабирует спрайт по ширине, так что именно пропорции исходника делают
	сегмент высоким в игре. Девять таких сегментов ставятся подряд по клеткам
	одной колонки и читаются как сплошная стена."""
	width, height = 460, 1200
	image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cx = width * 0.5

	frame = (150, 160, 172, 255)
	frame_dark = (92, 100, 112, 255)
	glow = (110, 220, 255, 255)
	glow_dim = (70, 170, 220, 180)

	# Несущая рама по краям столба.
	for sign in (-1, 1):
		x = cx + sign * width * 0.34
		draw.rounded_rectangle(
			[x - width * 0.06, height * 0.03, x + width * 0.06, height * 0.97],
			radius=width * 0.03, fill=frame, outline=INK, width=6,
		)

	# Энергетическое полотно между рамами — полупрозрачные горизонтальные
	# полосы, чтобы читалось как силовое поле, а не сплошная броня.
	panel_left = cx - width * 0.26
	panel_right = cx + width * 0.26
	draw.rounded_rectangle(
		[panel_left, height * 0.05, panel_right, height * 0.95],
		radius=width * 0.04, fill=(30, 60, 78, 140), outline=glow_dim, width=4,
	)
	bands = 9
	for index in range(bands):
		y0 = height * (0.06 + index * 0.88 / bands)
		y1 = y0 + height * 0.88 / bands * 0.55
		draw.rectangle([panel_left + width * 0.03, y0, panel_right - width * 0.03, y1],
					   fill=glow_dim, outline=None)

	# Узловые перемычки-генераторы через равные интервалы — разбивают
	# монотонность и дают точки, куда "целится" глаз при стрельбе по стене.
	nodes = 3
	for index in range(nodes):
		ny = height * (0.20 + index * 0.30)
		draw.rounded_rectangle(
			[cx - width * 0.40, ny - height * 0.025, cx + width * 0.40, ny + height * 0.025],
			radius=width * 0.02, fill=frame_dark, outline=INK, width=5,
		)
		draw.ellipse([cx - width * 0.09, ny - width * 0.09, cx + width * 0.09, ny + width * 0.09],
					 fill=glow, outline=INK, width=4)

	return image


def draw_planet(base, accent, highlight, ring_color=None, label_glow=None):
	"""Плейсхолдер планеты-сферы: тот же формат, что assets/planets/human.png
	(квадратный холст, сфера почти во весь кадр, лёгкий ободок атмосферы)."""
	size = 900
	image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(image)
	cx = cy = size * 0.5
	radius = size * 0.42

	if ring_color is not None:
		# Кольцо у пиратской твердыни — плоский эллипс позади сферы.
		ring_w, ring_h = radius * 2.5, radius * 0.55
		draw.ellipse([cx - ring_w / 2, cy - ring_h / 2, cx + ring_w / 2, cy + ring_h / 2],
					 outline=ring_color, width=int(size * 0.02))

	draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=base, outline=INK, width=6)

	# Терминатор: тёмная дуга с противоположной стороны от света.
	shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	shadow_draw = ImageDraw.Draw(shadow)
	shadow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(0, 0, 0, 110))
	shadow_draw.ellipse([cx - radius * 0.35, cy - radius * 1.05, cx + radius * 1.55, cy + radius * 1.05],
						 fill=(0, 0, 0, 0))
	mask = Image.new("L", (size, size), 0)
	mask_draw = ImageDraw.Draw(mask)
	mask_draw.ellipse([cx - radius * 0.15, cy - radius * 1.1, cx + radius * 1.7, cy + radius * 1.1], fill=255)
	shadow.putalpha(Image.composite(Image.new("L", (size, size), 0), shadow.split()[3], mask))
	image.alpha_composite(shadow)

	# Пятна ландшафта/построек — несколько плюшек, чтобы силуэт не был пустым.
	for fx, fy, fr in ((-0.30, -0.18, 0.16), (0.10, 0.08, 0.22), (0.28, -0.22, 0.12), (-0.10, 0.28, 0.14)):
		px, py, pr = cx + fx * radius * 1.6, cy + fy * radius * 1.6, radius * fr
		if (px - cx) ** 2 + (py - cy) ** 2 > (radius * 0.92) ** 2:
			continue
		draw.ellipse([px - pr, py - pr, px + pr, py + pr], fill=highlight, outline=None)

	# Атмосферный ободок.
	draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], outline=(highlight[0], highlight[1], highlight[2], 140), width=4)

	if label_glow is not None:
		glow_r = radius * 1.12
		draw.ellipse([cx - glow_r, cy - glow_r, cx + glow_r, cy + glow_r], outline=label_glow, width=3)
	return image


def main():
	for directory in (SHIP_DIR, PLANET_DIR):
		os.makedirs(directory, exist_ok=True)
	written = []

	platform_path = os.path.join(SHIP_DIR, "orbital_platform.png")
	draw_orbital_platform().save(platform_path)
	written.append(platform_path)

	trading_path = os.path.join(PLANET_DIR, "trading.png")
	draw_planet(
		base=(70, 150, 158, 255), accent=(40, 90, 96, 255), highlight=(230, 196, 110, 255),
		label_glow=(120, 220, 210, 120),
	).save(trading_path)
	written.append(trading_path)

	pirate_path = os.path.join(PLANET_DIR, "pirate.png")
	draw_planet(
		base=(96, 44, 40, 255), accent=(56, 24, 22, 255), highlight=(220, 90, 60, 255),
		ring_color=(150, 60, 50, 160), label_glow=(230, 90, 70, 120),
	).save(pirate_path)
	written.append(pirate_path)

	for path in written:
		print(os.path.relpath(path, ROOT).replace("\\", "/"))


if __name__ == "__main__":
	main()
