extends Node2D

const VillageTheme = preload("res://scripts/ui/ui_theme.gd")
const VillageArt = preload("res://scripts/ui/village_art.gd")
const QuestTrackerScene = preload("res://scenes/ui/QuestTracker.tscn")
const WorldMapPanelScene = preload("res://scenes/ui/WorldMapPanel.tscn")
const QuestLogPanelScene = preload("res://scenes/ui/QuestLogPanel.tscn")
const TradePanelScene = preload("res://scenes/ui/TradePanel.tscn")
const ProgressionPanelScene = preload("res://scenes/ui/ProgressionPanel.tscn")
const NavigationCoordinatorScript = preload("res://scripts/navigation/navigation_coordinator.gd")

const WORLD := Rect2(42, 92, 1196, 506)
const CAMERA_BOUNDS := Rect2(0,0,1280,720)
var selected_id := ""
var debug_visible := false
var canvas: CanvasLayer
var clock_label: Label
var brand_label: Label
var resource_label: Label
var event_label: Label
var hint_label: Label
var info_panel: Panel
var info_label: Label
var dialogue_label: Label
var relationship_label: Label
var needs_label: Label
var memory_label: Label
var log_label: Label
var debug_panel: Panel
var debug_label: Label
var showcase_panel: Panel
var pulse_panel: Panel
var pulse_label: Label
var inventory_panel: Panel
var inventory_label: Label
var pause_panel: Panel
var pause_label: Label
var pause_motion_button: Button
var toast_label: Label
var journal_panel: Panel
var journal_label: Label
var journal_title_label: Label
var journal_mode := "chronicle"
var daily_echo_day := 1
var daily_echo_category := "all"
const DAILY_ECHO_CATEGORIES := ["all","social","world","quest","economy","location","progression"]
const DAILY_ECHO_CATEGORY_LABELS := {"all":"全部","social":"居民","world":"世界","quest":"任務","economy":"經濟","location":"地點","progression":"進展"}
var time_panel: Panel
var time_label: Label
var renown_label: Label
var action_dock: Panel
var action_dock_title: Label
var action_dock_hint: Label
var action_buttons: Array[Button] = []
var interaction_prompt: Panel
var interaction_prompt_label: Label
var impact_feedback: Panel
var impact_title: Label
var impact_body: Label
var impact_remaining := 0.0
var motion_enabled := true
var ambience_clock := 0.0
var quest_tracker
var world_map_panel
var quest_log_panel
var main_menu_panel: Panel
var settings_panel: Panel
var menu_status_label: Label
var continue_button: Button
var autosave_toggle: CheckButton
var motion_toggle: CheckButton
var fullscreen_toggle: CheckButton
var audio_toggle: CheckButton
var trade_panel
var progression_panel
var craft_button: Button
var gather_button: Button
var navigation_coordinator: Node2D
var player_camera: Camera2D
var camera_follow_target := Vector2.ZERO

func _ready() -> void:
	create_input_map()
	create_camera()
	create_navigation()
	create_ui()
	EventBus.event_logged.connect(func(_time: String, _message: String): refresh_ui())
	EventBus.community_progressed.connect(func(_entry: Dictionary): refresh_ui())
	EventBus.quest_changed.connect(func(_snapshot: Array): refresh_ui())
	EventBus.location_changed.connect(func(_location_id: String): refresh_ui())
	EventBus.save_completed.connect(func(_path: String): refresh_ui())
	EventBus.progression_unlocked.connect(handle_progression_unlock)
	motion_enabled = SaveManager.get_preference("motion",true)
	sync_motion_controls()
	GameTime.set_simulation_paused(true)
	queue_redraw()
	if "--visual-qa" in OS.get_cmdline_user_args(): call_deferred("capture_visual_qa")

func capture_visual_qa() -> void:
	var captures := [
		{"file":"storybook_intro.png","minute":780,"intro":true},
		{"file":"storybook_explore_dawn.png","minute":360,"intro":false},
		{"file":"storybook_explore_noon.png","minute":780,"intro":false},
		{"file":"storybook_explore_night.png","minute":60,"intro":false},
		{"file":"storybook_event_danger.png","minute":780,"intro":false,"scenario":"danger"},
		{"file":"quest_in_progress.png","minute":810,"intro":false,"scenario":"quest"},
		{"file":"forest_echo_complete.png","minute":930,"intro":false,"scenario":"forest_complete"},
		{"file":"consumer_main_menu.png","minute":780,"intro":false,"scenario":"main_menu"},
		{"file":"consumer_settings.png","minute":780,"intro":false,"scenario":"settings"},
		{"file":"consumer_trade.png","minute":780,"intro":false,"scenario":"trade"},
		{"file":"village_progression.png","minute":780,"intro":false,"scenario":"progression"}
	]
	for capture in captures:
		var file_name := str(capture["file"])
		var scenario := str(capture.get("scenario",""))
		GameTime.minute = int(capture["minute"])
		main_menu_panel.visible = false
		settings_panel.visible = false
		trade_panel.visible = false
		inventory_panel.visible = false
		journal_panel.visible = false
		progression_panel.visible = false
		world_map_panel.visible = false
		quest_log_panel.visible = false
		pause_panel.visible = false
		impact_feedback.visible = false
		GameTime.set_simulation_paused(false)
		if scenario == "danger":
			GameManager.load_showcase("danger")
		else:
			GameManager.new_game()
		if scenario == "quest": GameManager.interact("alice","ask")
		if scenario == "forest_complete":
			GameManager.interact("alice","ask")
			GameManager.travel_to("forest_edge")
			GameManager.interact("diana","give_bread")
		if scenario == "progression":
			GameManager.interact("alice","talk")
			GameManager.interact("alice","give_bread")
		if scenario == "trade": GameManager.player["position"] = GameManager.npcs["alice"]["position"] + Vector2(-38,0)
		showcase_panel.visible = bool(capture["intro"])
		selected_id = "" if bool(capture["intro"]) or scenario in ["main_menu","settings"] else ("bob" if scenario == "danger" else ("diana" if scenario == "forest_complete" else "alice"))
		info_panel.visible = not bool(capture["intro"]) and scenario not in ["main_menu","settings"]
		if selected_id != "": dialogue_label.text = GameManager.dialogue(GameManager.npcs[selected_id])
		refresh_ui()
		if scenario == "main_menu":
			main_menu_panel.visible = true
			refresh_main_menu()
		if scenario == "settings":
			main_menu_panel.visible = true
			open_settings()
		if scenario == "trade": open_trade_panel()
		if scenario == "progression":
			progression_panel.refresh(GameManager.progression_snapshot())
			progression_panel.visible = true
			progression_panel.move_to_front()
		if scenario == "danger":
			show_interaction_feedback("ask","危險來襲時，村民的協助與逃離選擇都會留下可追溯的記憶。")
		if scenario == "forest_complete":
			show_interaction_feedback("give","任務完成：黛安娜收下麵包，森林記住了你的善意。")
		queue_redraw()
		await get_tree().process_frame
		if scenario in ["danger","forest_complete","settings","trade","progression"]: await get_tree().create_timer(0.24).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var result := image.save_png("res://tests/visual_qa/" + file_name)
		if result != OK:
			push_error("無法輸出視覺 QA 截圖：" + file_name)
			get_tree().quit(1)
			return
		print("VISUAL_CAPTURE " + file_name + " size=" + str(image.get_width()) + "x" + str(image.get_height()))
	get_tree().quit(0)

func visual_qa_capture_names() -> Array:
	return ["storybook_intro.png","storybook_explore_dawn.png","storybook_explore_noon.png","storybook_explore_night.png","storybook_event_danger.png","quest_in_progress.png","forest_echo_complete.png","consumer_main_menu.png","consumer_settings.png","consumer_trade.png","village_progression.png"]

func create_input_map() -> void:
	var bindings := {"interact":KEY_E,"talk":KEY_C,"give":KEY_G,"steal":KEY_X,"trade":KEY_T,"ask":KEY_Q,"cancel":KEY_ESCAPE,"debug":KEY_F3,"inventory":KEY_I,"journal":KEY_J,"daily_summary":KEY_L,"progression":KEY_P,"world_map":KEY_M,"quest_log":KEY_K,"speed_normal":KEY_1,"speed_2x":KEY_2,"speed_5x":KEY_5,"speed_10x":KEY_0,"save_game":KEY_F5,"load_game":KEY_F9,"event_rain":KEY_R,"event_festival":KEY_F,"event_shortage":KEY_H,"event_danger":KEY_B,"event_injury":KEY_N}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.keycode = bindings[action]
			InputMap.action_add_event(action,key)

func _process(delta: float) -> void:
	if motion_enabled: ambience_clock += delta
	if impact_remaining > 0.0:
		impact_remaining -= delta
		if impact_remaining <= 0.0: impact_feedback.visible = false
	handle_shortcuts()
	if not is_blocking_modal_open(): move_player(delta)
	update_player_camera(delta)
	sync_simulation_pause()
	refresh_ui()
	queue_redraw()

func move_player(delta: float) -> void:
	var direction := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if Input.is_key_pressed(KEY_A): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	if Input.is_key_pressed(KEY_W): direction.y -= 1
	if Input.is_key_pressed(KEY_S): direction.y += 1
	if direction.length() > 0.0:
		GameManager.player["position"] += direction.normalized() * 180.0 * delta
		GameManager.player["position"] = GameManager.player["position"].clamp(WORLD.position + Vector2(12,12), WORLD.end - Vector2(12,12))

func create_camera() -> void:
	player_camera = Camera2D.new()
	player_camera.name = "PlayerCamera"
	player_camera.position = CAMERA_BOUNDS.get_center()
	camera_follow_target = GameManager.player["position"]
	player_camera.position_smoothing_enabled = true
	player_camera.position_smoothing_speed = 5.0
	player_camera.limit_left = int(CAMERA_BOUNDS.position.x)
	player_camera.limit_top = int(CAMERA_BOUNDS.position.y)
	player_camera.limit_right = int(CAMERA_BOUNDS.end.x)
	player_camera.limit_bottom = int(CAMERA_BOUNDS.end.y)
	player_camera.limit_smoothed = false
	add_child(player_camera)
	player_camera.make_current()

func update_player_camera(delta: float) -> void:
	if player_camera == null: return
	camera_follow_target = GameManager.player["position"]
	var viewport_size := get_viewport_rect().size
	if CAMERA_BOUNDS.size.x <= viewport_size.x and CAMERA_BOUNDS.size.y <= viewport_size.y:
		player_camera.position = CAMERA_BOUNDS.get_center()
		return
	var weight := 1.0 - exp(-5.0 * maxf(delta,0.0))
	player_camera.position = player_camera.position.lerp(camera_follow_target,weight)

func handle_shortcuts() -> void:
	if settings_panel.visible:
		if Input.is_action_just_pressed("cancel"): close_settings()
		return
	if main_menu_panel.visible: return
	if Input.is_action_just_pressed("interact"): select_nearest()
	if Input.is_action_just_pressed("debug"):
		debug_visible = not debug_visible
		debug_panel.visible = debug_visible
	if Input.is_action_just_pressed("inventory"):
		toggle_modal_panel(inventory_panel)
	if Input.is_action_just_pressed("journal"):
		set_journal_mode("chronicle")
		toggle_modal_panel(journal_panel)
	if Input.is_action_just_pressed("daily_summary"):
		set_journal_mode("daily")
		toggle_modal_panel(journal_panel)
	if Input.is_action_just_pressed("progression"):
		if not progression_panel.visible: progression_panel.refresh(GameManager.progression_snapshot())
		toggle_modal_panel(progression_panel)
	if Input.is_action_just_pressed("world_map"):
		toggle_modal_panel(world_map_panel)
	if Input.is_action_just_pressed("quest_log"):
		toggle_modal_panel(quest_log_panel)
	if Input.is_action_just_pressed("give"): perform("give_bread")
	if Input.is_action_just_pressed("talk"): perform("talk")
	if Input.is_action_just_pressed("steal"): perform("steal_food")
	if Input.is_action_just_pressed("trade"): perform("trade")
	if Input.is_action_just_pressed("ask"): perform("ask")
	if Input.is_action_just_pressed("speed_normal"): GameTime.set_speed("normal")
	if Input.is_action_just_pressed("speed_2x"): GameTime.set_speed("2x")
	if Input.is_action_just_pressed("speed_5x"): GameTime.set_speed("5x")
	if Input.is_action_just_pressed("speed_10x"): GameTime.set_speed("10x")
	if Input.is_action_just_pressed("save_game"): SaveManager.save_game()
	if Input.is_action_just_pressed("load_game"): SaveManager.load_game()
	if Input.is_action_just_pressed("event_rain"): GameManager.trigger_world_event("rain")
	if Input.is_action_just_pressed("event_festival"): GameManager.trigger_world_event("festival")
	if Input.is_action_just_pressed("event_shortage"): GameManager.trigger_world_event("food_shortage")
	if Input.is_action_just_pressed("event_danger"): GameManager.trigger_world_event("minor_danger")
	if Input.is_action_just_pressed("event_injury"): GameManager.trigger_world_event("npc_injury")
	if Input.is_action_just_pressed("cancel"):
		if trade_panel.visible:
			trade_panel.visible = false
		elif quest_log_panel.visible:
			quest_log_panel.visible = false
		elif world_map_panel.visible:
			world_map_panel.visible = false
		elif showcase_panel.visible:
			showcase_panel.visible = false
		elif journal_panel.visible:
			journal_panel.visible = false
		elif progression_panel.visible:
			progression_panel.visible = false
		elif inventory_panel.visible:
			inventory_panel.visible = false
		elif pause_panel.visible:
			pause_panel.visible = false
		else:
			pause_panel.visible = true
			info_panel.visible = false
			selected_id = ""
	sync_simulation_pause()

func create_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	brand_label = make_label(Vector2(58,4),Vector2(520,30),20,VillageTheme.SUN)
	brand_label.text = "ECHO VILLAGE  ·  AI 驅動 NPC 生活模擬"
	clock_label = make_label(Vector2(58,35), Vector2(370,38), 22, VillageTheme.PAPER)
	resource_label = make_label(Vector2(876,35), Vector2(345,38), 18, VillageTheme.PAPER)
	event_label = make_label(Vector2(440,35), Vector2(390,38), 16, VillageTheme.SUN)
	renown_label = make_label(Vector2(900,6), Vector2(320,22), 13, VillageTheme.MOSS_LIGHT)
	renown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label = make_label(Vector2(58,610), Vector2(730,28), 14, VillageTheme.PAPER)
	hint_label.text = "E 查看村民  •  G 贈送  •  T 交易  •  J 編年  •  L 今日回音  •  P 村落手札  •  F3 除錯"
	log_label = make_label(Vector2(58,644), Vector2(730,66), 13, VillageTheme.PAPER_DARK)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label = make_label(Vector2(390,566),Vector2(420,26),14,VillageTheme.SUN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_pulse_panel()
	create_time_panel()
	create_inventory_panel()
	create_journal_panel()
	create_pause_panel()
	create_interaction_prompt()
	create_impact_feedback()
	create_action_dock()
	create_expansion_ui()
	info_panel = Panel.new()
	info_panel.name = "NpcDossier"
	info_panel.position = Vector2(808,530)
	info_panel.size = Vector2(413,180)
	info_panel.add_theme_stylebox_override("panel",VillageTheme.panel_style(VillageTheme.PAPER,VillageTheme.INK,8))
	canvas.add_child(info_panel)
	info_label = make_panel_label(info_panel,Vector2(12,8),Vector2(385,25),16,VillageTheme.INK)
	relationship_label = make_panel_label(info_panel,Vector2(12,33),Vector2(385,20),13,VillageTheme.INK_SOFT)
	needs_label = make_panel_label(info_panel,Vector2(12,54),Vector2(385,20),13,VillageTheme.INK_SOFT)
	memory_label = make_panel_label(info_panel,Vector2(12,76),Vector2(385,32),13,VillageTheme.INK_SOFT)
	memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label = make_panel_label(info_panel,Vector2(12,112),Vector2(385,58),14,VillageTheme.INK_SOFT)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.visible = false
	debug_panel = Panel.new()
	debug_panel.name = "DebugOverlay"
	debug_panel.position = Vector2(58,188)
	debug_panel.size = Vector2(340,402)
	debug_panel.add_theme_stylebox_override("panel",VillageTheme.panel_style(VillageTheme.NIGHT,VillageTheme.PAPER_DARK,8))
	canvas.add_child(debug_panel)
	debug_label = make_panel_label(debug_panel,Vector2(12,10),Vector2(316,246),13,VillageTheme.PAPER)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_debug_button("AddBreadButton",Vector2(12,270),"+ 麵包",debug_add_bread)
	add_debug_button("StressNeedButton",Vector2(174,270),"飢餓 +25",debug_stress_need)
	add_debug_button("TeleportButton",Vector2(12,326),"傳送至居民",debug_teleport)
	add_debug_button("InjuryEventButton",Vector2(174,326),"觸發受傷事件",func(): GameManager.trigger_world_event("npc_injury"))
	debug_panel.visible = false
	create_showcase_panel()
	create_main_menu()
	create_settings_panel()

func create_main_menu() -> void:
	main_menu_panel = Panel.new()
	main_menu_panel.name = "MainMenu"
	main_menu_panel.position = Vector2.ZERO
	main_menu_panel.size = Vector2(1280,720)
	main_menu_panel.add_theme_stylebox_override("panel",VillageTheme.panel_style(Color("102332",0.96),VillageTheme.SUN,0))
	canvas.add_child(main_menu_panel)
	var eyebrow := make_panel_label(main_menu_panel,Vector2(410,112),Vector2(460,24),13,VillageTheme.MOSS_LIGHT)
	eyebrow.text = "AI-DRIVEN NPC LIFE SIMULATION RPG"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := make_panel_label(main_menu_panel,Vector2(310,145),Vector2(660,70),44,VillageTheme.SUN)
	title.text = "ECHO VILLAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := make_panel_label(main_menu_panel,Vector2(370,218),Vector2(540,52),16,VillageTheme.PAPER_DARK)
	subtitle.text = "一座即使沒有玩家介入，也會持續生活、記憶與改變的小村莊。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_button = make_menu_button(main_menu_panel,"ContinueButton",Vector2(490,305),"繼續旅程")
	continue_button.pressed.connect(continue_game)
	var new_game_button := make_menu_button(main_menu_panel,"NewGameButton",Vector2(490,365),"開始新旅程")
	new_game_button.pressed.connect(start_new_game)
	var settings_button := make_menu_button(main_menu_panel,"SettingsButton",Vector2(490,425),"遊戲設定")
	settings_button.pressed.connect(open_settings)
	var showcase_button := make_menu_button(main_menu_panel,"ShowcaseButton",Vector2(490,485),"作品集展示模式")
	showcase_button.pressed.connect(func(): main_menu_panel.visible = false; showcase_panel.visible = true; sync_simulation_pause())
	menu_status_label = make_panel_label(main_menu_panel,Vector2(410,558),Vector2(460,50),13,VillageTheme.PAPER_DARK)
	menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refresh_main_menu()

func make_menu_button(parent: Control, node_name: String, at: Vector2, text_value: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = at
	button.size = Vector2(300,48)
	button.text = text_value
	button.add_theme_font_size_override("font_size",16)
	style_action_button(button,VillageTheme.MOSS_LIGHT)
	parent.add_child(button)
	return button

func refresh_main_menu() -> void:
	if continue_button == null: return
	continue_button.disabled = not SaveManager.has_save()
	continue_button.tooltip_text = "載入最近一次存檔" if not continue_button.disabled else "尚未建立存檔"
	menu_status_label.text = "已偵測到存檔，可繼續上次旅程。" if SaveManager.has_save() else "第一次來訪？選擇「開始新旅程」。"

func start_new_game() -> void:
	GameTime.reset_clock()
	GameManager.new_game()
	selected_id = ""
	info_panel.visible = false
	main_menu_panel.visible = false
	showcase_panel.visible = false
	SaveManager.autosave_game()
	sync_simulation_pause()
	show_interaction_feedback("start","新旅程已開始。靠近居民按 E 交談，向艾莉絲詢問第一份委託。")

func continue_game() -> void:
	if not SaveManager.load_game():
		menu_status_label.text = "存檔無法讀取；你仍可安全開始新旅程。"
		refresh_main_menu()
		return
	main_menu_panel.visible = false
	showcase_panel.visible = false
	selected_id = ""
	info_panel.visible = false
	sync_simulation_pause()
	show_interaction_feedback("load","已回到上次儲存的村落狀態。")

func create_settings_panel() -> void:
	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.position = Vector2(420,136)
	settings_panel.size = Vector2(440,448)
	settings_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.TEAL))
	canvas.add_child(settings_panel)
	var title := make_panel_label(settings_panel,Vector2(24,20),Vector2(390,36),25,VillageTheme.INK)
	title.text = "遊戲設定  /  SETTINGS"
	var description := make_panel_label(settings_panel,Vector2(24,62),Vector2(390,42),13,VillageTheme.INK_SOFT)
	description.text = "所有設定會自動保存。關閉動態效果可減少環境微動。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	autosave_toggle = make_settings_toggle("AutosaveToggle",Vector2(24,122),"每日開始時自動存檔")
	motion_toggle = make_settings_toggle("MotionToggle",Vector2(24,180),"環境動態與介面轉場")
	fullscreen_toggle = make_settings_toggle("FullscreenToggle",Vector2(24,238),"全螢幕顯示")
	audio_toggle = make_settings_toggle("AudioToggle",Vector2(24,296),"介面與互動提示音效")
	autosave_toggle.toggled.connect(func(value: bool): SaveManager.set_preference("autosave",value))
	motion_toggle.toggled.connect(func(value: bool): set_motion_enabled(value))
	fullscreen_toggle.toggled.connect(apply_fullscreen)
	audio_toggle.toggled.connect(func(value: bool): SoundManager.set_enabled(value))
	var close := Button.new()
	close.name = "CloseButton"
	close.position = Vector2(246,376)
	close.size = Vector2(168,48)
	close.text = "套用並返回"
	style_action_button(close,VillageTheme.TEAL)
	close.pressed.connect(close_settings)
	settings_panel.add_child(close)
	settings_panel.visible = false

func make_settings_toggle(node_name: String, at: Vector2, label: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.position = at
	toggle.size = Vector2(390,48)
	toggle.text = label
	toggle.add_theme_font_size_override("font_size",15)
	toggle.add_theme_color_override("font_color",VillageTheme.INK)
	toggle.add_theme_color_override("font_pressed_color",VillageTheme.INK)
	toggle.add_theme_color_override("font_hover_color",VillageTheme.INK)
	toggle.add_theme_color_override("font_hover_pressed_color",VillageTheme.INK)
	toggle.add_theme_color_override("font_focus_color",VillageTheme.INK)
	settings_panel.add_child(toggle)
	return toggle

func open_settings() -> void:
	autosave_toggle.button_pressed = SaveManager.get_preference("autosave",true)
	motion_enabled = SaveManager.get_preference("motion",true)
	sync_motion_controls()
	fullscreen_toggle.button_pressed = SaveManager.get_preference("fullscreen",false)
	audio_toggle.button_pressed = SaveManager.get_preference("audio",true)
	SoundManager.play_ui()
	settings_panel.visible = true
	animate_panel_in(settings_panel)
	sync_simulation_pause()

func close_settings() -> void:
	settings_panel.visible = false
	sync_simulation_pause()

func apply_fullscreen(value: bool) -> void:
	SaveManager.set_preference("fullscreen",value)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)

func is_blocking_modal_open() -> bool:
	return main_menu_panel.visible or settings_panel.visible or pause_panel.visible or showcase_panel.visible or inventory_panel.visible or journal_panel.visible or progression_panel.visible or world_map_panel.visible or quest_log_panel.visible or trade_panel.visible

func sync_simulation_pause() -> void:
	GameTime.set_simulation_paused(is_blocking_modal_open())

func create_expansion_ui() -> void:
	quest_tracker = QuestTrackerScene.instantiate()
	world_map_panel = WorldMapPanelScene.instantiate()
	quest_log_panel = QuestLogPanelScene.instantiate()
	trade_panel = TradePanelScene.instantiate()
	progression_panel = ProgressionPanelScene.instantiate()
	canvas.add_child(quest_tracker)
	canvas.add_child(world_map_panel)
	canvas.add_child(quest_log_panel)
	canvas.add_child(trade_panel)
	canvas.add_child(progression_panel)
	world_map_panel.travel_requested.connect(handle_travel_request)
	trade_panel.buy_requested.connect(handle_buy_request)
	trade_panel.sell_requested.connect(handle_sell_request)

func handle_travel_request(location_id: String) -> void:
	var result: Dictionary = GameManager.travel_to(location_id)
	if bool(result.get("ok",false)):
		selected_id = ""
		info_panel.visible = false
		world_map_panel.visible = false
		show_interaction_feedback("travel","已抵達 %s。" % str(GameManager.location_defs[location_id].get("display_name",location_id)))
		refresh_ui()
		queue_redraw()
	else:
		show_interaction_feedback("travel",str(result.get("reason","無法前往。")))

func create_pulse_panel() -> void:
	pulse_panel = Panel.new()
	pulse_panel.name = "VillagePulse"
	pulse_panel.position = Vector2(58,108)
	pulse_panel.size = Vector2(280,182)
	pulse_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(Color("f7edcf"),VillageTheme.MOSS))
	canvas.add_child(pulse_panel)
	var title := make_panel_label(pulse_panel,Vector2(16,14),Vector2(245,28),17,VillageTheme.INK)
	title.text = "村落脈動  /  VILLAGE PULSE"
	pulse_label = make_panel_label(pulse_panel,Vector2(16,48),Vector2(245,120),14,VillageTheme.INK_SOFT)
	pulse_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func create_time_panel() -> void:
	time_panel = Panel.new()
	time_panel.name = "TimeControls"
	time_panel.position = Vector2(58,502)
	time_panel.size = Vector2(280,92)
	time_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(Color("f7edcf"),VillageTheme.TEAL))
	canvas.add_child(time_panel)
	var title := make_panel_label(time_panel,Vector2(16,10),Vector2(245,22),15,VillageTheme.INK)
	title.text = "時間控制  /  SIMULATION"
	time_label = make_panel_label(time_panel,Vector2(16,34),Vector2(115,20),12,VillageTheme.INK_SOFT)
	add_time_button("1×",Vector2(136,38),"normal")
	add_time_button("2×",Vector2(170,38),"2x")
	add_time_button("5×",Vector2(204,38),"5x")
	add_time_button("10×",Vector2(238,38),"10x")

func add_time_button(text_value: String, position_value: Vector2, speed_key: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = Vector2(29 if speed_key != "10x" else 36,34)
	button.add_theme_font_size_override("font_size",11)
	style_action_button(button,VillageTheme.TEAL)
	button.pressed.connect(func(): GameTime.set_speed(speed_key))
	time_panel.add_child(button)

func create_inventory_panel() -> void:
	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.position = Vector2(915,108)
	inventory_panel.size = Vector2(306,430)
	inventory_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.PAPER,VillageTheme.SUN))
	canvas.add_child(inventory_panel)
	var title := make_panel_label(inventory_panel,Vector2(16,14),Vector2(260,28),17,VillageTheme.INK)
	title.text = "玩家背包  /  INVENTORY"
	inventory_label = make_panel_label(inventory_panel,Vector2(16,52),Vector2(265,205),14,VillageTheme.INK_SOFT)
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	craft_button = Button.new()
	craft_button.name = "CraftButton"
	craft_button.text = "製作森林藥劑"
	craft_button.position = Vector2(16,270)
	craft_button.size = Vector2(274,42)
	craft_button.add_theme_font_size_override("font_size",13)
	style_action_button(craft_button,VillageTheme.MOSS)
	craft_button.pressed.connect(craft_forest_remedy)
	inventory_panel.add_child(craft_button)
	gather_button = Button.new()
	gather_button.name = "GatherButton"
	gather_button.text = "採集月光藥草"
	gather_button.position = Vector2(16,318)
	gather_button.size = Vector2(274,42)
	gather_button.add_theme_font_size_override("font_size",13)
	style_action_button(gather_button,VillageTheme.TEAL)
	gather_button.pressed.connect(gather_forest_herb)
	inventory_panel.add_child(gather_button)
	var close := Button.new()
	close.text = "關閉  I"
	close.position = Vector2(188,378)
	close.size = Vector2(102,34)
	close.add_theme_font_size_override("font_size",12)
	style_action_button(close,VillageTheme.SUN)
	close.pressed.connect(func(): inventory_panel.visible = false)
	inventory_panel.add_child(close)
	inventory_panel.visible = false

func create_journal_panel() -> void:
	journal_panel = Panel.new()
	journal_panel.name = "ChroniclePanel"
	journal_panel.position = Vector2(860,108)
	journal_panel.size = Vector2(360,390)
	journal_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.LILAC))
	canvas.add_child(journal_panel)
	var eyebrow := make_panel_label(journal_panel,Vector2(18,14),Vector2(270,18),12,VillageTheme.LILAC)
	eyebrow.text = "每個選擇都會留下回音"
	journal_title_label = make_panel_label(journal_panel,Vector2(18,34),Vector2(320,30),20,VillageTheme.INK)
	journal_title_label.text = "村落編年  /  CHRONICLE"
	journal_label = make_panel_label(journal_panel,Vector2(18,73),Vector2(320,177),13,VillageTheme.INK_SOFT)
	journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var previous_button := Button.new()
	previous_button.name = "DailyPrevButton"
	previous_button.text = "‹ 上一日"
	previous_button.position = Vector2(18,258)
	previous_button.size = Vector2(96,34)
	previous_button.add_theme_font_size_override("font_size",12)
	previous_button.tooltip_text = "回看前一天的事件"
	style_action_button(previous_button,VillageTheme.TEAL)
	previous_button.pressed.connect(func(): set_daily_echo_day(daily_echo_day - 1))
	journal_panel.add_child(previous_button)
	var next_button := Button.new()
	next_button.name = "DailyNextButton"
	next_button.text = "下一日 ›"
	next_button.position = Vector2(120,258)
	next_button.size = Vector2(96,34)
	next_button.add_theme_font_size_override("font_size",12)
	next_button.tooltip_text = "回看後一天的事件"
	style_action_button(next_button,VillageTheme.TEAL)
	next_button.pressed.connect(func(): set_daily_echo_day(daily_echo_day + 1))
	journal_panel.add_child(next_button)
	var filter_button := Button.new()
	filter_button.name = "DailyFilterButton"
	filter_button.text = "分類：全部"
	filter_button.position = Vector2(222,258)
	filter_button.size = Vector2(120,34)
	filter_button.add_theme_font_size_override("font_size",12)
	filter_button.tooltip_text = "切換居民、世界、任務、經濟、地點與進展事件"
	style_action_button(filter_button,VillageTheme.SUN)
	filter_button.pressed.connect(cycle_daily_echo_category)
	journal_panel.add_child(filter_button)
	var daily_button := Button.new()
	daily_button.name = "DailySummaryButton"
	daily_button.text = "今日回音  L"
	daily_button.position = Vector2(18,342)
	daily_button.size = Vector2(190,34)
	daily_button.add_theme_font_size_override("font_size",12)
	style_action_button(daily_button,VillageTheme.SUN)
	daily_button.pressed.connect(func(): set_journal_mode("chronicle" if journal_mode == "daily" else "daily"))
	journal_panel.add_child(daily_button)
	var close := Button.new()
	close.text = "關閉  J"
	close.position = Vector2(218,342)
	close.size = Vector2(124,34)
	close.add_theme_font_size_override("font_size",12)
	style_action_button(close,VillageTheme.LILAC)
	close.pressed.connect(func(): journal_panel.visible = false)
	journal_panel.add_child(close)
	journal_panel.visible = false

func create_pause_panel() -> void:
	pause_panel = Panel.new()
	pause_panel.name = "PausePanel"
	pause_panel.position = Vector2(465,250)
	pause_panel.size = Vector2(350,208)
	pause_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.PAPER,VillageTheme.LILAC))
	canvas.add_child(pause_panel)
	var title := make_panel_label(pause_panel,Vector2(18,18),Vector2(310,32),22,VillageTheme.INK)
	title.text = "暫停選單"
	pause_label = make_panel_label(pause_panel,Vector2(18,55),Vector2(310,42),14,VillageTheme.INK_SOFT)
	pause_label.text = "按 Esc 繼續探索\n按 I 開啟背包 · J 查看編年 · F5 儲存"
	var resume := Button.new()
	resume.text = "繼續探索"
	resume.position = Vector2(18,111)
	resume.size = Vector2(145,38)
	resume.pressed.connect(func(): pause_panel.visible = false)
	style_action_button(resume,VillageTheme.MOSS)
	pause_panel.add_child(resume)
	var menu := Button.new()
	menu.text = "展示選單"
	menu.position = Vector2(187,111)
	menu.size = Vector2(145,38)
	menu.pressed.connect(func(): pause_panel.visible = false; showcase_panel.visible = true)
	style_action_button(menu,VillageTheme.SUN)
	pause_panel.add_child(menu)
	var motion := Button.new()
	pause_motion_button = motion
	motion.text = "動態效果：開"
	motion.position = Vector2(18,159)
	motion.size = Vector2(314,34)
	motion.add_theme_font_size_override("font_size",12)
	style_action_button(motion,VillageTheme.TEAL)
	motion.pressed.connect(func(): set_motion_enabled(not motion_enabled))
	pause_panel.add_child(motion)
	sync_motion_controls()
	pause_panel.visible = false

func make_label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	canvas.add_child(label)
	return label

func make_panel_label(parent: Control, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func add_debug_button(node_name: String, at: Vector2, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.position = at
	button.size = Vector2(152,44)
	button.text = text_value
	button.add_theme_font_size_override("font_size",12)
	style_action_button(button,VillageTheme.TEAL)
	button.pressed.connect(callback)
	debug_panel.add_child(button)

func debug_add_bread() -> void:
	GameManager.debug_add_player_item("bread",2)
	show_interaction_feedback("debug","已加入麵包 ×2。")

func debug_stress_need() -> void:
	if selected_id == "":
		show_interaction_feedback("debug","請先選取一位居民。")
		return
	GameManager.debug_adjust_need(selected_id,"hunger",25.0)
	show_interaction_feedback("debug","已提高選取居民的飢餓需求。")

func debug_teleport() -> void:
	if selected_id == "":
		show_interaction_feedback("debug","請先選取一位居民。")
		return
	GameManager.debug_teleport_player_to_npc(selected_id)
	show_interaction_feedback("debug","已傳送至選取居民身旁。")

func create_navigation() -> void:
	navigation_coordinator = NavigationCoordinatorScript.new()
	navigation_coordinator.name = "NavigationCoordinator"
	add_child(navigation_coordinator)

func add_button(text_value: String, position_value: Vector2, size_value: Vector2, action: String, color: Color) -> void:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size",13)
	style_action_button(button,color)
	button.pressed.connect(func(): perform(action))
	canvas.add_child(button)

func create_action_dock() -> void:
	action_dock = Panel.new()
	action_dock.name = "ActionDock"
	action_dock.position = Vector2(808,438)
	action_dock.size = Vector2(413,82)
	action_dock.add_theme_stylebox_override("panel",VillageTheme.card_style(Color("f7edcf"),VillageTheme.MOSS))
	canvas.add_child(action_dock)
	action_dock_title = make_panel_label(action_dock,Vector2(12,6),Vector2(190,24),15,VillageTheme.INK)
	action_dock_hint = make_panel_label(action_dock,Vector2(196,8),Vector2(204,20),11,VillageTheme.INK_SOFT)
	action_dock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var actions := [
		{"name":"TalkButton","label":"交談","action":"talk","color":VillageTheme.TEAL,"width":62},
		{"name":"GiveButton","label":"送麵包","action":"give_bread","color":VillageTheme.MOSS,"width":82},
		{"name":"StealButton","label":"偷取","action":"steal_food","color":VillageTheme.BRICK,"width":58},
		{"name":"TradeButton","label":"交易","action":"trade","color":VillageTheme.SUN,"width":62},
		{"name":"AskButton","label":"詢問","action":"ask","color":VillageTheme.MOSS_LIGHT,"width":62}
	]
	var offset := 12.0
	for entry in actions:
		var button := Button.new()
		button.name = str(entry["name"])
		button.text = str(entry["label"])
		button.position = Vector2(offset,40)
		button.size = Vector2(float(entry["width"]),32)
		button.add_theme_font_size_override("font_size",12)
		button.tooltip_text = str(entry["label"]) + "（需先選取居民）"
		style_action_button(button,entry["color"])
		button.pressed.connect(func(): perform(str(entry["action"])))
		action_dock.add_child(button)
		action_buttons.append(button)
		offset += float(entry["width"]) + 8.0

func create_interaction_prompt() -> void:
	interaction_prompt = Panel.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.size = Vector2(164,30)
	interaction_prompt.add_theme_stylebox_override("panel",VillageTheme.panel_style(Color("172c3a"),VillageTheme.SUN,8))
	canvas.add_child(interaction_prompt)
	interaction_prompt_label = make_panel_label(interaction_prompt,Vector2(10,4),Vector2(148,22),12,VillageTheme.PAPER)
	interaction_prompt.visible = false

func create_impact_feedback() -> void:
	impact_feedback = Panel.new()
	impact_feedback.name = "ImpactFeedback"
	impact_feedback.position = Vector2(382,478)
	impact_feedback.size = Vector2(402,50)
	impact_feedback.add_theme_stylebox_override("panel",VillageTheme.card_style(Color("fff3d7"),VillageTheme.SUN))
	canvas.add_child(impact_feedback)
	impact_title = make_panel_label(impact_feedback,Vector2(14,5),Vector2(374,18),12,VillageTheme.MOSS)
	impact_body = make_panel_label(impact_feedback,Vector2(14,23),Vector2(374,22),13,VillageTheme.INK_SOFT)
	impact_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	impact_feedback.visible = false

func refresh_contextual_interaction() -> void:
	var has_selected := selected_id != "" and GameManager.npcs.has(selected_id)
	if has_selected and (not npc_is_present(selected_id) or GameManager.player["position"].distance_to(GameManager.npcs[selected_id]["position"]) > 150.0):
		selected_id = ""
		info_panel.visible = false
		has_selected = false
	if has_selected:
		var npc: Dictionary = GameManager.npcs[selected_id]
		action_dock_title.text = "與 %s 互動" % str(npc["display_name"])
		action_dock_hint.text = "C / G / X / T / Q"
	else:
		action_dock_title.text = "選取一位居民開始互動"
		action_dock_hint.text = "靠近後按 E"
	for button in action_buttons:
		button.disabled = not has_selected
		button.tooltip_text = "可直接使用快捷鍵" if has_selected else "先靠近居民並按 E 選取"
	var nearby_id := nearest_npc_id(112.0)
	interaction_prompt.visible = not has_selected and nearby_id != ""
	if interaction_prompt.visible:
		var nearby: Dictionary = GameManager.npcs[nearby_id]
		interaction_prompt_label.text = "E  與 %s 交談" % str(nearby["display_name"])
		interaction_prompt.position = (GameManager.player["position"] + Vector2(18,-48)).clamp(Vector2(352,96),Vector2(1052,572))

func nearest_npc_id(radius: float = 104.0) -> String:
	var nearest := ""
	var shortest := radius
	for id in GameManager.npcs:
		if not npc_is_present(str(id)): continue
		var distance: float = GameManager.player["position"].distance_to(GameManager.npcs[id]["position"])
		if distance < shortest:
			shortest = distance
			nearest = id
	return nearest

func npc_is_present(npc_id: String) -> bool:
	if not GameManager.npcs.has(npc_id): return false
	if GameManager.current_location == "forest_edge": return npc_id in ["diana","eric"]
	return true

func show_interaction_feedback(action: String, response: String) -> void:
	var labels := {"talk":"交談留下了回憶","give_bread":"善意被記住了","steal_food":"關係正在改變","trade":"交易完成","ask":"新的線索已更新","gather":"採集完成"}
	impact_title.text = str(labels.get(action,"互動完成"))
	impact_body.text = response
	impact_feedback.visible = true
	impact_feedback.modulate = Color(1,1,1,0.0) if motion_enabled else Color.WHITE
	impact_feedback.scale = Vector2(0.96,0.96) if motion_enabled else Vector2.ONE
	impact_feedback.pivot_offset = impact_feedback.size * 0.5
	if motion_enabled:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(impact_feedback,"modulate",Color.WHITE,0.18)
		tween.tween_property(impact_feedback,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_remaining = 3.8

func style_action_button(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color",VillageTheme.INK)
	var styles: Dictionary = VillageTheme.button_style(color,color.lightened(0.12),color.darkened(0.12))
	button.add_theme_stylebox_override("normal",styles["normal"])
	button.add_theme_stylebox_override("hover",styles["hover"])
	button.add_theme_stylebox_override("pressed",styles["pressed"])
	button.add_theme_stylebox_override("disabled",VillageTheme.panel_style(VillageTheme.PAPER_DARK.lightened(0.08),VillageTheme.PAPER_DARK,8))
	button.add_theme_color_override("font_disabled_color",VillageTheme.INK_SOFT.darkened(0.12))

func create_showcase_panel() -> void:
	showcase_panel = Panel.new()
	showcase_panel.position = Vector2(350,145)
	showcase_panel.size = Vector2(580,250)
	showcase_panel.add_theme_stylebox_override("panel",VillageTheme.card_style(VillageTheme.CREAM,VillageTheme.SUN))
	canvas.add_child(showcase_panel)
	var eyebrow := make_panel_label(showcase_panel,Vector2(24,18),Vector2(520,22),13,VillageTheme.MOSS)
	eyebrow.text = "自主村落模擬  ·  PORTFOLIO SHOWCASE"
	var title := make_panel_label(showcase_panel,Vector2(24,42),Vector2(530,38),29,VillageTheme.INK)
	title.text = "歡迎來到 Echo Village"
	var subtitle := make_panel_label(showcase_panel,Vector2(24,86),Vector2(530,44),14,VillageTheme.INK_SOFT)
	subtitle.text = "每個 NPC 都依需求、日程、人格、記憶與關係決策。選擇情境，立即觀察系統如何連鎖影響村落。"
	add_showcase_button("自由探索",Vector2(24,150),"start")
	add_showcase_button("A  善意記憶",Vector2(161,150),"kindness")
	add_showcase_button("B  流言擴散",Vector2(298,150),"rumor")
	add_showcase_button("C  突發危險",Vector2(435,150),"danger")
	var close_hint := make_panel_label(showcase_panel,Vector2(24,205),Vector2(530,20),12,VillageTheme.INK_SOFT)
	close_hint.text = "F3 顯示決策證據 · I 開啟背包 · Esc 開啟暫停選單"

func add_showcase_button(text_value: String, position_value: Vector2, scenario: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = Vector2(120,40)
	button.add_theme_font_size_override("font_size",12)
	style_action_button(button,VillageTheme.MOSS_LIGHT)
	button.pressed.connect(func(): launch_showcase(scenario))
	showcase_panel.add_child(button)

func launch_showcase(scenario: String) -> void:
	if scenario == "start":
		GameManager.new_game()
		showcase_panel.visible = false
		return
	var response := GameManager.load_showcase(scenario)
	selected_id = {"kindness":"alice","rumor":"charlie","danger":"bob"}.get(scenario,"")
	info_panel.visible = selected_id != ""
	dialogue_label.text = response
	showcase_panel.visible = false

func open_side_panel(panel: Panel) -> void:
	toggle_modal_panel(panel)

func close_modal_panels() -> void:
	inventory_panel.visible = false
	journal_panel.visible = false
	progression_panel.visible = false
	world_map_panel.visible = false
	quest_log_panel.visible = false
	trade_panel.visible = false
	pause_panel.visible = false
	showcase_panel.visible = false

func toggle_modal_panel(panel: Control) -> void:
	var should_open := not panel.visible
	close_modal_panels()
	if should_open:
		if panel.has_method("set_visible_with_motion"):
			panel.set_visible_with_motion(true,motion_enabled)
		else:
			panel.visible = true
			animate_panel_in(panel)
		panel.move_to_front()
	sync_simulation_pause()

func set_motion_enabled(value: bool) -> void:
	motion_enabled = value
	SaveManager.set_preference("motion",value)
	sync_motion_controls()

func sync_motion_controls() -> void:
	if motion_toggle != null:
		motion_toggle.set_pressed_no_signal(motion_enabled)
	if pause_motion_button != null:
		pause_motion_button.text = "動態效果：開" if motion_enabled else "動態效果：關"

func animate_panel_in(panel: Control) -> void:
	if not motion_enabled: return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1,1,1,0.0)
	panel.scale = Vector2(0.97,0.97)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel,"modulate",Color.WHITE,0.18)
	tween.tween_property(panel,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func select_nearest() -> void:
	var nearest := nearest_npc_id(112.0)
	if nearest == "":
		GameManager.add_log("請靠近村民後再互動。")
		return
	selected_id = nearest
	info_panel.visible = true
	perform("talk")

func perform(action: String) -> void:
	if selected_id == "":
		GameManager.add_log("請先按 E 選取附近的村民。")
		return
	if action == "trade":
		SoundManager.play_interaction("trade")
		open_trade_panel()
		return
	var response := GameManager.interact(selected_id,action)
	SoundManager.play_interaction(action)
	dialogue_label.text = response
	info_panel.visible = true
	show_interaction_feedback(action,response)

func refresh_ui() -> void:
	var visual: Dictionary = GameTime.visual_profile()
	var progress: Dictionary = GameManager.community_progress()
	clock_label.text = GameTime.formatted_time() + "  ·  " + str(visual["phase"]) + "  ×%.0f" % GameTime.time_scale
	resource_label.text = "硬幣 %d   麵包 %d   藥品 %d" % [GameManager.player["coin"],GameManager.count_item(GameManager.player["inventory"],"bread"),GameManager.count_item(GameManager.player["inventory"],"medicine")]
	event_label.text = "事件：" + str(GameManager.active_event.get("display_name","平靜的村落"))
	var progression_snapshot: Dictionary = GameManager.progression_snapshot()
	renown_label.text = "聲望 %d  ·  %s  ·  成就 %d / 6" % [int(progression_snapshot["renown"]),str(progression_snapshot["tier"].get("title","陌生旅人")),progression_snapshot["unlocked_ids"].size()]
	time_label.text = "%s · 動態%s" % [str(visual["phase"]),"開" if motion_enabled else "關"]
	log_label.text = "\n".join(GameManager.event_log.slice(maxi(0,GameManager.event_log.size() - 3)))
	toast_label.text = ""
	if GameManager.event_log.size() > 0:
		toast_label.text = GameManager.event_log.back()
	pulse_label.text = "居民運作中：%d / 5\n當前事件：%s\n模擬速度：×%.0f\n編年進度：%d / 3\n\nE 選取村民，查看關係與記憶。" % [GameManager.npcs.size(),str(GameManager.active_event.get("display_name","平靜的村落")),GameTime.time_scale,int(progress["unlocked"])]
	inventory_label.text = inventory_summary()
	craft_button.disabled = GameManager.current_location != "forest_edge" or GameManager.count_item(GameManager.player["inventory"],"herb") < 2
	craft_button.tooltip_text = "消耗月光藥草 ×2，製作藥品 ×1" if not craft_button.disabled else "需在低語森林邊緣並持有 2 株月光藥草"
	gather_button.disabled = not GameManager.can_gather_location_resource("herb")
	gather_button.tooltip_text = "森林每輪可採集 3 株月光藥草" if not gather_button.disabled else "需在森林邊緣，或本輪資源已採完"
	refresh_journal_panel(progress)
	progression_panel.refresh(progression_snapshot)
	quest_tracker.refresh(GameManager.active_quest_snapshot())
	world_map_panel.set_locations(GameManager.location_defs,GameManager.current_location,GameManager.discovered_locations)
	quest_log_panel.refresh(GameManager.active_quest_snapshot(),GameManager.completed_quests)
	refresh_contextual_interaction()
	if selected_id != "" and GameManager.npcs.has(selected_id):
		var snapshot: Dictionary = GameManager.npc_showcase_snapshot(selected_id)
		var npc: Dictionary = GameManager.npcs[selected_id]
		var relation: Dictionary = snapshot["relationship"]
		var needs: Dictionary = snapshot["needs"]
		info_label.text = "%s · %s · %s · %s" % [snapshot["display_name"],snapshot["occupation"],mood_text(snapshot["mood"]),action_text(snapshot["action"])]
		relationship_label.text = GameManager.relationship_summary(selected_id)
		needs_label.text = "需求  飢餓 %d  ·  體力 %d  ·  社交 %d  ·  安全 %d" % [int(needs["hunger"]),int(needs["energy"]),int(needs["social"]),int(needs["safety"])]
		memory_label.text = GameManager.latest_memory_summary(selected_id)
		if dialogue_label.text == "": dialogue_label.text = GameManager.dialogue(npc)
		info_label.tooltip_text = "信任 %d · 好感 %d · 記憶 %d" % [int(relation.get("trust",0)),int(relation.get("affinity",0)),npc["memories"].size()]
	if debug_visible: refresh_debug()

func chronicle_text(progress: Dictionary) -> String:
	var lines := ["目前聲望：%d" % int(progress["renown"]),"","[%s] 善意留下回音" % ("已解鎖" if bool(progress["kindness"]) else "未解鎖"),"贈送麵包，觀察記憶與信任如何改變。","","[%s] 流言開始擴散" % ("已解鎖" if bool(progress["rumor"]) else "未解鎖"),"偷取食物，觀察負面記憶如何傳播。","","[%s] 危機考驗勇氣" % ("已解鎖" if bool(progress["crisis"]) else "未解鎖"),"按 B 觸發危險，使用 F3 比較 NPC 決策。"]
	return "\n".join(lines)

func set_journal_mode(mode: String) -> void:
	var was_daily := journal_mode == "daily"
	journal_mode = "daily" if mode == "daily" else "chronicle"
	if journal_mode == "daily" and not was_daily:
		daily_echo_day = GameTime.day
		daily_echo_category = "all"
	if journal_label != null: refresh_journal_panel(GameManager.community_progress())

func refresh_journal_panel(progress: Dictionary = {}) -> void:
	if journal_label == null: return
	var snapshot: Dictionary = progress if not progress.is_empty() else GameManager.community_progress()
	var is_daily: bool = journal_mode == "daily"
	journal_title_label.text = "今日回音  /  DAILY ECHOES" if is_daily else "村落編年  /  CHRONICLE"
	if is_daily:
		daily_echo_day = clampi(daily_echo_day,1,maxi(1,GameTime.day))
		journal_label.text = daily_echoes_text(GameManager.daily_summary(daily_echo_day,daily_echo_category),daily_echo_category)
		var previous_button := journal_panel.get_node_or_null("DailyPrevButton") as Button
		var next_button := journal_panel.get_node_or_null("DailyNextButton") as Button
		var filter_button := journal_panel.get_node_or_null("DailyFilterButton") as Button
		if previous_button != null:
			previous_button.disabled = daily_echo_day <= 1
			previous_button.tooltip_text = "已經是最早保留日期" if previous_button.disabled else "回看前一天的事件"
		if next_button != null:
			next_button.disabled = daily_echo_day >= GameTime.day
			next_button.tooltip_text = "目前沒有更晚的日期" if next_button.disabled else "回看後一天的事件"
		if filter_button != null: filter_button.text = "分類：%s" % str(DAILY_ECHO_CATEGORY_LABELS.get(daily_echo_category,"全部"))
	var toggle_button := journal_panel.get_node_or_null("DailySummaryButton") as Button
	if toggle_button != null: toggle_button.text = "村落編年  J" if is_daily else "今日回音  L"

func set_daily_echo_day(value: int) -> void:
	daily_echo_day = clampi(value,1,maxi(1,GameTime.day))
	if journal_mode == "daily" and journal_label != null: refresh_journal_panel(GameManager.community_progress())

func set_daily_echo_category(value: String) -> void:
	daily_echo_category = value if DAILY_ECHO_CATEGORIES.has(value) else "all"
	if journal_mode == "daily" and journal_label != null: refresh_journal_panel(GameManager.community_progress())

func cycle_daily_echo_category() -> void:
	var index := DAILY_ECHO_CATEGORIES.find(daily_echo_category)
	set_daily_echo_category(str(DAILY_ECHO_CATEGORIES[(index + 1) % DAILY_ECHO_CATEGORIES.size()]))

func daily_echoes_text(summary: Dictionary, category: String = "all") -> String:
	var counts: Dictionary = summary.get("category_counts",{})
	var category_label := str(DAILY_ECHO_CATEGORY_LABELS.get(category,"全部"))
	var lines := ["第 %d 天 · %s · 共記錄 %d 件事件" % [int(summary.get("day",GameTime.day)),category_label,int(summary.get("total_events",0))],"居民 %d  ·  世界 %d  ·  任務 %d" % [int(counts.get("social",0)),int(counts.get("world",0)),int(counts.get("quest",0))],"經濟 %d  ·  地點 %d  ·  進展 %d" % [int(counts.get("economy",0)),int(counts.get("location",0)),int(counts.get("progression",0))],""]
	var highlights: Array = summary.get("highlights",[])
	if highlights.is_empty():
		lines.append("這一天沒有符合目前篩選的回音。")
	else:
		lines.append("重要回音")
		for value in highlights.slice(0,5):
			var event: Dictionary = value
			lines.append("• %s  %s" % [str(event.get("phase","")),str(event.get("message",""))])
	return "\n".join(lines)

func handle_progression_unlock(achievement: Dictionary) -> void:
	var message := "成就解鎖：%s\n%s" % [str(achievement.get("title","新的回音")),str(achievement.get("description",""))]
	show_interaction_feedback("achievement",message)
	SoundManager.play_interaction("achievement")
	refresh_ui()

func inventory_summary() -> String:
	var lines := ["硬幣  %d 枚" % int(GameManager.player["coin"]),""]
	for item_id in GameManager.item_defs:
		var definition: Dictionary = GameManager.item_defs[item_id]
		lines.append("%s  × %d" % [str(definition.get("display_name",item_id)),GameManager.count_item(GameManager.player["inventory"],str(item_id))])
	lines.append("")
	lines.append("I 關閉 · 森林可製作藥劑")
	return "\n".join(lines)

func craft_forest_remedy() -> void:
	var result: Dictionary = GameManager.craft_recipe("forest_remedy")
	var response := "製作完成：月光藥草 ×2 → 藥品 ×1。" if bool(result.get("ok",false)) else str(result.get("reason","目前無法製作。"))
	show_interaction_feedback("craft",response)
	SoundManager.play_interaction("craft")
	refresh_ui()

func gather_forest_herb() -> void:
	var result: Dictionary = GameManager.gather_location_resource("herb")
	var response := "採集完成：月光藥草 ×1，這片藥草地尚可採集 %d 次。" % int(result.get("remaining",0)) if bool(result.get("ok",false)) else str(result.get("reason","目前無法採集。"))
	show_interaction_feedback("gather",response)
	SoundManager.play_interaction("gather")
	refresh_ui()

func open_trade_panel() -> void:
	if selected_id == "" or not GameManager.npcs.has(selected_id):
		show_interaction_feedback("trade","請先靠近一位居民並按 E 選取。")
		return
	refresh_trade_panel()
	close_modal_panels()
	trade_panel.set_visible_with_motion(true,motion_enabled)
	trade_panel.move_to_front()
	sync_simulation_pause()

func trade_catalog() -> Array:
	var result: Array = []
	if selected_id == "" or not GameManager.npcs.has(selected_id): return result
	var npc: Dictionary = GameManager.npcs[selected_id]
	for item_id in GameManager.item_defs:
		var definition: Dictionary = GameManager.item_defs[item_id]
		var buy_price := GameManager.trade_price(selected_id,str(item_id))
		var sell_value := GameManager.sell_price(selected_id,str(item_id))
		var merchant_count := GameManager.count_item(npc["inventory"],str(item_id))
		var player_count := GameManager.count_item(GameManager.player["inventory"],str(item_id))
		result.append({"id":str(item_id),"display_name":str(definition.get("display_name",item_id)),"category":str(definition.get("category","物品")),"buy_price":buy_price,"sell_price":sell_value,"merchant_count":merchant_count,"player_count":player_count,"can_buy":merchant_count > 0 and int(GameManager.player["coin"]) >= buy_price,"can_sell":player_count > 0 and int(npc.get("coin",0)) >= sell_value})
	return result

func refresh_trade_panel() -> void:
	if selected_id == "" or not GameManager.npcs.has(selected_id): return
	trade_panel.set_catalog(trade_catalog(),str(GameManager.npcs[selected_id]["display_name"]),int(GameManager.player["coin"]))

func handle_buy_request(item_id: String) -> void:
	var result: Dictionary = GameManager.buy_item(selected_id,item_id,1)
	show_interaction_feedback("trade","買入完成。" if bool(result.get("ok",false)) else str(result.get("reason","無法買入。")))
	refresh_trade_panel()
	refresh_ui()

func handle_sell_request(item_id: String) -> void:
	var result: Dictionary = GameManager.sell_item(selected_id,item_id,1)
	show_interaction_feedback("trade","出售完成。" if bool(result.get("ok",false)) else str(result.get("reason","無法出售。")))
	refresh_trade_panel()
	refresh_ui()

func refresh_debug() -> void:
	var lines := ["模擬除錯面板","時間：" + GameTime.formatted_time(),"村民：%d   事件：%s" % [GameManager.npcs.size(),str(GameManager.active_event.get("display_name","無"))],"","[R] 降雨   [F] 祭典","[H] 糧食短缺   [B] 突發危險","[N] 林場受傷事件",""]
	if selected_id != "" and GameManager.npcs.has(selected_id):
		var npc: Dictionary = GameManager.npcs[selected_id]
		var n: Dictionary = npc["needs"]
		var important_memories := 0
		for memory in npc["memories"]:
			if int(memory.get("importance",0)) >= 60: important_memories += 1
		var path_nodes: int = navigation_coordinator.debug_path_for(selected_id).size() if navigation_coordinator != null and navigation_coordinator.has_method("debug_path_for") else 0
		var score_entries: Array = []
		for action_id in npc["scores"]: score_entries.append({"id":str(action_id),"score":float(npc["scores"][action_id])})
		score_entries.sort_custom(func(a: Dictionary,b: Dictionary): return float(a["score"]) > float(b["score"]))
		var top_scores: Array[String] = []
		for entry in score_entries.slice(0,mini(3,score_entries.size())): top_scores.append("%s %.1f" % [str(entry["id"]),float(entry["score"])])
		lines.append("%s — %s / %s" % [npc["display_name"],state_text(npc["state"]),action_text(npc["action"])])
		lines.append("目前目標：%s" % str(npc.get("current_goal","無")))
		lines.append("所在位置：%s" % str(npc.get("current_location","未知")))
		lines.append("移動目標：%s" % str(npc.get("current_target",Vector2.ZERO)))
		lines.append("情緒：%s" % mood_text(str(npc.get("mood","Neutral"))))
		lines.append("飢餓 %d | 體力 %d" % [n["hunger"],n["energy"]])
		lines.append("社交 %d | 安全 %d" % [n["social"],n["safety"]])
		lines.append("重要記憶：%d / 全部 %d" % [important_memories,npc["memories"].size()])
		lines.append("路徑節點：%d" % path_nodes)
		lines.append("最高分數：" + "  ·  ".join(top_scores))
	debug_label.text = "\n".join(lines)

func _draw() -> void:
	var visual: Dictionary = GameTime.visual_profile()
	var light := float(visual["light"])
	var is_night := bool(visual["is_night"])
	VillageArt.draw_sky(self,Rect2(Vector2.ZERO,Vector2(1280,720)),light,ambience_clock,is_night)
	VillageArt.draw_celestial(self,GameTime.minute,light)
	draw_rect(Rect2(0,0,1280,82),Color("102332").lerp(Color("183e49"),light * 0.45))
	draw_line(Vector2(42,82),Vector2(1238,82),VillageTheme.SUN,2.0)
	var art_time := ambience_clock if motion_enabled else 0.0
	if GameManager.current_location == "forest_edge":
		VillageArt.draw_forest_edge(self,WORLD,light,art_time)
	else:
		VillageArt.draw_meadow(self,WORLD,light,art_time)
		VillageArt.draw_stream(self,light,art_time)
		VillageArt.draw_path(self)
		VillageArt.draw_fountain(self,Vector2(625,355),art_time)
		VillageArt.draw_building(self,Vector2(318,188),Vector2(126,90),"tavern",light,is_night)
		VillageArt.draw_building(self,Vector2(842,182),Vector2(126,92),"shop",light,is_night)
		VillageArt.draw_building(self,Vector2(830,458),Vector2(136,94),"farm",light,is_night)
		VillageArt.draw_building(self,Vector2(296,452),Vector2(128,90),"healer",light,is_night)
		for home in [[Vector2(110,150),VillageTheme.SUN,"艾莉絲"],[Vector2(1074,150),Color("a66d4c"),"鮑伯"],[Vector2(112,500),VillageTheme.LILAC,"查理"],[Vector2(1064,500),VillageTheme.MOSS_LIGHT,"黛安娜"],[Vector2(664,500),Color("9a6948"),"艾瑞克"]]:
			VillageArt.draw_cottage(self,home[0],home[1],home[2],light,is_night)
		for tree_data in [[Vector2(1082,492),49.0],[Vector2(1018,460),34.0],[Vector2(1132,440),31.0],[Vector2(184,464),38.0],[Vector2(478,180),28.0],[Vector2(735,510),32.0]]:
			VillageArt.draw_tree(self,tree_data[0],tree_data[1],light,art_time)
	draw_rect(WORLD,Color(0.04,0.07,0.18,(1.0 - light) * 0.42))
	draw_rect(WORLD,Color("f6e7bf",0.16),false,2.0)
	VillageArt.draw_event_marker(self,str(GameManager.active_event.get("display_name","")),not GameManager.active_event.is_empty(),ambience_clock if motion_enabled else 0.0)
	if debug_visible and navigation_coordinator != null:
		for path in navigation_coordinator.debug_paths(): draw_polyline(path,Color(VillageTheme.SUN,0.85),2.0)
	for id in GameManager.npcs:
		if not npc_is_present(str(id)): continue
		var npc: Dictionary = GameManager.npcs[id]
		VillageArt.draw_character(self,id,npc,id == selected_id,motion_enabled,ambience_clock)
		if id == selected_id or npc["action"] != "Wander":
			VillageArt.draw_action_badge(self,npc["position"],action_text(str(npc["action"])),id == selected_id)
	VillageArt.draw_player(self,GameManager.player["position"],motion_enabled,ambience_clock)

func mood_text(value: String) -> String:
	return {"Happy":"開心","Neutral":"平靜","Sad":"難過","Angry":"生氣","Afraid":"害怕","Tired":"疲憊"}.get(value,value)

func action_text(value: String) -> String:
	return {"Idle":"待命","Moving":"移動","Eat":"用餐","Sleep":"睡眠","Work":"工作","Socialize":"社交","Shop":"採買","GoHome":"回家","Flee":"逃離","Help":"協助","Rest":"休息","Wander":"閒逛"}.get(value,value)

func state_text(value: String) -> String:
	return {"Idle":"待命","Moving":"移動中","PerformingAction":"執行行動","Talking":"交談","Sleeping":"睡眠中","Working":"工作中"}.get(value,value)
