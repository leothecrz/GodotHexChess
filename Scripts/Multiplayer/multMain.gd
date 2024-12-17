extends Control;
class_name MultiplayerMain;

enum REASONS {DEFAULT, SERVERSHUTODWN};

const SERVER_ID : int = 1;
const MAX_CON : int = 1;
const TIMEOUTSECS : int = 10;
const UPNP_FAILURE_NO_GATEWAY = -1


# Signals
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
@onready var clientDialog = $BG/ClientDialog;
@onready var serverDialog = $BG/ServerDialog
#HostJoin
@onready var adrs = $BG/HJScreen/Address;
@onready var port = $BG/HJScreen/Port;
@onready var uname = $BG/HJScreen/UName;
#Lobby
@onready var lbName = $BG/LobbyScreen/MyName;
@onready var oplbName = $BG/LobbyScreen/OpName;
@onready var opProfIMG = $BG/LobbyScreen/IMGBG_OP/OpProfIMG;


#State
var NATThread:Thread = null

var players : Dictionary = {}
var player_info : Dictionary = {"name": "Name"}
var SERVER_PORT : int = 4440;
var myname : String = "";
var SERVER_ADRS : String = "";

#Universal Plug and Play
var UniversalPnP = UPNP.new();
var portsAreOpen = false;
var cancelled = false;
var useUPNP


##UTILITY
#TODO ::
func isValidADRS(Str:String) -> bool:
	if(Str.is_empty()): return false;
	var parts : PackedStringArray = Str.split('.');
	if(parts.size() != 4):
		return false;
	for part : String in parts:
		if(not part.is_valid_int()):
			return false;
		var num : int = int(part);
		if((num < 0) or (num > 255)):
			return false;
		if part != str(num):
			return false;
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
	return;
func _notification(what: int) -> void:
	if(what == NOTIFICATION_WM_CLOSE_REQUEST):
		hostCleanUp();
	return;


## GUI
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
func setOpGUI(newplayer : Dictionary) -> void:
	oplbName.text = centerText(newplayer["name"]);
	opProfIMG.visible = true;
	return;
#
func resetOpGUI() -> void:
	oplbName.text = centerText("Empty");
	opProfIMG.visible = false;
	return;


#UPNP CLEANUP
func hostCleanUp():
	if(portsAreOpen):
		var resOne = UniversalPnP.delete_port_mapping(SERVER_PORT, "UDP")
		if(resOne != UPNP.UPNPResult.UPNP_RESULT_SUCCESS):
			var ref = ConfirmationDialog.new();
			var dialogfunc = func(): ref.queue_free();
			ref.confirmed.connect(dialogfunc)
			ref.canceled.connect(dialogfunc)
			ref.dialog_text = "UPNP was unable to close oppened ports.";
			add_child(ref);
			ref.move_to_center();
			ref.visible = true;
			return;
		portsAreOpen = false;
	return;


## Error GUI INFORM
#
func serverPeerSetupErrorHandle(err):
	var ref = ConfirmationDialog.new();
	var dialogfunc = func(): ref.queue_free();
	ref.confirmed.connect(dialogfunc)
	ref.canceled.connect(dialogfunc)
	match (err):
		20:
			ref.dialog_text = "Cant create multiplayer peer";
		_:
			ref.dialog_text = "Peer setup failed because: ERROR %d " % err;

	add_child(ref);
	ref.move_to_center();
	ref.visible = true;
	return;
#
func serverSetupErrorHandle(err):
	var ref = ConfirmationDialog.new();
	var dialogfunc = func(): ref.queue_free();
	ref.confirmed.connect(dialogfunc)
	ref.canceled.connect(dialogfunc)
	match (err):
		UPNP_FAILURE_NO_GATEWAY:
			ref.dialog_text = "The found Gateway can't foward ports";
		UPNP.UPNPResult.UPNP_RESULT_CONFLICT_WITH_OTHER_MAPPING:
			ref.dialog_text = "selected PORT %d is already in use" % SERVER_PORT;
		_:
			ref.dialog_text = "UPNP setup failed because: ERROR %d " % err;

	add_child(ref);
	ref.move_to_center();
	ref.visible = true;
	return;


## PREP CLIENT/SERVER
#
func finishServerSetup(err):
	if(useUPNP):
		if(NATThread):
			NATThread.wait_to_finish();
			NATThread = null;
		if(cancelled):
			print("START CANCELLED");
			hostCleanUp();
			return;
		serverDialog._deactivate();
		if(err != UPNP.UPNPResult.UPNP_RESULT_SUCCESS):
			serverSetupErrorHandle(err);
			return; #FAILED UPNP START
	
	var serverPeer = ENetMultiplayerPeer.new();
	var error = serverPeer.create_server(SERVER_PORT, MAX_CON);
	if (error != OK):
		serverPeerSetupErrorHandle(error)
		return;
	
	lobbyVisible();
	multiplayer.multiplayer_peer = serverPeer;
	multiplayer_enabled.emit(true);

	players[SERVER_ID] = player_info;
	player_connected.emit(SERVER_ID, player_info);
	
	print("Server INIT");
	return;
#Do not call on main thread; blocks;
func setupUPNP(server_port):
	print("Using UPNP") 
	var err = UniversalPnP.discover();
	if (err != UPNP.UPNPResult.UPNP_RESULT_SUCCESS):
		finishServerSetup.call_deferred(err);
		return
	print("UPNP DICOVERY") 
	if UniversalPnP.get_gateway() and UniversalPnP.get_gateway().is_valid_gateway():
		err = UniversalPnP.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP", 43200);
		print("TIMED LEASE: ", err)
		if(err != UPNP.UPNPResult.UPNP_RESULT_SUCCESS):
			err = UniversalPnP.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP");
			print("UNDEFINED LEASE: ", err)
			if(err != UPNP.UPNPResult.UPNP_RESULT_SUCCESS):
				print("UPNP FAILED\n")
				finishServerSetup.call_deferred(err);
				return;
		print("UPNP SUCCESS\n")
		portsAreOpen = true;
		finishServerSetup.call_deferred(UPNP.UPNPResult.UPNP_RESULT_SUCCESS);
		return;
	print("UPNP FOUND FAILURE\n")
	finishServerSetup.call_deferred(UPNP_FAILURE_NO_GATEWAY); # Found device can't foward ports
	return;
# SETUP AS HOST
func beginServerSetup():
	if(useUPNP):
		portsAreOpen = false;
		cancelled = false;
		serverDialog._activate();
		NATThread = Thread.new()
		NATThread.start(setupUPNP.bind(SERVER_PORT))
	else:
		finishServerSetup(UPNP.UPNPResult.UPNP_RESULT_SUCCESS);
	return;
# SETUP CLIENT AS P2
func joinAsPlayerTwo():
	clientDialog._activate();
	
	var clientPeer : ENetMultiplayerPeer = ENetMultiplayerPeer.new();
	var error = clientPeer.create_client(SERVER_ADRS, SERVER_PORT);
	if (error != OK):
		serverPeerSetupErrorHandle(error);
		return;
	clientPeer.get_peer(1).set_timeout(0,0,1000*TIMEOUTSECS);
	
	print("JOINING");
	multiplayer.multiplayer_peer = clientPeer;
	return;


## Peer Connections
#Save the given player_info to the sender_ID
@rpc("any_peer", "reliable")
func registerPlayer(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id();
	players[new_player_id] = new_player_info;
	
	setOpGUI(new_player_info);
	player_connected.emit(new_player_id, new_player_info);
	
	print("Adding Player : ", new_player_id, " PLAYERS : ",players);
	return;
# When a peer connects, send them my player info. Player Info Swap.
func onPlayerConnected(id : int):
	registerPlayer.rpc_id(id, player_info);
	return;
#Called when any connection ends
func onPlayerDisconnected(id : int):
	if(not multiplayer.is_server()):
		return; #Ignore for clients
	
	players.erase(id);
	player_disconnected.emit(id);
	
	resetOpGUI();
	
	print("PLAYER LEFT: ", id, " Remaining: ", players);
	return;


## CLIENT CONNECTIONS
#Client; Called when client succefully connects to server
func onConnectOK():
	clientDialog._deactivate();
	
	lbName.text = centerText(myname);
	var peer_id = multiplayer.get_unique_id();
	players[peer_id] = player_info;
	
	multiplayer_enabled.emit(false);
	player_connected.emit(peer_id, player_info);
	
	lobbyVisible();
	print("Connect OK : ", peer_id);
	return;
#Client; Called when client fails to connect to server
func onConnectFAIL():
	clientDialog._failed();
	
	multiplayer.multiplayer_peer = null;
	
	print("FAILED CONNECTION");
	return;	


#Default cleanup after multiplayer
func shutdownCleanUp(reason : REASONS):
	resetOpGUI();
	hostVisible();
	shutdownServerClient.emit(reason);
	multiplayer_disabled.emit();
	multiplayer.multiplayer_peer = null;
	players.clear();
	return;
#Called when peer disconnects from server
func onDisconnect():
	shutdownCleanUp(REASONS.SERVERSHUTODWN);
	print("SERVER DISCONECTED");
	return


## MULT GUI BUTTONS
func _on_check_button_toggled(toggled_on: bool) -> void:
	useUPNP = toggled_on;
	return;
func _on_host_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	
	player_info["name"] = myname;
	SERVER_PORT = (port.text if isValidPort(port.text) else "4440").to_int();
	SERVER_ADRS = adrs.text if isValidADRS(adrs.text) else "127.0.0.1";
	
	lbName.text = centerText(myname);
	
	beginServerSetup();
	return;
func _on_join_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	
	player_info["name"] = myname;
	SERVER_PORT = (port.text if isValidPort(port.text) else "4440").to_int();
	SERVER_ADRS = adrs.text if isValidADRS(adrs.text) else "127.0.0.1";
	
	joinAsPlayerTwo();
	return;
func _on_leave_pressed() -> void:
	if(multiplayer.is_server()):
		hostCleanUp();
	shutdownCleanUp(REASONS.DEFAULT);
	return;
func _on_close_pressed() -> void:
	visible = false;
	multGUIClosed.emit();
	return;

func _on_cancel_search_pressed() -> void:
	clientDialog._deactivate();
	
	multiplayer.multiplayer_peer = null;
	
	print("CANCELED CONNECTION");
	return;
func _on_ok_search_pressed() -> void:
	clientDialog._deactivate();
	return;

func _on_cancel_connect_pressed() -> void:
	serverDialog._deactivate();
	multiplayer.multiplayer_peer = null;
	cancelled = true;
	return;
