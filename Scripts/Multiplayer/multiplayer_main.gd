extends Node

@onready var MultiplayerGUI = $MultiplayerGUI;

const SERVER_ID : int = 1;
const MAX_CON : int = 1;

var SERVER_PORT : int = 4440;
var SERVER_ADRS : String = "";
var players : Dictionary = {}
var player_info : Dictionary = {"name": "Name"}
var players_loaded : int = 0




# GUI SIGNALS
signal player_connected(peer_id, player_info);
signal player_disconnected(peer_id);
signal server_disconnected;
signal multiplayer_enabled(ishost:bool);
signal multiplayer_disabled();

func _showGUI():
	MultiplayerGUI._showGUI();
	return;

# When a peer connects, send them my player info.
# Player Info Swap
func player_add(id : int):
	registerPlayer.rpc_id(id, player_info);
	return;
#Client; Called when any connection ends
func player_remove(id : int):
	players.erase(id);
	player_disconnected.emit(id);
	MultiplayerGUI.playerLeft();
	print("PLAYER LEFT ", players);
	pass;

#Save the given player_info to the sender_ID
@rpc("any_peer", "reliable")
func registerPlayer(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id();
	players[new_player_id] = new_player_info;
	
	MultiplayerGUI.prepLobby(players);
	
	player_connected.emit(new_player_id, new_player_info);
	print("Adding Player : ", new_player_id, " PLAYERS : ",players);
	return;


#Client; Called when client succefully connects to server
func connect_ok():
	var peer_id = multiplayer.get_unique_id();
	players[peer_id] = player_info;
	player_connected.emit(peer_id, player_info);
	print("Connect OK : ", peer_id);
	return;
#Client; Called when client fails to connect to server
func connect_failed():
	multiplayer.multiplayer_peer = null;
	print("FAILED CONNECTION");
	return;	








func serverDisconnected():
	multiplayer.multiplayer_peer = null
	players.clear();
	MultiplayerGUI._server_disconnected();
	print("SERVER DISCONECTED");
	return




##
func startServer():
	var serverPeer = ENetMultiplayerPeer.new();
	var error = serverPeer.create_server(SERVER_PORT, MAX_CON);
	if error:
		pass;
		
	multiplayer.multiplayer_peer = serverPeer;
	
	players[SERVER_ID] = player_info;
	player_connected.emit(SERVER_ID, player_info);
	
	multiplayer_enabled.emit(true);
	print("Server INIT");
	return;
##
func joinAsPlayerTwo():
	var clientPeer = ENetMultiplayerPeer.new();
	var error =clientPeer.create_client(SERVER_ADRS, SERVER_PORT);
	if error:
		pass;
	multiplayer.multiplayer_peer = clientPeer;
	multiplayer_enabled.emit(false);
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


func _on_multiplayer_gui_leave_multiplayer() -> void:
	multiplayer.multiplayer_peer = null;
	return;
