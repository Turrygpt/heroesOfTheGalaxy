## Авторские силуэты и обозначения FFA поверх общего рендера карты.
extends Node2D

const CLANS := preload("res://scripts/saturn_clans.gd")
const BLACK_KEY := """
shader_type canvas_item;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR *= vec4(tex.rgb, tex.a * smoothstep(0.012, 0.08, max(tex.r, max(tex.g, tex.b))));
}
"""
var sprites: Dictionary = {}
var backdrop: Sprite2D
var status: Label
var journal: Button
var radio_log: Button

static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var source := Image.new()
	if source.load(path) == OK:
		return ImageTexture.create_from_image(source)
	return null

func _ready() -> void:
	z_index = 2
	var map = get_parent()
	var key := Shader.new()
	key.code = BLACK_KEY
	for object in map.map_objects:
		if not object.has("texture"):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = texture(String(object.texture))
		if sprite.texture == null:
			sprite.free()
			continue
		sprite.position = map._object_footprint_center(object.cell, int(object.size))
		sprite.scale = Vector2.ONE * float(object.size) * 96.0 * 0.88 / maxf(sprite.texture.get_width(), sprite.texture.get_height())
		if object.kind == "saturn_moon":
			var material := ShaderMaterial.new()
			material.shader = key
			sprite.material = material
		add_child(sprite)
		sprites[String(object.mission_id)] = sprite
	backdrop = Sprite2D.new()
	backdrop.texture = texture("res://assets/space/far_planets/saturn_parallax.png")
	backdrop.position = Vector2(2900, 2150)
	backdrop.scale = Vector2.ONE * 2.6
	backdrop.modulate.a = 0.22
	backdrop.z_index = -9
	var material := ShaderMaterial.new()
	material.shader = key
	backdrop.material = material
	add_child(backdrop)
	var legend := VBoxContainer.new()
	legend.name = "SaturnClansLegend"
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.position = Vector2(18, 80)
	map.get_node("HUD").add_child(legend)
	for owner in range(2, 6):
		var label := Label.new()
		label.text = CLANS.title(owner)
		label.add_theme_color_override("font_color", CLANS.color(owner))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_outline_size", 4)
		legend.add_child(label)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.custom_minimum_size.x = 390
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_outline_size", 4)
	legend.add_child(status)
	journal = Button.new()
	journal.text = "Задачи экспедиции"
	journal.pressed.connect(func() -> void: map.show_expedition_journal())
	legend.add_child(journal)
	preload("res://scripts/ui_style.gd").apply_button(journal)
	radio_log = Button.new()
	radio_log.text = "Радиожурнал"
	radio_log.pressed.connect(func() -> void: map.saturn_story.show_history())
	legend.add_child(radio_log)
	preload("res://scripts/ui_style.gd").apply_button(radio_log)

func _process(_delta: float) -> void:
	var map = get_parent()
	journal.disabled = not map.is_processing() or map.is_moving or map.reward_dialog_count > 0
	radio_log.disabled = journal.disabled
	backdrop.position = Vector2(2900, 2150) + (map.camera.position - map.far_planet_camera_origin) * 0.2
	var done: Array = map.story_state.get("neutralized_clans", [])
	var count := 0
	for stage in [1, 2, 3]:
		if done.has(stage):
			count += 1
	status.text = "Кланы: %d / 3 · Тефия: %s" % [count, "база основана" if map.human_planet_owner == 1 else "нужна база"]
	var objective := "Нейтрализовать три клана; основать базу на Тефии (26, 18)"
	if map.human_planet_owner == 1:
		objective = "Нейтрализовать три клана; развивать верфи на Тефии"
	if count == 3:
		objective = "Изучить архив большой верфи (44, 39)"
		if bool(map.story_state.get("archive_3", false)):
			objective = "Построить тяжёлую верфь и нанять крейсеры на Тефии"
		if map.final_assault_ready():
			objective = "Разгромить Чёрное Солнце и отключить док (50, 49)"
	if bool(map.story_state.get("gate_open", false)):
		objective = "Изучить журнал дока (55, 49)" if not bool(map.story_state.get("archive_4", false)) else "Раскрыть тайну Энцелада: E-7 (55, 18)"
	status.text += "\n" + objective
	queue_redraw()

func _draw() -> void:
	var map = get_parent()
	for object in map.map_objects:
		if not object.has("texture"):
			continue
		var center: Vector2 = map._object_footprint_center(object.cell, int(object.size))
		var caption := String(object.name)
		var tint := Color("c0d8e9")
		if object.kind == "pirate_clan_station":
			var owner := int(object.get("captured_by", int(object.stage) + 1))
			caption = CLANS.title(owner) + " · станция %d" % int(object.stage)
			tint = CLANS.color(owner)
		elif object.kind == "neutralized_outpost":
			tint = Color("78818b")
		elif String(object.mission_id) == "tethys":
			caption = "Тефия · база экспедиции" if map.human_planet_owner == 1 else "Тефия · место для базы"
			tint = CLANS.color(1) if map.human_planet_owner == 1 else tint
		var sprite: Sprite2D = sprites.get(String(object.mission_id))
		if sprite != null:
			sprite.modulate = Color(0.4, 0.45, 0.5) if object.kind == "neutralized_outpost" else Color.WHITE
		var position := center + Vector2(-200, float(object.size) * 48.0 + 16)
		draw_string(ThemeDB.fallback_font, position + Vector2(2, 2), caption, HORIZONTAL_ALIGNMENT_CENTER, 400, 19, Color.BLACK)
		draw_string(ThemeDB.fallback_font, position, caption, HORIZONTAL_ALIGNMENT_CENTER, 400, 19, tint)
	if not bool(map.story_state.get("gate_open", false)):
		var a := Vector2(50, 33.5) * 96
		var b := Vector2(56, 33.5) * 96
		draw_dashed_line(a, b, Color("f2d35b"), 4, 22)
		draw_string(ThemeDB.fallback_font, a + Vector2(0, -15), "ЗАКРЫТЫЙ ФАРВАТЕР · КОДЫ НА ТЯЖЁЛОЙ ВЕРФИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f2d35b"))
