extends Node

const MUTE_ICON = preload("res://mods/LPSharcc.ReelerChat/Assets/mic_mute.png")
const UNMUTE_ICON = preload("res://mods/LPSharcc.ReelerChat/Assets/mic_unmute.png")
const MUTE_SOUND = preload("res://mods/LPSharcc.ReelerChat/Assets/mic_mute.ogg")
const UNMUTE_SOUND = preload("res://mods/LPSharcc.ReelerChat/Assets/mic_unmute.ogg")
const CHANNEL = 36
const SAVE_FILENAME = "user://webfishing_reelchat_volumes.save"

var steam_id = Network.STEAM_ID
var current_sample_rate: int = 16000
var has_loopback: bool = false
var is_voice_toggled: bool = false
var packet_read_limit: int = 5
var use_optimal_sample_rate: bool = false
var local_voice_generator: AudioStreamGenerator = null
var local_playback: AudioStreamPlayer = null
var local_voice_buffer: PoolByteArray = PoolByteArray()
var slider_window_opened: bool = false
var slider_window_scene = preload("res://mods/LPSharcc.ReelerChat/Scenes/volumeSliderWindow.tscn")
var slider_window_instance: Node = null
var current_ui
var mic_icon
var mic_sound
var tween

onready var PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")
onready var KeybindAPI = get_tree().root.get_node("BlueberryWolfiAPIs/KeybindsAPI")
onready var Reelchat = get_tree().root.get_node("LPSharccReelerChat")

onready var entities = get_tree().current_scene.get_node("Viewport/main/entities")

func _ready():
	print("reelerchat init")
	local_voice_generator = AudioStreamGenerator.new()
	local_voice_generator.mix_rate = current_sample_rate
	$Voice.stream = local_voice_generator
	$Voice.play()
	
	yield(get_tree().create_timer(0.5), "timeout")
	var toggle_mic_signal = KeybindAPI.register_keybind({
		"action_name": "toggle_mic",
		"title": "Toggle Mic",
		"key": KEY_F,
	})
	
	var pushtalk_mic_signal = KeybindAPI.register_keybind({
		"action_name": "toggle_ptt",
		"title": "Toggle Push to Talk",
		"key": KEY_T,
	})
	
	var open_slider_window_signal = KeybindAPI.register_keybind({
		"action_name": "open_slider_window",
		"title": "Open Reelchat Volume Control Window",
		"key": KEY_L,
	})
	
	print(toggle_mic_signal)
	KeybindAPI.connect(toggle_mic_signal, self, "_on_toggle_voice_pressed")
	KeybindAPI.connect(pushtalk_mic_signal, self, "_on_to_talk_button_down")
	KeybindAPI.connect(pushtalk_mic_signal + "_up", self, "_on_to_talk_button_up")
	KeybindAPI.connect(open_slider_window_signal, self, "_on_open_slider_window_pressed")
	
	_init_ui()
	
func _init_ui():
	current_ui = preload("res://mods/LPSharcc.ReelerChat/Scenes/reelchatUI.tscn").instance()
	get_tree().root.get_node("playerhud/main/in_game").add_child(current_ui)
	mic_icon = current_ui.get_node("mic_icon")
	mic_sound = current_ui.get_node("mic_sound")
	tween = Tween.new()
	current_ui.add_child(tween)

func _ui_tween_size(ui, factor):
	tween.interpolate_property(
		ui,
		"rect_scale",
		mic_icon.rect_scale,
		mic_icon.rect_scale * factor,
		1.0,
		Tween.TRANS_ELASTIC,
		Tween.EASE_OUT
	)

func _process(_delta: float)->void :
	check_for_voice()

func _send_net(type: String, data: Dictionary = {}, target = "all"):
	var complete_data: Dictionary = { "steamid": Network.STEAM_ID, "type": ("reelchat_%s" % type), "voice_data": data}

	if target in ["all", "steamlobby"]:
		emit_signal("reelchat_voice", Network.STEAM_ID, complete_data)
		
		Network._send_P2P_Packet(complete_data, target, 2, CHANNEL)
	elif int(target) == Network.STEAM_ID:
		emit_signal("reelchat_voice", target, complete_data)
	else:
		Network._send_P2P_Packet(complete_data, int(target), 2, CHANNEL)

func _on_loopback_pressed()->void :
	has_loopback = not has_loopback
	print("Loopback enabled: %s" % has_loopback)


func _on_optimal_pressed()->void :
	use_optimal_sample_rate = not use_optimal_sample_rate

func is_busy():
	if not PlayerAPI: return true
	if not is_instance_valid(PlayerAPI.local_player): return true
	if PlayerAPI.local_player.busy: return true
	return false

func _on_toggle_voice_pressed()->void :
	if is_busy(): return
	is_voice_toggled = not is_voice_toggled
	print("Toggling voice chat: %s" % is_voice_toggled)
	change_voice_status()


func _on_to_talk_button_down()->void :
	if is_busy(): return
	print("Starting voice chat")
	is_voice_toggled = true
	change_voice_status()


func _on_to_talk_button_up()->void :
	if is_busy(): return
	print("Stopping voice chat")
	is_voice_toggled = false
	change_voice_status()

func change_voice_status()->void :
	
	Steam.setInGameVoiceSpeaking(Network.STEAM_ID, is_voice_toggled)

	if is_voice_toggled:
		mic_icon.texture = UNMUTE_ICON
		mic_sound.stream = UNMUTE_SOUND
		mic_sound.play()
		_ui_tween_size(mic_icon, 5)
		
		Steam.startVoiceRecording()
	else:
		mic_icon.texture = MUTE_ICON
		mic_sound.stream = MUTE_SOUND
		mic_sound.play()
		_ui_tween_size(mic_icon, 1)
		
		Steam.stopVoiceRecording()


func check_for_voice()->void :
	var available_voice: Dictionary = Steam.getAvailableVoice()
	if available_voice["result"] == Steam.VOICE_RESULT_OK and available_voice["buffer"] > 0:
		var voice_data: Dictionary = Steam.getVoice()
		if voice_data["result"] == Steam.VOICE_RESULT_OK and voice_data["written"]:
			_send_net("voice_packet", voice_data, "all")
			
			if has_loopback:
				print("Loopback on")
				process_voice_data(voice_data)


func get_sample_rate()->void :
	var optimal_sample_rate: int = Steam.getVoiceOptimalSampleRate()
	if use_optimal_sample_rate:
		current_sample_rate = optimal_sample_rate
	else :
		current_sample_rate = 16000
	print("Current sample rate: %s" % current_sample_rate)


func process_voice_data(voice_data: Dictionary)->void :
	get_sample_rate()

	var decompressed_voice: Dictionary = Steam.decompressVoice(voice_data["buffer"], voice_data["written"], current_sample_rate)

	if decompressed_voice["result"] == Steam.VOICE_RESULT_OK and decompressed_voice["size"] > 0:

		local_voice_buffer = decompressed_voice["uncompressed"]

		var samples_to_add: int = int(decompressed_voice["size"] / 2)
		var buffer: PoolVector2Array = PoolVector2Array()

		for i in range(samples_to_add):
			
			var sample_int: int = int(local_voice_buffer[i * 2]) | (int(local_voice_buffer[i * 2 + 1]) << 8)

			
			if sample_int >= 32768:
				sample_int -= 65536

			
			var sample_float: float = sample_int / 32768.0

			
			buffer.append(Vector2(sample_float, sample_float))

		
		var playback = $Voice.get_stream_playback() as AudioStreamGeneratorPlayback
		if playback.can_push_buffer(buffer.size()):
			playback.push_buffer(buffer)

func _on_open_slider_window_pressed()->void:
	
	if slider_window_opened:
		# save the volumes and close the window
		# TODO make it async so we dont have to wait for the save to be put on disk
		
		var save = File.new()
		save.open(SAVE_FILENAME, File.WRITE)
		save.store_var(Reelchat.volumes)
		save.close()
		
		slider_window_instance.queue_free()
		slider_window_instance = null
	else:
		# open the window
		var player_hud = get_node_or_null("/root/playerhud")
		var meow: Control = \
			player_hud.get_node_or_null("main")
		
		if meow and meow.get_focus_owner():
			return
		
		slider_window_instance = slider_window_scene.instance()
		player_hud.add_child(slider_window_instance)
	
	slider_window_opened = !slider_window_opened
