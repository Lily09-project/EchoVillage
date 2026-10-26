extends Panel

var _visibility_tween: Tween

## The village journal: a short story of each day, written from that day's
## causal events and rumour retellings. Older days can be revisited.

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")

var day := 1
var latest_day := 1
var day_label: Label
var story_label: Label
var source_label: Label
var previous_button: Button
var next_button: Button

func _ready() -> void:
	visibility_changed.connect(_on_panel_visibility_changed)
	position = Vector2(300,112)
	size = Vector2(680,480)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.SUN))
	_label("EyebrowLabel",Vector2(26,16),Vector2(620,18),12,VillageTheme.BRICK,"每天結束時，村子會把發生的事寫成故事")
	_label("TitleLabel",Vector2(26,38),Vector2(620,32),23,VillageTheme.INK,"村落日誌  /  VILLAGE JOURNAL")
	day_label = _label("DayLabel",Vector2(26,80),Vector2(620,26),17,VillageTheme.MOSS,"")
	story_label = _label("StoryLabel",Vector2(26,114),Vector2(628,250),15,VillageTheme.INK)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label = _label("SourceLabel",Vector2(26,372),Vector2(628,22),12,VillageTheme.INK_SOFT,"")
	previous_button = _button("PreviousDayButton",Vector2(26,410),Vector2(120,46),"‹ 前一天",VillageTheme.TEAL)
	previous_button.pressed.connect(func(): show_day(day - 1))
	next_button = _button("NextDayButton",Vector2(154,410),Vector2(120,46),"後一天 ›",VillageTheme.TEAL)
	next_button.pressed.connect(func(): show_day(day + 1))
	var close := _button("CloseButton",Vector2(490,410),Vector2(164,46),"關閉日誌  V",VillageTheme.SUN)
	close.pressed.connect(func(): visible = false)
	visible = false

func open_today(current_day: int) -> void:
	latest_day = maxi(1,current_day)
	show_day(latest_day)

func show_day(target_day: int) -> void:
	day = clampi(target_day,1,latest_day)
	var entry: Dictionary = GameManager.journal_for_day(day)
	day_label.text = "第 %d 天%s" % [day,"（今天，仍在書寫中）" if day == latest_day else ""]
	story_label.text = str(entry.get("text",""))
	var cited: Array = entry.get("cited",[])
	source_label.text = "這一天沒有可引用的事件。" if bool(entry.get("empty",false)) else "根據當天 %d 件事件與傳聞寫成；完整紀錄見「今日回音」（L）。" % cited.size()
	previous_button.disabled = day <= 1
	next_button.disabled = day >= latest_day

func _label(node_name: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, text_value: String = "") -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = label_size
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	VillageTheme.configure_label(label)
	add_child(label)
	return label

func _button(node_name: String, at: Vector2, button_size: Vector2, text_value: String, fill: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = at
	button.size = button_size
	button.text = text_value
	button.add_theme_font_size_override("font_size",14)
	VillageTheme.configure_button(button)
	var styles := VillageTheme.button_style(fill,fill.lightened(0.12),fill.darkened(0.12))
	for key in styles: button.add_theme_stylebox_override(key,styles[key])
	var ink := VillageTheme.CREAM if fill.get_luminance() < 0.45 else VillageTheme.INK
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		button.add_theme_color_override(state,ink)
	add_child(button)
	return button

func _stop_visibility_motion() -> void:
	if _visibility_tween != null and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null
	modulate = Color.WHITE
	scale = Vector2.ONE

func _on_panel_visibility_changed() -> void:
	if not visible: _stop_visibility_motion()

func _exit_tree() -> void:
	_stop_visibility_motion()

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	_stop_visibility_motion()
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0)
	_visibility_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_visibility_tween.tween_property(self,"modulate",Color.WHITE,0.18)
