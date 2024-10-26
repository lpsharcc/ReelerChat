extends Node

const LOCALAUDIO_PREFAB = preload("res://mods/BlueberryWolfi.ReelChat/Scenes/localAudio.tscn")
const REMOTE_AUDIO_PREFAB = preload("res://mods/BlueberryWolfi.ReelChat/Scenes/remoteAudio.tscn")

var prefabType = LOCALAUDIO_PREFAB
signal reelchat_voice(steamid, data)

var PlayerAPI

func readPackets():
	if Network.PLAYING_OFFLINE: return 
	
	var PACKET_SIZE = Steam.getAvailableP2PPacketSize(5)
	if PACKET_SIZE > 0:
		var PACKET = Steam.readP2PPacket(PACKET_SIZE, 5)
		
		if PACKET.empty():
			print("Error! Empty Packet!")
		
		var data = bytes2var(PACKET.data.decompress_dynamic( - 1, File.COMPRESSION_GZIP))

		emit_signal("reelchat_voice", int(data.steamid), data)

func _ready():
	PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")
	PlayerAPI.connect("_player_added", self, "init_playeraudio")

func _process(delta):
	if Network.STEAM_LOBBY_ID > 0:
		readPackets()

func init_playeraudio(player):
	print("reelchat player added")
	if player.name == "player":
		prefabType = LOCALAUDIO_PREFAB
	elif player.name.begins_with("@player@"):
		prefabType = REMOTE_AUDIO_PREFAB
		
	var playeraudioInstance = prefabType.instance()
	player.add_child(playeraudioInstance)
