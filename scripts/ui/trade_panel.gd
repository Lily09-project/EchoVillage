extends Panel

signal buy_requested(item_id: String)
signal sell_requested(item_id: String)

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
var catalog: Array = []
var merchant_label: Label
var item_selector: OptionButton
var detail_label: Label
var buy_button: Button
var sell_button: Button

func _ready() -> void:
	position = Vector2(370,118)
	size = Vector2(540,470)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.SUN))
	make_label(Vector2(24,18),Vector2(490,36),24,VillageTheme.INK,"交易櫃台  /  MARKET")
	merchant_label = make_label(Vector2(24,58),Vector2(490,26),14,VillageTheme.INK_SOFT,"")
	make_label(Vector2(24,104),Vector2(490,22),13,VillageTheme.INK_SOFT,"選擇要交易的物品")
	item_selector = OptionButton.new()
	item_selector.name = "ItemSelector"
	item_selector.position = Vector2(24,132)
	item_selector.size = Vector2(492,48)
	item_selector.add_theme_font_size_override("font_size",15)
	add_child(item_selector)
	item_selector.item_selected.connect(func(_index: int): refresh_selection())
	detail_label = make_label(Vector2(24,198),Vector2(492,120),15,VillageTheme.INK_SOFT,"")
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_button = make_button("BuyButton",Vector2(24,332),Vector2(230,52),"買入 1 個",VillageTheme.MOSS)
	sell_button = make_button("SellButton",Vector2(286,332),Vector2(230,52),"出售 1 個",VillageTheme.SUN)
	buy_button.pressed.connect(_request_buy)
	sell_button.pressed.connect(_request_sell)
	var close := make_button("CloseButton",Vector2(326,404),Vector2(190,44),"關閉交易  Esc",VillageTheme.LILAC)
	close.pressed.connect(func(): visible = false)
	visible = false

func _request_buy() -> void:
	if not catalog.is_empty(): buy_requested.emit(str(catalog[item_selector.selected]["id"]))

func _request_sell() -> void:
	if not catalog.is_empty(): sell_requested.emit(str(catalog[item_selector.selected]["id"]))

func set_catalog(entries: Array, merchant_name: String, player_coin: int) -> void:
	var previous_id := ""
	if not catalog.is_empty() and item_selector.selected >= 0: previous_id = str(catalog[item_selector.selected].get("id",""))
	catalog = entries.duplicate(true)
	merchant_label.text = "%s的交易桌  ·  你持有 %d 枚硬幣" % [merchant_name,player_coin]
	item_selector.clear()
	var selected_index := 0
	for index in catalog.size():
		var entry: Dictionary = catalog[index]
		item_selector.add_item("%s  ·  %s" % [str(entry["display_name"]),str(entry["category"])])
		if str(entry["id"]) == previous_id: selected_index = index
	if not catalog.is_empty(): item_selector.select(selected_index)
	refresh_selection()

func refresh_selection() -> void:
	if catalog.is_empty():
		detail_label.text = "目前沒有可交易的物品。"
		buy_button.disabled = true
		sell_button.disabled = true
		return
	var entry: Dictionary = catalog[clampi(item_selector.selected,0,catalog.size() - 1)]
	detail_label.text = "%s\n\n商人庫存：%d　你的背包：%d\n買入價：%d 枚　出售價：%d 枚" % [str(entry["display_name"]),int(entry["merchant_count"]),int(entry["player_count"]),int(entry["buy_price"]),int(entry["sell_price"])]
	buy_button.disabled = not bool(entry["can_buy"])
	sell_button.disabled = not bool(entry["can_sell"])
	buy_button.tooltip_text = "庫存與硬幣足夠時可買入" if not buy_button.disabled else "商人缺貨或你的硬幣不足"
	sell_button.tooltip_text = "出售後立即取得硬幣" if not sell_button.disabled else "你沒有此物品，或商人硬幣不足"

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
	var label := Label.new()
	label.position = at
	label.size = extent
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	add_child(label)
	return label

func make_button(node_name: String, at: Vector2, extent: Vector2, text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = at
	button.size = extent
	button.text = text_value
	button.add_theme_font_size_override("font_size",14)
	var styles := VillageTheme.button_style(color,color.lightened(0.12),color.darkened(0.12))
	button.add_theme_stylebox_override("normal",styles["normal"])
	button.add_theme_stylebox_override("hover",styles["hover"])
	button.add_theme_stylebox_override("pressed",styles["pressed"])
	button.add_theme_stylebox_override("disabled",VillageTheme.panel_style(VillageTheme.PAPER_DARK.lightened(0.08),VillageTheme.PAPER_DARK,8))
	button.add_theme_color_override("font_color",VillageTheme.INK)
	button.add_theme_color_override("font_disabled_color",VillageTheme.INK_SOFT)
	add_child(button)
	return button
