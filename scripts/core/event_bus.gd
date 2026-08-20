extends Node

signal event_logged(timestamp: String, message: String)
signal memory_created(npc_id: String, memory: Dictionary)
signal relationship_changed(subject_id: String, target_id: String, changes: Dictionary)
signal world_event_changed(event_id: String)
signal npc_action_changed(npc_id: String, action: String)
signal player_interaction(npc_id: String, interaction: String)
signal save_completed(path: String)
signal community_progressed(entry: Dictionary)
signal quest_changed(snapshot: Array)
signal location_changed(location_id: String)
signal inventory_changed(inventory: Dictionary)
signal progression_unlocked(achievement: Dictionary)
signal story_arc_updated(arc_id: String, stage_id: String, consequence: Dictionary)

func log_event(timestamp: String, message: String) -> void:

	event_logged.emit(timestamp, message)
