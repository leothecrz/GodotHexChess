extends Control

enum REASONS {DEFAULT, SERVERSHUTODWN}
const SERVER_ID : int = 1;
const MAX_CON : int = 1;
const TIMEOUTSECS : int = 10;

# Signals
signal upnp_completed(error)

signal shutdownServerClient(reason:int);
signal multGUIClosed();

# GUI SIGNALS
signal player_connected(peer_id, player_info);
signal player_disconnected(peer_id);
signal multiplayer_enabled(ishost:bool);
signal multiplayer_disabled();

#References
@onready var tabs = $BG/Type;
@onready var HJ = $BG/HJScreen;
@onready var Lobby = $BG/LobbyScreen;
#
@onready var SearchDialog = $BG/Searching;
@onready var StartDialog = $BG/Connecting
#HostJoin
@onready var adrs = $BG/HJScreen/Address;
@onready var port = $BG/HJScreen/Port;
@onready var uname = $BG/HJScreen/UName;
#Lobby
@onready var lbName = $BG/LobbyScreen/MyName;
@onready var oplbName = $BG/LobbyScreen/OpName;
@onready var opProfIMG = $BG/LobbyScreen/IMGBG_OP/OpProfIMG;


#State
var NATThread = null

var players : Dictionary = {}
var player_info : Dictionary = {"name": "Name"}
var players_loaded : int = 0
var SERVER_PORT : int = 4440;
var myname : String = "";
var SERVER_ADRS : String = "";

#Universal Plug and Play
var UniversalPnP = UPNP.new();
var upnpDevice = null;

##UTILITY
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


## SETUP NODE
func _ready() -> void:
	#Client
	multiplayer.connected_to_server.connect(onConnectOK);
	multiplayer.connection_failed.connect(onConnectFAIL);
	multiplayer.server_disconnected.connect(onDisconnect);
	#Everyone
	multiplayer.peer_connected.connect(onPlayerConnected);
	multiplayer.peer_disconnected.connect(onPlayerDisconnected);
	
	upnp_completed.connect(serverSetup);
	return;


## MULT GUI BUTTONS
func _on_host_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	
	player_info["name"] = myname;
	SERVER_PORT = (port.text if isValidPort(port.text) else "4440").to_int();
	SERVER_ADRS = adrs.text if isValidADRS(adrs.text) else "127.0.0.1";
	
	lbName.text = centerText(myname);
	
	startServer();
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
	multiplayer_disabled.emit();
	
	multiplayer.multiplayer_peer = null;
	visible = false;
	return;

func _on_cancel_search_pressed() -> void:
	SearchDialog._deactivate();
	
	multiplayer.multiplayer_peer = null;
	multiplayer_disabled.emit();
	
	print("CANCELED CONNECTION");
	return;
func _on_ok_search_pressed() -> void:
	SearchDialog._deactivate();
	return;

func _on_close_pressed() -> void:
	visible = false;
	multGUIClosed.emit();
	return;

func _on_cancel_connect_pressed() -> void:
	return;



# Open the GUI Dialog
func _showGUI() -> void:
	visible = true;
	return;
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



#Update GUI
func updateGUIofPlayer(newplayer : Dictionary) -> void:
	oplbName.text = centerText(newplayer["name"]);
	opProfIMG.visible = true;
	return;
#
func playerLeft() -> void:
	oplbName.text = centerText("Empty");
	opProfIMG.visible = false;
	return;
#
func resetLobby() -> void:
	oplbName.text = centerText("Empty");
	opProfIMG.visible = false;
	return;


func serverSetup(err):
	var serverPeer = ENetMultiplayerPeer.new();
	var error = serverPeer.create_server(SERVER_PORT, MAX_CON);
	StartDialog._deactivate();
	
	if(err != OK):
		var ref = ConfirmationDialog.new();
		ref.dialog_text = "UPNP Failed Becase: ERROR:%d" % err;
		var dialogfunc = func(): ref.queue_free();
		ref.confirmed.connect(dialogfunc)
		ref.canceled.connect(dialogfunc)
		add_child(ref);
		ref.move_to_center();
		ref.visible = true;
	
	if (error):
		hostVisible();
		push_warning(error);
		return;
	
	lobbyVisible();
	multiplayer.multiplayer_peer = serverPeer;
	multiplayer_enabled.emit(true);

	players[SERVER_ID] = player_info;
	player_connected.emit(SERVER_ID, player_info);
	
	print("Server INIT");
	return;
func _upnp_setup(server_port):
	var err = UniversalPnP.discover();

	if (err != OK):
		push_error(str(err));
		upnp_completed.emit.call_deferred(err);
		return
		
	print("UPNP DISCOVER : count - ", UniversalPnP.get_device_count(), " err - ", err);
	print(UniversalPnP.get_device(0).description_url);
	
	if UniversalPnP.get_gateway() and UniversalPnP.get_gateway().is_valid_gateway():
		UniversalPnP.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP", 43200);
		UniversalPnP.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP", 43200);
		upnp_completed.emit.call_deferred(OK);
		print("GATEWAY")
	else:
		upnp_completed.emit.call_deferred(-1);
	print("SETUP DONE")
	return;
## SETUP AS HOST
func startServer():
	NATThread = Thread.new()
	NATThread.start(_upnp_setup.bind(SERVER_PORT))
	StartDialog._activate();
	return;
## SETUP CLIENT AS P2
func joinAsPlayerTwo():
	SearchDialog._activate();
	
	var clientPeer : ENetMultiplayerPeer = ENetMultiplayerPeer.new();
	var error = clientPeer.create_client(SERVER_ADRS, SERVER_PORT);
	if (error):
		push_warning(error);
		return;
		
	clientPeer.get_peer(1).set_timeout(0,0,1000*TIMEOUTSECS);
	
	multiplayer.multiplayer_peer = clientPeer;
	multiplayer_enabled.emit(false);
	
	print("JOINING");
	return;



#Save the given player_info to the sender_ID
@rpc("any_peer", "reliable")
func registerPlayer(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id();
	players[new_player_id] = new_player_info;
	
	updateGUIofPlayer(new_player_info);
	player_connected.emit(new_player_id, new_player_info);
	
	print("Adding Player : ", new_player_id, " PLAYERS : ",players);
	return;

# When a peer connects, send them my player info. Player Info Swap.
func onPlayerConnected(id : int):
	registerPlayer.rpc_id(id, player_info);
	return;
#Called when any connection ends
func onPlayerDisconnected(id : int):
	players.erase(id);
	player_disconnected.emit(id);
	
	playerLeft();
	
	print("PLAYER LEFT ", players);
	return;



#Client; Called when client succefully connects to server
func onConnectOK():
	SearchDialog._deactivate();
	
	lobbyVisible();
	lbName.text = centerText(myname);
	
	var peer_id = multiplayer.get_unique_id();
	players[peer_id] = player_info;
	player_connected.emit(peer_id, player_info);
	
	print("Connect OK : ", peer_id);
	return;
#Client; Called when client fails to connect to server
func onConnectFAIL():
	SearchDialog._failed();
	
	multiplayer.multiplayer_peer = null;
	multiplayer_disabled.emit();
	
	print("FAILED CONNECTION");
	return;	



#Called when disconnect from the server
func onDisconnect():
	multiplayer.multiplayer_peer = null
	
	players.clear();
	
	resetLobby();
	hostVisible();
	
	shutdownServerClient.emit(REASONS.SERVERSHUTODWN);
	multiplayer_disabled.emit();
	
	print("SERVER DISCONECTED");
	return
