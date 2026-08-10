class_name NeedsService
extends RefCounted

func update(npc: Dictionary, active_event_id: String) -> void:
	var needs: Dictionary = npc["needs"]
	var personality: Dictionary = npc.get("personality",{})
	var greed := float(personality.get("greed",0.5))
	var discipline := float(personality.get("discipline",0.5))
	var sociability := float(personality.get("sociability",0.5))
	var bravery := float(personality.get("bravery",0.5))
	var hunger_delta := 0.105 + greed * 0.055
	var energy_delta := 0.42 if npc["action"] == "Sleep" else (-0.11 + discipline * 0.05 if npc["action"] == "Work" else -0.07)
	var social_delta := -0.33 if npc["action"] == "Socialize" else 0.03 + sociability * 0.06
	var safety_delta := 0.18 * (1.15 - bravery * 0.3) if active_event_id == "minor_danger" else -(0.07 + bravery * 0.05)
	needs["hunger"] = clampf(float(needs["hunger"]) + hunger_delta,0.0,100.0)
	needs["energy"] = clampf(float(needs["energy"]) + energy_delta,0.0,100.0)
	needs["social"] = clampf(float(needs["social"]) + social_delta,0.0,100.0)
	needs["safety"] = clampf(float(needs["safety"]) + safety_delta,0.0,100.0)
