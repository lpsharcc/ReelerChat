extends Node

const LOCALAUDIO_PREFAB = preload("res://mods/LPSharcc.ReelerChat/Scenes/localAudio.tscn")
const REMOTE_AUDIO_PREFAB = preload("res://mods/LPSharcc.ReelerChat/Scenes/remoteAudio.tscn")
const SAVE_FILENAME = "user://webfishing_reelchat_volumes.save"

var prefabType = LOCALAUDIO_PREFAB
signal reelchat_voice(steamid, data)

var volumes
var PlayerAPI
var CHANNEL = 36

func read_packets():
	if Network.PLAYING_OFFLINE:
		return

	for i in 32:
		var packets = Steam.receiveMessagesOnChannel(CHANNEL, 8)
		if packets.size() == 0:
			break

		for packet in packets:
			var PACKET_SIZE: int = packet["payload"].size()
			if PACKET_SIZE > 0:
				var sender = packet["identity"]
				var data = bytes2var(packet.payload.decompress_dynamic(-1, Network.COMPRESSION_TYPE))

				if not data.has("type"):
					continue

				var type = data["type"]
				emit_signal("reelchat_voice", sender, data)

func _ready():
	PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")
	PlayerAPI.connect("_player_added", self, "init_playeraudio")
	var save = File.new()
	volumes = {}
	if save.file_exists(SAVE_FILENAME):
		save.open(SAVE_FILENAME, File.READ)
		volumes = save.get_var()
		save.close()
	else: 
		save.open(SAVE_FILENAME, File.WRITE)
		save.store_var(volumes)
		save.close()
	set_process(true)

func _process(delta):
	if Network.STEAM_LOBBY_ID > 0:
		read_packets()

func init_playeraudio(player):
	print("reelchat player added")
	if player.name == "player":
		prefabType = LOCALAUDIO_PREFAB
	elif player.name.begins_with("@player@"):
		prefabType = REMOTE_AUDIO_PREFAB
		
	var playeraudioInstance = prefabType.instance()
	
	if !volumes.has(player):
		volumes[player] = 1.0
	var voice: AudioStreamPlayer3D = playeraudioInstance.get_node("Voice")
	var volume_value = volumes[player] - 1.0
	voice.unit_db = 36.0 * volume_value if volume_value > 0 else volume_value * 80.0
	
	player.add_child(playeraudioInstance)
