class_name VillageTheme
extends RefCounted

const INK := Color("241d1a")
const INK_SOFT := Color("4d4036")
const PAPER := Color("f7edcf")
const PAPER_DARK := Color("dfc995")
const MOSS := Color("2f7257")
const MOSS_LIGHT := Color("79b786")
const BRICK := Color("bb594d")
const SUN := Color("e7aa4c")
const NIGHT := Color("172a3c")
const SKY := Color("5c9fb2")
const DANGER := Color("c64d4c")
const CREAM := Color("fff7df")
const TEAL := Color("2e8894")
const LILAC := Color("806598")
const OVERLAY := Color(0.05, 0.09, 0.13, 0.78)

static func panel_style(fill: Color = PAPER, border: Color = INK, radius: int = 10) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.06, 0.05, 0.04, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func card_style(fill: Color, accent: Color) -> StyleBoxFlat:
	var style := panel_style(fill, accent, 14)
	style.set_border_width(SIDE_LEFT, 6)
	style.shadow_size = 14
	return style

static func button_style(fill: Color, hover: Color, pressed: Color) -> Dictionary:

	return {"normal": panel_style(fill, INK, 8), "hover": panel_style(hover, INK, 8), "pressed": panel_style(pressed, INK, 8)}
