extends Panel

signal travel_requested(location_id: String)
const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
var status_label: Label
var village_button: Button
var forest_button: Button

func _ready() -> void:
	position = Vector2(390,150)
	size = Vector2(500,300)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.TEAL))
	var title := make_label(Vector2(24,18),Vector2(360,34),22,VillageTheme.INK,"世界地圖  /  WORLD MAP")
	status_label = make_label(Vector2(24,58),Vector2(452,54),14,VillageTheme.INK_SOFT,"")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	village_button = make_button(Vector2(24,128),Vector2(210,56),"回音村廣場")
	forest_button = make_button(Vector2(266,128),Vector2(210,56),"低語森林邊緣")
	village_button.pressed.connect(func(): travel_requested.emit("village_square"))
	forest_button.pressed.connect(func(): travel_requested.emit("forest_edge"))
	var close := make_button(Vector2(326,226),Vector2(150,48),"關閉地圖  M")
	close.pressed.connect(func(): visible = false)
	visible = false

func set_locations(definitions: Dictionary, current_id: String, discovered: Array) -> void:
	var current_name := str(definitions.get(current_id,{}).get("display_name",current_id))
	status_label.text = "目前位置：%s\n選擇相鄰地點旅行；新地點會永久記錄於探索進度。" % current_name
	village_button.text = "回音村廣場" + ("  ·  目前位置" if current_id == "village_square" else "")
	forest_button.text = "低語森林邊緣" + ("  ·  目前位置" if current_id == "forest_edge" else ("  ·  已探索" if "forest_edge" in discovered else "  ·  未探索"))
	village_button.disabled = current_id == "village_square"
	forest_button.disabled = current_id == "forest_edge"

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0)
	scale = Vector2(0.97,0.97)
	pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self,"modulate",Color.WHITE,0.18)
	tween.tween_property(self,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func make_label(at: Vector2, extent: Vector2, font_size: int, color: Color, text_value: String) -> Label:
	var label := Label.new(); label.position = at; label.size = extent; label.text = text_value
	label.add_theme_font_size_override("font_size",font_size); label.add_theme_color_override("font_color",color); add_child(label); return label

func make_button(at: Vector2, extent: Vector2, text_value: String) -> Button:
	var button := Button.new(); button.position = at; button.size = extent; button.text = text_value; button.tooltip_text = text_value
	button.add_theme_font_size_override("font_size",13)
	var styles := VillageTheme.button_style(VillageTheme.MOSS_LIGHT,VillageTheme.MOSS_LIGHT.lightened(0.12),VillageTheme.MOSS_LIGHT.darkened(0.12))
	button.add_theme_stylebox_override("normal",styles["normal"]); button.add_theme_stylebox_override("hover",styles["hover"]); button.add_theme_stylebox_override("pressed",styles["pressed"])
	add_child(button); return button
