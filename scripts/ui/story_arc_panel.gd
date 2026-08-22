extends Panel

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")

signal choice_requested(arc_id: String, choice_id: String)

var arc_list: VBoxContainer
var choice_list: VBoxContainer
var title_label: Label
var summary_label: Label
var stage_label: Label
var feedback_label: Label
var selected_arc_id := ""
var _last_fingerprint := ""
var _snapshot: Dictionary = {}

func _ready() -> void:
	position = Vector2(250,92)
	size = Vector2(780,540)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.LILAC))
	_make_label("EyebrowLabel",Vector2(24,16),Vector2(730,20),12,VillageTheme.LILAC,"居民的選擇，會變成村落的故事")
	_make_label("TitleLabel",Vector2(24,40),Vector2(730,34),24,VillageTheme.INK,"故事線  /  LIVING STORIES")
	var divider := ColorRect.new()
	divider.position = Vector2(24,84)
	divider.size = Vector2(732,1)
	divider.color = VillageTheme.INK_SOFT
	divider.modulate = Color(1,1,1,0.25)
	add_child(divider)
	arc_list = VBoxContainer.new()
	arc_list.name = "ArcList"
	arc_list.position = Vector2(24,102)
	arc_list.size = Vector2(216,350)
	arc_list.add_theme_constant_override("separation",8)
	add_child(arc_list)
	var detail := Panel.new()
	detail.name = "DetailPanel"
	detail.position = Vector2(262,102)
	detail.size = Vector2(494,350)
	detail.add_theme_stylebox_override("panel",VillageTheme.panel_style(VillageTheme.PAPER,VillageTheme.INK_SOFT,8))
	add_child(detail)
	title_label = _make_label_on(detail,"StoryTitle",Vector2(18,16),Vector2(458,32),20,VillageTheme.INK,"")
	summary_label = _make_label_on(detail,"StorySummary",Vector2(18,54),Vector2(458,58),13,VillageTheme.INK_SOFT,"")
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_label = _make_label_on(detail,"StoryStage",Vector2(18,122),Vector2(458,92),14,VillageTheme.INK,"")
	stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_list = VBoxContainer.new()
	choice_list.name = "ChoiceList"
	choice_list.position = Vector2(18,222)
	choice_list.size = Vector2(458,112)
	choice_list.add_theme_constant_override("separation",8)
	detail.add_child(choice_list)
	feedback_label = _make_label_on(self,"FeedbackLabel",Vector2(24,464),Vector2(470,32),13,VillageTheme.INK_SOFT,"")
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := Button.new()
	close.name = "CloseButton"
	close.position = Vector2(588,468)
	close.size = Vector2(168,46)
	close.text = "關閉故事線  O"
	close.tooltip_text = "關閉故事線面板（O 或 Esc）"
	close.add_theme_font_size_override("font_size",14)
	_style_button(close,VillageTheme.LILAC)
	close.pressed.connect(func(): visible = false)
	add_child(close)
	visible = false

func refresh(snapshot: Dictionary) -> void:
	var fingerprint := JSON.stringify(snapshot)
	if fingerprint == _last_fingerprint: return
	_last_fingerprint = fingerprint
	_snapshot = snapshot.duplicate(true)
	var arcs: Dictionary = _snapshot.get("arcs",{})
	if selected_arc_id.is_empty() or not arcs.has(selected_arc_id):
		selected_arc_id = _first_interactive_arc(arcs)
	_clear_container(arc_list)
	for arc_id in arcs:
		var record: Dictionary = arcs[arc_id]
		var button := Button.new()
		button.name = "Arc_%s" % str(arc_id)
		button.custom_minimum_size = Vector2(216,48)
		button.text = _arc_button_text(record)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",12)
		_style_button(button,VillageTheme.MOSS if str(record.get("status","")) == "active" else VillageTheme.TEAL)
		button.disabled = str(record.get("status","")) == "locked"
		button.pressed.connect(func(): _select_arc(str(arc_id)))
		arc_list.add_child(button)
	_render_selected()

func _first_interactive_arc(arcs: Dictionary) -> String:
	for arc_id in arcs:
		if str(arcs[arc_id].get("status","")) == "active": return str(arc_id)
	for arc_id in arcs:
		if str(arcs[arc_id].get("status","")) == "completed": return str(arc_id)
	return str(arcs.keys()[0]) if not arcs.is_empty() else ""

func _select_arc(arc_id: String) -> void:
	selected_arc_id = arc_id
	_render_selected()

func _render_selected() -> void:
	_clear_container(choice_list)
	var record: Dictionary = _snapshot.get("arcs",{}).get(selected_arc_id,{})
	if record.is_empty():
		title_label.text = "尚未有故事線"
		summary_label.text = "與居民互動、接受任務或觸發世界事件，讓新的故事逐步浮現。"
		stage_label.text = ""
		return
	title_label.text = "%s  ·  %s" % [str(record.get("title",selected_arc_id)),_status_text(str(record.get("status","locked")))]
	summary_label.text = str(record.get("summary",""))
	var stage: Dictionary = record.get("stage",{})
	if str(record.get("status","")) == "active" and not stage.is_empty():
		stage_label.text = "%s\n%s" % [str(stage.get("title","目前階段")),str(stage.get("description",""))]
		for choice in stage.get("choices",[]):
			var button := Button.new()
			button.name = "Choice_%s" % str(choice.get("id",""))
			button.custom_minimum_size = Vector2(458,48)
			button.text = "%s\n%s" % [str(choice.get("label","選擇")),str(choice.get("description",""))]
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_font_size_override("font_size",12)
			_style_button(button,VillageTheme.SUN)
			button.pressed.connect(func(): choice_requested.emit(selected_arc_id,str(choice.get("id",""))))
			choice_list.add_child(button)
	elif str(record.get("status","")) == "completed":
		stage_label.text = "這條故事線已完成。\n你的選擇已經寫入村落回音與居民記憶。"
	else:
		stage_label.text = "故事尚未發生。\n繼續探索，讓世界條件自然出現。"

func show_feedback(message: String) -> void:
	feedback_label.text = message

func _arc_button_text(record: Dictionary) -> String:
	var status := str(record.get("status","locked"))
	var marker := "●" if status == "active" else ("✓" if status == "completed" else "○")
	return "%s  %s" % [marker,str(record.get("title","未命名故事"))]

func _status_text(status: String) -> String:
	return {"active":"進行中","completed":"已完成","locked":"尚未發生"}.get(status,"尚未發生")

func _clear_container(container: Node) -> void:
	for child in container.get_children(): child.queue_free()

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0)
	scale = Vector2(0.97,0.97)
	pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self,"modulate",Color.WHITE,0.18)
	tween.tween_property(self,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _make_label(node_name: String, at: Vector2, extent: Vector2, font_size: int, color: Color, text_value: String) -> Label:
	return _make_label_on(self,node_name,at,extent,font_size,color,text_value)

func _make_label_on(parent: Control, node_name: String, at: Vector2, extent: Vector2, font_size: int, color: Color, text_value: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = extent
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _style_button(button: Button, accent: Color) -> void:
	var styles := VillageTheme.button_style(accent,accent.lightened(0.12),accent.darkened(0.12))
	button.add_theme_stylebox_override("normal",styles["normal"])
	button.add_theme_stylebox_override("hover",styles["hover"])
	button.add_theme_stylebox_override("pressed",styles["pressed"])
	button.add_theme_stylebox_override("disabled",VillageTheme.panel_style(VillageTheme.PAPER_DARK,VillageTheme.INK_SOFT,6))
	# Keep the amber choice buttons readable in both normal and hover states.
	# Godot's default Button font color is light, which fails contrast on SUN.
	button.add_theme_color_override("font_color",VillageTheme.INK)
	button.add_theme_color_override("font_hover_color",VillageTheme.INK)
	button.add_theme_color_override("font_pressed_color",VillageTheme.INK)
	button.add_theme_color_override("font_disabled_color",VillageTheme.INK_SOFT)
