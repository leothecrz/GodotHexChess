extends Control

enum REASONS {DEFAULT, SERVERSHUTODWN}

#Signals
signal shutdownServerClient(reason:int);
signal multGUIClosed();

# GUI SIGNALS
signal player_connected(peer_id, player_info);
signal player_disconnected(peer_id);
signal multiplayer_enabled(ishost:bool);
signal multiplayer_disabled();

#Screens
@onready var HJ = $BG/HJScreen;
@onready var Lobby = $BG/LobbyScreen;

@onready var adrs = $BG/HJScreen/Address;
@onready var port = $BG/HJScreen/Port;
@onready var uname = $BG/HJScreen/UName;

@onready var lbName = $BG/LobbyScreen/MyName;
@onready var oplbName = $BG/LobbyScreen/OpName;
@onready var opProfIMG = $BG/LobbyScreen/IMGBG_OP/OpProfIMG;

@onready var tabs = $BG/Type;

const SERVER_ID : int = 1;
const MAX_CON : int = 1;

#States

var SERVER_PORT : int = 4440;
var SERVER_ADRS : String = "";
var players : Dictionary = {}
var player_info : Dictionary = {"name": "Name"}
var players_loaded : int = 0

var myname = "";


func _ready() -> void:
	#Client
	multiplayer.connected_to_server.connect(onConnectOK);
	multiplayer.connection_failed.connect(onConnectFAIL);
	multiplayer.server_disconnected.connect(onDisconnect);
	#Everyone
	multiplayer.peer_connected.connect(onPlayerConnected);
	multiplayer.peer_disconnected.connect(onPlayerDisconnected);
	return;



# Close the GUI Dialog
func _on_close_pressed() -> void:
	visible = false;
	multGUIClosed.emit();
	pass
#
func _showGUI() -> void:
	visible = true;
	return


#HJ Screen
func hostVisible() -> void:
	HJ.visible = true;
	Lobby.visible = false;
	tabs.current_tab = 0;
	return;
#Lobby Screen
func lobbyVisible() -> void:
	HJ.visible = false;
	Lobby.visible = true;
	tabs.current_tab = 1;
	return;


#Fill Lobby With PlayerData
func prepLobby(players:Dictionary) -> void:
	lobbyVisible();
	if players.keys().size() != 2 : push_error("Invalid players list")
	var pKeys = players.keys();
	lbName.text = centerText(players[pKeys[0]]["name"]);
	oplbName.text = centerText(players[pKeys[1]]["name"]);
	opProfIMG.visible = true;
	return;

func playerLeft() -> void:
	oplbName.text = centerText("Empty");
	opProfIMG.visible = false;
	return;

func resetLobby() -> void:
	oplbName.text = centerText("Empty");
	opProfIMG.visible = false;
	return;


#TODO ::
func isValidADRS(Str:String) -> bool:
	if(Str.is_empty()): return false;
	
	return true;
#TODO ::
func isValidPort(Str:String) -> bool:
	if(Str.is_empty()): return false;
	if(not Str.is_valid_int()): return false;
	return true;
#TODO ::
func isValidUname(Str:String) -> bool:
	if(Str.is_empty()): return false;
	return true;
#BBCODE Center Str string
func centerText(Str) -> String:
	return "[center]" + Str + "[/center]";




##
func startServer():
	var serverPeer = ENetMultiplayerPeer.new();
	var error = serverPeer.create_server(SERVER_PORT, MAX_CON);
	if error:
		pass;
		
	multiplayer.multiplayer_peer = serverPeer;
	multiplayer_enabled.emit(true);

	players[SERVER_ID] = player_info;
	player_connected.emit(SERVER_ID, player_info);
	
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



func _on_host_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	
	player_info["name"] = myname;
	SERVER_PORT = (port.text if isValidPort(port.text) else "4440").to_int();
	SERVER_ADRS = adrs.text if isValidADRS(adrs.text) else "127.0.0.1";
	startServer();
	
	lbName.text = centerText(myname);
	lobbyVisible();
	return;

func _on_join_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	
	player_info["name"] = myname;
	SERVER_PORT = (port.text if isValidPort(port.text) else "4440").to_int();
	SERVER_ADRS = adrs.text if isValidADRS(adrs.text) else "127.0.0.1";
	
	joinAsPlayerTwo();
	return;

func _on_leave_pressed() -> void:
	resetLobby();
	hostVisible();
	shutdownServerClient.emit(REASONS.DEFAULT);
	
	multiplayer.multiplayer_peer = null;
	
	visible = false;
	return;



#Save the given player_info to the sender_ID
@rpc("any_peer", "reliable")
func registerPlayer(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id();
	players[new_player_id] = new_player_info;
	prepLobby(players);
	
	player_connected.emit(new_player_id, new_player_info);
	print("Adding Player : ", new_player_id, " PLAYERS : ",players);
	return;

# When a peer connects, send them my player info.
# Player Info Swap
func onPlayerConnected(id : int):
	registerPlayer.rpc_id(id, player_info);
	return;
#Client; Called when any connection ends
func onPlayerDisconnected(id : int):
	players.erase(id);
	player_disconnected.emit(id);
	playerLeft();
	print("PLAYER LEFT ", players);
	pass;


#Client; Called when client succefully connects to server
func onConnectOK():
	var peer_id = multiplayer.get_unique_id();
	players[peer_id] = player_info;
	player_connected.emit(peer_id, player_info);
	print("Connect OK : ", peer_id);
	return;
#Client; Called when client fails to connect to server
func onConnectFAIL():
	multiplayer.multiplayer_peer = null;
	print("FAILED CONNECTION");
	return;	



func onDisconnect():
	multiplayer.multiplayer_peer = null
	players.clear();
	
	resetLobby();
	hostVisible();
	shutdownServerClient.emit(REASONS.SERVERSHUTODWN);
	
	print("SERVER DISCONECTED");
	return
