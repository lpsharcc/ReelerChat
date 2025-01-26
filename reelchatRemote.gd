extends Node

var current_sample_rate: int = 16000
var has_loopback: bool = true
var is_voice_toggled: bool = false
var packet_read_limit: int = 5
var use_optimal_sample_rate: bool = false
var local_voice_generator: AudioStreamGenerator = null
var local_playback: AudioStreamPlayer = null
var local_voice_buffer: PoolByteArray = PoolByteArray()
onready var PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")

func _receive_net(steamid, data):
	var type: String = (data["type"]).trim_prefix("reelchat_")
	match type:
		"voice_packet":
			if int(get_parent().owner_id) == int(steamid):
				process_voice_data(data.voice_data)

func _ready():
	print("reelchat init")
	get_tree().root.get_node("BlueberryWolfiReelChat").connect("reelchat_voice", self, "_receive_net")
	local_voice_generator = AudioStreamGenerator.new()
	local_voice_generator.mix_rate = current_sample_rate
	$Voice.stream = local_voice_generator
	$Voice.play()

func get_sample_rate()->void :
	var optimal_sample_rate: int = Steam.getVoiceOptimalSampleRate()
	if use_optimal_sample_rate:
		current_sample_rate = optimal_sample_rate
	else :
		current_sample_rate = 16000


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
