extends Node2D

const WORLD := Rect2(42,92,1196,506)
const MOVE_SPEED := 76.0
const STALL_TIMEOUT := 4.0
var agents: Dictionary = {}
var actors: Dictionary = {}
var last_positions: Dictionary = {}
var stalled_seconds: Dictionary = {}

func _ready() -> void:
	create_navigation_region()
	for npc_id in GameManager.npcs:
		var actor := Node2D.new()
		actor.name = "Actor_" + str(npc_id)
		add_child(actor)
		var agent := NavigationAgent2D.new()
		agent.name = "Agent_" + str(npc_id)
		agent.path_desired_distance = 5.0
		agent.target_desired_distance = 7.0
		agent.avoidance_enabled = false
		actor.add_child(agent)
		actors[npc_id] = actor
		agents[npc_id] = agent
		last_positions[npc_id] = GameManager.npcs[npc_id]["position"]
		stalled_seconds[npc_id] = 0.0
	call_deferred("sync_targets")

func create_navigation_region() -> void:
	var region := NavigationRegion2D.new()
	region.name = "WalkableRegion"
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([WORLD.position,Vector2(WORLD.end.x,WORLD.position.y),WORLD.end,Vector2(WORLD.position.x,WORLD.end.y)])
	polygon.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_polygon = polygon
	add_child(region)

func sync_targets() -> void:
	for npc_id in agents:
		if not GameManager.npcs.has(npc_id): continue
		var npc: Dictionary = GameManager.npcs[npc_id]
		var actor: Node2D = actors[npc_id]
		var agent: NavigationAgent2D = agents[npc_id]
		actor.position = npc["position"]
		agent.target_position = npc["target"]

func _physics_process(delta: float) -> void:
	if GameTime.simulation_paused: return
	for npc_id in agents:
		if not GameManager.npcs.has(npc_id): continue
		var npc: Dictionary = GameManager.npcs[npc_id]
		var actor: Node2D = actors[npc_id]
		var agent: NavigationAgent2D = agents[npc_id]
		actor.position = npc["position"]
		if agent.target_position.distance_to(npc["target"]) > 1.0: agent.target_position = npc["target"]
		if not agent.is_navigation_finished():
			var next_point := agent.get_next_path_position()
			if next_point != Vector2.ZERO: npc["position"] = npc["position"].move_toward(next_point,MOVE_SPEED * delta)
		track_stall(str(npc_id),delta)

func track_stall(npc_id: String, delta: float) -> void:
	var current: Vector2 = GameManager.npcs[npc_id]["position"]
	var previous: Vector2 = last_positions.get(npc_id,current)
	var agent: NavigationAgent2D = agents[npc_id]
	if current.distance_to(previous) < 0.15 and not agent.is_navigation_finished():
		stalled_seconds[npc_id] = float(stalled_seconds.get(npc_id,0.0)) + delta
		if float(stalled_seconds[npc_id]) >= STALL_TIMEOUT: recover_stalled_agent(npc_id)
	else:
		stalled_seconds[npc_id] = 0.0
	last_positions[npc_id] = current

func recover_stalled_agent(npc_id: String) -> void:
	if not GameManager.npcs.has(npc_id) or not agents.has(npc_id): return
	var npc: Dictionary = GameManager.npcs[npc_id]
	npc["target"] = npc["position"]
	npc["current_target"] = npc["position"]
	npc["state"] = "Idle"
	npc["goal"] = "Recover from navigation timeout"
	npc["current_goal"] = npc["goal"]
	stalled_seconds[npc_id] = 0.0
	GameManager.add_log("%s 的移動路徑逾時，已安全重設。" % str(npc["display_name"]))

func debug_paths() -> Array:
	var paths: Array = []
	for agent in agents.values():
		var path: PackedVector2Array = agent.get_current_navigation_path()
		if path.size() > 1: paths.append(path)
	return paths

func debug_path_for(npc_id: String) -> PackedVector2Array:
	if not agents.has(npc_id): return PackedVector2Array()
	return agents[npc_id].get_current_navigation_path()
