extends Panel

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
var summary_label: Label
var achievements_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
	position = Vector2(320,120)
	size = Vector2(640,480)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.MOSS))
	_make_label("EyebrowLabel",Vector2(26,16),Vector2(588,20),12,VillageTheme.MOSS,"每個選擇，都在塑造你與村落的關係")
	_make_label("TitleLabel",Vector2(26,40),Vector2(588,34),24,VillageTheme.INK,"村落手札  /  VILLAGE JOURNAL")
	summary_label = _make_label("SummaryLabel",Vector2(26,82),Vector2(588,58),14,VillageTheme.INK_SOFT,"")
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_bar = ProgressBar.new()
	progress_bar.name = "ReputationProgress"
	progress_bar.position = Vector2(26,143)
	progress_bar.size = Vector2(588,18)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background",VillageTheme.panel_style(VillageTheme.PAPER_DARK,VillageTheme.INK_SOFT,6))
	progress_bar.add_theme_stylebox_override("fill",VillageTheme.panel_style(VillageTheme.MOSS_LIGHT,VillageTheme.MOSS,6))
	add_child(progress_bar)
	_make_label("SectionLabel",Vector2(26,178),Vector2(588,24),16,VillageTheme.INK,"成就里程碑")
	achievements_label = _make_label("AchievementsLabel",Vector2(26,208),Vector2(588,202),13,VillageTheme.INK_SOFT,"")
	achievements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := Button.new()
	close.name = "CloseButton"
	close.position = Vector2(448,418)
	close.size = Vector2(166,46)
	close.text = "關閉手札  P"
	close.tooltip_text = "關閉村落手札（P 或 Esc）"
	close.add_theme_font_size_override("font_size",14)
	var styles := VillageTheme.button_style(VillageTheme.MOSS,VillageTheme.MOSS.lightened(0.12),VillageTheme.MOSS.darkened(0.12))
	close.add_theme_stylebox_override("normal",styles["normal"])
	close.add_theme_stylebox_override("hover",styles["hover"])
	close.add_theme_stylebox_override("pressed",styles["pressed"])
	close.pressed.connect(func(): visible = false)
	add_child(close)
	visible = false

func refresh(snapshot: Dictionary) -> void:
	var tier: Dictionary = snapshot.get("tier",{})
	var renown := int(snapshot.get("renown",0))
	var next_minimum := int(tier.get("next_minimum",renown))
	var is_final := int(tier.get("index",0)) >= 4
	summary_label.text = "聲望 %d  ·  稱號：%s\n%s" % [renown,str(tier.get("title","陌生旅人")),"已達最高稱號" if is_final else "下一稱號需要 %d 聲望" % next_minimum]
	progress_bar.value = float(snapshot.get("next_tier_progress",0.0)) * 100.0
	var lines: Array[String] = []
	for value in snapshot.get("achievements",[]):
		var achievement: Dictionary = value
		var status := "已完成" if bool(achievement.get("unlocked",false)) else "未完成"
		lines.append("[%s]  %s — %s" % [status,str(achievement.get("title","未命名")),str(achievement.get("description",""))])
	achievements_label.text = "\n\n".join(lines)

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
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = extent
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label
