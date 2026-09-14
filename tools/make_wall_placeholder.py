# -*- coding: utf-8 -*-
"""Генератор плейсхолдера сегмента орбитальной стены. Отдельный скрипт, а не
часть make_defense_placeholders.py: тот пересоздаёт orbital_platform.png и
планеты, а их уже заменили настоящим артом — запускать main() того скрипта
снова нельзя.

Запуск:  python tools/make_wall_placeholder.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_defense_placeholders import draw_wall_segment, ROOT, SHIP_DIR

if __name__ == "__main__":
	os.makedirs(SHIP_DIR, exist_ok=True)
	path = os.path.join(SHIP_DIR, "orbital_wall.png")
	draw_wall_segment().save(path)
	print(os.path.relpath(path, ROOT).replace("\\", "/"))
