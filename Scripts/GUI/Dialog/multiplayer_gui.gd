extends Control


enum REASONS {DEFAULT, SERVERSHUTODWN}


#Signals
signal hostServer(uname:String,adrs:String,port:String);
signal joinServer(uname:String,adrs:String,port:String);
signal shutdownServerClient(reason:int);
signal leaveMultiplayer();
signal multGUIClosed();


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


#States
var myname = "";



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





func _on_host_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	hostServer.emit(
		myname,
		adrs.text if isValidADRS(adrs.text) else "127.0.0.1",
		port.text if isValidPort(port.text) else "4440"
	);
	lbName.text = centerText(myname);
	lobbyVisible();
	return;

func _on_join_lobby_pressed() -> void:
	myname = uname.text if isValidUname(uname.text) else "UNKNOWN_PLAYER"
	joinServer.emit(
		myname,
		adrs.text if isValidADRS(adrs.text) else "127.0.0.1",
		port.text if isValidPort(port.text) else "4440"
	);
	return;

func _on_leave_pressed() -> void:
	resetLobby();
	hostVisible();
	shutdownServerClient.emit(REASONS.DEFAULT);
	leaveMultiplayer.emit();
	visible = false;
	return;

func _server_disconnected() -> void:
	resetLobby();
	hostVisible();
	shutdownServerClient.emit(REASONS.SERVERSHUTODWN);
	leaveMultiplayer.emit();
	return;
