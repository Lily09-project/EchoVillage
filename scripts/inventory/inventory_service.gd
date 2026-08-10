class_name InventoryService
extends RefCounted

var item_definitions: Dictionary = {}

func configure(definitions: Dictionary) -> void:
	item_definitions = definitions

func add_item(inventory: Dictionary, item_id: String, amount: int) -> bool:
	if amount <= 0 or not item_definitions.has(item_id): return false
	inventory[item_id] = count_item(inventory,item_id) + amount
	return true

func remove_item(inventory: Dictionary, item_id: String, amount: int) -> bool:
	if amount <= 0 or not item_definitions.has(item_id) or count_item(inventory,item_id) < amount: return false
	inventory[item_id] = count_item(inventory,item_id) - amount
	return true

func count_item(inventory: Dictionary, item_id: String) -> int:
	return maxi(0,int(inventory.get(item_id,0)))

func has_item(inventory: Dictionary, item_id: String, amount: int = 1) -> bool:
	return amount > 0 and item_definitions.has(item_id) and count_item(inventory,item_id) >= amount
