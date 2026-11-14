extends Panel

signal source_requested(actor: String, rumor_id: String)

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
var source_picker: OptionButton
var source_button: Button
var sources: Array = []

func _ready() -> void:
	position = Vector2(300,112)
	size = Vector2(680,480)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.SUN))
	_label("EyebrowLabel",Vector2(26,16),Vector2(620,18),12,VillageTheme.BRICK,"每天結束時，村子會把發生的事寫成故事")
	_label("TitleLabel",Vector2(26,38),Vector2(620,32),23,VillageTheme.INK,"村落日誌  /  VILLAGE JOURNAL")
	day_label = _label("DayLabel",Vector2(26,80),Vector2(620,26),17,VillageTheme.MOSS,"")
	story_label = _label("StoryLabel",Vector2(26,114),Vector2(628,154),15,VillageTheme.INK)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label = _label("SourceLabel",Vector2(26,327),Vector2(628,66),12,VillageTheme.INK_SOFT,"")
	source_picker = OptionButton.new()
	source_picker.name = "SourcePicker"
	source_picker.position = Vector2(26,273)
	source_picker.size = Vector2(450,44)
	source_picker.clip_text = true
	source_picker.item_selected.connect(func(_index: int): _show_source())
	add_child(source_picker)
	source_button = _button("SourceButton",Vector2(490,273),Vector2(164,44),"查看來源",VillageTheme.TEAL)
	source_button.pressed.connect(_open_source)
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
	day = clampi(target_day,earliest_day(),latest_day)
	var entry: Dictionary = GameManager.journal_for_day(day)
	day_label.text = "第 %d 天%s" % [day,"（今天，仍在書寫中）" if day == latest_day else ""]
	story_label.text = str(entry.get("text",""))
	var raw_sources = entry.get("sources",[])
	sources = raw_sources.filter(func(item): return item is Dictionary) if raw_sources is Array else []
	source_picker.clear()
	for source in sources:
		var line := str(source.get("text",""))
		source_picker.add_item(line.left(26) + ("…" if line.length() > 26 else ""))
	source_picker.visible = not sources.is_empty()
	source_button.visible = source_picker.visible
	if source_picker.visible: source_picker.select(0)
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_show_source()
	if sources.is_empty():
		source_label.text = "這一天沒有可引用的事件。" if bool(entry.get("empty",false)) else "此日誌只有摘要，可查看今日回音。"
	previous_button.disabled = day <= earliest_day()
	next_button.disabled = day >= latest_day

func _source() -> Dictionary:
	var index := source_picker.selected
	return sources[index] if index >= 0 and index < sources.size() else {}

func _actor(source: Dictionary) -> String:
	var actors = source.get("actors",[])
	if actors is Array:
		for actor in actors:
			if GameManager.npcs.has(str(actor)): return str(actor)
	return ""

func _show_source() -> void:
	var source := _source()
	var names: Dictionary = GameManager.actor_names()
	var participants := PackedStringArray()
	var actors = source.get("actors",[])
	if actors is Array:
		for actor in actors:
			if names.has(str(actor)): participants.append(str(names[str(actor)]))
	source_label.text = str(source.get("time",""))
	if not participants.is_empty(): source_label.text += "  " + "、".join(participants)
	source_button.disabled = _actor(source).is_empty() and str(source.get("rumor_id","")).is_empty()

func _open_source() -> void:
	var source := _source()
	source_requested.emit(_actor(source),str(source.get("rumor_id","")))

## Only the last MAX_JOURNAL_DAYS finished days are archived; older days can no
## longer be written from events, so paging stops there instead of showing an
## empty day.
func earliest_day() -> int:
	return maxi(1,latest_day - int(GameManager.MAX_JOURNAL_DAYS))

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

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0)
	var tween := create_tween()
	tween.tween_property(self,"modulate",Color.WHITE,0.18)
