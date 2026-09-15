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
const FOCUS := Color("f7d88a")
const OVERLAY := Color(0.05, 0.09, 0.13, 0.78)
const SURFACE_NIGHT := Color("102b3a")
const SURFACE_NIGHT_RAISED := Color("193c50")
const BORDER_NIGHT := Color("4f6b7b")
const SPACE_UNIT := 8.0

static func panel_style(fill: Color = PAPER, border: Color = INK, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(clampi(radius, 8, 18))
	style.shadow_color = Color(0.04, 0.05, 0.08, 0.34)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func card_style(fill: Color, accent: Color) -> StyleBoxFlat:
	var style := panel_style(fill, accent, 16)
	style.set_border_width(SIDE_LEFT, 5)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	return style

static func button_style(fill: Color, hover: Color, pressed: Color) -> Dictionary:
	var focus := panel_style(hover, FOCUS, 12)
	focus.set_border_width_all(3)
	return {"normal": panel_style(fill, INK, 12), "hover": panel_style(hover, INK, 12), "pressed": panel_style(pressed, INK, 12), "focus": focus}

static func configure_label(label: Label, wrap: bool = false) -> Label:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func configure_button(button: Button) -> Button:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(maxf(button.custom_minimum_size.x, 44.0), maxf(button.custom_minimum_size.y, 44.0))
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return button
