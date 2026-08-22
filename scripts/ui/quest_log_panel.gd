extends Panel

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
var body_label: Label

func _ready() -> void:
	position = Vector2(350,130)
	size = Vector2(580,410)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.LILAC))
	var title := Label.new(); title.position = Vector2(24,18); title.size = Vector2(530,34); title.text = "任務日誌  /  QUEST LOG"
	title.add_theme_font_size_override("font_size",22); title.add_theme_color_override("font_color",VillageTheme.INK); add_child(title)
	body_label = Label.new(); body_label.position = Vector2(24,64); body_label.size = Vector2(532,270)
	body_label.add_theme_font_size_override("font_size",14); body_label.add_theme_color_override("font_color",VillageTheme.INK_SOFT); body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(body_label)
	var close := Button.new(); close.position = Vector2(392,344); close.size = Vector2(164,48); close.text = "關閉日誌  K"; close.tooltip_text = "關閉任務日誌"
	var styles := VillageTheme.button_style(VillageTheme.LILAC,VillageTheme.LILAC.lightened(0.12),VillageTheme.LILAC.darkened(0.12))
	close.add_theme_stylebox_override("normal",styles["normal"]); close.add_theme_stylebox_override("hover",styles["hover"]); close.add_theme_stylebox_override("pressed",styles["pressed"]); close.pressed.connect(func(): visible = false); add_child(close)
	visible = false

func refresh(entries: Array, completed: Array) -> void:
	var lines: Array[String] = []
	if entries.is_empty(): lines.append("目前沒有進行中的任務。\n\n靠近艾莉絲並選擇「詢問」，她會告訴你森林邊緣的委託。")
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var objective: Dictionary = entry.get("objective",{})
		lines.append("【%s】\n%s\n目前目標：%s\n獎勵：%s" % [str(entry.get("title","任務")),str(entry.get("description","")),str(objective.get("description","")),format_rewards(entry.get("rewards",{}))])
	if not completed.is_empty(): lines.append("\n已完成：%s" % format_completed(completed))
	body_label.text = "\n\n".join(lines)

func format_rewards(rewards: Dictionary) -> String:
	var labels: Array[String] = []
	for reward_id in rewards:
		var key: String = str(reward_id)
		var display_name: String = str({"coin":"金幣","renown":"聲望"}.get(key,""))
		if display_name == "" and GameManager.item_defs.has(key):
			display_name = str(GameManager.item_defs[key].get("display_name",key))
		if display_name == "": display_name = key
		labels.append("%s +%d" % [display_name,int(rewards[reward_id])])
	return "、".join(labels) if not labels.is_empty() else "無"

func format_completed(completed: Array) -> String:
	var titles: Array[String] = []
	for quest_id in completed:
		var key: String = str(quest_id)
		var definition: Dictionary = GameManager.quest_defs.get(key,{})
		titles.append(str(definition.get("title",key)))
	return "、".join(titles)

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0); scale = Vector2(0.97,0.97); pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self,"modulate",Color.WHITE,0.18)
	tween.tween_property(self,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
