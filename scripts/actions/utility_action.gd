class_name UtilityAction
extends NPCAction

func _init(id: String) -> void:
	super(id)

func can_execute(npc: Dictionary, _context: Dictionary) -> bool:
	if action_id == "Eat":
		return int(npc.get("inventory",{}).get("bread",0)) > 0
	return true

func calculate_score(npc: Dictionary, context: Dictionary) -> float:
	var needs: Dictionary = npc.get("needs",{})
	var personality: Dictionary = npc.get("personality",{})
	var hunger := float(needs.get("hunger",0.0))
	var energy := float(needs.get("energy",100.0))
	var social := float(needs.get("social",0.0))
	var safety := float(needs.get("safety",0.0))
	var discipline := float(personality.get("discipline",0.5))
	var sociability := float(personality.get("sociability",0.5))
	var bravery := float(personality.get("bravery",0.5))
	var hour := int(context.get("hour",12))
	var scheduled := str(context.get("scheduled_action","Wander"))
	var event_id := str(context.get("event_id",""))
	var mood := str(npc.get("mood","Neutral"))
	var danger := event_id == "minor_danger"
	match action_id:
		"Eat": return hunger + (22.0 if event_id == "food_shortage" else 0.0) + 15.0 + (8.0 if mood == "Angry" else 0.0)
		"Sleep": return 100.0 - energy + (26.0 if hour >= 22 or hour < 6 else 0.0) + (12.0 if mood == "Tired" else 0.0)
		"Work": return (42.0 if scheduled == "Work" else 0.0) + discipline * 34.0 - (28.0 if event_id == "rain" else 0.0)
		"Socialize": return social * 0.72 + sociability * 28.0 + (28.0 if event_id == "festival" else 0.0) + (18.0 if event_id == "rain" else 0.0) + (4.0 if mood == "Happy" else 0.0)
		"Shop": return hunger * 0.25 + (24.0 if int(npc.get("inventory",{}).get("bread",0)) == 0 else 0.0)
		"GoHome": return (38.0 if scheduled == "GoHome" else 0.0) + (20.0 if hour >= 20 else 0.0)
		"Flee": return (safety * (1.1 - bravery * 0.8) if danger else 0.0) + (20.0 if danger and bravery < 0.5 else 0.0) + (26.0 if mood == "Afraid" else 0.0)
		"Help": return (safety * 0.55 if danger else 0.0) + (bravery * 55.0 if danger else 0.0)
		"Rest": return maxf(0.0,62.0 - energy) + (10.0 if scheduled == "Rest" else 0.0) + (12.0 if mood == "Tired" else 0.0)
		"Wander": return 13.0 + float(context.get("wander_variance",0.0))
	return 0.0
