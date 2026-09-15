extends SceneTree
## Отладочный съёмщик декораций дальнего космоса: рисует комету и далёкую
## планету в SubViewport и сохраняет PNG. Геймплея не касается, нужен только
## чтобы посмотреть на эффекты, не запуская всю карту.
##
##   ./Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tools/comet_shot.gd

const SpaceDecorations := preload("res://scripts/space_decorations.gd")
const SHOT_SIZE := Vector2i(1280, 720)
## Сколько секунд жизни кометы "промотать" до снимка - на нулевом времени
## искры ещё не разлетелись и хвост выглядит беднее, чем в игре.
const WARMUP_SECONDS := 6.0

var canvas: CometCanvas
var viewport: SubViewport
var frames := 0


class CometCanvas extends Node2D:
	var decorations: Dictionary = {}
	var comets: Array[Dictionary] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SHOT_SIZE)), Color(0.04, 0.04, 0.08))
		SpaceDecorations.draw(self, decorations, comets)


func _initialize() -> void:
	viewport = SubViewport.new()
	viewport.size = SHOT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	canvas = CometCanvas.new()
	viewport.add_child(canvas)

	var comets := SpaceDecorations.make_comets(7, Vector2(SHOT_SIZE))
	var comet := comets[0]
	comet["position"] = Vector2(SHOT_SIZE) * Vector2(0.72, 0.52)
	comet["velocity"] = Vector2(40.0, -14.0)
	comet["radius"] = 18.0
	canvas.comets = [comet] as Array[Dictionary]
	canvas.decorations = {"planets": [{
		"position": Vector2(SHOT_SIZE) * Vector2(0.17, 0.35),
		"radius": 110.0,
		"color": SpaceDecorations.FAR_PLANET_TINTS[2],
		"texture": SpaceDecorations.FAR_PLANET_TEXTURES[0],
		"rim_angle": -0.9,
	}]}
	var step := 1.0 / 60.0
	for _tick in range(int(WARMUP_SECONDS / step)):
		SpaceDecorations.tick_comets(canvas.comets, Vector2(SHOT_SIZE), step)
	canvas.queue_redraw()


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	viewport.get_texture().get_image().save_png("res://comet_preview.png")
	print("saved res://comet_preview.png")
	return true
