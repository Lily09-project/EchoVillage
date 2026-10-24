extends Panel

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
signal accept_requested(quest_id: String)
var body_label: Label
var offers_box: VBoxContainer
var offers_title: Label

func _ready() -> void:
	position = Vector2(330,92)
	size = Vector2(620,540)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.LILAC))
	var title := Label.new(); title.position = Vector2(24,18); title.size = Vector2(530,34); title.text = "任務日誌  /  QUEST LOG"
	title.add_theme_font_size_override("font_size",22); title.add_theme_color_override("font_color",VillageTheme.INK); VillageTheme.configure_label(title); add_child(title)
	body_label = Label.new(); body_label.position = Vector2(24,64); body_label.size = Vector2(572,200)
	body_label.add_theme_font_size_override("font_size",14); body_label.add_theme_color_override("font_color",VillageTheme.INK_SOFT); VillageTheme.configure_label(body_label,true); add_child(body_label)
	offers_title = Label.new(); offers_title.name = "OffersTitle"; offers_title.position = Vector2(24,276); offers_title.size = Vector2(572,24); offers_title.text = "村民委託  /  COMMISSIONS"
	offers_title.add_theme_font_size_override("font_size",16); offers_title.add_theme_color_override("font_color",VillageTheme.INK); VillageTheme.configure_label(offers_title); add_child(offers_title)
	offers_box = VBoxContainer.new(); offers_box.name = "OffersBox"; offers_box.position = Vector2(24,304); offers_box.size = Vector2(572,164); offers_box.add_theme_constant_override("separation",6); add_child(offers_box)
	var close := Button.new(); close.position = Vector2(432,476); close.size = Vector2(164,48); close.text = "關閉日誌  K"; close.tooltip_text = "關閉任務日誌"
	VillageTheme.configure_button(close)
	var styles := VillageTheme.button_style(VillageTheme.LILAC,VillageTheme.LILAC.lightened(0.12),VillageTheme.LILAC.darkened(0.12))
	close.add_theme_stylebox_override("normal",styles["normal"]); close.add_theme_stylebox_override("hover",styles["hover"]); close.add_theme_stylebox_override("pressed",styles["pressed"]); close.add_theme_stylebox_override("focus",styles["focus"]); close.pressed.connect(func(): visible = false); add_child(close)
	visible = false

func refresh(entries: Array, completed: Array, offers: Array = []) -> void:
	_refresh_offers(offers)
	var lines: Array[String] = []
	if entries.is_empty(): lines.append("目前沒有進行中的任務。\n\n靠近艾莉絲並選擇「詢問」，她會告訴你森林邊緣的委託。")
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var objective: Dictionary = entry.get("objective",{})
		lines.append("【%s】\n%s\n目前目標：%s\n獎勵：%s" % [str(entry.get("title","任務")),str(entry.get("description","")),str(objective.get("description","")),format_rewards(entry.get("rewards",{}))])
	if not completed.is_empty(): lines.append("\n已完成：%s" % format_completed(completed))
	body_label.text = "\n\n".join(lines)

## Commissions generated from the simulation, each with an accept button.
func _refresh_offers(offers: Array) -> void:
	if offers_box == null: return
	for child in offers_box.get_children(): child.queue_free()
	if offers.is_empty():
		var empty := Label.new(); empty.name = "NoOffers"; empty.custom_minimum_size = Vector2(572,40)
		empty.text = "目前沒有居民需要幫忙。流言、飢餓與爭執都可能帶來新的委託。"
		empty.add_theme_font_size_override("font_size",13); empty.add_theme_color_override("font_color",VillageTheme.INK_SOFT); VillageTheme.configure_label(empty,true); offers_box.add_child(empty)
		return
	for offer_value in offers:
		var offer: Dictionary = offer_value
		var row := HBoxContainer.new(); row.name = "Offer_%s" % str(offer.get("id","")); row.custom_minimum_size = Vector2(572,48); row.add_theme_constant_override("separation",10)
		var text := Label.new(); text.custom_minimum_size = Vector2(430,48); text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text = "%s｜%s" % [str(offer.get("title","委託")),format_rewards(offer.get("rewards",{}))]
		text.tooltip_text = str(offer.get("description",""))
		text.add_theme_font_size_override("font_size",13); text.add_theme_color_override("font_color",VillageTheme.INK); VillageTheme.configure_label(text,true); row.add_child(text)
		var accept := Button.new(); accept.name = "AcceptButton"; accept.text = "接受"; accept.custom_minimum_size = Vector2(110,44)
		accept.tooltip_text = str(offer.get("description",""))
		VillageTheme.configure_button(accept)
		var styles := VillageTheme.button_style(VillageTheme.MOSS,VillageTheme.MOSS.lightened(0.12),VillageTheme.MOSS.darkened(0.12))
		for key in styles: accept.add_theme_stylebox_override(key,styles[key])
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: accept.add_theme_color_override(state,VillageTheme.CREAM)
		var quest_id := str(offer.get("id",""))
		accept.pressed.connect(func(): accept_requested.emit(quest_id))
		row.add_child(accept)
		offers_box.add_child(row)

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
		titles.append(str(definition.get("title","村民委託" if key.begins_with("emergent_") else key)))
	return "、".join(titles)

func set_visible_with_motion(value: bool, motion_enabled: bool) -> void:
	visible = value
	if not value or not motion_enabled: return
	modulate = Color(1,1,1,0); scale = Vector2(0.97,0.97); pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self,"modulate",Color.WHITE,0.18)
	tween.tween_property(self,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
