class_name NPCAction
extends RefCounted

var action_id: String

func _init(id: String) -> void:
	action_id = id

func can_execute(_npc: Dictionary, _context: Dictionary) -> bool:
	return true

func calculate_score(_npc: Dictionary, _context: Dictionary) -> float:
	return 0.0

func start(npc: Dictionary, context: Dictionary) -> void:
	npc["current_action"] = action_id
	npc["current_goal"] = "%s based on needs and schedule" % action_id
	npc["current_target"] = context.get("target",npc.get("position",Vector2.ZERO))
	npc["action_started_minute"] = int(context.get("minute",0))

func update(_npc: Dictionary, _context: Dictionary) -> String:
	return "running"

func finish(npc: Dictionary, _context: Dictionary) -> void:
	npc["last_completed_action"] = action_id

func cancel(npc: Dictionary, _context: Dictionary) -> void:
	npc["last_cancelled_action"] = action_id

