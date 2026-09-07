## Единая палитра, поверхности и состояния элементов игрового интерфейса.
extends RefCounted

const SURFACE := Color("181b20")
const RAISED := Color("24282e")
const BORDER := Color("444a52")
const INK := Color("edf0f2")
const MUTED := Color("a0a7af")
const GOLD := Color("d6ba80")
const CYAN := Color("82c9c1")


static func font() -> Font:
	var result := SystemFont.new()
	result.font_names = PackedStringArray(["Segoe UI Variable Display", "Segoe UI Variable", "Segoe UI", "Noto Sans", "Arial"])
	result.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return result


static func surface(accent: Color = BORDER, background: Color = SURFACE, horizontal: float = 16, vertical: float = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# Сохраняем смысловые оттенки, приглушая насыщенные старые подложки.
	style.bg_color = SURFACE.lerp(background, 0.12)
	style.bg_color.a = 1.0
	style.border_color = BORDER.lerp(accent, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


static func inset(horizontal: float = 14, vertical: float = 12) -> StyleBoxFlat:
	var style := surface(BORDER, SURFACE, horizontal, vertical)
	style.draw_center = false
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.set_corner_radius_all(0)
	return style


static func button_style(state: String) -> StyleBoxFlat:
	var style := surface(BORDER, RAISED, 14, 8)
	style.bg_color = RAISED
	match state:
		"hover":
			style.bg_color = Color("33363a")
			style.border_color = GOLD
		"pressed", "tab_selected":
			style.bg_color = Color("343127")
			style.border_color = GOLD
		"disabled":
			style.bg_color = Color("1b1e22")
			style.border_color = Color("30343a")
		"focus":
			style.draw_center = false
			style.border_color = CYAN
	return style


static func apply_button(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, button_style(state))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 16
	for type: String in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit", "TextEdit", "RichTextLabel", "ItemList", "Tree", "PopupMenu", "TabBar"]:
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, GOLD)
		theme.set_color("font_disabled_color", type, Color("747b83"))
		theme.set_color("font_selected_color", type, GOLD)
	for type: String in ["Button", "OptionButton", "MenuButton"]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			theme.set_stylebox(state, type, button_style(state))
	for type: String in ["Panel", "PanelContainer", "PopupPanel", "PopupMenu", "AcceptDialog"]:
		theme.set_stylebox("panel", type, surface(BORDER, SURFACE, 0, 0))
	for type: String in ["LineEdit", "TextEdit", "Tree", "ItemList"]:
		theme.set_stylebox("normal" if type in ["LineEdit", "TextEdit"] else "panel", type, surface(BORDER, SURFACE, 8, 6))
		theme.set_stylebox("focus", type, button_style("focus"))
		theme.set_stylebox("selected", type, button_style("pressed"))
		theme.set_color("selection_color", type, Color("465651"))
	for state: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
		var mapped := {"tab_selected": "pressed", "tab_hovered": "hover", "tab_disabled": "disabled", "tab_focus": "focus"}
		theme.set_stylebox(state, "TabBar", button_style(mapped.get(state, "normal")))
	theme.set_stylebox("panel", "TabContainer", surface())
	for state: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "tab_focus"]:
		theme.set_stylebox(state, "TabContainer", theme.get_stylebox(state, "TabBar"))
	var tooltip := surface(BORDER, SURFACE, 12, 8)
	tooltip.shadow_size = 6
	tooltip.shadow_color = Color(0, 0, 0, 0.35)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	for type: String in ["HSeparator", "VSeparator"]:
		var rule := StyleBoxLine.new()
		rule.color = BORDER
		rule.thickness = 1
		rule.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, rule)
	for type: String in ["HScrollBar", "VScrollBar"]:
		for state: String in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			var track := surface(BORDER, SURFACE, 4, 4)
			track.bg_color = Color("51585e") if state.begins_with("grabber") else SURFACE
			track.set_border_width_all(0)
			theme.set_stylebox(state, type, track)
	for type: String in ["HSlider", "VSlider"]:
		for state: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			var track := surface(BORDER, SURFACE, 2, 2)
			track.bg_color = CYAN if state != "slider" else BORDER
			track.set_border_width_all(0)
			theme.set_stylebox(state, type, track)
	theme.set_stylebox("background", "ProgressBar", surface(BORDER, SURFACE, 0, 0))
	var fill := surface(CYAN, CYAN, 0, 0)
	fill.bg_color = CYAN
	theme.set_stylebox("fill", "ProgressBar", fill)
	return theme
