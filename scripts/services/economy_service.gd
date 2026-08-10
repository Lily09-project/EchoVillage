class_name EconomyService
extends RefCounted

var definitions: Dictionary

func _init(recipe_definitions: Dictionary) -> void:
	definitions = recipe_definitions

func craft(inventory: Dictionary, current_location: String, recipe_id: String) -> Dictionary:
	if not definitions.has(recipe_id): return {"ok":false,"reason":"找不到這份配方。"}
	var recipe: Dictionary = definitions[recipe_id]
	if str(recipe.get("required_location","")) != current_location: return {"ok":false,"reason":"必須在指定地點製作。"}
	var ingredients: Dictionary = recipe.get("ingredients",{})
	for item_id in ingredients:
		if int(inventory.get(item_id,0)) < int(ingredients[item_id]): return {"ok":false,"reason":"素材不足。"}
	for item_id in ingredients: inventory[item_id] = int(inventory.get(item_id,0)) - int(ingredients[item_id])
	var output_id := str(recipe.get("output_item",""))
	var output_amount := int(recipe.get("output_amount",1))
	inventory[output_id] = int(inventory.get(output_id,0)) + output_amount
	return {"ok":true,"reason":"","output":{"item_id":output_id,"amount":output_amount}}
