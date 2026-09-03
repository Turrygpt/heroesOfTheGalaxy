"""Готовит спрайт-листы препятствий к использованию в Godot.

Листы приходят из генератора картинок на сплошном чёрном фоне. Скрипт
выбивает фон в альфу, чтобы препятствия ложились поверх параллакса, а не
закрывали его чёрным прямоугольником.

Режимы:
  rock  — твёрдые тела (астероиды, планетоиды, обломки). Маска по яркости,
          дырки внутри тела заливаются, край слегка размывается.
  glow  — светящиеся объекты (туманности, аномалии). Альфа берётся прямо из
          яркости, поэтому клубы плавно растворяются в космосе.

Использование:
  python tools/prepare_obstacle_sheets.py rock  "<исходник>" assets/space/obstacle_asteroid_field.png
"""

import sys

import numpy as np
from PIL import Image, ImageFilter

ROCK_THRESHOLD = 0.045
ROCK_RAMP_LOW = 0.015
ROCK_RAMP_HIGH = 0.065
ROCK_SHARPEN = (2.0, 95, 3)
GLOW_GAIN = 1.9


def luminance(image: Image.Image) -> np.ndarray:
    pixels = np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0
    return pixels @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def rock_alpha(image: Image.Image) -> Image.Image:
    luma = luminance(image)
    # Замыкание: сначала расширяем силуэт, потом сжимаем обратно. Кратеры и
    # тени внутри камня перестают быть дырками в альфе.
    solid = Image.fromarray(((luma > ROCK_THRESHOLD) * 255).astype(np.uint8))
    solid = solid.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    # Край берётся из самой яркости, а не из размытой маски: полупрозрачным
    # остаётся только реальный переход в чёрный фон шириной в пиксель-другой,
    # поэтому камень не обрастает мыльным ореолом.
    ramp = np.clip((luma - ROCK_RAMP_LOW) / (ROCK_RAMP_HIGH - ROCK_RAMP_LOW), 0.0, 1.0) * 255.0
    alpha = np.maximum(ramp, np.asarray(solid, dtype=np.float32))
    return Image.fromarray(alpha.astype(np.uint8))


def glow_alpha(image: Image.Image) -> Image.Image:
    alpha = np.clip(luminance(image) * GLOW_GAIN, 0.0, 1.0) * 255.0
    return Image.fromarray(alpha.astype(np.uint8))


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    mode, source_path, destination_path = sys.argv[1:4]
    if mode not in ("rock", "glow"):
        print(f"неизвестный режим: {mode}")
        return 2

    image = Image.open(source_path).convert("RGB")
    alpha = rock_alpha(image) if mode == "rock" else glow_alpha(image)
    if mode == "rock":
        # Камни на карте видны почти в масштабе 1:1, и мягкость генератора
        # там читается как мыло. Лёгкая нерезкая маска возвращает грани.
        radius, percent, threshold = ROCK_SHARPEN
        image = image.filter(ImageFilter.UnsharpMask(radius, percent, threshold))
    result = image.convert("RGBA")
    result.putalpha(alpha)
    result.save(destination_path)

    covered = np.count_nonzero(np.asarray(alpha) > 8) / float(alpha.width * alpha.height)
    print(f"{destination_path}: {result.size[0]}x{result.size[1]}, непрозрачно {covered:.1%}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
