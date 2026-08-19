extends Node

const DATA_PATH := "res://data/"
const DECISION_INTERVAL := 10
const ACTION_SWITCH_COOLDOWN := 15
const MAX_MEMORIES_PER_NPC := 32
const LocationServiceScript = preload("res://scripts/services/location_service.gd")
const QuestServiceScript = preload("res://scripts/services/quest_service.gd")
const EconomyServiceScript = preload("res://scripts/services/economy_service.gd")
const ActionRegistryScript = preload("res://scripts/ai/action_registry.gd")
const NPCStateMachineScript = preload("res://scripts/npc/npc_state_machine.gd")
const InventoryServiceScript = preload("res://scripts/inventory/inventory_service.gd")
const NeedsServiceScript = preload("res://scripts/needs/needs_service.gd")
const RelationshipServiceScript = preload("res://scripts/relationship/relationship_service.gd")
const ProgressionServiceScript = preload("res://scripts/progression/progression_service.gd")
var npc_profiles: Dictionary = {}
var dialogues: Dictionary = {}
var event_defs: Dictionary = {}
var location_defs: Dictionary = {}
var quest_defs: Dictionary = {}
var recipe_defs: Dictionary = {}
var item_defs: Dictionary = {}
var achievement_defs: Array = []
var npcs: Dictionary = {}
var player := {"id":"player","position":Vector2(625,405),"inventory":{"bread":3,"medicine":1},"coin":24}
var economy := {"bread":4,"vegetable":3,"wood":5,"medicine":9}
var active_event: Dictionary = {}
var event_log: Array[String] = []
var timeline_events: Array = []
var timeline_sequence := 0
var memory_sequence := 0
var community := {}
var current_location := "village_square"
var discovered_locations: Array = ["village_square"]
var active_quests := {}
var completed_quests: Array = []
var world_flags := {}
var progression := {}
var location_service
var quest_service
var economy_service
var action_registry = ActionRegistryScript.new()
var npc_state_machine = NPCStateMachineScript.new()
var minimum_action_score := 12.0
var inventory_service = InventoryServiceScript.new()
var needs_service = NeedsServiceScript.new()
var relationship_service = RelationshipServiceScript.new()
var progression_service = ProgressionServiceScript.new()

func _ready() -> void:
	load_data()
	new_game()
	GameTime.minute_changed.connect(_on_minute)
	GameTime.day_changed.connect(_on_day_changed)
	EventBus.event_logged.connect(func(timestamp: String, message: String): _append_log(timestamp + "  " + message))

func load_data() -> void:
	npc_profiles = read_json("npcs/npc_profiles.json")
	dialogues = read_json("dialogue/templates.json")
	event_defs = read_json("events/world_events.json")
	location_defs = index_by_id(read_json("world/locations.json").get("locations", []))
	quest_defs = index_by_id(read_json("quests/quests.json").get("quests", []))
	recipe_defs = index_by_id(read_json("items/recipes.json").get("recipes", []))
	item_defs = read_json("items/items.json")
	achievement_defs = read_json("progression/achievements.json").get("achievements",[])
	progression_service = ProgressionServiceScript.new(achievement_defs)
	inventory_service.configure(item_defs)
	location_service = LocationServiceScript.new(location_defs)
	quest_service = QuestServiceScript.new(quest_defs)
	economy_service = EconomyServiceScript.new(recipe_defs)

func index_by_id(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		if entry is Dictionary and entry.has("id"):
			result[str(entry["id"])] = entry.duplicate(true)
	return result

func has_expansion_data() -> bool:
	return location_defs.has_all(["village_square","forest_edge"]) and quest_defs.has("forest_echo") and recipe_defs.has("forest_remedy")

func new_game() -> void:
	npcs.clear()
	memory_sequence = 0
	player = {"id":"player","position":Vector2(625,405),"inventory":{"bread":3,"medicine":1},"coin":24}
	economy = {"bread":4,"vegetable":3,"wood":5,"medicine":9,"herb":6}
	active_event.clear()
	event_log.clear()
	timeline_events.clear()
	timeline_sequence = 0
	community = {"renown":0,"kindness":false,"rumor":false,"crisis":false,"entries":[]}
	current_location = "village_square"
	discovered_locations = ["village_square"]
	active_quests = {}
	completed_quests = []
	world_flags = {}
	progression = progression_service.default_state()
	for raw in npc_profiles.get("npcs", []):
		var npc: Dictionary = raw.duplicate(true)
		var spawn: Array = npc.get("spawn", [620,360])
		npc["position"] = Vector2(float(spawn[0]), float(spawn[1]))
		npc["target"] = npc["position"]
		npc["needs"] = {"hunger":26.0,"energy":82.0,"social":45.0,"safety":8.0}
		npc["inventory"] = npc.get("starting_inventory", {}).duplicate(true)
		npc["relationships"] = npc.get("starting_relationships", {}).duplicate(true)
		npc["memories"] = []
		npc["mood"] = "Neutral"
		npc["action"] = "Idle"
		npc["state"] = "Idle"
		npc["goal"] = "Settle into the day"
		npc["current_location"] = "village_square"
		npc["current_action"] = "Idle"
		npc["current_target"] = npc["target"]
		npc["temporary_modifiers"] = []
		npc["current_goal"] = npc["goal"]
		npc["scores"] = {}
		npc["last_decision"] = -100
		npc["action_started_minute"] = 0
		npc["state_entered_minute"] = 0
		npc["action_cooldowns"] = {}
		npcs[str(npc["id"])] = npc
	for npc_id in npcs:
		var npc: Dictionary = npcs[npc_id]
		for target_id in npcs:
			if target_id != npc_id and not npc["relationships"].has(target_id):
				npc["relationships"][target_id] = {"affinity":0.0,"trust":0.0,"fear":0.0,"respect":0.0}
	add_log("村落模擬已啟動，共有 %d 位自主村民。" % npcs.size())

func _on_minute(_minute: int, _hour: int) -> void:
	if not active_event.is_empty():
		var event_name := str(active_event.get("display_name","世界事件"))
		var lifecycle: Dictionary = WorldEventManager.advance_event(active_event,1)
		active_event = lifecycle.get("event",{}).duplicate(true)
		if bool(lifecycle.get("ended",false)): add_log(event_name + "已結束。")
	for value in npcs.values():
		var npc: Dictionary = value
		update_needs(npc)
		update_mood(npc)
		if GameTime.minute - int(npc["last_decision"]) >= DECISION_INTERVAL:
			decide(npc)
		move_npc(npc)
	if active_event.get("id","") == "minor_danger" and not bool(active_event.get("consequence_resolved",false)):
		resolve_danger_actions()

func _on_day_changed(_day: int, _day_of_week: int) -> void:
	for npc in npcs.values(): decay_memories(npc,1)

func update_needs(npc: Dictionary) -> void:
	needs_service.update(npc,str(active_event.get("id","")))

func decide(npc: Dictionary) -> void:
	var scores := utility_scores(npc)
	npc["scores"] = scores
	var choice := "Wander"
	var best := -999.0
	for action in scores:
		if float(scores[action]) > best:
			best = float(scores[action])
			choice = action
	if best < minimum_action_score: choice = "Idle"
	var previous_action := str(npc.get("current_action","Idle"))
	var previous = action_registry.get_action(previous_action)
	if previous != null and previous_action != choice:
		previous.cancel(npc,action_context(npc))
		npc["action_cooldowns"][previous_action] = GameTime.minute + ACTION_SWITCH_COOLDOWN
	npc["action"] = choice
	npc["goal"] = choice + " based on needs and schedule"
	npc["target"] = target_for(npc,choice)
	var context := action_context(npc)
	context["target"] = npc["target"]
	var selected = action_registry.get_action(choice)
	if selected != null: selected.start(npc,context)
	npc["current_goal"] = npc["goal"]
	npc_state_machine.transition_for_action(npc,choice,npc["target"],GameTime.minute)
	npc["last_decision"] = GameTime.minute
	EventBus.npc_action_changed.emit(str(npc["id"]), choice)
	add_log("%s 選擇 Action %s，分數 %.1f。" % [str(npc["display_name"]),choice,best])
	if choice == "Eat" and remove_item(npc["inventory"], "bread", 1):
		npc["needs"]["hunger"] = maxf(0.0, float(npc["needs"]["hunger"]) - 48.0)
		add_log(str(npc["display_name"]) + "吃了麵包。")
	if choice == "Socialize": socialize(npc)

func utility_scores(npc: Dictionary) -> Dictionary:
	return action_registry.calculate_scores(npc,action_context(npc))

func action_context(npc: Dictionary) -> Dictionary:
	var hour := GameTime.minute / 60
	return {
		"minute":GameTime.minute,
		"hour":hour,
		"scheduled_action":schedule_action(npc,hour),
		"event_id":str(active_event.get("id","")),
		"action_cooldowns":npc.get("action_cooldowns",{}),
		"wander_variance":randf() * 6.0
	}

func schedule_action(npc: Dictionary, hour: int) -> String:
	var result := "Wander"
	for data in npc.get("base_schedule", []):
		if hour >= int(data["hour"]): result = str(data["action"])
	return result

func target_for(npc: Dictionary, action: String) -> Vector2:
	var points := {"square":Vector2(625,355),"tavern":Vector2(370,240),"shop":Vector2(900,235),"farm":Vector2(895,505),"healer":Vector2(355,500),"wood":Vector2(1030,480),"alice_home":Vector2(145,180),"bob_home":Vector2(1110,180),"charlie_home":Vector2(150,535),"diana_home":Vector2(1100,535),"eric_home":Vector2(700,535),"flee":Vector2(1170,580)}
	if action == "Work": return points.get(str(npc["work_location"]), points["square"])
	if action == "Socialize": return points["tavern"]
	if action == "Shop" or action == "Eat": return points["shop"]
	if action == "GoHome" or action == "Sleep": return points.get(str(npc["home_location"]), points["square"])
	if action == "Flee": return points["flee"]
	return points["square"]

func move_npc(npc: Dictionary) -> void:
	if npc["position"].distance_to(npc["target"]) > 2.0:
		npc["position"] = npc["position"].move_toward(npc["target"], 1.35)
		npc["state"] = "Moving"
	if npc["position"].distance_to(npc["target"]) <= 8.0: npc["current_location"] = location_label_for_action(str(npc["action"]),npc)
	npc_state_machine.update(npc,GameTime.minute)

func location_label_for_action(action: String, npc: Dictionary) -> String:
	if action in ["GoHome","Sleep"]: return str(npc.get("home_location","village_square"))
	if action == "Work": return str(npc.get("work_location","village_square"))
	if action == "Socialize": return "tavern"
	if action in ["Shop","Eat"]: return "shop"
	return current_location

func socialize(source: Dictionary) -> void:
	for value in npcs.values():
		var receiver: Dictionary = value
		if receiver["id"] != source["id"] and source["position"].distance_to(receiver["position"]) < 120.0:
			source["needs"]["social"] = maxf(0.0, float(source["needs"]["social"]) - 18.0)
			share_memory(source, receiver)
			return

func share_memory(source: Dictionary, receiver: Dictionary) -> void:
	for data in source["memories"]:
		var memory: Dictionary = data
		if int(memory["importance"]) >= 30 and not bool(memory.get("shared", false)):
			var heard: Dictionary = memory.duplicate(true)
			heard["id"] = "heard_" + str(memory["id"])
			heard["event_type"] = "heard_" + str(memory["event_type"])
			heard["description"] = "%s told %s: %s" % [source["display_name"],receiver["display_name"],memory["description"]]
			heard["shared"] = true
			receiver["memories"].append(heard)
			trim_memories(receiver)
			memory["shared"] = true
			if memory["subject_id"] == "player": change_relationship(receiver,"player",{"trust":float(memory["emotional_value"]) * 0.35,"affinity":float(memory["emotional_value"]) * 0.2})
			add_log("%s 將一段記憶告訴了 %s。" % [source["display_name"],receiver["display_name"]])
			return

func create_memory(npc_id: String, kind: String, description: String, emotion: float, importance: int, subject_id: String = "player", object_id: String = "", metadata: Dictionary = {}) -> void:
	if not npcs.has(npc_id): return
	memory_sequence += 1
	var memory := {"id":"memory_%d" % memory_sequence,"event_type":kind,"subject_id":subject_id,"object_id":object_id,"location":current_location,"timestamp":GameTime.formatted_time(),"description":description,"importance":importance,"emotional_value":emotion,"metadata":metadata.duplicate(true),"shared":false}
	npcs[npc_id]["memories"].append(memory)
	trim_memories(npcs[npc_id])
	EventBus.memory_created.emit(npc_id, memory)
	add_log("%s 建立了記憶：%s" % [npcs[npc_id]["display_name"],kind])

func decay_memories(npc: Dictionary, elapsed_days: int = 1) -> void:
	var retained: Array = []
	for data in npc.get("memories",[]):
		var memory: Dictionary = data
		if int(memory.get("importance",0)) < 60:
			memory["importance"] = int(memory.get("importance",0)) - maxi(1,elapsed_days) * 3
		if int(memory.get("importance",0)) > 0: retained.append(memory)
	npc["memories"] = retained
	trim_memories(npc)

func trim_memories(npc: Dictionary) -> void:
	var memories: Array = npc.get("memories",[])
	while memories.size() > MAX_MEMORIES_PER_NPC:
		var weakest_index := 0
		for index in memories.size():
			if int(memories[index].get("importance",0)) < int(memories[weakest_index].get("importance",0)): weakest_index = index
		memories.remove_at(weakest_index)
	npc["memories"] = memories

func interact(npc_id: String, intent: String) -> String:
	if not npcs.has(npc_id): return "尚未選取村民。"
	progression["stats"]["interactions"] = int(progression.get("stats",{}).get("interactions",0)) + 1
	evaluate_progression()
	var npc: Dictionary = npcs[npc_id]
	if intent == "talk":
		npc["state"] = "Talking"
		npc["state_entered_minute"] = GameTime.minute
		create_memory(npc_id,"small_talk","玩家停下腳步與我交談。",2,12,"player",npc_id,{"intent":"talk"})
		change_relationship(npc,"player",{"affinity":0.5})
		add_log("玩家與 %s 交談。" % str(npc["display_name"]))
		return dialogue(npc)
	if npc_id == "alice" and intent == "ask" and not active_quests.has("forest_echo") and not is_quest_completed("forest_echo"):
		accept_quest("forest_echo")
	EventBus.player_interaction.emit(npc_id, intent)
	notify_quest("talk_to_npc",npc_id)
	if npc_id == "diana" and intent == "give_bread" and current_location == "forest_edge":
		var objective: Dictionary = quest_service.current_objective(active_quests,"forest_echo")
		if str(objective.get("kind","")) == "deliver_item" and str(objective.get("target_id","")) == "bread":
			var delivery: Dictionary = complete_delivery("forest_echo","bread",1)
			if bool(delivery.get("ok",false)): return "黛安娜收下麵包。任務「林間回音」完成，森林記住了你的善意。"
			return str(delivery.get("reason","目前無法交付。"))
	if intent == "give_bread":
		if remove_item(player["inventory"],"bread",1):
			add_item(npc["inventory"],"bread",1)
			create_memory(npc_id,"player_gave_item","玩家在我需要時送了我麵包。",20,45)
			change_relationship(npc,"player",{"affinity":5.0,"trust":2.0})
			record_community("kindness",3,"善意留下回音","你在需要時分享麵包，艾莉絲將這份善意記在心裡。")
			return "%s 收下了麵包，信任提升。" % npc["display_name"]
		return "你的背包裡沒有麵包。"
	if intent == "steal_food":
		if remove_item(npc["inventory"],"bread",1):
			add_item(player["inventory"],"bread",1)
			create_memory(npc_id,"player_stole_item","玩家偷走了我的食物。",-32,70)
			change_relationship(npc,"player",{"affinity":-15.0,"trust":-25.0,"fear":8.0})
			record_community("rumor",-2,"流言開始擴散","一個被看見的選擇，可能會變成整座村莊的共同記憶。")
			return "%s 看見你偷走食物。這件事可能會傳開。" % npc["display_name"]
		return "%s 沒有麵包可偷。" % npc["display_name"]
	if intent == "trade":
		return "%s打開了交易桌。價格會受到關係與世界事件影響。" % npc["display_name"]
	return dialogue(npc)

func social_interaction(source_id: String, receiver_id: String, mode: String) -> Dictionary:
	if source_id == receiver_id or not npcs.has(source_id) or not npcs.has(receiver_id): return {"ok":false,"reason":"居民資料無效。"}
	var source: Dictionary = npcs[source_id]
	var receiver: Dictionary = npcs[receiver_id]
	match mode:
		"greet":
			change_relationship(source,receiver_id,{"affinity":1.0,"respect":0.5})
			change_relationship(receiver,source_id,{"affinity":1.0})
			add_log("%s 向 %s 打招呼。" % [str(source["display_name"]),str(receiver["display_name"])])
			return {"ok":true,"mode":mode}
		"share_information":
			var before: int = receiver["memories"].size()
			share_memory(source,receiver)
			var shared: bool = receiver["memories"].size() > before
			return {"ok":shared,"mode":mode,"reason":"" if shared else "沒有適合分享的記憶。"}
		"argue":
			change_relationship(source,receiver_id,{"affinity":-4.0,"trust":-6.0,"respect":-2.0})
			change_relationship(receiver,source_id,{"affinity":-3.0,"trust":-4.0})
			create_memory(source_id,"npc_argued","我與 %s 發生爭執。" % str(receiver["display_name"]),-10,34,source_id,receiver_id)
			create_memory(receiver_id,"npc_argued","%s 與我發生爭執。" % str(source["display_name"]),-8,30,source_id,receiver_id)
			return {"ok":true,"mode":mode}
	return {"ok":false,"reason":"不支援的社交方式。"}

func can_gather_location_resource(item_id: String) -> bool:
	return current_location == "forest_edge" and item_id == "herb" and int(world_flags.get("forest_herbs_gathered",0)) < 3

func gather_location_resource(item_id: String) -> Dictionary:
	if not item_defs.has(item_id): return {"ok":false,"reason":"找不到這種資源。"}
	if not can_gather_location_resource(item_id): return {"ok":false,"reason":"此地暫時沒有可採集的資源。"}
	add_item(player["inventory"],item_id,1)
	world_flags["forest_herbs_gathered"] = int(world_flags.get("forest_herbs_gathered",0)) + 1
	notify_quest("collect_item",item_id)
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	add_log("玩家在森林採集了月光藥草。")
	evaluate_progression()
	return {"ok":true,"item_id":item_id,"amount":1,"remaining":3 - int(world_flags["forest_herbs_gathered"])}

func dialogue(npc: Dictionary) -> String:
	var relation: Dictionary = npc["relationships"].get("player", {"trust":0.0})
	if float(relation.get("trust",0.0)) < -15.0: return str(dialogues.get("distrust","你想做什麼？"))
	if npc["memories"].size() > 0:
		var last: Dictionary = npc["memories"].back()
		if float(last["emotional_value"]) < -10.0: return "我仍記得你做過的事。"
		if float(last["emotional_value"]) > 10.0: return "很高興再見到你。我記得你的善意。"
	return str(dialogues.get(str(npc["mood"]).to_lower(),"早安。"))

func trade_price(npc_id: String, item_id: String) -> int:
	if not npcs.has(npc_id) or not item_defs.has(item_id): return 0
	var relation: Dictionary = npcs[npc_id]["relationships"].get("player", {"affinity":0.0})
	var modifier := 1.0 - clampf(float(relation.get("affinity",0.0)) / 200.0,-0.25,0.25)
	if active_event.get("id","") == "food_shortage" and item_id == "bread": modifier *= 1.5
	return maxi(1,ceili(int(economy.get(item_id,4)) * modifier))

func sell_price(npc_id: String, item_id: String) -> int:
	var buy_price := trade_price(npc_id,item_id)
	return maxi(1,floori(float(buy_price) * 0.55)) if buy_price > 0 else 0

func buy_item(npc_id: String, item_id: String, amount: int = 1) -> Dictionary:
	if amount <= 0 or not npcs.has(npc_id) or not item_defs.has(item_id): return {"ok":false,"reason":"找不到可交易的物品。"}
	var npc: Dictionary = npcs[npc_id]
	if count_item(npc["inventory"],item_id) < amount: return {"ok":false,"reason":"商人目前沒有足夠庫存。"}
	var unit_price := trade_price(npc_id,item_id)
	var total := unit_price * amount
	if int(player["coin"]) < total: return {"ok":false,"reason":"你的硬幣不足，需要 %d 枚。" % total}
	player["coin"] = int(player["coin"]) - total
	npc["coin"] = int(npc.get("coin",0)) + total
	remove_item(npc["inventory"],item_id,amount)
	add_item(player["inventory"],item_id,amount)
	create_memory(npc_id,"trade_event","玩家向我購買了%s。" % str(item_defs[item_id].get("display_name",item_id)),5,18)
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	add_log("交易完成：買入 %s × %d。" % [str(item_defs[item_id].get("display_name",item_id)),amount])
	return {"ok":true,"reason":"","unit_price":unit_price,"total":total}

func sell_item(npc_id: String, item_id: String, amount: int = 1) -> Dictionary:
	if amount <= 0 or not npcs.has(npc_id) or not item_defs.has(item_id): return {"ok":false,"reason":"找不到可交易的物品。"}
	if count_item(player["inventory"],item_id) < amount: return {"ok":false,"reason":"你的背包裡沒有足夠物品。"}
	var npc: Dictionary = npcs[npc_id]
	var unit_price := sell_price(npc_id,item_id)
	var total := unit_price * amount
	if int(npc.get("coin",0)) < total: return {"ok":false,"reason":"商人目前沒有足夠硬幣收購。"}
	remove_item(player["inventory"],item_id,amount)
	add_item(npc["inventory"],item_id,amount)
	player["coin"] = int(player["coin"]) + total
	npc["coin"] = int(npc.get("coin",0)) - total
	create_memory(npc_id,"trade_event","玩家向我出售了%s。" % str(item_defs[item_id].get("display_name",item_id)),4,16)
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	add_log("交易完成：出售 %s × %d。" % [str(item_defs[item_id].get("display_name",item_id)),amount])
	return {"ok":true,"reason":"","unit_price":unit_price,"total":total}

func trigger_world_event(event_id: String) -> void:
	var definition: Dictionary = event_defs.get(event_id,{})
	if definition.is_empty(): return
	active_event = WorldEventManager.start_event(definition,GameTime.minute)
	if active_event.is_empty():
		add_log("世界事件資料無效：" + event_id)
		return
	if event_id == "minor_danger":
		record_community("crisis",2,"危機考驗勇氣","突發危險讓每位居民依人格與需求，選擇協助或逃離。")
	if event_id == "npc_injury" and npcs.has("eric"):
		active_event["target_npc_id"] = "eric"
		var eric: Dictionary = npcs["eric"]
		eric["needs"]["energy"] = maxf(0.0,float(eric["needs"]["energy"]) - 32.0)
		eric["mood"] = "Tired"
		eric["temporary_modifiers"].append({"id":"injured","remaining_minutes":int(active_event["duration"])})
		create_memory("eric","npc_injury","我在林場意外受傷，必須暫時放慢腳步。",-22,72,"world","eric",{"event_id":"npc_injury"})
	add_log("世界事件開始：" + str(active_event["display_name"]))
	EventBus.world_event_changed.emit(event_id)

func resolve_danger_actions() -> bool:
	if active_event.get("id","") != "minor_danger": return false
	var helper: Dictionary = {}
	var receiver: Dictionary = {}
	for npc in npcs.values():
		if helper.is_empty() and str(npc.get("action","")) == "Help": helper = npc
		if receiver.is_empty() and str(npc.get("action","")) == "Flee": receiver = npc
	if helper.is_empty() or receiver.is_empty(): return false
	create_memory(str(receiver["id"]),"npc_helped_npc","%s 在危險中保護了我。" % str(helper["display_name"]),24,68,str(helper["id"]),str(receiver["id"]),{"event_id":"minor_danger"})
	create_memory(str(helper["id"]),"helped_npc","我在危險中協助了 %s。" % str(receiver["display_name"]),16,54,str(helper["id"]),str(receiver["id"]),{"event_id":"minor_danger"})
	change_relationship(receiver,str(helper["id"]),{"affinity":10.0,"trust":10.0,"respect":15.0})
	active_event["consequence_resolved"] = true
	add_log("%s 在危險中協助 %s，兩人建立了新的信任。" % [str(helper["display_name"]),str(receiver["display_name"])])
	return true

func load_showcase(scenario_id: String) -> String:
	new_game()
	if scenario_id == "kindness":
		player["position"] = Vector2(875,245)
		interact("alice","give_bread")
		add_log("展示情境 A：善意會留下正向記憶並改變對話。")
		return "展示 A：艾莉絲已收到麵包；查看她的記憶、好感與對話。"
	if scenario_id == "rumor":
		player["position"] = Vector2(875,500)
		interact("bob","steal_food")
		share_memory(npcs["bob"],npcs["charlie"])
		add_log("展示情境 B：偷竊 → 負面記憶 → 流言傳播 → 信任下降。")
		return "展示 B：鮑伯已將偷竊記憶告訴查理；可比較兩人的關係。"
	if scenario_id == "danger":
		trigger_world_event("minor_danger")
		for id in ["bob","eric","alice","charlie","diana"]:
			npcs[id]["needs"]["safety"] = 72.0
			decide(npcs[id])
		resolve_danger_actions()
		add_log("展示情境 C：突發危險觸發勇氣導向的協助與逃離決策。")
		return "展示 C：開啟 F3，觀察勇氣不同的 NPC 選擇協助或逃離。"
	return "找不到展示情境。"

func relationship_summary(npc_id: String) -> String:
	if not npcs.has(npc_id): return ""
	var relation: Dictionary = npcs[npc_id]["relationships"].get("player",{})
	return "信任 %d  ·  好感 %d  ·  恐懼 %d  ·  尊敬 %d" % [int(relation.get("trust",0)),int(relation.get("affinity",0)),int(relation.get("fear",0)),int(relation.get("respect",0))]

func latest_memory_summary(npc_id: String) -> String:
	if not npcs.has(npc_id) or npcs[npc_id]["memories"].is_empty(): return "尚無值得記住的事件。"
	var memory: Dictionary = npcs[npc_id]["memories"].back()
	return "記憶：%s" % str(memory["description"])

func npc_showcase_snapshot(npc_id: String) -> Dictionary:
	if not npcs.has(npc_id): return {}
	var npc: Dictionary = npcs[npc_id]
	return {
		"id":npc_id,
		"display_name":npc["display_name"],
		"occupation":npc["occupation"],
		"mood":npc["mood"],
		"action":npc["action"],
		"goal":npc["goal"],
		"needs":npc["needs"].duplicate(true),
		"relationship":npc["relationships"].get("player",{}).duplicate(true),
		"memory_count":npc["memories"].size()
	}

func record_community(flag: String, renown_change: int, title: String, description: String) -> void:
	if bool(community.get(flag,false)): return
	community[flag] = true
	community["renown"] = maxi(0,int(community.get("renown",0)) + renown_change)
	var entry := {"flag":flag,"title":title,"description":description,"renown_change":renown_change,"time":GameTime.formatted_time()}
	community["entries"].append(entry)
	EventBus.community_progressed.emit(entry)
	add_log("村落編年解鎖：「%s」" % title)
	evaluate_progression()

func community_progress() -> Dictionary:
	var result: Dictionary = community.duplicate(true)
	var unlocked := 0
	for flag in ["kindness","rumor","crisis"]:
		if bool(result.get(flag,false)): unlocked += 1
	result["unlocked"] = unlocked
	return result

func chronicle_entries() -> Array:
	return community.get("entries",[]).duplicate(true)

func change_relationship(npc: Dictionary, target: String, changes: Dictionary) -> void:
	relationship_service.apply_change(npc,target,changes)
	EventBus.relationship_changed.emit(str(npc["id"]),target,changes)

func update_mood(npc: Dictionary) -> void:
	var n: Dictionary = npc["needs"]
	if float(n["safety"]) > 65.0: npc["mood"] = "Afraid"
	elif float(n["energy"]) < 25.0: npc["mood"] = "Tired"
	elif float(n["hunger"]) > 75.0: npc["mood"] = "Angry"
	elif float(n["social"]) > 70.0: npc["mood"] = "Sad"
	else: npc["mood"] = "Happy" if float(n["hunger"]) < 25.0 and float(n["energy"]) > 70.0 else "Neutral"

func add_item(inv: Dictionary, item: String, amount: int) -> bool:
	return inventory_service.add_item(inv,item,amount)
func remove_item(inv: Dictionary, item: String, amount: int) -> bool:
	return inventory_service.remove_item(inv,item,amount)
func count_item(inv: Dictionary, item: String) -> int:
	return inventory_service.count_item(inv,item)
func has_item(inv: Dictionary, item: String, amount: int = 1) -> bool:
	return inventory_service.has_item(inv,item,amount)

func debug_adjust_need(npc_id: String, need_id: String, delta: float) -> Dictionary:
	if not npcs.has(npc_id) or not npcs[npc_id]["needs"].has(need_id): return {"ok":false,"reason":"找不到居民或需求。"}
	var npc: Dictionary = npcs[npc_id]
	npc["needs"][need_id] = clampf(float(npc["needs"][need_id]) + delta,0.0,100.0)
	update_mood(npc)
	add_log("除錯：%s 的 %s 已調整。" % [str(npc["display_name"]),need_id])
	return {"ok":true,"value":npc["needs"][need_id]}

func debug_add_player_item(item_id: String, amount: int) -> Dictionary:
	if amount <= 0 or not item_defs.has(item_id): return {"ok":false,"reason":"物品或數量無效。"}
	add_item(player["inventory"],item_id,amount)
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	add_log("除錯：玩家取得 %s × %d。" % [str(item_defs[item_id].get("display_name",item_id)),amount])
	return {"ok":true}

func debug_teleport_player_to_npc(npc_id: String) -> Dictionary:
	if not npcs.has(npc_id): return {"ok":false,"reason":"找不到居民。"}
	player["position"] = npcs[npc_id]["position"] + Vector2(28,0)
	add_log("除錯：已傳送到 %s 身旁。" % str(npcs[npc_id]["display_name"]))
	return {"ok":true}

func accept_quest(quest_id: String) -> Dictionary:
	var result: Dictionary = quest_service.accept(active_quests,completed_quests,quest_id)
	if bool(result.get("ok",false)):
		add_log("接受任務：「%s」" % str(quest_defs[quest_id].get("title",quest_id)))
		EventBus.quest_changed.emit(active_quest_snapshot())
	return result

func travel_to(location_id: String) -> Dictionary:
	var result: Dictionary = location_service.travel(current_location,discovered_locations,world_flags,location_id)
	if not bool(result.get("ok",false)): return result
	current_location = str(result["location_id"])
	discovered_locations = result["discovered_locations"].duplicate(true)
	apply_location_layout(current_location)
	notify_quest("visit_location",current_location)
	EventBus.location_changed.emit(current_location)
	add_log("抵達：%s" % str(location_defs[current_location].get("display_name",current_location)))
	return result

func apply_location_layout(location_id: String) -> void:
	if location_id == "forest_edge":
		player["position"] = Vector2(625,545)
		if npcs.has("diana"): npcs["diana"]["position"] = Vector2(790,430)
		if npcs.has("eric"): npcs["eric"]["position"] = Vector2(1020,470)
	elif location_id == "village_square":
		player["position"] = Vector2(625,405)
		if npcs.has("diana"): npcs["diana"]["position"] = Vector2(355,500)
		if npcs.has("eric"): npcs["eric"]["position"] = Vector2(1030,480)

func complete_delivery(quest_id: String, item_id: String, amount: int) -> Dictionary:
	if quest_id in completed_quests: return {"ok":false,"reason":"任務已經完成。"}
	var objective: Dictionary = quest_service.current_objective(active_quests,quest_id)
	if objective.is_empty() or str(objective.get("kind","")) != "deliver_item" or str(objective.get("target_id","")) != item_id or amount < int(objective.get("amount",1)):
		return {"ok":false,"reason":"目前沒有符合的交付目標。"}
	if count_item(player["inventory"],item_id) < amount: return {"ok":false,"reason":"背包中的物品不足。"}
	remove_item(player["inventory"],item_id,amount)
	var progress := notify_quest("deliver_item",item_id,amount)
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	return {"ok":quest_id in progress.get("completed",[]),"reason":"" if quest_id in progress.get("completed",[]) else "交付進度已更新。"}

func craft_recipe(recipe_id: String) -> Dictionary:
	var result: Dictionary = economy_service.craft(player["inventory"],current_location,recipe_id)
	if bool(result.get("ok",false)):
		EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
		add_log("完成製作：%s" % str(result["output"]["item_id"]))
	return result

func active_quest_snapshot() -> Array[Dictionary]:
	return quest_service.snapshot(active_quests)

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests

func notify_quest(kind: String, target_id: String, amount: int = 1) -> Dictionary:
	var progress: Dictionary = quest_service.notify(active_quests,completed_quests,kind,target_id,amount)
	for quest_id in progress.get("completed",[]): award_quest(str(quest_id))
	if not progress.get("changed",[]).is_empty(): EventBus.quest_changed.emit(active_quest_snapshot())
	return progress

func award_quest(quest_id: String) -> void:
	var definition: Dictionary = quest_defs.get(quest_id,{})
	var rewards: Dictionary = definition.get("rewards",{})
	player["coin"] = int(player.get("coin",0)) + int(rewards.get("coin",0))
	for item_id in rewards:
		if str(item_id) not in ["coin","renown"]: add_item(player["inventory"],str(item_id),int(rewards[item_id]))
	community["renown"] = int(community.get("renown",0)) + int(rewards.get("renown",0))
	for flag in definition.get("on_complete_flags",[]): world_flags[str(flag)] = true
	create_memory(str(definition.get("giver_id","alice")),"quest_completed","玩家完成了「%s」。" % str(definition.get("title",quest_id)),24,55)
	add_log("完成任務：「%s」" % str(definition.get("title",quest_id)))
	EventBus.inventory_changed.emit(player["inventory"].duplicate(true))
	evaluate_progression()

func evaluate_progression() -> Array:
	var result: Dictionary = progression_service.evaluate(progression,_progression_context())
	progression = result.get("state",progression_service.default_state()).duplicate(true)
	var unlocked: Array = result.get("unlocked",[])
	for achievement in unlocked:
		var safe: Dictionary = achievement.duplicate(true)
		EventBus.progression_unlocked.emit(safe)
		add_log("成就解鎖：「%s」" % str(safe.get("title","未命名成就")))
	return unlocked.duplicate(true)

func _progression_context() -> Dictionary:
	return {
		"renown":int(community.get("renown",0)),
		"community_flags":community.duplicate(true),
		"completed_quests":completed_quests.duplicate(true),
		"world_flags":world_flags.duplicate(true),
		"stats":progression.get("stats",{}).duplicate(true),
		"timestamp":GameTime.formatted_time()
	}

func progression_snapshot() -> Dictionary:
	var renown := int(community.get("renown",0))
	var tier: Dictionary = progression_service.reputation_tier(renown)
	var minimum := int(tier.get("minimum",0))
	var next_minimum := int(tier.get("next_minimum",minimum))
	var progress_ratio := 1.0 if next_minimum <= minimum else clampf(float(renown - minimum) / float(next_minimum - minimum),0.0,1.0)
	var achievements: Array = []
	for value in achievement_defs:
		var definition: Dictionary = value.duplicate(true)
		definition["unlocked"] = str(definition.get("id","")) in progression.get("unlocked_ids",[])
		achievements.append(definition)
	return {"renown":renown,"tier":tier,"next_tier_progress":progress_ratio,"unlocked_ids":progression.get("unlocked_ids",[]).duplicate(true),"achievements":achievements,"stats":progression.get("stats",{}).duplicate(true)}

func legacy_serialize() -> Dictionary:
	return {"save_version":1,"player":encode_value(player),"npcs":encode_value(npcs),"economy":economy,"active_event":active_event,"event_log":event_log,"memory_sequence":memory_sequence,"community":community}
func serialize() -> Dictionary:
	var state := legacy_serialize()
	state["save_version"] = 3
	state["current_location"] = current_location
	state["discovered_locations"] = discovered_locations.duplicate(true)
	state["active_quests"] = active_quests.duplicate(true)
	state["completed_quests"] = completed_quests.duplicate(true)
	state["world_flags"] = world_flags.duplicate(true)
	state["progression"] = progression.duplicate(true)
	state["timeline_events"] = timeline_events.duplicate(true)
	state["timeline_sequence"] = timeline_sequence
	return state
func deserialize(data: Dictionary) -> bool:
	if not (data is Dictionary): return false
	player = decode_value(data.get("player",player))
	npcs = decode_value(data.get("npcs",npcs))
	economy = data.get("economy",economy)
	active_event = data.get("active_event",{})
	event_log.clear()
	for entry in data.get("event_log",[]):
		event_log.append(str(entry))
	memory_sequence = int(data.get("memory_sequence",0))
	community = data.get("community",{"renown":0,"kindness":false,"rumor":false,"crisis":false,"entries":[]}).duplicate(true)
	current_location = str(data.get("current_location","village_square"))
	discovered_locations = data.get("discovered_locations",["village_square"]).duplicate(true)
	active_quests = data.get("active_quests",{}).duplicate(true)
	completed_quests = data.get("completed_quests",[]).duplicate(true)
	world_flags = data.get("world_flags",{}).duplicate(true)
	progression = data.get("progression",progression_service.default_state()).duplicate(true)
	timeline_events.clear()
	for value in data.get("timeline_events",[]):
		if value is Dictionary: timeline_events.append(value.duplicate(true))
	timeline_sequence = int(data.get("timeline_sequence",timeline_events.size()))
	return true
func encode_value(value):
	if value is Vector2: return {"__vector2":[value.x,value.y]}
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = encode_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(encode_value(item))
		return result
	return value
func decode_value(value):
	if value is Dictionary:
		if value.has("__vector2"): return Vector2(float(value["__vector2"][0]),float(value["__vector2"][1]))
		var result := {}
		for key in value: result[key] = decode_value(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(decode_value(item))
		return result
	return value
func read_json(relative: String) -> Dictionary:
	var file := FileAccess.open(DATA_PATH + relative,FileAccess.READ)
	if file == null:
		push_error("Missing data file: " + relative)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
func _append_log(line: String) -> void:
	event_log.append(line)
	if event_log.size() > 80: event_log.pop_front()

func classify_timeline_category(message: String) -> String:
	if message.contains("交易") or message.contains("買入") or message.contains("出售"): return "economy"
	if message.contains("任務") or message.contains("製作"): return "quest"
	if message.contains("世界事件") or message.contains("事件開始") or message.contains("危險") or message.contains("受傷"): return "world"
	if message.contains("聲望") or message.contains("編年") or message.contains("成就"): return "progression"
	if message.contains("交談") or message.contains("贈") or message.contains("偷") or message.contains("協助") or message.contains("打招呼") or message.contains("記憶") or message.contains("信任"): return "social"
	if message.begins_with("抵達"): return "location"
	return "simulation"

func record_timeline_event(message: String) -> void:
	timeline_sequence += 1
	var event := {
		"id":"echo_%d" % timeline_sequence,
		"day":GameTime.day,
		"minute":GameTime.minute,
		"time":GameTime.formatted_time(),
		"phase":GameTime.day_phase(),
		"location":current_location,
		"category":classify_timeline_category(message),
		"message":message
	}
	timeline_events.append(event)
	if timeline_events.size() > 160: timeline_events.pop_front()

func timeline_snapshot(category: String = "all", target_day: int = -1, limit: int = 12) -> Array:
	var result: Array = []
	var safe_limit: int = maxi(1,limit)
	for index in range(timeline_events.size() - 1,-1,-1):
		var event: Dictionary = timeline_events[index]
		if target_day >= 0 and int(event.get("day",0)) != target_day: continue
		if category != "all" and str(event.get("category","simulation")) != category: continue
		result.append(event.duplicate(true))
		if result.size() >= safe_limit: break
	return result

func daily_summary(target_day: int = -1) -> Dictionary:
	var day_value: int = GameTime.day if target_day < 0 else target_day
	var category_counts := {"social":0,"world":0,"quest":0,"economy":0,"progression":0,"location":0,"simulation":0}
	var highlights: Array = []
	var total_events := 0
	for value in timeline_events:
		var event: Dictionary = value
		if int(event.get("day",0)) != day_value: continue
		total_events += 1
		var category: String = str(event.get("category","simulation"))
		category_counts[category] = int(category_counts.get(category,0)) + 1
		if category != "simulation": highlights.append(event.duplicate(true))
	if highlights.size() > 6:
		highlights = highlights.slice(highlights.size() - 6)
	highlights.reverse()
	return {"day":day_value,"total_events":total_events,"category_counts":category_counts,"highlights":highlights}

func add_log(message: String) -> void:
	record_timeline_event(message)
	EventBus.log_event(GameTime.formatted_time(),message)
