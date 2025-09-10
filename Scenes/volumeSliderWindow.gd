extends Node

const SLIDER_PREFAB = preload("res://mods/LPSharcc.ReelerChat/Scenes/sliderPanel.tscn")

onready var Reelchat = get_tree().root.get_node("LPSharccReelerChat")
onready var PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")

onready var slider_container = $ScrollContainer/VBoxContainer

func add_slider_with_name(id: int, name: String)->void:
	var instance = SLIDER_PREFAB.instance()
	var name_label: RichTextLabel = instance.get_node("NameLabel")
	
	slider_container.add_child(instance)
	
	name_label.text = name
	instance.steam_id = id
	var player: Node = PlayerAPI.get_player_from_steamid(str(id))
	
	# if this fails, theres something very very wrong 
	# so we dont care either way :)
	var rc_instance = player.get_node("ReelchatAudio")
	instance.voice = rc_instance.get_node("Voice")
	
	if !Reelchat.volumes.has(id):
		Reelchat.volumes[id] = 1.0
	instance.slider.value = Reelchat.volumes[id]
	instance.name = "slider" + str(id)
	

func _ready():
	var PlayerAPI = get_tree().root.get_node("BlueberryWolfiAPIs/PlayerAPI")
	for player in Network.WEB_LOBBY_MEMBERS:
		if player == PlayerAPI.local_player.owner_id: continue
		add_slider_with_name(player, Steam.getFriendPersonaName(player))
