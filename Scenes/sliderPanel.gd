extends Node

onready var slider:HSlider = $HSlider
onready var line:LineEdit = $LineEdit
onready var Reelchat = get_tree().root.get_node("LPSharccReelerChat")


var regex = RegEx.new()
var steam_id
var voice: AudioStreamPlayer3D

func _ready():
	regex.compile("^d*\\.d*$")
	

func _on_text_entered(new_text: String):
	print("here for real")
	var new_value = Reelchat.volumes[steam_id]
	var result:RegExMatch = regex.search(new_text.strip_escapes())
	if result:
		print("wow no way")
		# check successful, set the value to the new one
		new_value = float(new_text)
	print(result)
	print(new_text)
	slider.value = new_value

func _on_slider_value_changed(value):
	line.text = str(value)
	Reelchat.volumes[steam_id] = value
	var volume_value = value - 1.0
	voice.unit_db = 36.0 * volume_value if volume_value > 0 else volume_value * 80.0
