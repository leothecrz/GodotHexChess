extends Control;

# Entry Point of Game
#
#
# Error Codes
# 1 No Game Data Node

#Const -- TODO :: Should Be Set By Engine Node
const SQRT_THREE_DIV_TWO = sqrt(3) / 2;
enum PIECES { ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES { BLACK, WHITE };
enum MOVE_TYPES { MOVES, CAPTURE, ENPASSANT, PROMOTE}


# Position State
@onready var VIEWPORT_CENTER_POSITION = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
@onready var PIXEL_OFFSET = 35;
@onready var AXIAL_X_SCALE = 1.4;
@onready var AXIAL_Y_SCALE = 0.9395;
@onready var PIECE_SCALE = 0.18;
@onready var MOVE_SCALE = 0.015;


# Node Ref
@onready var EngineNode:HexEngineSharp = $HCE;

@onready var BoardControler = $StaticGUI/Mid;
@onready var LeftPanel = $StaticGUI/Left
@onready var SideSelect = $StaticGUI/Right/BG/Options/SideSelect
@onready var EnemySelect = $StaticGUI/Right/BG/Options/EnemySelect

@onready var TAndFrom = $DynamicGUI/PosGUI;
@onready var MoveNode = $DynamicGUI/MoveGUI;
@onready var ChessPiecesNode = $DynamicGUI/PiecesContainer;

@onready var BGMusicPlayer = $BGMusic;
@onready var SettingsDialog = $Settings;
@onready var MultiplayerControl = $Multiplayer;


# State
var masterAIThread : Thread = Thread.new();
var threadActive : bool = false;

var isRotatedWhiteDown : bool = true;
var gameRunning : bool = false;
var minimumUndoSizeReq : int = 1;
var selfSide : int = 0;

# Temp
var activePieces : Array;
var currentLegalMoves : Dictionary;

#References
var tempDialog : AcceptDialog = null;
var thinkingDialogRef : Node = null;
var fenDialog : Node = null;

#Multiplayer
var multiplayerConnected : bool = false;
var isHost : bool = false;
var playerCount = 0;

# Signals
signal gameSwitchedSides(newSideTurn:int);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();





# Utility
## Convert Axial Cordinates To Viewport Cords
func axialToPixel(axial : Vector2i) -> Vector2:
	var x = float(axial.x) * AXIAL_X_SCALE;
	var y = ( SQRT_THREE_DIV_TWO * ( float(axial.y * 2) + float(axial.x) ) ) * AXIAL_Y_SCALE;
	return Vector2(x, y);
## Spawn a simple pop up that will display TEXT for TIME seconds
func spawnNotice(TEXT : String, TIME : float = 1.8) -> void:
	var notice = preload("res://Scenes/SimpleNotice.tscn").instantiate();
	notice.NOTICE_TEXT = TEXT;
	notice.POP_TIME = TIME;
	
	self.add_child(notice);
	notice.position = Vector2i(VIEWPORT_CENTER_POSITION.x-(notice.size.x/2),550);
	return;
## Check if it is my turn
func isItMyTurn() -> bool:
	var isWhite = (selfSide == 0);
	return EngineNode._getIsWhiteTurn() == isWhite;


##
func repositionToFrom(fpos : Vector2i, tpos : Vector2i) -> void:
	var from = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(fpos) * (1 if isRotatedWhiteDown else -1));
	var to =  VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(tpos) * (1 if isRotatedWhiteDown else -1));
	TAndFrom.setVis(true);
	TAndFrom.moveFrom(from.x,from.y);
	TAndFrom.moveTo(to.x,to.y);
	return;






# DISPLAY PIECES
## Connect Signals For Chess Pieces
func connectPieceToSignals(newPieceScene:Node) -> void:
	## Connect Piece To Piece Controller
	newPieceScene.pieceSelected.connect(_chessPiece_OnPieceSELECTED);
	newPieceScene.pieceDeselected.connect(_chessPiece_OnPieceDESELECTED);
	## Connect Piece Controller To Piece
	gameSwitchedSides.connect(newPieceScene._on_Control_GameSwitchedSides);
	pieceSelectedLockOthers.connect(newPieceScene._on_Control_LockPiece);
	pieceUnselectedUnlockOthers.connect(newPieceScene._on_Control_UnlockPiece);
	return;

## Setup A Chess Piece Scene
func preloadChessPiece(side:int, pieceType:int, piece:Vector2i) -> Node:
	var newPieceScene:Node = preload("res://Scenes/chess_piece.tscn").instantiate();
	var cords = piece * (1 if isRotatedWhiteDown else -1);
	
	newPieceScene.side = side;
	newPieceScene.pieceType = pieceType;
	newPieceScene.pieceCords = piece;
	newPieceScene.isSetup = true;
	newPieceScene.transform.origin = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(cords));
	
	# TODO: FIX SCALE-ING
	newPieceScene.scale.x = PIECE_SCALE;
	newPieceScene.scale.y = PIECE_SCALE;
	
	return newPieceScene;

## Hand piece data to new scene. Connect scene to piece controller. Add to container.
func prepareChessPieceNode(side:int, typeindex:int, pieceType:int, piece:Vector2i) -> void:
	var newPieceScene = preloadChessPiece(side, pieceType, piece);
	ChessPiecesNode.get_child(side).get_child(typeindex).add_child(newPieceScene,);
	connectPieceToSignals(newPieceScene);
	return;

## Spawn all the pieces in 'activePieces' at their positions. AP structure [{{},{}...},{{},{}...}]
func spawnActivePieces() -> void:
	for side:int in range(activePieces.size()):
		for pieceType:int in activePieces[side]:
			for piece:Vector2i in activePieces[side][pieceType]:
				prepareChessPieceNode(side, pieceType-1, pieceType, piece);
	return;





# MOVE RESPONCE
## Destroy gui element of captured piece
func updateScenceTree_OfCapture() -> void:	
	var i:int = SIDES.WHITE if(EngineNode._getIsWhiteTurn()) else SIDES.BLACK;
	var j:int =  EngineNode.CaptureType() - 1;
	var index = EngineNode.CaptureIndex()
	
	var ref:Node = ChessPiecesNode.get_child(i).get_child(j).get_child(index);
	ref.get_parent().remove_child(ref);
	ref.queue_free();
	
	return;

## Despawn the pawn gui element, spawn 'pto' gui element for promoted type.
func updateScenceTree_OfPromotionInterupt(cords:Vector2i, key:int, index:int, pTo) -> void:
	var ref:Node;
	var i:int = SIDES.WHITE if (EngineNode._getIsWhiteTurn()) else SIDES.BLACK;
	for pawnIndex in range( activePieces[i][PIECES.PAWN].size() ):
		if (activePieces[i][PIECES.PAWN][pawnIndex] == cords):
			ref = ChessPiecesNode.get_child(i).get_child(PIECES.PAWN-1).get_child(pawnIndex);
			break;
	
	prepareChessPieceNode(ref.side, pTo-1, EngineNode.getPiecetype(pTo), ref.pieceCords);

	ref.get_parent().remove_child(ref);	
	ref.queue_free();

	submitMove(cords, key, index, pTo, false);
	pieceUnselectedUnlockOthers.emit();
	
	get_child(get_child_count() - 1).queue_free();
	
	allowAITurn();
	return;

## Get new state data from engine
func updateGUI_Elements() -> void:
	if(EngineNode._getGameInCheck() != LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();

	if(EngineNode._getIsWhiteTurn()):
		emit_signal("gameSwitchedSides", SIDES.WHITE);
		BoardControler.setSignalWhite();
	else:
		emit_signal("gameSwitchedSides", SIDES.BLACK);
		BoardControler.setSignalBlack();

	if(EngineNode._getGameOverStatus()):
		if(EngineNode._getGameInCheck()):
			
			setConfirmTempDialog(AcceptDialog.new(),\
			"%s has won by CheckMate." % ["White" if EngineNode._getIsBlackTurn() else "Black"],\
			killDialog);
		else:
			setConfirmTempDialog(AcceptDialog.new(),\
			"StaleMate. Game ends in a draw.",\
			killDialog);
	
	
	LeftPanel._updateHist(EngineNode._getHistTop());
	return;

## Handle post move gui updates
func syncToEngine() -> void:
	activePieces = EngineNode._getActivePieces();
	currentLegalMoves = EngineNode._getMoves();
	if(EngineNode.CaptureValid()):
		updateScenceTree_OfCapture();
	updateGUI_Elements();
	return;





# Move Submit
## Interupt a promotion submission to get promotion type
func submitMoveInterupt(cords:Vector2i, moveType:int, moveIndex:int) -> void:
	var dialog = preload("res://Scenes/PromotionDialog.tscn").instantiate();
	dialog.z_index = 1; #place on foreground
	dialog.cords = cords;
	dialog.key = moveType;
	dialog.index = moveIndex;
	dialog.promotionAccepted.connect(updateScenceTree_OfPromotionInterupt); # signal connect
	add_child(dialog);
	return;

## Sumbit a move to the engine and update state
func submitMove(cords:Vector2i, moveType, moveIndex:int, promoteTo:int=0, passInterupt=true) -> void:
	
	if(moveType == MOVE_TYPES.PROMOTE and passInterupt):
		submitMoveInterupt(cords, moveType, moveIndex);
		return
	
	if(multiplayerConnected):
		receiveMove.rpc(cords, moveType, moveIndex, promoteTo);
	
	EngineNode._makeMove(cords, moveType, moveIndex, promoteTo);
	
	var toV = currentLegalMoves[cords][moveType][moveIndex];
	repositionToFrom(cords, toV);

	syncToEngine();
	return;





# Move GUI
## Setup and display a legal move on GUI
func spawnAMove(moves:Array, color:Color, key, cords):
	for i in range(moves.size()):
		var move = moves[i];
		var activeScene = preload("res://Scenes/HexTile.tscn").instantiate();
		var cord = move if isRotatedWhiteDown else (move * -1);
		
		activeScene.hexCords = cords;
		activeScene.hexKey = key;
		activeScene.hexIndex = i;
		activeScene.hexMove = move;
		activeScene.transform.origin = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(cord));
		activeScene.rotation_degrees = 90;
		activeScene.z_index = 1;
		activeScene.isSetup = true;
		
		activeScene.scale.x = MOVE_SCALE;
		activeScene.scale.y = MOVE_SCALE;
		
		MoveNode.add_child(activeScene);
		
		activeScene.SpriteNode.set_modulate(color);
	return;

## Spawn the moves from the given 'moves' dictionary for the piece 'cords'
func spawnMoves(moves:Dictionary, cords) -> void:
	for key in moves.keys():
		match key:
			MOVE_TYPES.MOVES: 			spawnAMove(moves[key], Color.WHITE, key, cords);
			MOVE_TYPES.CAPTURE: 		spawnAMove(moves[key], Color.DARK_RED, key, cords);
			MOVE_TYPES.PROMOTE: 		spawnAMove(moves[key], Color.DARK_KHAKI, key, cords);
			MOVE_TYPES.ENPASSANT: 		spawnAMove(moves[key], Color.SEA_GREEN, key, cords);
	return;





# AI Moves
##
func syncMasterAIThreadToMain():
	if(masterAIThread.is_started()):
		masterAIThread.wait_to_finish();
	if(thinkingDialogRef):
		thinkingDialogRef.queue_free();
	
	threadActive = false;

	var to : Vector2i = EngineNode._getEnemyTo();
	var i : int = SIDES.BLACK if (EngineNode._getIsWhiteTurn()) else SIDES.WHITE;
	var j : int = EngineNode._getEnemyChoiceType() - 1;
	var k : int = EngineNode._getEnemyChoiceIndex();
	var ref : Node = ChessPiecesNode.get_child(i);
	ref = ref.get_child(j)
	ref = ref.get_child(k);
		
	repositionToFrom(ref._getPieceCords(), to);
	
	if (EngineNode._getEnemyPromoted()):
		prepareChessPieceNode(i,EngineNode._getEnemyPTo()-1, EngineNode._getEnemyPTo(), to);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
	else:
		ref._setPieceCords(to, VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(to*(1 if isRotatedWhiteDown else -1))));
	
	syncToEngine();
	pieceUnselectedUnlockOthers.emit();
	return;

##
func passAIToNewThread():
	EngineNode._passToAI();
	syncMasterAIThreadToMain.call_deferred();
	return;

##
func allowAITurn():
	if(  not EngineNode._getIsEnemyAI() ):
		return;
	if( EngineNode._getGameOverStatus() ):
		return
	
	threadActive = true;
	pieceSelectedLockOthers.emit();
	TAndFrom.setVis(false);
	
	thinkingDialogRef = preload("res://Scenes/AI_Turn_Diolog.tscn").instantiate();
	thinkingDialogRef.z_index = 1;
	add_child(thinkingDialogRef);
	
	if ( OK != masterAIThread.start(passAIToNewThread) ):
		passAIToNewThread();
	
	return;





## CLICK AND DRAG (MOUSE) API
## Submit a move to engine or Deselect 
func  _chessPiece_OnPieceDESELECTED(cords:Vector2i, key, index:int) -> void:
	var isNotPromoteMove = key != MOVE_TYPES.PROMOTE;
	for node in MoveNode.get_children():
		MoveNode.remove_child(node);
		node.queue_free();
		
	if (isNotPromoteMove): pieceUnselectedUnlockOthers.emit();
	
	if (index >= 0):
		submitMove(cords, key, index);
		if(isNotPromoteMove):
			allowAITurn();
	return;
## Lock Other Pieces
## Sub :: Spawn Piece's Moves 
func  _chessPiece_OnPieceSELECTED(_SIDE:int, _TYPE:int, CORDS:Vector2i) -> void:
	pieceSelectedLockOthers.emit();
	var thisPiecesMoves = {};
	for key in currentLegalMoves[CORDS].keys():
		thisPiecesMoves[key] = currentLegalMoves[CORDS][key];
	spawnMoves(thisPiecesMoves, CORDS);
	return;





# DIALOGS
##
func killDialog():
	if(tempDialog != null):
		tempDialog.queue_free()
		tempDialog = null;
	return;
##
func setConfirmTempDialog(type:AcceptDialog, input:String, method:Callable):
	tempDialog = type;
	tempDialog.confirmed.connect(method);
	tempDialog.canceled.connect(killDialog);
	add_child(tempDialog)
	tempDialog.dialog_text = input;
	tempDialog.move_to_center();
	tempDialog.visible = true;
	return;








# MENU HELPERS
func FenOK(stir:String, strict:bool) -> void:
	fenDialog.queue_free();
	if(not strict):
		startGameFromFen(stir);
		return;
	if(EngineNode._FENCHECK(stir)):
		startGameFromFen(stir);
		return;
	spawnNotice("[center]String Failed Fen Check[/center]", 1.0);
	return;
func FenCancel() -> void:
	fenDialog.queue_free();
	return;




# MENUBAR
func _on_history_id_pressed(id: int) -> void:
	if(!activePieces): spawnNotice("[center]Game NOT Running[/center]",  0.8); return;
	if(masterAIThread.is_started()): spawnNotice("[center]AI Running[/center]",  0.8); return;
	match (id):
		0:
			DisplayServer.clipboard_set(EngineNode._getFullHistString());
			spawnNotice("[center]History copied to clipboard[/center]",  0.8)
			return;
		_: return;
func _on_fen_id_pressed(id: int) -> void:
	match(id):
		0:
			if activePieces : return;
			fenDialog = preload("res://Scenes/GetFen.tscn").instantiate();
			fenDialog.OKButtonPressed.connect(FenOK);
			fenDialog.CANCELButtonPressed.connect(FenCancel);
			add_child(fenDialog);
			pass;
		1:
			if not activePieces : return;
			DisplayServer.clipboard_set(EngineNode._getBoardFenNow());
			spawnNotice("[center]Fen copied to clipboard[/center]",1.0)
			pass;
		_: return;
func _on_test_id_pressed(id: int) -> void:
	match ( id ):
		0:
			if(activePieces): spawnNotice("[center]Game Running[/center]",  0.8);  return;
			EngineNode._test(0);
			return;
		1:
			if(!activePieces): spawnNotice("[center]Game NOT Running[/center]",  0.8); return;
			if(masterAIThread.is_started()): spawnNotice("[center]AI Running[/center]",  0.8); return;
			spawnNotice("[center] Board H(): %d [/center]" % EngineNode._intTest(1),  2);
			return;
			
		_:
			return;





# GUI MENUS
## Set item select value.
func _selectSide_OnItemSelect(index:int) -> void:
	if(gameRunning):
		spawnNotice("[center]Can't switch sides mid-game.[/center]", 1.0);
		SideSelect._setSelected(selfSide);
		return; 
		
	selfSide = index;
	var isUserPlayingW = (selfSide == 0);
	
	BoardControler.checkAndFlipBoard(isUserPlayingW);
	isRotatedWhiteDown = isUserPlayingW;
	
	EngineNode.UpdateEnemy(EngineNode._getEnemyType(), selfSide != 0);
	return;
##
func _on_enemy_select_item_selected(index:int) -> void:
	if(gameRunning):
		EnemySelect._setSelected(EngineNode._getEnemyType());
		return; 
	
	if(multiplayerConnected):
		spawnNotice("[center]Multiplayer Connected[/center]",1.0)
		EnemySelect._setSelected(EngineNode._getEnemyType());
		return;
	
	var type:int = index;
	if(index > 1):
		type = index - 1;
	EngineNode.UpdateEnemy(type, selfSide != 0);
	
	minimumUndoSizeReq = 1;
	if(type == 0):
		minimumUndoSizeReq += 1;
	return;





## SETTINGS
##
func changeRes(choice:int):
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);
	match choice:
		0: #Def
			DisplayServer.window_set_size(Vector2i(1152,648));
		1: #1.5
			DisplayServer.window_set_size(Vector2i(1728,972));
		2: #2
			DisplayServer.window_set_size(Vector2i(2304,1296));
		3: #Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED);
		4: #Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN);
	return;
##
func toggleMusic(choice):
	if choice == 1:
		BGMusicPlayer._stopPlaying();
		return;
	BGMusicPlayer._continuePlaying();
	return;
##
func toggleSound(_choice):
	return;
##
func updateSoundBus(bus,choice):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), choice);
	return;
##
func closeSettingsDialog():
	SettingsDialog.visible = false;
	if(gameRunning and isItMyTurn()):
		pieceUnselectedUnlockOthers.emit();
	return
##
func _on_settings_dialog_settings_updated(settingIndex:int, choice:int):
	match settingIndex:
		0:changeRes(choice);
		1:pass;
		2:toggleMusic(choice);
		3:toggleSound(choice);
		4:updateSoundBus("Master", choice)
		5:updateSoundBus("Music", choice)
		6:updateSoundBus("Sound", choice);
		7:closeSettingsDialog();
	return;





# BUTTONS HELPERS
##
@rpc("authority", "call_remote", "reliable")
func setSide(isW:bool):
	selfSide = 0 if isW else 1;
	
	var isUserPlayingW = (selfSide == 0);
	BoardControler.checkAndFlipBoard(isUserPlayingW);
	isRotatedWhiteDown = isUserPlayingW;
	SideSelect._setSelected(selfSide);
	return;
##
@rpc("authority", "call_remote", "reliable")
func startGameFromFen(stateString : String = "") -> void:
	if(stateString == ""):
		if not EngineNode._initDefault():
			spawnNotice("[center]DEFAULT START FAILED[/center]", 1.0);
			return;
	else:
		if not EngineNode.initiateEngine(stateString):
			spawnNotice("[center]Fen Invalid[/center]", 1.0);
			return;
	
	syncToEngine()
	spawnActivePieces();
	gameSwitchedSides.emit(SIDES.WHITE if EngineNode._getIsWhiteTurn() else SIDES.BLACK);
	gameRunning = true;
	
	if( EngineNode._getIsEnemyAI() and EngineNode._getEnemyIsWhite() ): allowAITurn();
	return;
##
@rpc("any_peer", "call_remote", "reliable")
func resignCleanUp():
	if(tempDialog and is_instance_valid(tempDialog)): tempDialog.queue_free();
	
	EngineNode._resign();
	activePieces.clear();
	currentLegalMoves.clear();
	
	BoardControler.setSignalWhite();
	TAndFrom.setVis(false);
	gameRunning = false;
	
	for colorNodes in ChessPiecesNode.get_children():
		for pieceNodes in colorNodes.get_children():
			for piece in pieceNodes.get_children():
				piece.queue_free();
	
	LeftPanel._updateHist([]);
	if(LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();
	return;
## TODO :: FIX FORCED NEW GAME
@rpc("authority", "call_remote", "reliable")
func forceNewGame():
	killDialog();
	resignCleanUp();
	startGameFromFen();
	if(multiplayerConnected):
		if(isHost):
			forceNewGame.rpc();
		else:
			spawnNotice("[center]Host forced a new game.[/center]");
	return;
##
@rpc("any_peer", "call_remote", "reliable")
func multResign():
	resignCleanUp()
	if(multiplayer.get_remote_sender_id() == 0):
		multResign.rpc();
		return
	spawnNotice("[center]Opponent has resigned.[/center]");
	return;





# Undo
##
func undoCapture():
	if( not EngineNode.uncaptureValid() ):
		return;
	##Undo Uncapture
	var captureSideToUndo = SIDES.BLACK if EngineNode._getIsWhiteTurn() else SIDES.WHITE;
	var cType = EngineNode._getCaptureType();
	var cIndex = EngineNode._getCaptureIndex();
	var newPos = activePieces[captureSideToUndo][cType][cIndex];
	var newPieceScene = preloadChessPiece(captureSideToUndo, cType, newPos);
	connectPieceToSignals(newPieceScene);

	var ref  = ChessPiecesNode\
	.get_child(captureSideToUndo)\
	.get_child(cType-1);
	
	## respawn captured piece
	if( ref.get_child_count(false) > 0):
		if (cIndex == 0):
			ref.add_child(newPieceScene);
			ref.move_child(newPieceScene, 0);
		else:
			ref.get_child(cIndex-1)\
			.add_sibling(newPieceScene);
	else:
		ref.add_child(newPieceScene);
	## ID which piece needs to be moved
	return;
##
func undoPromoteOrDefault(uType:int, uIndex:int, sideToUndo:int):
	var newPos;
	if(not EngineNode.unpromoteValid()):
		newPos = activePieces[sideToUndo][uType][uIndex];
		var pieceREF = ChessPiecesNode.get_child(sideToUndo).get_child(uType-1).get_child(uIndex);
		var from = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(pieceREF._getPieceCords()) * (1 if isRotatedWhiteDown else -1));
		pieceREF._setPieceCords(newPos , VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(newPos * (1 if isRotatedWhiteDown else -1))));	
		repositionToFrom(from, newPos);
		return;
	##Undo Promotion
	var pType = EngineNode.unpromoteType();
	var pIndex = EngineNode.unpromoteIndex();
	newPos = activePieces[sideToUndo][PIECES.PAWN][pIndex] ;
	var ref = ChessPiecesNode.get_child(sideToUndo).get_child(pType-1);
	var refChildCount = ref.get_child_count(false);
	var From = ref._getPieceCords();
	ref.get_child(refChildCount-1).queue_free();

	var newPieceScene = preloadChessPiece(sideToUndo, PIECES.PAWN, newPos);
	connectPieceToSignals(newPieceScene);
	ref = ChessPiecesNode.get_child(sideToUndo).get_child(PIECES.PAWN-1)
	ref.add_child(newPieceScene);
	ref.move_child(newPieceScene,pIndex);
	
	repositionToFrom(From,ref._getPieceCords())
	return;
##
func syncUndo():
	var uType:int = EngineNode.undoType();
	var uIndex:int = EngineNode.undoIndex();
	var sideToUndo:int = SIDES.WHITE if EngineNode._getIsWhiteTurn() else SIDES.BLACK;
	
	activePieces = EngineNode._getActivePieces();
	currentLegalMoves = EngineNode._getMoves();
	
	undoPromoteOrDefault(uType, uIndex, sideToUndo);
	undoCapture();
	updateGUI_Elements();
	return;
##
func undoAI():
	if(not EngineNode._getIsEnemyAI()):
		return;
	EngineNode._undoLastMove(true);
	syncUndo();
	return





# BUTTONS
## New Game Button Pressed.
# Sub : Calls Spawn Pieces
func _newGame_OnButtonPress() -> void:
	if(threadActive):
		spawnNotice("[center]Please wait until AI has made its turn[/center]");
		return;
	
	if(multiplayerConnected):
		if(isHost):
			if(playerCount != 2):
				return;
		else:
			spawnNotice("[center]Only host can start the game[/center]");
			return;
	
	if(gameRunning):
		setConfirmTempDialog(ConfirmationDialog.new(), "There is a game already running. Start Another?", forceNewGame);
		return;
	
	startGameFromFen();
	
	if(multiplayerConnected and isHost):
		setSide.rpc(selfSide != 0);
		startGameFromFen.rpc();
		syncCheckMultiplayer.rpc(true);
	
	return;

## Resign Button Pressed.
func _resign_OnButtonPress() -> void:
	if(not gameRunning):
		return;
	
	if(threadActive):
		spawnNotice("[center]Please wait until AI has made its turn[/center]");
		return;

	if(EngineNode._getGameOverStatus()):
		resignCleanUp();
		if(multiplayerConnected and isHost):
			resignCleanUp.rpc();
		return;

	if(multiplayerConnected):
		setConfirmTempDialog(ConfirmationDialog.new(), "Resign the match?", multResign);
		return;
	
	setConfirmTempDialog(ConfirmationDialog.new(), "Resign the match?", resignCleanUp);

	return;

## Undo Button Pressed
func _on_undo_pressed():
	if(threadActive):
		spawnNotice("[center]Please wait until AI has made its turn[/center]");
		return;
	
	if(EngineNode._getMoveHistorySize() < minimumUndoSizeReq):
		setConfirmTempDialog(ConfirmationDialog.new(), "There is NO history to undo.", killDialog);
		return;
	
	if(multiplayerConnected): 
		spawnNotice("[center]NOT available during multiplayer ... yet.[/center]", 1.0);
		return;
	
	EngineNode._undoLastMove(true);
	syncUndo();
	undoAI();
	return;

## Settings Button Pressed
func _on_settings_pressed():
	SettingsDialog.visible = true;
	SettingsDialog.z_index = 1;
	if(gameRunning):
		pieceSelectedLockOthers.emit();
	return;





#
##
func hostShutdown(_reason : int):
	spawnNotice("[center]Host Shutdown[/center]")
	pass;
##
func clientShutdown(reason:int):
	if(reason == 0):
		spawnNotice("[center]Client Shutdown[/center]");
	elif(reason == 1):
		spawnNotice("[center]Disconected from server.[/center]");

	pass;




#MULTIPLAYER
##
##
@rpc("any_peer", "call_remote", "reliable")
func receiveMove(cords:Vector2i, moveType:int, moveIndex:int, promoteTo:int=0):
	print(Time.get_ticks_usec()/10000000.0," - ", multiplayer.get_unique_id(), " - Received Move: ", cords, " ", moveType, " ", moveIndex, " ", promoteTo);
	
	var toPos = currentLegalMoves[cords][moveType][moveIndex];
	repositionToFrom(cords, toPos);

	var t=0;
	var index = 0;
	var side = SIDES.WHITE if (selfSide != 0) else SIDES.BLACK;
	var escapeloop = false;
	for pieceType in activePieces[side]:
		if(escapeloop): break;
		t = pieceType;
		index = 0;
		for piece in activePieces[side][pieceType]:
			if(piece == cords): escapeloop = true; break;
			index +=1;
	
	var ref = ChessPiecesNode.get_child(side).get_child(t-1).get_child(index);
	
	if (moveType == MOVE_TYPES.PROMOTE):
		prepareChessPieceNode(side,promoteTo-1, promoteTo, toPos);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
	else:
		ref._setPieceCords(toPos, VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axialToPixel(toPos*(1 if isRotatedWhiteDown else -1))));
	
	EngineNode._makeMove(cords, moveType, moveIndex, promoteTo);
	syncToEngine();
	syncCheckMultiplayer.rpc(true);
	return;
##
@rpc("any_peer", "call_remote", "reliable")
func syncCheckMultiplayer(sendSync:bool):
	if(sendSync):
		print(Time.get_ticks_usec()/10000000.0," - ",multiplayer.get_remote_sender_id()," sent a sync request to ", multiplayer.get_unique_id());
		syncCheckMultiplayer.rpc(false);
	else:
		print(Time.get_ticks_usec()/10000000.0," - ", multiplayer.get_unique_id()," is in sync with ", multiplayer.get_remote_sender_id());

	if(isItMyTurn()):
		print(Time.get_ticks_usec()/10000000.0," - ","My Turn: ", multiplayer.get_unique_id())
		pieceUnselectedUnlockOthers.emit();
		return;
	pieceSelectedLockOthers.emit();
	return;

##MULTIPLAYER GUI ON & OFF
func _on_mult_pressed() -> void:
	MultiplayerControl._showGUI();
	if(gameRunning and isItMyTurn()):
		pieceSelectedLockOthers.emit();
	return;
func _on_mult_gui_mult_gui_closed() -> void:
	if(gameRunning and isItMyTurn()):
		pieceUnselectedUnlockOthers.emit();
	return;

##MULTIPLAYER ON & OFF
func _on_multiplayer_multiplayer_enabled(ishost: bool) -> void:
	multiplayerConnected = true;
	isHost = ishost;
	return;
func _on_multiplayer_multiplayer_disabled() -> void:
	multiplayerConnected = false;
	isHost = false;
	return


func _on_mult_gui_shutdown_server_client(reason:int) -> void:
	if (isHost):
		hostShutdown(reason);
		return;
		
	clientShutdown(reason);
	return;

func _on_multiplayer_player_connected(peer_id: Variant, player_info: Variant) -> void:
	playerCount +=1;
	return;
func _on_multiplayer_player_disconnected(peer_id: Variant) -> void:
	playerCount -=1;
	return;
