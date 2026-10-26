extends Panel

var _visibility_tween: Tween

## Rumour network: who heard which story, from whom, and how much of it is
## still true. The graph is mirrored by a text chain for screen readers and
## colour-blind players; distorted retellings are marked by text and dashes,
## never by colour alone.

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
const MAX_LISTED := 6
const NODE_RADIUS := 26.0

var rumors: Array = []
var names: Dictionary = {}
var selected_rumor := ""
var colorblind := false
var list_box: VBoxContainer
var graph: Control
var chain_label: Label
var legend_label: Label
var empty_label: Label

func _ready() -> void:
	visibility_changed.connect(_on_panel_visibility_changed)
	position = Vector2(220,96)
	size = Vector2(840,528)
	add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.TEAL))
	_label("EyebrowLabel",Vector2(24,14),Vector2(600,18),12,VillageTheme.TEAL,"每一次轉述都會變得更模糊、也更戲劇化")
	_label("TitleLabel",Vector2(24,34),Vector2(600,32),22,VillageTheme.INK,"傳聞網路  /  RUMOR NETWORK")
	list_box = VBoxContainer.new()
	list_box.name = "RumorList"
	list_box.position = Vector2(24,78)
	list_box.size = Vector2(300,370)
	list_box.add_theme_constant_override("separation",8)
	add_child(list_box)
	graph = Control.new()
	graph.name = "NetworkGraph"
	graph.position = Vector2(340,78)
	graph.size = Vector2(476,250)
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph.draw.connect(_draw_graph)
	add_child(graph)
	legend_label = _label("LegendLabel",Vector2(340,62),Vector2(476,16),11,VillageTheme.INK_SOFT,"")
	chain_label = _label("ChainLabel",Vector2(340,336),Vector2(476,124),12,VillageTheme.INK_SOFT,"")
	chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label = _label("EmptyLabel",Vector2(24,90),Vector2(300,120),13,VillageTheme.INK_SOFT,"村裡還沒有傳聞。\n\n試著在居民面前做點什麼——善意或過錯都會被記住，並在夜裡的閒聊中傳開。")
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close := Button.new()
	close.name = "CloseButton"
	close.position = Vector2(652,466)
	close.size = Vector2(164,46)
	close.text = "關閉網路  U"
	close.tooltip_text = "關閉傳聞網路（U 或 Esc）"
	close.add_theme_font_size_override("font_size",14)
	_style(close,VillageTheme.TEAL)
	close.pressed.connect(func(): visible = false)
	add_child(close)
	visible = false

func refresh(snapshot: Array, actor_names: Dictionary, use_colorblind: bool = false) -> void:
	rumors = snapshot
	names = actor_names
	colorblind = use_colorblind
	if selected_rumor.is_empty() or not _has(selected_rumor):
		selected_rumor = str(rumors[0]["id"]) if not rumors.is_empty() else ""
	for child in list_box.get_children(): child.queue_free()
	empty_label.visible = rumors.is_empty()
	legend_label.text = "" if rumors.is_empty() else "實線＝如實轉述　虛線＝走樣　圓點越偏%s＝越不可信" % ("橘" if colorblind else "紅")
	for rumor in rumors.slice(0,MAX_LISTED):
		var button := Button.new()
		button.name = "Rumor_%s" % str(rumor["id"])
		button.custom_minimum_size = Vector2(300,52)
		button.toggle_mode = true
		button.button_pressed = str(rumor["id"]) == selected_rumor
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",12)
		var status := "已澄清" if bool(rumor.get("debunked",false)) else "%d 人知道" % rumor.get("holders",[]).size()
		button.text = "%s\n%s · %s" % [_shorten(str(rumor["original"]),20),str(names.get(str(rumor["origin_npc"]),rumor["origin_npc"])) + " 目擊",status]
		button.tooltip_text = str(rumor["original"])
		_style(button,VillageTheme.PAPER_DARK if str(rumor["id"]) != selected_rumor else VillageTheme.SUN)
		var rumor_id := str(rumor["id"])
		button.pressed.connect(func(): select(rumor_id))
		list_box.add_child(button)
	_update_chain()
	graph.queue_redraw()

func select(rumor_id: String) -> void:
	selected_rumor = rumor_id
	refresh(rumors,names,colorblind)

func selected() -> Dictionary:
	for rumor in rumors:
		if str(rumor["id"]) == selected_rumor: return rumor
	return {}

func chain_text() -> String:
	return chain_label.text

func _update_chain() -> void:
	var rumor := selected()
	if rumor.is_empty():
		chain_label.text = ""
		return
	var lines: Array[String] = ["原始事件：%s" % str(rumor["original"])]
	var holders: Array = rumor.get("holders",[])
	for holder in holders:
		if str(holder["heard_from"]).is_empty(): continue
		var marker := "（走樣 ×%d）" % int(holder["version"]) if int(holder["version"]) > 0 else ""
		lines.append("%s ← %s｜強度 %d、可信度 %d%%%s：「%s」" % [str(holder["name"]),str(names.get(str(holder["heard_from"]),holder["heard_from"])),int(holder["strength"]),int(round(float(holder["credibility"]) * 100.0)),marker,str(holder["text"])])
	if bool(rumor.get("debunked",false)): lines.append("這則傳聞已被澄清，不會再傳下去。")
	elif lines.size() == 1: lines.append("目前只有目擊者知道；等居民閒聊時才會傳開。")
	chain_label.text = "\n".join(lines)

func _node_positions() -> Dictionary:
	var ids: Array = names.keys().filter(func(id): return id != "player")
	ids.sort()
	var center := graph.size * 0.5
	var radius := minf(graph.size.x,graph.size.y) * 0.5 - NODE_RADIUS - 6.0
	var result := {}
	for index in ids.size():
		var angle := -PI / 2.0 + TAU * float(index) / float(maxi(ids.size(),1))
		result[ids[index]] = center + Vector2(cos(angle),sin(angle)) * Vector2(radius * 1.5,radius)
	return result

func _draw_graph() -> void:
	var positions := _node_positions()
	var rumor := selected()
	var holders := {}
	for holder in rumor.get("holders",[]): holders[str(holder["id"])] = holder
	var positive := VillageTheme.positive_color(colorblind)
	var negative := VillageTheme.negative_color(colorblind)
	var font := get_theme_default_font()
	for transmission in rumor.get("transmissions",[]):
		var from_id := str(transmission["from"])
		var to_id := str(transmission["to"])
		if not positions.has(from_id) or not positions.has(to_id): continue
		var a: Vector2 = positions[from_id]
		var b: Vector2 = positions[to_id]
		var direction := (b - a).normalized()
		var start := a + direction * NODE_RADIUS
		var end := b - direction * (NODE_RADIUS + 4.0)
		var width := 1.5 + float(transmission["strength"]) / 25.0
		var color := negative if bool(transmission["distorted"]) else VillageTheme.INK_SOFT
		if bool(transmission["distorted"]): graph.draw_dashed_line(start,end,color,width,8.0)
		else: graph.draw_line(start,end,color,width,true)
		var left := end - direction * 12.0 + direction.orthogonal() * 6.0
		var right := end - direction * 12.0 - direction.orthogonal() * 6.0
		graph.draw_colored_polygon(PackedVector2Array([end,left,right]),color)
	for npc_id in positions:
		var at: Vector2 = positions[npc_id]
		var holder: Dictionary = holders.get(npc_id,{})
		var fill := VillageTheme.PAPER_DARK
		if not holder.is_empty(): fill = positive.lerp(negative,1.0 - float(holder["credibility"]))
		graph.draw_circle(at,NODE_RADIUS,fill)
		graph.draw_arc(at,NODE_RADIUS,0.0,TAU,32,VillageTheme.INK,2.0 if not holder.is_empty() else 1.0)
		if str(rumor.get("origin_npc","")) == npc_id:
			graph.draw_string(font,at + Vector2(-14,5),"目擊",HORIZONTAL_ALIGNMENT_LEFT,-1,12,VillageTheme.CREAM)
	# Names last, on a paper pill, so arrows never run through them.
	for npc_id in positions:
		var at: Vector2 = positions[npc_id]
		var label := str(names.get(npc_id,npc_id))
		var text_size := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,13)
		var pill := Rect2(at + Vector2(-text_size.x / 2.0 - 6.0,NODE_RADIUS + 2.0),Vector2(text_size.x + 12.0,20.0))
		graph.draw_rect(pill,VillageTheme.CREAM)
		graph.draw_string(font,at + Vector2(-text_size.x / 2.0,NODE_RADIUS + 17.0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,VillageTheme.INK)

func _has(rumor_id: String) -> bool:
	for rumor in rumors:
		if str(rumor["id"]) == rumor_id: return true
	return false

func _shorten(text: String, length: int) -> String:
	return text if text.length() <= length else text.left(length - 1) + "…"

func _label(node_name: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, text_value: String) -> Label:
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

func _style(button: Button, fill: Color) -> void:
	VillageTheme.configure_button(button)
	var styles := VillageTheme.button_style(fill,fill.lightened(0.12),fill.darkened(0.12))
	for key in styles: button.add_theme_stylebox_override(key,styles[key])
	var ink := VillageTheme.CREAM if fill.get_luminance() < 0.45 else VillageTheme.INK
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,ink)

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
