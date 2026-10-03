## Общая раскладка наземной базы; улучшения сохраняют место и масштаб участка.
extends RefCounted

const ART := "res://assets/planet_surface/human/moon_base_v2/"
const MOONS := ["tethys", "titan", "dione", "enceladus"]
const NAMES := {"tethys": "ТЕФИЯ", "titan": "ТИТАН", "dione": "ДИОНА", "enceladus": "ЭНЦЕЛАД"}
const MODULES := {
	"mage_guild": {"at": Vector2(365, 535), "size": Vector2(375, 310), "levels": 4},
	"tavern": {"at": Vector2(645, 595), "size": Vector2(310, 240), "levels": 1},
	"townhall": {"at": Vector2(930, 625), "size": Vector2(460, 375), "levels": 4},
	"marketplace": {"at": Vector2(1235, 515), "size": Vector2(360, 275), "levels": 1},
	"fort": {"at": Vector2(1480, 640), "size": Vector2(340, 295), "levels": 3},
	"fighter_yard": {"at": Vector2(250, 735), "size": Vector2(325, 250), "levels": 2},
	"gunship_yard": {"at": Vector2(555, 805), "size": Vector2(365, 275), "levels": 2},
	"corvette_yard": {"at": Vector2(360, 1030), "size": Vector2(445, 295), "levels": 2},
	"frigate_yard": {"at": Vector2(1135, 825), "size": Vector2(445, 310), "levels": 2},
	"destroyer_yard": {"at": Vector2(1500, 940), "size": Vector2(480, 325), "levels": 2},
	"cruiser_yard": {"at": Vector2(925, 1070), "size": Vector2(570, 360), "levels": 1},
}

static func texture_for(kind: String, level: int) -> AtlasTexture:
	var source := load(ART + "%s_%d.png" % [kind, level]) as Texture2D
	if source == null:
		return null
	var result := AtlasTexture.new()
	result.atlas = source
	result.region = source.get_image().get_used_rect()
	return result
