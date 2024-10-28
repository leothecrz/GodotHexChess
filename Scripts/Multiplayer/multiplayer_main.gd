extends Node

@onready var gui = $"../MultGUI";

const SERVER_ID = 1;
const MAX_CON = 1;
const DEFAULT_SERVER_IP = "127.0.0.1";

var SERVER_PORT : int = 4440;
var SERVER_ADRS : String = "";
var players = {}
var player_info = {"name": "Name"}
var players_loaded = 0

#Server INIT
#JOINING
#Connect OK : 1501180601
#Adding Player : 1
#Adding Player : 1501180601



# GUI SIGNALS
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected




# When a peer connects, send them my player info.
# Player Info Swap
func player_add(id : int):
	registerPlayer.rpc_id(id, player_info);
	return;

#
@rpc("any_peer", "reliable")
func registerPlayer(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id();
	players[new_player_id] = new_player_info;
	player_connected.emit(new_player_id, new_player_info);
	
	print("Adding Player : ", new_player_id, " PLAYERS : ",players);
	gui.prepLobby(players);
	return;
	

#Client
func connect_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	print("Connect OK : ", peer_id);
	return;
	
	
	
func player_remove(id : int):
	players.erase(id)
	player_disconnected.emit(id)
	print("PLAYER LEFT ", players);
	pass;





func connect_failed():
	multiplayer.multiplayer_peer = null;
	print("FAILED CONNECTION");
	pass;

func serverDisconnected():
	multiplayer.multiplayer_peer = null
	players.clear();
	print("SERVER DISC ", players);
	# clean up gameboard and reset for single player
	pass;





func startServer():
	var serverPeer = ENetMultiplayerPeer.new();
	var error = serverPeer.create_server(SERVER_PORT, MAX_CON);
	if error:
		pass;
	multiplayer.multiplayer_peer = serverPeer;
	
	players[SERVER_ID] = player_info;
	player_connected.emit(SERVER_ID, player_info);
	
	print("Server INIT");
	return;


func joinAsPlayerTwo():
	var clientPeer = ENetMultiplayerPeer.new();
	var error =clientPeer.create_client(SERVER_ADRS, SERVER_PORT);
	if error:
		pass;
	multiplayer.multiplayer_peer = clientPeer;
	print("JOINING");
	return;





func _ready() -> void:
	#Client
	multiplayer.connected_to_server.connect(connect_ok);
	multiplayer.connection_failed.connect(connect_failed);
	multiplayer.server_disconnected.connect(serverDisconnected);
	#Everyone
	multiplayer.peer_connected.connect(player_add);
	multiplayer.peer_disconnected.connect(player_remove);
	return;





func _on_mult_gui_host_server(uname: String, adrs: String, port: String) -> void:
	player_info["name"] = uname;
	SERVER_PORT = port.to_int();
	SERVER_ADRS = adrs;
	startServer();
	return;


func _on_mult_gui_join_server(uname: String, adrs: String, port: String) -> void:
	player_info["name"] = uname;
	SERVER_PORT = port.to_int();
	SERVER_ADRS = adrs;
	joinAsPlayerTwo();
	return;
