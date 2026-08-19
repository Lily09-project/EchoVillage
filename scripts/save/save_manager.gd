extends Node

const SAVE_PATH := "user://echo_village_save.json"
const PREFERENCES_PATH := "user://echo_village_preferences.json"
const MAX_SAVE_BYTES := 4 * 1024 * 1024
const MAX_PREFERENCES_BYTES := 64 * 1024
const SaveMigrationService = preload("res://scripts/save/save_migration.gd")
var preferences := {"autosave":true,"motion":true,"fullscreen":false,"audio":true,"onboarding_seen":false}
var last_save_kind := ""
var _test_storage_root := ""

func _ready() -> void:
	load_preferences()
	if not GameTime.day_changed.is_connected(_on_day_changed): GameTime.day_changed.connect(_on_day_changed)

func has_save() -> bool:
	return FileAccess.file_exists(_storage_path("echo_village_save.json",SAVE_PATH))

func configure_test_storage(root: String) -> bool:
	# Test-only isolation: never redirect a release build. CI may provide an
	# absolute temporary directory; local runs default to a project-local folder
	# so fuzz/save tests cannot overwrite a developer's real user:// save.
	if not OS.is_debug_build(): return false
	var normalized := root.strip_edges()
	if normalized.is_empty(): return false
	var absolute := ""
	if normalized.begins_with("res://"):
		if normalized.length() <= 6: return false
		absolute = ProjectSettings.globalize_path(normalized)
	elif normalized.begins_with("/") or normalized.begins_with("\\\\") or (normalized.length() >= 3 and normalized[1] == ":" and (normalized[2] == "\\" or normalized[2] == "/")):
		absolute = normalized
	else:
		return false
	if DirAccess.make_dir_recursive_absolute(absolute) != OK and not DirAccess.dir_exists_absolute(absolute): return false
	_test_storage_root = absolute.trim_suffix("/").trim_suffix("\\")
	return true

func _storage_path(filename: String, fallback: String) -> String:
	return _test_storage_root.path_join(filename) if not _test_storage_root.is_empty() else fallback

func save_game(kind: String = "manual") -> bool:
	var save_path := _storage_path("echo_village_save.json",SAVE_PATH)
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"save_version":2,"time":GameTime.serialize(),"world_state":GameManager.serialize()},"\t"))
	last_save_kind = kind
	GameManager.add_log("自動儲存完成。" if kind == "auto" else "手動儲存完成。")
	EventBus.save_completed.emit(save_path)
	return true

func autosave_game() -> bool:
	if not bool(preferences.get("autosave",true)): return false
	return save_game("auto")

func _on_day_changed(_day: int, _day_of_week: int) -> void:
	autosave_game()

func load_game() -> bool:
	var save_path := _storage_path("echo_village_save.json",SAVE_PATH)
	if not FileAccess.file_exists(save_path):
		GameManager.add_log("目前還沒有存檔。")
		return false
	var raw := read_limited_text(save_path,MAX_SAVE_BYTES)
	if raw.is_empty():
		GameManager.add_log("無法安全讀取此存檔。")
		return false
	var data = JSON.parse_string(raw)
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
	var preferences_path := _storage_path("echo_village_preferences.json",PREFERENCES_PATH)
	if not FileAccess.file_exists(preferences_path): return preferences.duplicate(true)
	var parsed = JSON.parse_string(read_limited_text(preferences_path,MAX_PREFERENCES_BYTES))
	preferences = sanitize_preferences(parsed)
	return preferences.duplicate(true)

func read_limited_text(path: String, max_bytes: int) -> String:
	if max_bytes < 0 or not FileAccess.file_exists(path): return ""
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > max_bytes: return ""
	return file.get_as_text()

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
	var file := FileAccess.open(_storage_path("echo_village_preferences.json",PREFERENCES_PATH),FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(preferences,"\t"))
	return true

func get_preference(key: String, fallback: bool = false) -> bool:
	return bool(preferences.get(key,fallback))
