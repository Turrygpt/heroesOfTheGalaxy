## Единые знаки владельцев: игрок — 1, четыре независимых пиратских клана — 2–5.
extends RefCounted

const COLORS := [Color("99a7b8"), Color("3ca5ff"), Color("ff8c42"), Color("ba83ff"), Color("43d6b0"), Color("f2d35b")]
const SIGNS := ["·", "●", "▲", "◆", "■", "✚"]
const NAMES := ["Нейтральные", "Экспедиция Павловой", "Ржавые Клыки", "Ночная Вуаль", "Ледяные Змеи", "Чёрное Солнце"]

static func color(owner: int) -> Color:
	return COLORS[clampi(owner, 0, 5)]

static func title(owner: int) -> String:
	return "%s %s" % [SIGNS[clampi(owner, 0, 5)], NAMES[clampi(owner, 0, 5)]]
