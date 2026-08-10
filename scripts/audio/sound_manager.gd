extends Node

var enabled := true
var ui_player: AudioStreamPlayer

func _ready() -> void:
	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UIAudioPlayer"
	ui_player.volume_db = -14.0
	add_child(ui_player)
	enabled = SaveManager.get_preference("audio",true)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and ui_player != null: ui_player.stop()
	SaveManager.set_preference("audio",value)

func play_ui() -> void:
	play_tone(520.0,0.055)

func play_interaction(kind: String = "talk") -> void:
	var tones := {"talk":620.0,"give_bread":760.0,"steal_food":240.0,"trade":470.0,"ask":580.0,"gather":690.0,"craft":820.0}
	play_tone(float(tones.get(kind,520.0)),0.075)

func play_tone(frequency: float, duration: float) -> void:
	if not enabled or ui_player == null: return
	ui_player.stream = make_tone(frequency,duration)
	ui_player.play()

func make_tone(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(1,int(sample_rate * duration))
	var samples := PackedByteArray()
	samples.resize(sample_count)
	for index in sample_count:
		var fade := 1.0 - float(index) / float(sample_count)
		samples[index] = clampi(int(128.0 + sin(TAU * frequency * float(index) / float(sample_rate)) * 38.0 * fade),0,255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = samples
	return stream
