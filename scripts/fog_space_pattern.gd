extends RefCounted
## Процедурная бесшовная текстура "неизведанного космоса" для тумана войны
## глобальной карты (см. fog_overlay.gd) - тёмная туманность со звёздами,
## как процедурный боевой SFX (procedural_sfx.gd), без внешних файлов.
## Тайлится через repeat_enable в шейдере, поэтому должна быть бесшовной по
## краям - собирается через доменное отражение шума (см. _seamless_noise).

const BASE_COLOR := Color(0.015, 0.025, 0.05, 1.0)
const NEBULA_COLOR := Color(0.08, 0.055, 0.14, 1.0)
const STAR_COUNT_PER_1000_PX := 6.0


static func generate(size: int, seed_value: int = 7) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	for x in range(size):
		for y in range(size):
			var value := _seamless_noise(noise, x, y, size)
			var t := clampf(value * 0.5 + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, BASE_COLOR.lerp(NEBULA_COLOR, t))
	_scatter_stars(image, size, seed_value)
	return ImageTexture.create_from_image(image)


## Бесшовный шум доменным отражением: значение в точке - билинейная смесь
## шума в исходной точке и в трёх её копиях, сдвинутых на size по каждой оси.
## На границе тайла (x=0/size, y=0/size) смесь всегда вырождается в одно и то
## же значение с обеих сторон, поэтому противоположные края тайла совпадают.
static func _seamless_noise(noise: FastNoiseLite, x: int, y: int, size: int) -> float:
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	var top_left := noise.get_noise_2d(x, y)
	var top_right := noise.get_noise_2d(x - size, y)
	var bottom_left := noise.get_noise_2d(x, y - size)
	var bottom_right := noise.get_noise_2d(x - size, y - size)
	var top := lerpf(top_left, top_right, fx)
	var bottom := lerpf(bottom_left, bottom_right, fx)
	return lerpf(top, bottom, fy)


## Редкие тусклые звёзды - намёк, что за туманом действительно есть карта,
## а не просто чёрный экран, как в HoMM. Каждая пишется отдельным пикселем,
## чтобы не размывалась линейной фильтрацией текстуры в один блик.
static func _scatter_stars(image: Image, size: int, seed_value: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var star_count := int(size * size / 1000.0 * STAR_COUNT_PER_1000_PX)
	for _index in range(star_count):
		var x := random.randi_range(0, size - 1)
		var y := random.randi_range(0, size - 1)
		var brightness := random.randf_range(0.2, 0.75)
		image.set_pixel(x, y, Color(brightness, brightness, brightness * 0.9 + 0.1, 1.0))
