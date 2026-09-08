# -*- coding: utf-8 -*-
"""Черновая сборка PNG фона меню из слоёв и процедурного космоса.

Живой фон в игре рисует `menu_space_backdrop.gd` (шейдер космоса + слои
из `assets/ui/main_menu_layers/`). Этот скрипт нужен, чтобы подогнать
раскладку и при желании запечь неподвижную картинку.

Запуск:  python tools/compose_menu_background.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = os.path.join(ROOT, "tmp")
OUT_PREVIEW = os.path.join(TMP, "preview_menu.png")
OUT_ASSET = os.path.join(ROOT, "assets", "ui", "main_menu_backgrounds", "heroes_of_the_galaxy_logo_earth.png")

WIDTH = 1920
HEIGHT = 1080
RNG_SEED = 1001


def _fbm(height: int, width: int, octaves: int, rng: np.random.Generator, base_cells: int) -> np.ndarray:
	"""Value-noise FBM, значения в [0, 1]."""
	acc = np.zeros((height, width), dtype=np.float32)
	amp = 0.55
	norm = 0.0
	cells = base_cells
	for _octave in range(octaves):
		grid = rng.random((cells + 1, cells + 1)).astype(np.float32)
		ys = np.linspace(0, cells, height, endpoint=False)
		xs = np.linspace(0, cells, width, endpoint=False)
		y0 = np.floor(ys).astype(np.int32)
		x0 = np.floor(xs).astype(np.int32)
		fy = (ys - y0).astype(np.float32)
		fx = (xs - x0).astype(np.float32)
		fy = fy * fy * (3.0 - 2.0 * fy)
		fx = fx * fx * (3.0 - 2.0 * fx)
		y1 = np.minimum(y0 + 1, cells)
		x1 = np.minimum(x0 + 1, cells)
		n00 = grid[y0[:, None], x0[None, :]]
		n10 = grid[y0[:, None], x1[None, :]]
		n01 = grid[y1[:, None], x0[None, :]]
		n11 = grid[y1[:, None], x1[None, :]]
		bottom = n00 * (1.0 - fx) + n10 * fx
		top = n01 * (1.0 - fx) + n11 * fx
		acc += (bottom * (1.0 - fy)[:, None] + top * fy[:, None]) * amp
		norm += amp
		amp *= 0.48
		cells = min(cells * 2, 256)
	return acc / norm


def _smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
	t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def make_space(width: int, height: int, seed: int) -> Image.Image:
	rng = np.random.default_rng(seed)
	yy, xx = np.mgrid[0:height, 0:width]
	u = xx.astype(np.float32) / float(width)
	v = yy.astype(np.float32) / float(height)

	warp = _fbm(height, width, 4, rng, 6)
	wu = np.clip(u + (warp - 0.5) * 0.18, 0.0, 1.0)
	wv = np.clip(v + (warp - 0.5) * 0.14, 0.0, 1.0)

	warm = _fbm(height, width, 5, rng, 5)
	cool = _fbm(height, width, 5, rng, 7)
	vein = _fbm(height, width, 4, rng, 4)

	# Тёплая пылевая туманность слева, как за кольцом на исходном кадре.
	warm_mask = _smoothstep(0.48, 0.02, u) * _smoothstep(0.02, 0.18, v) * _smoothstep(0.88, 0.48, v)
	warm_body = _smoothstep(0.42, 0.78, warm) * warm_mask
	warm_core = _smoothstep(0.62, 0.90, warm) * warm_mask

	# Холодный диагональный рукав справа-сверху — намёк на млечный путь.
	diag = (u * 0.62 + (1.0 - v) * 0.58)
	band = np.exp(-((diag - 0.82) ** 2) / 0.048) * _smoothstep(0.38, 0.72, u)
	cool_body = _smoothstep(0.48, 0.82, cool) * (0.22 + 0.78 * band)
	cool_core = _smoothstep(0.66, 0.92, cool) * band

	# Редкие фиолетовые облака в центре, чтобы космос не был плоским.
	mid = _smoothstep(0.55, 0.82, vein) * _smoothstep(0.18, 0.45, u) * _smoothstep(0.72, 0.42, u) * 0.35

	base = np.array([3, 7, 18], dtype=np.float32)
	rgb = np.empty((height, width, 3), dtype=np.float32)
	rgb[..., 0] = base[0]
	rgb[..., 1] = base[1]
	rgb[..., 2] = base[2]

	warm_color = np.array([156, 68, 22], dtype=np.float32)
	warm_hot = np.array([208, 112, 42], dtype=np.float32)
	cool_color = np.array([28, 58, 122], dtype=np.float32)
	cool_hot = np.array([168, 206, 242], dtype=np.float32)
	mid_color = np.array([48, 30, 78], dtype=np.float32)

	for c in range(3):
		rgb[..., c] += warm_body * warm_color[c] * 0.95
		rgb[..., c] += warm_core * warm_hot[c] * 0.62
		rgb[..., c] += cool_body * cool_color[c] * 0.55
		rgb[..., c] += cool_core * cool_hot[c] * 0.38
		rgb[..., c] += mid * mid_color[c]

	# Тусклая пыль по всему полю — слабее, чтобы оставался глубокий космос.
	dust = _fbm(height, width, 3, rng, 12)
	rgb[..., 0] += dust * 5.0
	rgb[..., 1] += dust * 6.0
	rgb[..., 2] += dust * 11.0

	rgb = np.clip(rgb, 0.0, 255.0)

	# Звёзды: мелкие точки, средние блики, редкие яркие с крестом.
	space = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
	px = space.load()
	star_rng = np.random.default_rng(seed + 17)

	def plot_star(cx: int, cy: int, radius: float, color: tuple[int, int, int], alpha: float) -> None:
		r = int(np.ceil(radius * 2.4))
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				x = cx + dx
				y = cy + dy
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				dist = (dx * dx + dy * dy) ** 0.5
				fall = max(0.0, 1.0 - dist / max(radius, 0.35))
				fall = fall * fall
				if fall <= 0.0:
					continue
				src = px[x, y]
				a = min(1.0, alpha * fall)
				px[x, y] = (
					int(src[0] + (color[0] - src[0]) * a),
					int(src[1] + (color[1] - src[1]) * a),
					int(src[2] + (color[2] - src[2]) * a),
					255,
				)

	# Мелкое поле.
	for _ in range(2800):
		x = int(star_rng.integers(0, width))
		y = int(star_rng.integers(0, height))
		b = float(star_rng.uniform(90, 210))
		tint = star_rng.uniform(-12, 18)
		plot_star(x, y, float(star_rng.uniform(0.35, 0.85)), (int(b + tint), int(b + tint * 0.4), int(min(255, b + 18))), float(star_rng.uniform(0.25, 0.7)))

	# Средние.
	for _ in range(280):
		x = int(star_rng.integers(0, width))
		y = int(star_rng.integers(0, height))
		b = float(star_rng.uniform(160, 255))
		plot_star(x, y, float(star_rng.uniform(0.9, 1.7)), (int(b), int(b * 0.96), int(min(255, b + 10))), float(star_rng.uniform(0.45, 0.9)))

	# Яркие с дифракционным крестом.
	for _ in range(18):
		x = int(star_rng.integers(40, width - 40))
		y = int(star_rng.integers(20, int(height * 0.62)))
		color = (255, 248, 232)
		plot_star(x, y, 3.2, color, 0.95)
		for arm in range(-18, 19):
			if 0 <= x + arm < width:
				plot_star(x + arm, y, 0.7, color, 0.35 * (1.0 - abs(arm) / 18.0))
			if 0 <= y + arm < height:
				plot_star(x, y + arm, 0.7, color, 0.28 * (1.0 - abs(arm) / 18.0))

	return space


def _load_layer(name: str) -> Image.Image:
	image = Image.open(os.path.join(TMP, name)).convert("RGBA")
	arr = np.array(image)
	# Вычищаем шум вырезания: почти нулевая альфа становится дырой.
	arr[..., 3] = np.where(arr[..., 3] < 4, 0, arr[..., 3])
	return Image.fromarray(arr, "RGBA")


def _paste(canvas: Image.Image, layer: Image.Image, center: tuple[float, float], width_px: float, rotate: float = 0.0, height_px: float | None = None) -> None:
	aspect = layer.size[1] / float(layer.size[0])
	w = max(1, int(round(width_px)))
	h = max(1, int(round(height_px if height_px is not None else w * aspect)))
	scaled = layer.resize((w, h), Image.Resampling.LANCZOS)
	if rotate != 0.0:
		scaled = scaled.rotate(rotate, resample=Image.Resampling.BICUBIC, expand=True)
	cx, cy = center
	x = int(round(cx - scaled.size[0] / 2.0))
	y = int(round(cy - scaled.size[1] / 2.0))
	tmp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
	tmp.paste(scaled, (x, y), scaled)
	canvas.alpha_composite(tmp)


def compose(save_asset: bool = False) -> str:
	canvas = make_space(WIDTH, HEIGHT, RNG_SEED)

	ring = _load_layer("ring.png")
	moons = _load_layer("moons.png")
	planet = _load_layer("planet.png")
	asteroids = _load_layer("asteroids.png")
	logo = _load_layer("logo.png")

	# Раскладка подогнана под исходный кадр 1670x942, пересчитана на 1920x1080.
	# Кольцо — центр глубоко за горизонтом, над атмосферой только верхняя дуга.
	_paste(canvas, ring, (WIDTH * 0.10, HEIGHT * 0.78), HEIGHT * 0.96, height_px=HEIGHT * 0.96)
	# Луны справа, крупная обрезается краем кадра.
	_paste(canvas, moons, (WIDTH * 0.95, HEIGHT * 0.47), HEIGHT * 0.50)
	# Планета сдвинута влево.
	_paste(canvas, planet, (WIDTH * 0.38, HEIGHT * 0.70), WIDTH * 1.28)
	# Пояс астероидов поверх правого края планеты.
	_paste(canvas, asteroids, (WIDTH * 0.87, HEIGHT * 0.84), HEIGHT * 0.54, rotate=-10.0)
	# Логотип по центру верхней половины, как на исходной картинке.
	_paste(canvas, logo, (WIDTH * 0.50, HEIGHT * 0.27), WIDTH * 0.55)

	rgb = canvas.convert("RGB")
	# Лёгкое сведение резкости после масштабирования слоёв.
	rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))
	rgb.save(OUT_PREVIEW, "PNG")
	if save_asset:
		os.makedirs(os.path.dirname(OUT_ASSET), exist_ok=True)
		rgb.save(OUT_ASSET, "PNG")
	return OUT_PREVIEW


if __name__ == "__main__":
	path = compose(save_asset=False)
	print(path)
