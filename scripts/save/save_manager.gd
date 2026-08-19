extends Node

const SAVE_PATH := "user://echo_village_save.json"
const PREFERENCES_PATH := "user://echo_village_preferences.json"
const SaveMigrationService = preload("res://scripts/save/save_migration.gd")
var preferences := {"autosave":true,"motion":true,"fullscreen":false,"audio":true,"onboarding_seen":false}
var last_save_kind := ""

func _ready() -> void:
	load_preferences()
	if not GameTime.day_changed.is_connected(_on_day_changed): GameTime.day_changed.connect(_on_day_changed)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(kind: String = "manual") -> bool:
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"save_version":2,"time":GameTime.serialize(),"world_state":GameManager.serialize()},"\t"))
	last_save_kind = kind
	GameManager.add_log("自動儲存完成。" if kind == "auto" else "手動儲存完成。")
	EventBus.save_completed.emit(SAVE_PATH)
	return true

func autosave_game() -> bool:
	if not bool(preferences.get("autosave",true)): return false
	return save_game("auto")

func _on_day_changed(_day: int, _day_of_week: int) -> void:
	autosave_game()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		GameManager.add_log("目前還沒有存檔。")
		return false
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		GameManager.add_log("無法安全讀取此存檔。")
		return false
	var migration: Dictionary = SaveMigrationService.migrate(data)
	if not bool(migration.get("ok",false)):
		GameManager.add_log(str(migration.get("reason","無法安全讀取此存檔。")))
		return false
	var migrated: Dictionary = migration["data"]
	GameTime.deserialize(migrated.get("time",{}))
	if not GameManager.deserialize(migrated.get("world_state",{})): return false
	GameManager.add_log("已讀取存檔並還原模擬狀態。")
	return true

func load_preferences() -> Dictionary:
	if not FileAccess.file_exists(PREFERENCES_PATH): return preferences.duplicate(true)
	var file := FileAccess.open(PREFERENCES_PATH,FileAccess.READ)
	if file == null: return preferences.duplicate(true)
	var parsed = JSON.parse_string(file.get_as_text())
	preferences = sanitize_preferences(parsed)
	return preferences.duplicate(true)

func sanitize_preferences(raw: Variant) -> Dictionary:
	var sanitized: Dictionary = preferences.duplicate(true)
	if not (raw is Dictionary): return sanitized
	var parsed: Dictionary = raw
	for key in sanitized:
		if parsed.has(key) and parsed[key] is bool: sanitized[key] = parsed[key]
	return sanitized

func set_preference(key: String, value: bool) -> bool:
	if not preferences.has(key): return false
	preferences[key] = value
	var file := FileAccess.open(PREFERENCES_PATH,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(preferences,"\t"))
	return true

func get_preference(key: String, fallback: bool = false) -> bool:
	return bool(preferences.get(key,fallback))
