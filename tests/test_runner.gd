extends Node

const UiRefreshSchedulerTest = preload("res://tests/suites/ui_refresh_scheduler_test.gd")

var passed := 0
var failed := 0
var results: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	await get_tree().process_frame
	var test_storage_root := OS.get_environment("ECHO_VILLAGE_TEST_STORAGE_ROOT")
	if test_storage_root.is_empty(): test_storage_root = "res://.test-data"
	var isolated_storage_ready := SaveManager.configure_test_storage(test_storage_root)
	if not isolated_storage_ready:
		check("測試使用隔離存檔目錄", false)
		get_tree().quit(1)
		return
	check("UI 刷新排程器合併髒區域請求", UiRefreshSchedulerTest.run())
	check("Concrete Action scripts use explicit dependencies and instantiate", concrete_action_scripts_test())
	GameManager.new_game()
	check("載入五位 NPC 設定檔", GameManager.npcs.size() == 5)
	check("所有 NPC 具有必要運行狀態", runtime_state_is_valid())
	check("背包增減資料一致", inventory_test())
	check("關係值正確限制在範圍內", relationship_test())
	check("正向互動會建立記憶", memory_test())
	check("存檔與讀檔能還原玩家狀態", save_load_test())
	check("存檔原子寫入與備份復原", save_recovery_test())
	check("糧食短缺會提高麵包價格", event_price_test())
	check("七日加速模擬保持健康", simulation_test())
	check("三十日加速模擬保持健康", long_simulation_stability_test())
	check("展示情境會重現記憶擴散與勇氣決策", showcase_test())
	check("玩家行動會推進村落編年與聲望", community_progress_test())
	check("村落編年會隨遊戲狀態序列化還原", community_progress_save_test())
	check("Living Stories 會產生可選擇且可存檔的分支後果", living_story_contract_test())
	check("故事選擇拒絕重複與未知輸入且不污染狀態", story_choice_safety_test())
	check("每日回音時間軸會分類並彙整重要事件", daily_echoes_summary_test())
	check("每日回音可依日期與分類查詢且維持邊界", daily_echoes_history_filter_test())
	check("每日回音面板提供摘要切換與快捷鍵入口", await daily_echoes_ui_test())
	check("每日回音面板提供歷史日期與分類控制", await daily_echoes_history_ui_test())
	check("日夜階段會正確映射遊戲時間", day_phase_test())
	check("NPC 展示快照會安全提供情緒、需求與關係", npc_showcase_snapshot_test())
	check("日夜視覺設定會提供可用亮度與標籤", visual_profile_test())
	check("主介面具備完整展示控制列與編年面板", await ui_structure_test())
	check("居民互動介面提供情境操作列、靠近提示與結果回饋", await contextual_interaction_ui_test())
	check("故事線面板提供分支選擇與明確關閉路徑", await story_arc_ui_test())
	check("故事線模態入口會暫停模擬並能完整關閉", await story_modal_behavior_test())
	check("關鍵操作具備離散按鍵輸入映射", input_map_test())
	check("繪本美術系統提供角色與日夜視覺資料", village_art_system_test())
	check("擴充內容資料契約可載入", expansion_data_contract_test())
	check("舊版存檔可安全遷移至世界狀態 v2", save_v1_migration_test())
	check("存檔邊界會拒絕損壞與超大資料", save_envelope_validation_test())
	check("偏好設定只接受布林型別", preference_type_safety_test())
	check("林間回音任務可依序推進並原子交付", forest_echo_progression_test())
	check("完成任務後不可重複取得獎勵", quest_reward_idempotency_test())
	check("森林配方製作成功且失敗時不消耗素材", crafting_atomicity_test())
	check("任務追蹤、世界地圖與任務日誌具備完整輸入路徑", await expansion_ui_structure_test())
	check("玩家可由詢問艾莉絲到贈禮黛安娜完成林間回音", quest_player_flow_test())
	check("森林邊境具備獨立的繪本場景繪製契約", forest_visual_contract_test())
	check("主場景提供可重複的視覺 QA 擷取入口", await visual_capture_interface_test())
	check("任務與森林視覺 QA 證據已產生", expansion_visual_capture_test())
	check("消費者主選單與設定介面具備完整入口", await consumer_shell_structure_test())
	check("首次旅程導覽可逐步操作、略過並從暫停選單重開", await onboarding_experience_test())
	check("存檔服務支援繼續遊戲、自動存檔與偏好設定", save_service_capabilities_test())
	check("遊戲時間可以在模態介面期間可靠暫停", game_time_pause_test())
	check("買入與出售交易會原子更新雙方金錢與庫存", trade_atomicity_test())
	check("交易面板提供選品、買入、出售與明確關閉路徑", await trade_ui_structure_test())
	check("背包摘要涵蓋完整物品目錄與森林製作入口", await complete_inventory_ui_test())
	check("NPC runtime 具備完整代理狀態與 NPC 對 NPC 關係", extended_runtime_contract_test())
	check("低重要度記憶會衰減且高重要度記憶受到保護", memory_decay_management_test())
	check("世界事件跨越午夜仍會依持續時間結束", world_event_lifecycle_test())
	check("NPC 受傷事件會產生可追溯後果", npc_injury_event_test())
	check("主場景使用 Godot 2D Navigation 並提供卡住保護", await navigation_runtime_test())
	check("Debug 工具可調整需求、增加物品與傳送玩家", debug_mutation_tools_test())
	check("F3 面板提供可操作的模擬診斷按鈕", await debug_ui_controls_test())
	check("森林互動不會選取未出現在當地的村民", await location_aware_interaction_test())
	check("五位 NPC Profile 具備年齡、對話人格與獨立住宅", npc_profile_consumer_contract_test())
	check("村落美術提供五間可辨識的居民住宅", village_homes_visual_contract_test())
	check("設定切換鈕在選取狀態仍維持高對比文字", await settings_selected_contrast_test())
	check("交易面板開啟時位於所有 HUD 卡片上方", await trade_modal_layering_test())
	check("模態面板互斥且關閉狀態一致", await modal_exclusivity_test())
	check("暫停選單動態偏好與設定頁同步", await motion_preference_sync_test())
	check("任務日誌使用玩家可讀的獎勵與任務名稱", await quest_log_copy_test())
	check("Utility AI 由可擴充的十種 NPC Action Registry 驅動", npc_action_registry_test())
	check("NPC State Machine 管理移動、工作、睡眠與逾時復原", npc_state_machine_test())
	check("十種 NPC 行動皆由獨立具名 Action 類別實作", concrete_npc_actions_test())
	check("Utility AI 支援最低門檻、行動冷卻與 Mood 修正", utility_stability_rules_test())
	check("雨天會降低工作傾向並提高室內社交傾向", rain_event_behavior_test())
	check("危險事件的協助行為會留下記憶並改變 NPC 關係", danger_help_consequence_test())
	check("NPC State Machine 明確支援規格要求的六種核心狀態", state_machine_required_states_test())
	check("玩家 Talk 會進入交談狀態並建立短期記憶", player_talk_flow_test())
	check("NPC 可打招呼、爭執與分享資訊並產生社會後果", npc_social_interaction_modes_test())
	check("森林公共資源可採集且會更新玩家背包與地點狀態", public_resource_gathering_test())
	check("互動列與背包提供正式 Talk 與採集操作", await talk_and_gather_ui_test())
	check("主場景具備平滑 Camera2D、世界邊界與玩家跟隨契約", await player_camera_contract_test())
	check("基礎音效服務可關閉、播放並由設定頁持久控制", await sound_service_and_settings_test())
	check("Optional AIService 僅輸出結構化文本並可安全 fallback", optional_ai_service_contract_test())
	check("Inventory 支援 has_item 並拒絕負數量與非法物品變更", inventory_safety_contract_test())
	check("Needs 成長率會受到 NPC personality 影響且維持一致語意", personality_need_rates_test())
	check("WorldEventManager 管理事件生命週期與完整資料契約", world_event_manager_contract_test())
	check("F3 診斷資訊完整呈現目標、位置、情緒、記憶與路徑", await debug_diagnostics_contract_test())
	check("NPC 每次重要決策都會記錄 Action 與 Utility Score", decision_event_log_contract_test())
	check("Inventory、Needs 與 Relationship 由獨立服務模組負責純邏輯", core_service_boundaries_test())
	check("村落聲望具有五級且邊界計算正確", progression_reputation_tiers_test())
	check("資料驅動成就可依世界快照解鎖", progression_achievement_rules_test())
	check("成就評估具一次性且未知條件安全", progression_idempotency_and_safety_test())
	check("新遊戲會建立可查詢的村落進展快照", progression_game_state_defaults_test())
	check("互動、採集與任務會觸發對應成就", progression_gameplay_unlocks_test())
	check("村落進展可存檔且舊版存檔安全補值", progression_save_compatibility_test())
	check("村落手札提供 P 快捷鍵與完整模態入口", await progression_panel_structure_test())
	check("村落手札清楚呈現稱號、進度與文字化成就狀態", await progression_panel_content_test())
	check("村落手札具 44px 關閉操作且開啟時暫停模擬", await progression_panel_accessibility_test())
	check("村落手札具有可重複的 GPU 視覺 QA 情境", await progression_visual_capture_contract_test())
	write_report()
	print("TEST_RESULT passed=%d failed=%d" % [passed,failed])
	print("Echo Village 測試：%d 通過，%d 失敗" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)

func check(name: String, condition: bool) -> void:
	results.append({"name":name,"passed":condition})
	if condition:
		passed += 1
		print("PASS  " + name)
	else:
		failed += 1
		push_error("FAIL  " + name)

func runtime_state_is_valid() -> bool:
	for npc in GameManager.npcs.values():
		for key in ["position","target","needs","inventory","relationships","memories","mood","action","state"]:
			if not npc.has(key): return false
	return true

func concrete_action_scripts_test() -> bool:
	var scripts := {
		"Eat":"res://scripts/actions/eat_action.gd",
		"Sleep":"res://scripts/actions/sleep_action.gd",
		"Work":"res://scripts/actions/work_action.gd",
		"Socialize":"res://scripts/actions/socialize_action.gd",
		"Wander":"res://scripts/actions/wander_action.gd",
		"Shop":"res://scripts/actions/shop_action.gd",
		"GoHome":"res://scripts/actions/go_home_action.gd",
		"Flee":"res://scripts/actions/flee_action.gd",
		"Help":"res://scripts/actions/help_action.gd",
		"Rest":"res://scripts/actions/rest_action.gd"
	}
	for action_id in scripts:
		var path: String = scripts[action_id]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or not file.get_as_text().begins_with('extends "res://scripts/actions/utility_action.gd"'):
			return false
		var script = load(path)
		var action = script.new() if script != null else null
		if action == null or action.action_id != action_id:
			return false
	return true

func inventory_test() -> bool:
	var inventory := {"bread":1}
	GameManager.add_item(inventory,"bread",2)
	return GameManager.count_item(inventory,"bread") == 3 and GameManager.remove_item(inventory,"bread",3) and GameManager.count_item(inventory,"bread") == 0 and not GameManager.remove_item(inventory,"bread",1)

func relationship_test() -> bool:
	var alice: Dictionary = GameManager.npcs["alice"]
	GameManager.change_relationship(alice,"player",{"trust":999.0,"affinity":-999.0})
	var relation: Dictionary = alice["relationships"]["player"]
	return relation["trust"] == 100.0 and relation["affinity"] == -100.0

func memory_test() -> bool:
	var before: int = int(GameManager.npcs["alice"]["memories"].size())
	GameManager.interact("alice","give_bread")
	return GameManager.npcs["alice"]["memories"].size() == before + 1

func save_load_test() -> bool:
	var original := int(GameManager.player["coin"])
	if not SaveManager.save_game(): return false
	GameManager.player["coin"] = 1
	if not SaveManager.load_game(): return false
	return int(GameManager.player["coin"]) == original

func save_recovery_test() -> bool:
	GameManager.new_game()
	GameManager.player["coin"] = 91
	if not SaveManager.save_game("manual"): return false
	GameManager.player["coin"] = 123
	if not SaveManager.save_game("manual"): return false
	var root := OS.get_environment("ECHO_VILLAGE_TEST_STORAGE_ROOT")
	if root.is_empty(): root = ProjectSettings.globalize_path("res://.test-data")
	var primary := root.path_join("echo_village_save.json")
	var backup := primary + ".bak"
	if not FileAccess.file_exists(backup): return false
	var corrupted := FileAccess.open(primary,FileAccess.WRITE)
	if corrupted == null: return false
	corrupted.store_string(JSON.stringify({"save_version":2,"world_state":{"player":"tampered","npcs":{}}}))
	corrupted.close()
	GameManager.player["coin"] = 777
	if not SaveManager.load_game(): return false
	return int(GameManager.player["coin"]) == 91 and FileAccess.file_exists(backup)

func event_price_test() -> bool:
	GameManager.new_game()
	var normal := GameManager.trade_price("alice","bread")
	GameManager.trigger_world_event("food_shortage")
	var shortage := GameManager.trade_price("alice","bread")
	return shortage > normal

func simulation_test() -> bool:
	GameManager.new_game()
	GameManager.trigger_world_event("minor_danger")
	for _minute in 10080:
		GameTime.advance_minute()
	for npc in GameManager.npcs.values():
		for value in npc["needs"].values():
			if float(value) < 0.0 or float(value) > 100.0: return false
		if npc["state"] == "" or npc["action"] == "": return false
	return true

func long_simulation_stability_test() -> bool:
	GameManager.new_game()
	var started_at := Time.get_ticks_usec()
	for _minute in 43200:
		GameTime.advance_minute()
	var elapsed_ms := int((Time.get_ticks_usec() - started_at) / 1000)
	var snapshot: Dictionary = GameManager.serialize()
	for npc in GameManager.npcs.values():
		for value in npc["needs"].values():
			if float(value) < 0.0 or float(value) > 100.0: return false
		if str(npc.get("state","")) == "" or str(npc.get("action","")) == "": return false
	print("LONG_SIMULATION days=30 elapsed_ms=%d" % elapsed_ms)
	return int(snapshot.get("save_version",0)) >= 3 and snapshot.has("npcs") and snapshot.has("progression")

func showcase_test() -> bool:
	GameManager.load_showcase("rumor")
	var charlie: Dictionary = GameManager.npcs["charlie"]
	var rumor_ok: bool = charlie["memories"].size() > 0 and float(charlie["relationships"]["player"]["trust"]) < 0.0
	GameManager.load_showcase("danger")
	var bravery_ok: bool = GameManager.npcs["alice"]["action"] == "Flee" and GameManager.npcs["bob"]["action"] == "Help"
	return rumor_ok and bravery_ok

func community_progress_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","give_bread")
	var after_kindness: Dictionary = GameManager.community_progress()
	GameManager.interact("bob","steal_food")
	GameManager.trigger_world_event("minor_danger")
	var result: Dictionary = GameManager.community_progress()
	return bool(after_kindness["kindness"]) and int(after_kindness["renown"]) >= 3 and bool(result["rumor"]) and bool(result["crisis"]) and int(result["unlocked"]) == 3

func community_progress_save_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","give_bread")
	var snapshot: Dictionary = GameManager.serialize()
	GameManager.new_game()
	GameManager.deserialize(snapshot)
	var result: Dictionary = GameManager.community_progress()
	return bool(result["kindness"]) and int(result["renown"]) >= 3 and int(result["unlocked"]) == 1

func living_story_contract_test() -> bool:
	if not FileAccess.file_exists("res://data/stories/story_arcs.json"): return false
	if not GameManager.has_method("story_snapshot") or not GameManager.has_method("choose_story_arc"): return false
	GameManager.new_game()
	GameManager.interact("bob","steal_food")
	var active_snapshot: Dictionary = GameManager.story_snapshot()
	var rumor: Dictionary = active_snapshot.get("arcs",{}).get("bread_rumor",{})
	if str(rumor.get("status","")) != "active": return false
	var choice: Dictionary = GameManager.choose_story_arc("bread_rumor","apologize")
	if not bool(choice.get("ok",false)): return false
	var completed: Dictionary = GameManager.story_snapshot().get("arcs",{}).get("bread_rumor",{})
	if str(completed.get("status","")) != "completed": return false
	var relationship: Dictionary = GameManager.npcs["bob"]["relationships"].get("player",{})
	if float(relationship.get("trust",0.0)) <= -25.0: return false
	var serialized: Dictionary = GameManager.serialize()
	GameManager.new_game()
	if not GameManager.deserialize(serialized): return false
	var restored: Dictionary = GameManager.story_snapshot().get("arcs",{}).get("bread_rumor",{})
	return str(restored.get("status","")) == "completed" and int(restored.get("choices_made",[]).size()) == 1

func story_choice_safety_test() -> bool:
	GameManager.new_game()
	GameManager.interact("bob","steal_food")
	var before: Dictionary = GameManager.story_snapshot()
	var unknown: Dictionary = GameManager.choose_story_arc("bread_rumor","not_a_choice")
	if bool(unknown.get("ok",false)) or GameManager.story_snapshot() != before: return false
	var chosen: Dictionary = GameManager.choose_story_arc("bread_rumor","deny")
	if not bool(chosen.get("ok",false)): return false
	var repeated: Dictionary = GameManager.choose_story_arc("bread_rumor","deny")
	return not bool(repeated.get("ok",false)) and GameManager.story_available_choices("bread_rumor").is_empty()

func daily_echoes_summary_test() -> bool:
	GameTime.reset_clock()
	GameManager.new_game()
	GameManager.add_log("玩家與艾莉絲交談。")
	GameManager.trigger_world_event("rain")
	GameManager.add_log("完成任務：「林間回音」。")
	var summary: Dictionary = GameManager.daily_summary()
	var timeline: Array = GameManager.timeline_snapshot("all",GameTime.day,20)
	var snapshot: Dictionary = GameManager.serialize()
	var categories: Dictionary = summary.get("category_counts",{})
	var has_required_fields: bool = not timeline.is_empty() and timeline[0].has_all(["id","day","time","phase","category","message"])
	var classified: bool = int(categories.get("social",0)) > 0 and int(categories.get("world",0)) > 0 and int(categories.get("quest",0)) > 0
	var has_highlights: bool = summary.get("highlights",[]).size() >= 3
	GameManager.new_game()
	var restored: bool = GameManager.deserialize(snapshot)
	var restored_summary: Dictionary = GameManager.daily_summary(1)
	return has_required_fields and classified and has_highlights and restored and int(restored_summary.get("total_events",0)) >= 3

func daily_echoes_history_filter_test() -> bool:
	GameTime.reset_clock()
	GameManager.new_game()
	GameManager.add_log("玩家與艾莉絲交談。")
	GameManager.add_log("玩家買入麵包。")
	GameTime.day = 2
	GameTime.minute = 360
	GameManager.add_log("第二天完成任務。")
	var social_day_one: Array = GameManager.timeline_snapshot("social",1,20)
	var economy_day_one: Array = GameManager.timeline_snapshot("economy",1,20)
	var day_one: Array = GameManager.timeline_snapshot("all",1,20)
	var day_two: Array = GameManager.timeline_snapshot("all",2,20)
	var bounded: Array = GameManager.timeline_snapshot("all",-1,1)
	var filtered_summary: Dictionary = GameManager.daily_summary(1,"social")
	var all_social: bool = not social_day_one.is_empty()
	for value in social_day_one:
		all_social = all_social and int(value.get("day",0)) == 1 and str(value.get("category","")) == "social"
	var summary_is_filtered: bool = int(filtered_summary.get("total_events",0)) == 1 and int(filtered_summary.get("category_counts",{}).get("social",0)) == 1 and int(filtered_summary.get("category_counts",{}).get("economy",0)) == 0
	return all_social and economy_day_one.size() == 1 and day_one.size() >= 3 and day_two.size() == 1 and bounded.size() == 1 and summary_is_filtered

func daily_echoes_ui_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.main_menu_panel.visible = false
	instance.set_journal_mode("chronicle")
	var button := instance.get_node_or_null("CanvasLayer/ChroniclePanel/DailySummaryButton") as Button
	var has_daily_entry: bool = button != null and button.text.contains("今日回音")
	instance.set_journal_mode("daily")
	instance.open_side_panel(instance.journal_panel)
	instance.refresh_ui()
	var text := str(instance.journal_label.text)
	var title := str(instance.journal_title_label.text)
	var result: bool = has_daily_entry and button != null and button.text.contains("村落編年") and title.contains("今日回音") and text.contains("事件") and InputMap.has_action("daily_summary")
	if button != null:
		button.emit_signal("pressed")
		var toggled_back: bool = instance.journal_mode == "chronicle" and str(instance.journal_title_label.text).contains("村落編年") and button.text.contains("今日回音")
		result = result and toggled_back
	instance.queue_free()
	return result

func daily_echoes_history_ui_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	GameTime.reset_clock()
	GameManager.new_game()
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.main_menu_panel.visible = false
	instance.set_journal_mode("daily")
	var previous := instance.get_node_or_null("CanvasLayer/ChroniclePanel/DailyPrevButton") as Button
	var next := instance.get_node_or_null("CanvasLayer/ChroniclePanel/DailyNextButton") as Button
	var filter := instance.get_node_or_null("CanvasLayer/ChroniclePanel/DailyFilterButton") as Button
	instance.set_daily_echo_day(0)
	instance.set_daily_echo_category("social")
	instance.refresh_ui()
	var text := str(instance.journal_label.text)
	var result: bool = previous != null and next != null and filter != null and previous.disabled and next.disabled and instance.daily_echo_day == 1 and instance.daily_echo_category == "social" and text.contains("居民")
	if filter != null:
		filter.emit_signal("pressed")
		result = result and instance.daily_echo_category == "world" and filter.text.contains("世界")
	instance.set_daily_echo_day(99)
	result = result and instance.daily_echo_day == GameTime.day
	instance.queue_free()
	return result

func day_phase_test() -> bool:
	return GameTime.phase_for_minute(360) == "黎明" and GameTime.phase_for_minute(780) == "正午" and GameTime.phase_for_minute(1140) == "黃昏" and GameTime.phase_for_minute(60) == "深夜"

func npc_showcase_snapshot_test() -> bool:
	GameManager.new_game()
	var snapshot: Dictionary = GameManager.npc_showcase_snapshot("alice")
	if snapshot.is_empty() or not snapshot.has_all(["display_name","mood","action","needs","relationship","memory_count","goal"]): return false
	var original_hunger: float = float(GameManager.npcs["alice"]["needs"]["hunger"])
	snapshot["needs"]["hunger"] = 99.0
	return float(GameManager.npcs["alice"]["needs"]["hunger"]) == original_hunger

func visual_profile_test() -> bool:
	var night: Dictionary = GameTime.visual_profile(60)
	var noon: Dictionary = GameTime.visual_profile(780)
	return night["phase"] == "深夜" and float(night["light"]) < 0.5 and noon["phase"] == "正午" and float(noon["light"]) > 0.9

func ui_structure_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var required := ["CanvasLayer/TimeControls","CanvasLayer/ChroniclePanel","CanvasLayer/InventoryPanel","CanvasLayer/PausePanel"]
	var result := true
	for path in required:
		if instance.get_node_or_null(path) == null:
			print("UI 缺少節點：" + path)
			result = false
	instance.queue_free()
	return result

func input_map_test() -> bool:
	for action in ["interact","inventory","journal","story_arcs","cancel","speed_normal","speed_2x","speed_5x","speed_10x","save_game","load_game","event_rain","event_festival","event_shortage","event_danger"]:
		if not InputMap.has_action(action): return false
	return true

func contextual_interaction_ui_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var dock := instance.get_node_or_null("CanvasLayer/ActionDock") as Control
	var prompt := instance.get_node_or_null("CanvasLayer/InteractionPrompt") as Control
	var feedback := instance.get_node_or_null("CanvasLayer/ImpactFeedback") as Control
	var action_count := 0
	if dock != null:
		for child in dock.get_children():
			if child is Button: action_count += 1
	var result := dock != null and prompt != null and feedback != null and action_count == 5 and instance.has_method("show_interaction_feedback")
	instance.queue_free()
	return result

func village_art_system_test() -> bool:
	var art = load("res://scripts/ui/village_art.gd")
	if art == null or not FileAccess.file_exists("res://assets/art/visual_palette.json"): return false
	var alice: Dictionary = art.character_style("alice")
	var night: Dictionary = art.time_palette(0.2,true)
	return alice.has_all(["body","hair","outfit","accent","role_prop"]) and night.has_all(["sky","ground","water","window_light","overlay_alpha"])

func expansion_data_contract_test() -> bool:
	return GameManager.has_method("has_expansion_data") and GameManager.has_expansion_data()

func save_v1_migration_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice", "give_bread")
	var legacy := {"save_version":1, "time":GameTime.serialize(), "world":GameManager.legacy_serialize()}
	var migration = load("res://scripts/save/save_migration.gd")
	if migration == null or not migration.has_method("migrate"): return false
	var result: Dictionary = migration.migrate(legacy)
	if not bool(result.get("ok",false)): return false
	var migrated: Dictionary = result.get("data",{})
	var state: Dictionary = migrated.get("world_state",{})
	return int(migrated.get("save_version",0)) == 2 and state.has_all(["player","npcs","current_location","discovered_locations","active_quests","completed_quests","world_flags"]) and int(state["player"]["inventory"].get("bread",0)) == 2

func save_envelope_validation_test() -> bool:
	var migration = load("res://scripts/save/save_migration.gd")
	if migration == null or not migration.has_method("migrate"): return false
	var malformed := [
		{"save_version":2,"world_state":{"player":"tampered","npcs":{}}},
		{"save_version":2,"world_state":{"player":{"inventory":[]},"npcs":{}}},
		{"save_version":1,"time":GameTime.serialize(),"world":{"player":"tampered","npcs":[]}},
		{"save_version":1,"time":GameTime.serialize(),"world":{"player":{},"npcs":{"alice":"tampered"}}}
	]
	for payload in malformed:
		if bool(migration.migrate(payload).get("ok",false)): return false
	var oversized: Dictionary = GameManager.serialize()
	var timeline: Array = []
	for _index in 513: timeline.append({"message":"oversized"})
	oversized["timeline_events"] = timeline
	var oversized_result: Dictionary = migration.migrate({"save_version":2,"world_state":oversized})
	if bool(oversized_result.get("ok",false)): return false
	var safe_state: Dictionary = GameManager.serialize()
	var invalid_times: Array = [
		{"minute":"tampered","day":1,"day_of_week":1,"time_scale":1.0},
		{"minute":-1,"day":1,"day_of_week":1,"time_scale":1.0},
		{"minute":1440,"day":1,"day_of_week":1,"time_scale":1.0},
		{"minute":360,"day":0,"day_of_week":1,"time_scale":1.0},
		{"minute":360,"day":1,"day_of_week":8,"time_scale":1.0},
		{"minute":360,"day":1,"day_of_week":1,"time_scale":0.0},
		{"minute":[],"day":1,"day_of_week":1,"time_scale":1.0}
	]
	for invalid_time in invalid_times:
		if bool(migration.migrate({"save_version":2,"time":invalid_time,"world_state":safe_state}).get("ok",false)): return false
	GameTime.deserialize({"minute":"tampered","day":-1,"day_of_week":99,"time_scale":0.0})
	var direct_time_safe := GameTime.minute == 360 and GameTime.day == 1 and GameTime.day_of_week == 1 and is_equal_approx(GameTime.time_scale,1.0)
	GameTime.reset_clock()
	if not direct_time_safe: return false
	var malformed_state_accepted := GameManager.deserialize({"player":"tampered","npcs":{}})
	GameManager.new_game()
	if malformed_state_accepted: return false
	if not bool(migration.migrate({"save_version":2,"world_state":GameManager.serialize()}).get("ok",false)): return false
	var temp_path := SaveManager._storage_path("echo_village_oversized_test.tmp","user://echo_village_oversized_test.tmp")
	var temp_file := FileAccess.open(temp_path,FileAccess.WRITE)
	if temp_file == null: return false
	temp_file.store_string("x".repeat(SaveManager.MAX_SAVE_BYTES + 1))
	temp_file.close()
	var rejected_oversized_file := SaveManager.read_limited_text(temp_path,SaveManager.MAX_SAVE_BYTES).is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	if not rejected_oversized_file: return false
	var malformed_vectors: Array = [
		{"__vector2":[]},
		{"__vector2":[1]},
		{"__vector2":"tampered"},
		{"nested":{"__vector2":[1]}}
	]
	for malformed_vector in malformed_vectors:
		var decoded = GameManager.decode_value(malformed_vector)
		if not (decoded is Dictionary) or decoded.has("__vector2"): return false
	var valid_vector = GameManager.decode_value({"__vector2":[12,34]})
	if not (valid_vector is Vector2) or valid_vector != Vector2(12,34): return false
	var deeply_nested: Dictionary = {"leaf":"ok"}
	for _depth in 96: deeply_nested = {"nested":deeply_nested}
	if not (GameManager.decode_value(deeply_nested) is Dictionary): return false
	return true

func preference_type_safety_test() -> bool:
	if not SaveManager.has_method("sanitize_preferences"): return false
	var original: Dictionary = SaveManager.preferences.duplicate(true)
	var sanitized: Dictionary = SaveManager.sanitize_preferences({"autosave":"false","motion":0,"fullscreen":1,"audio":false,"onboarding_seen":"true"})
	return sanitized.get("autosave") == original.get("autosave") and sanitized.get("motion") == original.get("motion") and sanitized.get("fullscreen") == original.get("fullscreen") and sanitized.get("audio") == false and sanitized.get("onboarding_seen") == original.get("onboarding_seen")

func forest_echo_progression_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("accept_quest"): return false
	if not bool(GameManager.accept_quest("forest_echo").get("ok",false)): return false
	GameManager.interact("alice","ask")
	if not bool(GameManager.travel_to("forest_edge").get("ok",false)): return false
	var bread_before := GameManager.count_item(GameManager.player["inventory"],"bread")
	GameManager.remove_item(GameManager.player["inventory"],"bread",bread_before)
	var blocked: Dictionary = GameManager.complete_delivery("forest_echo","bread",1)
	if bool(blocked.get("ok",false)) or GameManager.is_quest_completed("forest_echo"): return false
	GameManager.add_item(GameManager.player["inventory"],"bread",1)
	var complete: Dictionary = GameManager.complete_delivery("forest_echo","bread",1)
	return bool(complete.get("ok",false)) and GameManager.is_quest_completed("forest_echo") and GameManager.current_location == "forest_edge" and "forest_edge" in GameManager.discovered_locations and GameManager.count_item(GameManager.player["inventory"],"herb") == 2

func quest_reward_idempotency_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("accept_quest"): return false
	GameManager.accept_quest("forest_echo")
	GameManager.interact("alice","ask")
	GameManager.travel_to("forest_edge")
	GameManager.complete_delivery("forest_echo","bread",1)
	var coin_after := int(GameManager.player["coin"])
	var herb_after := GameManager.count_item(GameManager.player["inventory"],"herb")
	var duplicate: Dictionary = GameManager.complete_delivery("forest_echo","bread",1)
	return not bool(duplicate.get("ok",false)) and int(GameManager.player["coin"]) == coin_after and GameManager.count_item(GameManager.player["inventory"],"herb") == herb_after

func crafting_atomicity_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("craft_recipe"): return false
	GameManager.current_location = "forest_edge"
	GameManager.add_item(GameManager.player["inventory"],"herb",2)
	var medicine_before := GameManager.count_item(GameManager.player["inventory"],"medicine")
	var crafted: Dictionary = GameManager.craft_recipe("forest_remedy")
	var failed: Dictionary = GameManager.craft_recipe("forest_remedy")
	return bool(crafted.get("ok",false)) and not bool(failed.get("ok",false)) and GameManager.count_item(GameManager.player["inventory"],"medicine") == medicine_before + 1 and GameManager.count_item(GameManager.player["inventory"],"herb") == 0

func expansion_ui_structure_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var result := instance.get_node_or_null("CanvasLayer/QuestTracker") != null and instance.get_node_or_null("CanvasLayer/WorldMapPanel") != null and instance.get_node_or_null("CanvasLayer/QuestLogPanel") != null and InputMap.has_action("world_map") and InputMap.has_action("quest_log")
	instance.queue_free()
	return result

func quest_player_flow_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","ask")
	if not GameManager.active_quests.has("forest_echo"): return false
	if int(GameManager.active_quests["forest_echo"].get("objective_index",0)) != 1: return false
	if not bool(GameManager.travel_to("forest_edge").get("ok",false)): return false
	var response := GameManager.interact("diana","give_bread")
	return GameManager.is_quest_completed("forest_echo") and response.contains("林間回音") and bool(GameManager.world_flags.get("forest_echo_complete",false))

func forest_visual_contract_test() -> bool:
	var art = load("res://scripts/ui/village_art.gd")
	return art != null and art.has_method("draw_forest_edge")

func visual_capture_interface_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var result := instance.has_method("capture_visual_qa") and instance.has_method("visual_qa_capture_names")
	if result:
		var names: Array = instance.visual_qa_capture_names()
		for expected in ["quest_in_progress.png","forest_echo_complete.png","consumer_main_menu.png","consumer_settings.png","consumer_trade.png","village_progression.png","story_arc_active.png","consumer_onboarding.png"]: result = result and expected in names
	instance.queue_free()
	return result

func expansion_visual_capture_test() -> bool:
	for expected in ["quest_in_progress.png","forest_echo_complete.png","consumer_main_menu.png","consumer_settings.png","consumer_trade.png","village_progression.png","story_arc_active.png","consumer_onboarding.png"]:
		if not FileAccess.file_exists("res://tests/visual_qa/" + expected): return false
	return true

func consumer_shell_structure_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var required := [
		"CanvasLayer/MainMenu",
		"CanvasLayer/MainMenu/NewGameButton",
		"CanvasLayer/MainMenu/ContinueButton",
		"CanvasLayer/MainMenu/SettingsButton",
		"CanvasLayer/SettingsPanel",
		"CanvasLayer/SettingsPanel/AutosaveToggle",
		"CanvasLayer/SettingsPanel/MotionToggle",
		"CanvasLayer/SettingsPanel/FullscreenToggle"
	]
	var result := instance.has_method("start_new_game") and instance.has_method("continue_game") and instance.has_method("open_settings")
	for path in required: result = result and instance.get_node_or_null(path) != null
	instance.queue_free()
	return result

func save_service_capabilities_test() -> bool:
	return SaveManager.has_method("has_save") and SaveManager.has_method("autosave_game") and SaveManager.has_method("load_preferences") and SaveManager.has_method("set_preference")

func game_time_pause_test() -> bool:
	if not GameTime.has_method("set_simulation_paused"): return false
	GameTime.set_simulation_paused(true)
	var paused_ok: bool = bool(GameTime.simulation_paused)
	GameTime.set_simulation_paused(false)
	return paused_ok and not bool(GameTime.simulation_paused)

func trade_atomicity_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("buy_item") or not GameManager.has_method("sell_item"): return false
	var player_coin_before := int(GameManager.player["coin"])
	var player_bread_before := GameManager.count_item(GameManager.player["inventory"],"bread")
	var alice_bread_before := GameManager.count_item(GameManager.npcs["alice"]["inventory"],"bread")
	var bought: Dictionary = GameManager.buy_item("alice","bread",1)
	if not bool(bought.get("ok",false)): return false
	if int(GameManager.player["coin"]) >= player_coin_before or GameManager.count_item(GameManager.player["inventory"],"bread") != player_bread_before + 1 or GameManager.count_item(GameManager.npcs["alice"]["inventory"],"bread") != alice_bread_before - 1: return false
	var snapshot := GameManager.serialize()
	var invalid: Dictionary = GameManager.buy_item("alice","missing_item",1)
	if bool(invalid.get("ok",false)) or GameManager.serialize() != snapshot: return false
	var medicine_before := GameManager.count_item(GameManager.player["inventory"],"medicine")
	var sold: Dictionary = GameManager.sell_item("alice","medicine",1)
	return bool(sold.get("ok",false)) and GameManager.count_item(GameManager.player["inventory"],"medicine") == medicine_before - 1 and int(GameManager.player["coin"]) > int(snapshot["player"]["coin"])

func trade_ui_structure_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var required := ["CanvasLayer/TradePanel","CanvasLayer/TradePanel/ItemSelector","CanvasLayer/TradePanel/BuyButton","CanvasLayer/TradePanel/SellButton","CanvasLayer/TradePanel/CloseButton"]
	var result := instance.has_method("open_trade_panel")
	for path in required: result = result and instance.get_node_or_null(path) != null
	instance.queue_free()
	return result

func complete_inventory_ui_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var summary := str(instance.inventory_summary()) if instance.has_method("inventory_summary") else ""
	var result := instance.get_node_or_null("CanvasLayer/InventoryPanel/CraftButton") != null
	for item_name in ["麵包","蔬菜","木材","藥品","月光藥草"]: result = result and summary.contains(item_name)
	instance.queue_free()
	return result

func extended_runtime_contract_test() -> bool:
	GameManager.new_game()
	var required := ["current_location","current_action","current_target","temporary_modifiers","current_goal"]
	for npc_id in GameManager.npcs:
		var npc: Dictionary = GameManager.npcs[npc_id]
		if not npc.has_all(required): return false
		for target_id in GameManager.npcs:
			if target_id != npc_id and not npc["relationships"].has(target_id): return false
	return true

func memory_decay_management_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("decay_memories"): return false
	GameManager.create_memory("alice","small_talk","一段普通閒聊。",1,4)
	GameManager.create_memory("alice","life_event","一段重要的人生事件。",20,80)
	GameManager.decay_memories(GameManager.npcs["alice"],2)
	var has_low := false
	var has_high := false
	for memory in GameManager.npcs["alice"]["memories"]:
		has_low = has_low or str(memory["event_type"]) == "small_talk"
		has_high = has_high or str(memory["event_type"]) == "life_event"
	return not has_low and has_high and GameManager.npcs["alice"]["memories"].size() <= GameManager.MAX_MEMORIES_PER_NPC

func world_event_lifecycle_test() -> bool:
	GameManager.new_game()
	GameTime.minute = 1438
	GameTime.day = 1
	GameManager.trigger_world_event("rain")
	var duration := int(GameManager.active_event.get("duration",0))
	for _index in duration + 1: GameTime.advance_minute()
	return GameManager.active_event.is_empty() and GameTime.day >= 2

func npc_injury_event_test() -> bool:
	GameManager.new_game()
	if not GameManager.event_defs.has("npc_injury"): return false
	var energy_before := float(GameManager.npcs["eric"]["needs"]["energy"])
	var memories_before: int = int(GameManager.npcs["eric"]["memories"].size())
	GameManager.trigger_world_event("npc_injury")
	return str(GameManager.active_event.get("target_npc_id","")) == "eric" and float(GameManager.npcs["eric"]["needs"]["energy"]) < energy_before and GameManager.npcs["eric"]["memories"].size() == memories_before + 1

func navigation_runtime_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var coordinator := instance.get_node_or_null("NavigationCoordinator")
	var agent_count := coordinator.find_children("*","NavigationAgent2D",true,false).size() if coordinator != null else 0
	var result := coordinator != null and agent_count == 5 and coordinator.has_method("debug_paths") and coordinator.has_method("recover_stalled_agent")
	instance.queue_free()
	return result

func debug_mutation_tools_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("debug_adjust_need") or not GameManager.has_method("debug_add_player_item") or not GameManager.has_method("debug_teleport_player_to_npc"): return false
	var bread_before := GameManager.count_item(GameManager.player["inventory"],"bread")
	GameManager.debug_add_player_item("bread",2)
	GameManager.debug_adjust_need("alice","hunger",99.0)
	var teleported: Dictionary = GameManager.debug_teleport_player_to_npc("alice")
	return GameManager.count_item(GameManager.player["inventory"],"bread") == bread_before + 2 and float(GameManager.npcs["alice"]["needs"]["hunger"]) == 100.0 and bool(teleported.get("ok",false)) and GameManager.player["position"].distance_to(GameManager.npcs["alice"]["position"]) < 50.0

func debug_ui_controls_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var required := ["CanvasLayer/DebugOverlay/AddBreadButton","CanvasLayer/DebugOverlay/StressNeedButton","CanvasLayer/DebugOverlay/TeleportButton","CanvasLayer/DebugOverlay/InjuryEventButton"]
	var result := true
	for path in required: result = result and instance.get_node_or_null(path) != null
	instance.queue_free()
	return result

func location_aware_interaction_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	GameManager.current_location = "forest_edge"
	GameManager.player["position"] = GameManager.npcs["alice"]["position"]
	var nearest := str(instance.nearest_npc_id(40.0))
	var result: bool = nearest == "" and instance.npc_is_present("diana") and instance.npc_is_present("eric") and not instance.npc_is_present("alice")
	instance.queue_free()
	return result

func npc_profile_consumer_contract_test() -> bool:
	var homes := {}
	for profile in GameManager.npc_profiles.get("npcs",[]):
		if not profile.has_all(["age","dialogue_profile","home_location"]): return false
		if int(profile["age"]) < 18 or not (profile["dialogue_profile"] is Dictionary) or profile["dialogue_profile"].is_empty(): return false
		homes[str(profile["home_location"])] = true
	return homes.size() == 5

func village_homes_visual_contract_test() -> bool:
	var art = load("res://scripts/ui/village_art.gd")
	return art != null and art.has_method("draw_cottage") and GameManager.npcs["alice"]["home_location"] == "alice_home" and GameManager.target_for(GameManager.npcs["alice"],"GoHome") != GameManager.target_for(GameManager.npcs["alice"],"Work")

func settings_selected_contrast_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var toggle := instance.get_node_or_null("CanvasLayer/SettingsPanel/AutosaveToggle") as CheckButton
	var theme = load("res://scripts/ui/ui_theme.gd")
	var result: bool = toggle != null and toggle.get_theme_color("font_pressed_color") == theme.INK
	instance.queue_free()
	return result

func trade_modal_layering_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.main_menu_panel.visible = false
	instance.selected_id = "alice"
	GameManager.player["position"] = GameManager.npcs["alice"]["position"]
	instance.open_trade_panel()
	var panel := instance.get_node_or_null("CanvasLayer/TradePanel")
	var result: bool = panel != null and panel.get_index() == panel.get_parent().get_child_count() - 1
	instance.queue_free()
	return result

func story_arc_ui_test() -> bool:
	var scene := load("res://scenes/ui/StoryArcPanel.tscn") as PackedScene
	if scene == null: return false
	GameManager.new_game()
	GameManager.interact("bob","steal_food")
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.refresh(GameManager.story_snapshot())
	var close_button := instance.get_node_or_null("CloseButton") as Button
	var choices := instance.get_node_or_null("DetailPanel/ChoiceList") as VBoxContainer
	var result := close_button != null and close_button.text.contains("關閉") and choices != null and choices.get_child_count() == 2 and instance.has_method("set_visible_with_motion")
	instance.queue_free()
	return result

func story_modal_behavior_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.main_menu_panel.visible = false
	GameManager.new_game()
	instance.open_story_panel()
	var opened: bool = instance.story_arc_panel.visible and bool(GameTime.simulation_paused)
	instance.story_arc_panel.visible = false
	instance.sync_simulation_pause()
	var closed: bool = not instance.story_arc_panel.visible and not bool(GameTime.simulation_paused)
	instance.queue_free()
	return opened and closed

func onboarding_experience_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var previous_seen := SaveManager.get_preference("onboarding_seen",false)
	SaveManager.preferences["onboarding_seen"] = false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.start_new_game()
	await get_tree().process_frame
	var panel := instance.get_node_or_null("CanvasLayer/OnboardingPanel") as Panel
	var backdrop := instance.get_node_or_null("CanvasLayer/OnboardingBackdrop") as ColorRect
	var next := instance.get_node_or_null("CanvasLayer/OnboardingPanel/NextButton") as Button
	var skip := instance.get_node_or_null("CanvasLayer/OnboardingPanel/SkipButton") as Button
	var guide := instance.get_node_or_null("CanvasLayer/PausePanel/GuideButton") as Button
	var pause_motion := instance.pause_motion_button as Button
	var step_label := instance.get_node_or_null("CanvasLayer/OnboardingPanel/StepLabel") as Label
	var pause_layout_ok: bool = guide != null and pause_motion != null and guide.position.y + guide.size.y <= instance.pause_panel.size.y and guide.position.y + guide.size.y <= pause_motion.position.y
	var result: bool = panel != null and backdrop != null and next != null and skip != null and guide != null and step_label != null and pause_layout_ok and panel.visible and backdrop.visible and step_label.text.contains("1 / 3") and bool(GameTime.simulation_paused)
	if next != null:
		next.emit_signal("pressed")
		result = result and step_label.text.contains("2 / 3")
	if skip != null:
		skip.emit_signal("pressed")
		result = result and not panel.visible and SaveManager.get_preference("onboarding_seen",false) and not bool(GameTime.simulation_paused)
	if guide != null:
		instance.pause_panel.visible = true
		instance.sync_simulation_pause()
		guide.emit_signal("pressed")
		result = result and panel.visible and step_label.text.contains("1 / 3") and bool(GameTime.simulation_paused)
	instance.queue_free()
	SaveManager.set_preference("onboarding_seen",previous_seen)
	return result

func modal_exclusivity_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null: return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.main_menu_panel.visible = false
	instance.open_side_panel(instance.inventory_panel)
	var inventory_open: bool = instance.inventory_panel.visible and not instance.journal_panel.visible
	instance.open_side_panel(instance.journal_panel)
	var journal_replaced: bool = instance.journal_panel.visible and not instance.inventory_panel.visible
	instance.toggle_modal_panel(instance.progression_panel)
	var progression_replaced: bool = instance.progression_panel.visible and not instance.journal_panel.visible
	instance.close_modal_panels()
	var all_closed: bool = not instance.inventory_panel.visible and not instance.journal_panel.visible and not instance.progression_panel.visible and not instance.trade_panel.visible
	instance.queue_free()
	return inventory_open and journal_replaced and progression_replaced and all_closed

func motion_preference_sync_test() -> bool:
	var previous := SaveManager.get_preference("motion",true)
	SaveManager.set_preference("motion",false)
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	if scene == null:
		SaveManager.set_preference("motion",previous)
		return false
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var pause_button := instance.pause_motion_button as Button
	var settings_toggle := instance.motion_toggle as CheckButton
	var disabled_state: bool = not instance.motion_enabled and pause_button != null and pause_button.text.contains("關") and settings_toggle != null and not settings_toggle.button_pressed
	instance.set_motion_enabled(true)
	var enabled_state := bool(SaveManager.get_preference("motion",false)) and pause_button.text.contains("開") and settings_toggle.button_pressed
	instance.queue_free()
	SaveManager.set_preference("motion",previous)
	return disabled_state and enabled_state

func quest_log_copy_test() -> bool:
	GameManager.new_game()
	var scene := load("res://scenes/ui/QuestLogPanel.tscn") as PackedScene
	if scene == null: return false
	var panel := scene.instantiate()
	add_child(panel)
	panel.refresh([{"title":"林間回音","description":"測試任務","objective":{"description":"測試目標"},"rewards":{"coin":8,"herb":2}}],["forest_echo"])
	var body := str(panel.body_label.text)
	panel.queue_free()
	return body.contains("金幣 +8") and body.contains("月光藥草 +2") and body.contains("林間回音") and not body.contains("{\"coin\"") and not body.contains("forest_echo")

func npc_action_registry_test() -> bool:
	var registry_script = load("res://scripts/ai/action_registry.gd")
	if registry_script == null: return false
	var registry = registry_script.new()
	var expected := ["Eat","Sleep","Work","Socialize","Wander","Shop","GoHome","Flee","Help","Rest"]
	if registry.action_ids() != expected: return false
	for action_id in expected:
		var action = registry.get_action(action_id)
		if action == null or not action.has_method("can_execute") or not action.has_method("calculate_score") or not action.has_method("start") or not action.has_method("update") or not action.has_method("finish") or not action.has_method("cancel"): return false
	GameManager.new_game()
	var npc: Dictionary = GameManager.npcs["alice"]
	var context: Dictionary = GameManager.action_context(npc)
	var baseline: Dictionary = registry.calculate_scores(npc,context)
	npc["needs"]["hunger"] = 96.0
	var hungry: Dictionary = registry.calculate_scores(npc,GameManager.action_context(npc))
	return baseline.size() == expected.size() and float(hungry["Eat"]) > float(baseline["Eat"])

func npc_state_machine_test() -> bool:
	var machine_script = load("res://scripts/npc/npc_state_machine.gd")
	if machine_script == null: return false
	var machine = machine_script.new()
	GameManager.new_game()
	var npc: Dictionary = GameManager.npcs["bob"]
	machine.transition_for_action(npc,"Work",Vector2(1000,500),0)
	var moving_ok: bool = npc["state"] == "Moving" and npc["current_action"] == "Work"
	npc["position"] = npc["current_target"]
	machine.update(npc,1)
	var working_ok: bool = npc["state"] == "Working"
	machine.transition_for_action(npc,"Sleep",npc["position"],2)
	var sleeping_ok: bool = npc["state"] == "Sleeping"
	npc["state_entered_minute"] = -100
	machine.update(npc,100)
	return moving_ok and working_ok and sleeping_ok and npc["state"] == "Idle"

func concrete_npc_actions_test() -> bool:
	var expected := {
		"Eat":"eat_action.gd", "Sleep":"sleep_action.gd", "Work":"work_action.gd",
		"Socialize":"socialize_action.gd", "Wander":"wander_action.gd", "Shop":"shop_action.gd",
		"GoHome":"go_home_action.gd", "Flee":"flee_action.gd", "Help":"help_action.gd", "Rest":"rest_action.gd"
	}
	for action_id in expected:
		var action = GameManager.action_registry.get_action(action_id)
		if action == null or not str(action.get_script().resource_path).ends_with(str(expected[action_id])): return false
	return true

func utility_stability_rules_test() -> bool:
	GameManager.new_game()
	if GameManager.get("minimum_action_score") == null: return false
	var npc: Dictionary = GameManager.npcs["bob"]
	var context: Dictionary = GameManager.action_context(npc)
	context["action_cooldowns"] = {"Work":GameTime.minute + 30}
	var scores: Dictionary = GameManager.action_registry.calculate_scores(npc,context)
	var cooldown_ok: bool = float(scores["Work"]) <= -999.0
	npc["mood"] = "Afraid"
	var afraid_scores: Dictionary = GameManager.action_registry.calculate_scores(npc,GameManager.action_context(npc))
	npc["mood"] = "Neutral"
	var neutral_scores: Dictionary = GameManager.action_registry.calculate_scores(npc,GameManager.action_context(npc))
	return cooldown_ok and float(afraid_scores["Flee"]) > float(neutral_scores["Flee"])

func rain_event_behavior_test() -> bool:
	GameManager.new_game()
	var bob: Dictionary = GameManager.npcs["bob"]
	var normal: Dictionary = GameManager.utility_scores(bob)
	GameManager.trigger_world_event("rain")
	var rainy: Dictionary = GameManager.utility_scores(bob)
	return float(rainy["Work"]) < float(normal["Work"]) and float(rainy["Socialize"]) > float(normal["Socialize"])

func danger_help_consequence_test() -> bool:
	GameManager.load_showcase("danger")
	var found_memory := false
	var found_relationship := false
	for npc_id in GameManager.npcs:
		var npc: Dictionary = GameManager.npcs[npc_id]
		for memory in npc["memories"]:
			found_memory = found_memory or str(memory.get("event_type","")) == "npc_helped_npc"
		for target_id in npc["relationships"]:
			if target_id != "player": found_relationship = found_relationship or float(npc["relationships"][target_id].get("respect",0.0)) > 0.0
	return found_memory and found_relationship

func state_machine_required_states_test() -> bool:
	var required := ["Idle","Moving","PerformingAction","Talking","Sleeping","Working"]
	return GameManager.npc_state_machine.has_method("available_states") and GameManager.npc_state_machine.available_states() == required

func player_talk_flow_test() -> bool:
	GameManager.new_game()
	var before: int = GameManager.npcs["alice"]["memories"].size()
	var response := GameManager.interact("alice","talk")
	var latest: Dictionary = GameManager.npcs["alice"]["memories"].back() if GameManager.npcs["alice"]["memories"].size() > 0 else {}
	return response != "" and GameManager.npcs["alice"]["state"] == "Talking" and GameManager.npcs["alice"]["memories"].size() == before + 1 and str(latest.get("event_type","")) == "small_talk"

func npc_social_interaction_modes_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("social_interaction"): return false
	var affinity_before := float(GameManager.npcs["bob"]["relationships"]["charlie"]["affinity"])
	var greeted: Dictionary = GameManager.social_interaction("bob","charlie","greet")
	if not bool(greeted.get("ok",false)) or float(GameManager.npcs["bob"]["relationships"]["charlie"]["affinity"]) <= affinity_before: return false
	GameManager.create_memory("bob","saw_event","鮑伯看見玩家幫助村民。",18,70,"player","bob")
	var shared: Dictionary = GameManager.social_interaction("bob","charlie","share_information")
	var trust_before := float(GameManager.npcs["bob"]["relationships"]["charlie"]["trust"])
	var argued: Dictionary = GameManager.social_interaction("bob","charlie","argue")
	return bool(shared.get("ok",false)) and bool(argued.get("ok",false)) and GameManager.npcs["charlie"]["memories"].size() > 0 and float(GameManager.npcs["bob"]["relationships"]["charlie"]["trust"]) < trust_before

func public_resource_gathering_test() -> bool:
	GameManager.new_game()
	GameManager.current_location = "forest_edge"
	var before := GameManager.count_item(GameManager.player["inventory"],"herb")
	var result: Dictionary = GameManager.gather_location_resource("herb") if GameManager.has_method("gather_location_resource") else {"ok":false}
	return bool(result.get("ok",false)) and GameManager.count_item(GameManager.player["inventory"],"herb") == before + 1 and int(GameManager.world_flags.get("forest_herbs_gathered",0)) == 1

func talk_and_gather_ui_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var result := instance.get_node_or_null("CanvasLayer/ActionDock/TalkButton") != null and instance.get_node_or_null("CanvasLayer/InventoryPanel/GatherButton") != null and InputMap.has_action("talk")
	instance.queue_free()
	return result

func player_camera_contract_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var camera := instance.get_node_or_null("PlayerCamera") as Camera2D
	var start := camera.position if camera != null else Vector2.ZERO
	GameManager.player["position"] = Vector2(800,420)
	instance.update_player_camera(0.5) if instance.has_method("update_player_camera") else false
	var result: bool = camera != null and camera.position_smoothing_enabled and not camera.limit_smoothed and camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 1280 and camera.limit_bottom == 720 and camera.position == start and instance.get("camera_follow_target") == GameManager.player["position"]
	instance.queue_free()
	return result

func sound_service_and_settings_test() -> bool:
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager == null or not sound_manager.has_method("play_ui") or not sound_manager.has_method("play_interaction") or not sound_manager.has_method("set_enabled"): return false
	sound_manager.set_enabled(false)
	var disabled_ok: bool = not bool(sound_manager.enabled)
	sound_manager.set_enabled(true)
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var toggle := instance.get_node_or_null("CanvasLayer/SettingsPanel/AudioToggle") as CheckButton
	var result := disabled_ok and bool(sound_manager.enabled) and sound_manager.get_node_or_null("UIAudioPlayer") != null and toggle != null
	instance.queue_free()
	return result

func optional_ai_service_contract_test() -> bool:
	var service_script = load("res://scripts/ai/ai_service.gd")
	var mock_script = load("res://scripts/ai/mock_ai_provider.gd")
	if service_script == null or mock_script == null: return false
	var context := {"npc_profile":{"display_name":"艾莉絲"},"mood":"Happy","relevant_memories":[],"relationship":{"trust":20},"world_event":{},"situation":"greeting"}
	var original: Dictionary = context.duplicate(true)
	var service = service_script.new(mock_script.new())
	var response: Dictionary = service.generate_dialogue(context)
	var fallback = service_script.new()
	var fallback_response: Dictionary = fallback.generate_dialogue(context)
	var hostile_context := {"npc_profile":"tampered","mood":{"unexpected":true},"relevant_memories":["not-a-memory",{"importance":4,"description":"保留這段"}],"relationship":"tampered","world_event":"tampered","situation":"x".repeat(1000)}
	var hostile_response: Dictionary = service.generate_dialogue(hostile_context)
	var hostile_summary: String = service.summarize_memories(["tampered",{"importance":4,"description":"保留這段"},null])
	var hostile_goal: String = service.generate_long_term_goal({"npc_profile":"tampered"})
	return response.has_all(["dialogue","emotion","intent"]) and fallback_response.has_all(["dialogue","emotion","intent"]) and hostile_response.has_all(["dialogue","emotion","intent"]) and hostile_summary.contains("保留這段") and hostile_goal.contains("居民") and service.has_method("summarize_memories") and service.has_method("generate_long_term_goal") and context == original and not response.has("inventory") and not response.has("relationship_delta")

func inventory_safety_contract_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("has_item"): return false
	var inventory: Dictionary = GameManager.player["inventory"]
	var before: Dictionary = inventory.duplicate(true)
	var invalid_add = Callable(GameManager,"add_item").call(inventory,"bread",-2)
	var invalid_remove := GameManager.remove_item(inventory,"bread",-1)
	var unknown_add = Callable(GameManager,"add_item").call(inventory,"missing_item",1)
	return GameManager.has_item(inventory,"bread",1) and invalid_add == false and invalid_remove == false and unknown_add == false and inventory == before

func personality_need_rates_test() -> bool:
	GameManager.new_game()
	var disciplined: Dictionary = GameManager.npcs["bob"].duplicate(true)
	var impulsive: Dictionary = GameManager.npcs["charlie"].duplicate(true)
	for npc in [disciplined,impulsive]:
		npc["action"] = "Work"
		npc["needs"] = {"hunger":20.0,"energy":80.0,"social":30.0,"safety":20.0}
	GameManager.update_needs(disciplined)
	GameManager.update_needs(impulsive)
	return float(disciplined["needs"]["energy"]) > float(impulsive["needs"]["energy"]) and float(disciplined["needs"]["hunger"]) != float(impulsive["needs"]["hunger"])

func world_event_manager_contract_test() -> bool:
	var manager := get_node_or_null("/root/WorldEventManager")
	if manager == null or not manager.has_method("start_event") or not manager.has_method("advance_event"): return false
	for definition in GameManager.event_defs.values():
		if not definition.has_all(["id","start_time","duration","effects","notifications"]): return false
	var active: Dictionary = manager.start_event(GameManager.event_defs["rain"],120)
	if int(active.get("started_at",-1)) != 120 or int(active.get("remaining_minutes",0)) <= 0: return false
	var advanced: Dictionary = manager.advance_event(active,int(active["remaining_minutes"]))
	return bool(advanced.get("ended",false)) and advanced.get("event",{}).is_empty()

func debug_diagnostics_contract_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	instance.selected_id = "alice"
	instance.refresh_debug()
	var text_value := str(instance.debug_label.text)
	var result := true
	for label in ["目前目標","所在位置","移動目標","情緒","重要記憶","路徑節點"]: result = result and text_value.contains(label)
	instance.queue_free()
	return result

func decision_event_log_contract_test() -> bool:
	GameManager.new_game()
	GameManager.decide(GameManager.npcs["alice"])
	for line in GameManager.event_log:
		if str(line).contains("Action") and str(line).contains("分數"): return true
	return false

func core_service_boundaries_test() -> bool:
	var inventory_service = GameManager.get("inventory_service")
	var needs_service = GameManager.get("needs_service")
	var relationship_service = GameManager.get("relationship_service")
	return inventory_service != null and inventory_service.has_method("add_item") and inventory_service.has_method("remove_item") and inventory_service.has_method("has_item") and needs_service != null and needs_service.has_method("update") and relationship_service != null and relationship_service.has_method("apply_change")

func progression_reputation_tiers_test() -> bool:
	var script = load("res://scripts/progression/progression_service.gd")
	if script == null: return false
	var service = script.new([])
	var cases := {0:"陌生旅人",4:"陌生旅人",5:"熟悉面孔",11:"熟悉面孔",12:"值得信賴",24:"值得信賴",25:"村落支柱",39:"村落支柱",40:"回音守望者"}
	for renown in cases:
		var tier: Dictionary = service.reputation_tier(int(renown))
		if str(tier.get("title","")) != str(cases[renown]): return false
		if not tier.has_all(["index","title","minimum","next_minimum"]): return false
	return true

func progression_achievement_rules_test() -> bool:
	var script = load("res://scripts/progression/progression_service.gd")
	var file := FileAccess.open("res://data/progression/achievements.json",FileAccess.READ)
	if script == null or file == null: return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not (parsed.get("achievements",[]) is Array): return false
	var definitions: Array = parsed["achievements"]
	if definitions.size() != 6: return false
	var service = script.new(definitions)
	var state: Dictionary = service.default_state()
	var snapshot := {"renown":25,"community_flags":{"kindness":true,"crisis":true},"completed_quests":["forest_echo"],"world_flags":{"forest_herbs_gathered":3},"stats":{"interactions":1}}
	var result: Dictionary = service.evaluate(state,snapshot)
	return result.get("unlocked",[]).size() == 6 and result.get("state",{}).get("unlocked_ids",[]).size() == 6

func progression_idempotency_and_safety_test() -> bool:
	var script = load("res://scripts/progression/progression_service.gd")
	if script == null: return false
	var definitions := [{"id":"known","title":"已知","description":"測試","condition":{"type":"renown_at_least","value":1}},{"id":"unknown","title":"未知","description":"測試","condition":{"type":"unsupported","value":1}}]
	var service = script.new(definitions)
	var first: Dictionary = service.evaluate(service.default_state(),{"renown":2})
	var second: Dictionary = service.evaluate(first["state"],{"renown":2})
	return first["unlocked"].size() == 1 and str(first["unlocked"][0]["id"]) == "known" and second["unlocked"].is_empty() and second["state"]["unlocked_ids"].size() == 1

func progression_game_state_defaults_test() -> bool:
	GameManager.new_game()
	if not GameManager.has_method("progression_snapshot") or not GameManager.has_method("evaluate_progression"): return false
	var snapshot: Dictionary = GameManager.progression_snapshot()
	return snapshot.has_all(["renown","tier","next_tier_progress","unlocked_ids","achievements","stats"]) and str(snapshot["tier"].get("title","")) == "陌生旅人" and snapshot["unlocked_ids"].is_empty() and snapshot["achievements"].size() == 6

func progression_gameplay_unlocks_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","talk")
	var first: Dictionary = GameManager.progression_snapshot() if GameManager.has_method("progression_snapshot") else {}
	if "first_echo" not in first.get("unlocked_ids",[]): return false
	GameManager.current_location = "forest_edge"
	for _index in 3: GameManager.gather_location_resource("herb")
	var gathered: Dictionary = GameManager.progression_snapshot()
	if "herbalist" not in gathered.get("unlocked_ids",[]): return false
	GameManager.new_game()
	GameManager.interact("alice","ask")
	GameManager.travel_to("forest_edge")
	GameManager.interact("diana","give_bread")
	var completed: Dictionary = GameManager.progression_snapshot()
	return "forest_messenger" in completed.get("unlocked_ids",[]) and completed["unlocked_ids"].count("forest_messenger") == 1

func progression_save_compatibility_test() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","talk")
	var saved: Dictionary = GameManager.serialize()
	if int(saved.get("save_version",0)) != 3 or not saved.has("progression"): return false
	GameManager.new_game()
	if not GameManager.deserialize(saved): return false
	if "first_echo" not in GameManager.progression_snapshot().get("unlocked_ids",[]): return false
	var legacy: Dictionary = saved.duplicate(true)
	legacy["save_version"] = 2
	legacy.erase("progression")
	if not GameManager.deserialize(legacy): return false
	return GameManager.progression_snapshot().get("unlocked_ids",[]).is_empty()

func progression_panel_structure_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var panel = instance.get_node_or_null("CanvasLayer/ProgressionPanel")
	var result: bool = panel != null and InputMap.has_action("progression") and panel.has_method("refresh") and panel.has_method("set_visible_with_motion")
	instance.queue_free()
	return result

func progression_panel_content_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var panel = instance.get_node_or_null("CanvasLayer/ProgressionPanel")
	if panel == null:
		instance.queue_free()
		return false
	GameManager.new_game()
	GameManager.interact("alice","talk")
	panel.refresh(GameManager.progression_snapshot())
	var summary := panel.get_node_or_null("SummaryLabel") as Label
	var achievements := panel.get_node_or_null("AchievementsLabel") as Label
	var result: bool = summary != null and achievements != null and summary.text.contains("陌生旅人") and summary.text.contains("下一稱號") and achievements.text.contains("已完成") and achievements.text.contains("未完成") and achievements.text.contains("第一道回音")
	instance.queue_free()
	return result

func progression_panel_accessibility_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var panel = instance.get_node_or_null("CanvasLayer/ProgressionPanel")
	var close = panel.get_node_or_null("CloseButton") as Button if panel != null else null
	if panel != null:
		panel.visible = true
		instance.sync_simulation_pause()
	var result: bool = close != null and close.size.y >= 44.0 and close.text.contains("P") and bool(GameTime.simulation_paused)
	instance.queue_free()
	GameTime.set_simulation_paused(false)
	return result

func progression_visual_capture_contract_test() -> bool:
	var scene := load("res://scenes/main/Main.tscn") as PackedScene
	var instance := scene.instantiate()
	add_child(instance)
	await get_tree().process_frame
	var names: Array = instance.visual_qa_capture_names() if instance.has_method("visual_qa_capture_names") else []
	instance.queue_free()
	return "village_progression.png" in names

func write_report() -> void:
	var report := {"project":"Echo Village","timestamp":Time.get_datetime_string_from_system(),"passed":passed,"failed":failed,"results":results,"simulated_game_days":30}
	var file := FileAccess.open("res://tests/simulation_test_report.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"\t"))
