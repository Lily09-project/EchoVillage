extends Panel

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
var title_label: Label
var objective_label: Label

func _ready() -> void:
	position = Vector2(350,108)
	size = Vector2(420,96)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.SUN))
	title_label = Label.new()
	title_label.position = Vector2(16,10)
	title_label.size = Vector2(388,24)
	title_label.add_theme_font_size_override("font_size",15)
	title_label.add_theme_color_override("font_color",VillageTheme.INK)
	add_child(title_label)
	objective_label = Label.new()
	objective_label.position = Vector2(16,38)
	objective_label.size = Vector2(388,48)
	objective_label.add_theme_font_size_override("font_size",13)
	objective_label.add_theme_color_override("font_color",VillageTheme.INK_SOFT)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(objective_label)
	refresh([])

func refresh(entries: Array) -> void:
	if entries.is_empty():
		title_label.text = "旅途手札  /  QUEST TRACKER"
		objective_label.text = "向艾莉絲詢問村莊近況，開啟第一段旅程。  [K] 任務日誌"
		return
	var entry: Dictionary = entries[0]
	var objective: Dictionary = entry.get("objective",{})
	title_label.text = "%s  ·  第 %d 步" % [str(entry.get("title","任務")),int(entry.get("objective_index",0)) + 1]
	objective_label.text = "%s\n[K] 查看詳情  ·  [M] 世界地圖" % str(objective.get("description","目標已更新"))
