extends Node

signal minute_changed(minute: int, hour: int)
signal hour_changed(hour: int)
signal day_changed(day: int, day_of_week: int)

const MINUTES_PER_DAY := 1440
const SPEEDS := {"normal": 1.0, "2x": 2.0, "5x": 5.0, "10x": 10.0}
var minute: int = 360
var day: int = 1
var day_of_week: int = 1
var time_scale: float = 1.0
var seconds_per_game_minute: float = 0.12
var _accumulator: float = 0.0
var simulation_paused := false

func _process(delta: float) -> void:
	if simulation_paused: return
	_accumulator += delta * time_scale
	while _accumulator >= seconds_per_game_minute:
		_accumulator -= seconds_per_game_minute
		advance_minute()

func advance_minute() -> void:

	minute += 1
	if minute >= MINUTES_PER_DAY:
		minute = 0
		day += 1
		day_of_week = (day_of_week % 7) + 1
		day_changed.emit(day, day_of_week)
	if minute % 60 == 0:
		hour_changed.emit(minute / 60)
	minute_changed.emit(minute, minute / 60)

func set_speed(speed_key: String) -> void:

	time_scale = float(SPEEDS.get(speed_key, 1.0))

func set_simulation_paused(value: bool) -> void:
	simulation_paused = value

func reset_clock() -> void:
	minute = 360
	day = 1
	day_of_week = 1
	time_scale = 1.0
	_accumulator = 0.0
	simulation_paused = false

func formatted_time() -> String:

	return "第 %d 天  •  %02d:%02d" % [day, minute / 60, minute % 60]

func phase_for_minute(value: int) -> String:

	var normalized := posmod(value, MINUTES_PER_DAY)
	if normalized >= 300 and normalized < 420: return "黎明"
	if normalized >= 420 and normalized < 660: return "上午"
	if normalized >= 660 and normalized < 960: return "正午"
	if normalized >= 960 and normalized < 1140: return "午後"
	if normalized >= 1140 and normalized < 1260: return "黃昏"
	return "深夜"

func day_phase() -> String:

	return phase_for_minute(minute)

func visual_profile(value: int = minute) -> Dictionary:

	var normalized := posmod(value, MINUTES_PER_DAY)
	var solar := maxf(0.0,sin((float(normalized) - 360.0) * PI / 720.0))
	return {"phase":phase_for_minute(normalized),"light":0.22 + solar * 0.78,"is_night":solar < 0.12}

func serialize() -> Dictionary:

	return {"minute": minute, "day": day, "day_of_week": day_of_week, "time_scale": time_scale}

func deserialize(data: Dictionary) -> void:
	minute = _safe_integer(data.get("minute",360),360,0,MINUTES_PER_DAY - 1)
	day = _safe_integer(data.get("day",1),1,1,1000000)
	day_of_week = _safe_integer(data.get("day_of_week",1),1,1,7)
	time_scale = _safe_float(data.get("time_scale",1.0),1.0,0.01,10.0)
	_accumulator = 0.0

func _safe_integer(value: Variant, fallback: int, minimum: int, maximum: int) -> int:
	if not (value is int or value is float): return fallback
	var number := float(value)
	if number != floor(number) or number < float(minimum) or number > float(maximum): return fallback
	return int(number)

func _safe_float(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if not (value is int or value is float): return fallback
	var number := float(value)
	if number < minimum or number > maximum: return fallback
	return number
