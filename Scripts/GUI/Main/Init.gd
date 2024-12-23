extends Control;

# Entry Point of Game
#
# Error Codes
# 1 No Game Data Node

# Node Ref
@onready var EngineNode:HexEngineSharp = $HCE;
##
@onready var BoardControler = $StaticGUI/Mid;
@onready var LeftPanel = $StaticGUI/Left
@onready var RightPanel = $StaticGUI/Right
@onready var FenPanel = $StaticGUI/Right2
##
@onready var TAndFrom = $DynamicGUI/PosGUI;
@onready var MoveNode = $DynamicGUI/MoveGUI;
@onready var ChessPiecesNode = $DynamicGUI/PiecesContainer;
##
@onready var BGMusicPlayer = $BGMusic;
@onready var SoundSource = $SoundSource
@onready var SettingsDialog = $Settings;
@onready var MultiplayerControl = $MultiplayerControl;
# Position State
@onready var VIEWPORT_CENTER_POSITION : Vector2 = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);


# AI - THREAD
var masterAIThread : Thread = Thread.new();
var threadActive : bool = false;
#Board
var isRotatedWhiteDown : bool = true;
#Game
var gameRunning : bool = false;
var fenBuilding : bool = false;
var minimumUndoSizeReq : int = 1;
var selfSide : int = 1;
# Temp
var activePieces : Array;
var currentLegalMoves : Dictionary;
#Multiplayer
var multiplayerConnected : bool = false;
var isHost : bool = false;
var playerCount = 0;
#References
var thinkingDialogRef : Node = null;



# Signals
signal gameSwitchedSides(newSideTurn : GDHexConst.SIDES);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();



# Utility
## Convert Axial Cordinates To Viewport Cords

## Spawn a simple pop up that will display TEXT for TIME seconds
func spawnNotice(txt : String, time : float = 1.8) -> void:
	var notice : SimpleNotice = preload("res://Scenes/SimpleNotice.tscn").instantiate();
	notice.__setSetupVars(txt, time);
	self.add_child(notice);
	notice.position = Vector2i((int)(VIEWPORT_CENTER_POSITION.x-(notice.size.x/2.0)),550);
	return;
##
func isWhite() -> bool:
	return(selfSide == GDHexConst.SIDES.WHITE);
## Check if it is my turn
func isItMyTurn() -> bool:
	return EngineNode._getIsWhiteTurn() == isWhite();
##
func isBoardBusy() -> bool:
	return gameRunning or fenBuilding;
##
func cordinateToOrigin(cords : Vector2i) -> Vector2:
	return VIEWPORT_CENTER_POSITION + (GDHexConst.PIXEL_OFFSET * GDHexConst.axialToPixel(cords * (1 if isRotatedWhiteDown else -1)));

func swapRightPanel() -> void:
	RightPanel.visible = !RightPanel.visible;
	FenPanel.__swapModes();
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
	var newPieceScene : HexPiece = preload("res://Scenes/chess_piece.tscn").instantiate();
	newPieceScene.__setSetupVars(side, pieceType, piece, cordinateToOrigin(piece), GDHexConst.PIECE_SCALE);
	return newPieceScene;
## Give piece data to a new scene. Connect scene to piece controller. Add to container.
func prepareChessPieceNode(side:int, pieceType:int, piece:Vector2i) -> void:
	var newPiece : Node = preloadChessPiece(side, pieceType, piece);
	ChessPiecesNode.get_child(side).get_child(pieceType-1).add_child(newPiece);
	connectPieceToSignals(newPiece);
	return;
## Spawn all the pieces in 'activePieces' at their positions. AP structure [{{},{}...},{{},{}...}]
func spawnActivePieces() -> void:
	for side:int in range(activePieces.size()):
		for pieceType:int in activePieces[side]:
			for piece:Vector2i in activePieces[side][pieceType]:
				prepareChessPieceNode(side, pieceType, piece);
	return;



# MOVE RESPONCE
## Destroy gui element of captured piece
func updateScenceTree_OfCapture() -> void:	
	var i:int = GDHexConst.SIDES.WHITE if (EngineNode._getIsWhiteTurn()) else GDHexConst.SIDES.BLACK;
	var j:int =  EngineNode.CaptureType() - 1;
	var index = EngineNode.CaptureIndex()
	
	var ref:Node = ChessPiecesNode.get_child(i).get_child(j).get_child(index);
	ref.get_parent().remove_child(ref);
	ref.queue_free();
	
	LeftPanel.__pushCapture(i,j+1);
	return;
## Despawn the pawn gui element, spawn 'pto' gui element for promoted type.
func updateScenceTree_OfPromotionInterupt(cords:Vector2i, key:int, index:int, pTo) -> void:
	var ref:Node;
	var i:int = GDHexConst.SIDES.WHITE if (EngineNode._getIsWhiteTurn()) else GDHexConst.SIDES.BLACK;
	for pawnIndex in range( activePieces[i][GDHexConst.PIECES.PAWN].size() ):
		if (activePieces[i][GDHexConst.PIECES.PAWN][pawnIndex] == cords):
			ref = ChessPiecesNode.get_child(i).get_child(GDHexConst.PIECES.PAWN-1).get_child(pawnIndex);
			break;
	
	prepareChessPieceNode(ref.side, EngineNode.getPiecetype(pTo), ref.pieceCords);
	ref.get_parent().remove_child(ref);
	ref.queue_free();

	submitMove(cords, key, index, pTo, false);
	pieceUnselectedUnlockOthers.emit();
	
	allowAITurn();
	return;
## Get new state data from engine
func updateGUI_Elements() -> void:
	if(EngineNode._getGameInCheck() != LeftPanel.__getLabelState()):
		LeftPanel.__swapLabelState();

	if(EngineNode._getIsWhiteTurn()):
		gameSwitchedSides.emit(GDHexConst.SIDES.WHITE);
		BoardControler.setSignalWhite();
	else:
		gameSwitchedSides.emit(GDHexConst.SIDES.BLACK);
		BoardControler.setSignalBlack();

	if(EngineNode._getGameOverStatus()):
		if(EngineNode._getGameInCheck()):
			setConfirmTempDialog(AcceptDialog.new(),\
			"%s has won by CheckMate." % ["White" if EngineNode._getIsBlackTurn() else "Black"]);
			
		else:
			setConfirmTempDialog(AcceptDialog.new(),\
			"StaleMate. Game ends in a draw.");
		RightPanel.__setResignOff();
	else:
		RightPanel.__setResignOn();
	
	LeftPanel.__updateHist(EngineNode.GetTop5Hist());
	return;
## Handle post move gui updates
func syncToEngine() -> void:
	activePieces = EngineNode.GDGetActivePieces();
	currentLegalMoves = EngineNode.GDGetMoves();
	if(EngineNode.CaptureValid()):
		updateScenceTree_OfCapture();
	updateGUI_Elements();
	return;



# Move Submit
## Interupt a promotion submission to get promotion type
func interuptSubmitMove(cords:Vector2i, moveType:int, moveIndex:int) -> void:
	var dialog : PromotionDialog = preload("res://Scenes/PromotionDialog.tscn").instantiate();
	dialog.setupInitVars(cords,moveType,moveIndex,EngineNode._getIsWhiteTurn());
	dialog.promotionAccepted.connect(updateScenceTree_OfPromotionInterupt); # signal connect
	add_child(dialog);
	return;
## Sumbit a move to the engine and update state
func submitMove(cords:Vector2i, moveType:GDHexConst.MOVE_TYPES, moveIndex:int, promoteTo:int=0, doInterupt=true) -> void:
	if(moveType == GDHexConst.MOVE_TYPES.PROMOTE and doInterupt):
		interuptSubmitMove(cords, moveType, moveIndex);
		return
	
	if(multiplayerConnected):
		receiveMove.rpc(cords, moveType, moveIndex, promoteTo);
	EngineNode._makeMove(cords, moveType, moveIndex, promoteTo);
	
	
	repositionToFrom(cords, currentLegalMoves[cords][moveType][moveIndex]);
	syncToEngine();
	return;



# Move GUI
##
func repositionToFrom(fpos : Vector2i, tpos : Vector2i) -> void:
	var from = cordinateToOrigin(fpos);
	var to =  cordinateToOrigin(tpos);
	TAndFrom.__setVis(true);
	TAndFrom.__moveFrom(from.x,from.y);
	TAndFrom.__moveTo(to.x,to.y);
	return;
## Setup and display a legal move on GUI
func spawnAMove(moves:Array, color:Color, key:GDHexConst.MOVE_TYPES, cords:Vector2i):
	for i in range(moves.size()):
		var newMove : HexTile = preload("res://Scenes/HexTile.tscn").instantiate();
		newMove.__setSetupVars(cords, key, i, moves[i], cordinateToOrigin(moves[i]), GDHexConst.MOVE_SCALE);
		MoveNode.add_child(newMove);
		newMove.SpriteNode.set_modulate(color);
	return;
## Spawn the moves from the given 'moves' dictionary for the piece 'cords'
func spawnMoves(moves:Dictionary, cords:Vector2i) -> void:
	for key:GDHexConst.MOVE_TYPES in moves.keys():
		match key:
			GDHexConst.MOVE_TYPES.MOVES: 	 spawnAMove(moves[key], Color("#EDAE49"), key, cords); #YELLOW
			GDHexConst.MOVE_TYPES.CAPTURE: 	 spawnAMove(moves[key], Color("#990D35"), key, cords); #RED
			GDHexConst.MOVE_TYPES.PROMOTE: 	 spawnAMove(moves[key], Color("#F4A259"), key, cords); #GOLD
			GDHexConst.MOVE_TYPES.ENPASSANT: spawnAMove(moves[key], Color("#31E981"), key, cords); #GREEN
	return;



# AI Moves
##
func syncMasterAIThreadToMain():
	if(masterAIThread.is_started()):
		masterAIThread.wait_to_finish();
		threadActive = false;
	
	if(thinkingDialogRef):
		thinkingDialogRef.queue_free();
	
	var to : Vector2i = EngineNode._getEnemyTo();
	var i : int = GDHexConst.SIDES.BLACK if (EngineNode._getIsWhiteTurn()) else GDHexConst.SIDES.WHITE;
	var j : int = EngineNode._getEnemyChoiceType() - 1;
	var k : int = EngineNode._getEnemyChoiceIndex();
	var ref : Node = ChessPiecesNode.get_child(i);
	ref = ref.get_child(j)
	ref = ref.get_child(k);
		
	repositionToFrom(ref.__getPieceCords(), to);
	
	if (EngineNode._getEnemyPromoted()):
		prepareChessPieceNode(i, EngineNode._getEnemyPTo(), to);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
	else:
		ref.__setPieceCords(to,cordinateToOrigin(to));
	
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
	TAndFrom.__setVis(false);
	
	thinkingDialogRef = preload("res://Scenes/AI_Turn_Diolog.tscn").instantiate();
	add_child(thinkingDialogRef);
	
	if ( OK != masterAIThread.start(passAIToNewThread) ):
		passAIToNewThread();
	
	return;



##
func queueFreeMoves() -> void:
	for node : Node in MoveNode.get_children():
		MoveNode.remove_child(node);
		node.queue_free();
	return;
## CLICK AND DRAG (MOUSE) API
## Submit a move to engine or Deselect 
func  _chessPiece_OnPieceDESELECTED(cords : Vector2i, key : GDHexConst.MOVE_TYPES, index : int) -> void:
	SoundSource.__playPlaceSFX();
	queueFreeMoves();
	
	var isNotPromoteMove : bool = (key != GDHexConst.MOVE_TYPES.PROMOTE);
	if (isNotPromoteMove): 
		pieceUnselectedUnlockOthers.emit();
	if (index == -1): # -1 is used when a piece is deselected and a move is not choosen.
		return;
	
	submitMove(cords, key, index);
	if(isNotPromoteMove):
		allowAITurn();
	return;
## Lock Other Pieces
## Sub :: Spawn Piece's Moves 
func  _chessPiece_OnPieceSELECTED(CORDS:Vector2i) -> void:
	pieceSelectedLockOthers.emit();
	var thisPiecesMoves = {};
	for key in currentLegalMoves[CORDS].keys():
		thisPiecesMoves[key] = currentLegalMoves[CORDS][key];
	spawnMoves(thisPiecesMoves, CORDS);
	return;



#Dialog
##
func setConfirmTempDialog(type:AcceptDialog, input:String, method:Callable=func():type.queue_free()):
	type.dialog_text = input;
	type.confirmed.connect(method);
	type.canceled.connect(func () : type.queue_free());
	add_child(type)
	type.move_to_center();
	type.visible = true;
	return;



# MENU HELPERS
func FenOK(stir:String, strict:bool, ref:Node) -> void:
	ref.queue_free();
	
	if(multiplayerConnected and not isHost):
		spawnNotice("[center]Only host can start the game[/center]");
		return;
	
	if(not strict):
		startGameFromFen(stir);
		if(multiplayerConnected):
			setSide.rpc(not isWhite());
			startGameFromFen.rpc(stir);
			syncCheckMultiplayer.rpc(true);
		return;
	
	spawnNotice("[center]FEN Strict check is WIP[/center]", 1.0);
	if(not EngineNode._FENCHECK(stir)):
		spawnNotice("[center]String Failed Fen Check[/center]", 1.0);
		return;
		
	startGameFromFen(stir);
	
	if(multiplayerConnected):
		setSide.rpc(not isWhite());
		startGameFromFen.rpc(stir);
		syncCheckMultiplayer.rpc(true);
	return;



# MENUBAR
func _on_history_id_pressed(id: int) -> void:
	if(not gameRunning): spawnNotice("[center]Game NOT Running[/center]",  0.8); return;
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
			if (isBoardBusy()):
				spawnNotice("[center]Clean up board. Exit builder or game.[/center]")
				return;
			var fenDialog = preload("res://Scenes/GetFen.tscn").instantiate();
			fenDialog.OKButtonPressed.connect(FenOK);
			add_child(fenDialog);
			return;
		1:
			if (not gameRunning) : 
				spawnNotice("[center]There is no game running.[/center]",  0.8)
				return;
			DisplayServer.clipboard_set(EngineNode._getBoardFenNow());
			spawnNotice("[center]Fen copied to clipboard[/center]",1.0)
			return;
		2:
			if(gameRunning):
				spawnNotice("[center]Finish the current game to use board.[/center]")
				return;
			
			if(fenBuilding):
				print("Board Cleared")
				clearChessPieceNode();
			
			fenBuilding = !fenBuilding;
			LeftPanel.__checkFenBuild();
			swapRightPanel();
			
			
			
		_: return;
func _on_test_id_pressed(id: int) -> void:
	match ( id ):
		0:
			if(gameRunning): 
				spawnNotice("[center]Game is Running.[/center]",  0.8);  
				return;
			EngineNode.Test(0);
			return;
		1:
			if(not gameRunning): 
				spawnNotice("[center]Game NOT Running[/center]",  0.8); 
				return;
			if(masterAIThread.is_started()): 
				spawnNotice("[center]AI Running[/center]",  0.8); 
				return;
			spawnNotice("[center] Board H(): %d [/center]" % EngineNode.TestReturnInt(1),  2);
			return;
			
		_:
			return;



# GUI MENUS
## Set item select value.
func _selectSide_OnItemSelect(index:int) -> void:
	if(gameRunning):
		spawnNotice("[center]Can't switch sides mid-game.[/center]", 1.0);
		RightPanel.__setSide(selfSide);
		return; 
		
	selfSide = index;
	var isUserPlayingW = isWhite();
	
	BoardControler.__checkAndFlipBoard(isUserPlayingW);
	isRotatedWhiteDown = isUserPlayingW;
	
	EngineNode.UpdateEnemy(EngineNode._getEnemyType(), not isWhite());
	return;
##
func _on_enemy_select_item_selected(index:int) -> void:
	if(gameRunning):
		RightPanel.__setEnemy(EngineNode._getEnemyType());
		return; 
	
	if(multiplayerConnected):
		spawnNotice("[center]Multiplayer Connected[/center]")
		RightPanel.__setEnemy(EngineNode._getEnemyType());
		return;
	
	var type:int = index;
	#var difficulty:int = 0;
	if(index > 1):
		type = index - 1;
	#if(index > 2): # TODO :: DEFINE DIFICULTY SLIDER
		#difficulty = index - 3;
	EngineNode.UpdateEnemy(type, not isWhite());
	minimumUndoSizeReq = 1;
	if(type == 0):
		minimumUndoSizeReq += 1;
	return;



## SETTINGS
##
func toggleMusic(choice):
	if choice == 1:
		BGMusicPlayer.__stopPlaying();
		return;
	BGMusicPlayer.__continuePlaying();
	return;
##
func toggleSound(choice):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sound"), choice == 1)
	return;
##
func updateSoundBus(bus,choice):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), choice);
	return;
##
func closeSettingsDialog():
	SettingsDialog.visible = false;
	if(gameRunning):
		if(multiplayerConnected and not isItMyTurn()):
			return;
		pieceUnselectedUnlockOthers.emit();
	return
##
func _on_settings_dialog_settings_updated(settingIndex:int, choice:int):
	match settingIndex:
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
	selfSide = 1 if isW else 0;
	
	var isUserPlayingW = isWhite();
	BoardControler.__checkAndFlipBoard(isUserPlayingW);
	isRotatedWhiteDown = isUserPlayingW;
	RightPanel.__setSide(selfSide);
	return;
##
@rpc("authority", "call_remote", "reliable")
func startGameFromFen(stateString : String = "") -> void:
	if(stateString == ""):
		if not EngineNode.InitiateDefault():
			spawnNotice("[center]DEFAULT START FAILED[/center]", 1.0);
			return;
	else:
		if not EngineNode.initiateEngine(stateString):
			spawnNotice("[center]Fen Invalid[/center]", 1.0);
			return;
	
	RightPanel.__setResignOn();
	
	syncToEngine()
	spawnActivePieces();
	gameSwitchedSides.emit(GDHexConst.SIDES.WHITE if EngineNode._getIsWhiteTurn() else GDHexConst.SIDES.BLACK);
	gameRunning = true;
	
	if( EngineNode._getIsEnemyAI() and EngineNode._getEnemyIsWhite() ): allowAITurn();
	return;
##

func clearChessPieceNode() -> void:
	for colorNodes in ChessPiecesNode.get_children():
		for pieceNodes in colorNodes.get_children():
			for piece in pieceNodes.get_children():
				piece.queue_free();
	return;
@rpc("any_peer", "call_remote", "reliable")
func resignCleanUp() -> void:
	
	EngineNode._resign();
	activePieces.clear();
	currentLegalMoves.clear();
	
	BoardControler.setSignalWhite();
	TAndFrom.__setVis(false);
	gameRunning = false;
	
	clearChessPieceNode();
	
	LeftPanel.__resignCleanUp();
		
	return;
## TODO :: FIX FORCED NEW GAME
@rpc("authority", "call_remote", "reliable")
func forceNewGame() -> void:
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
func multResign() -> void:
	resignCleanUp()
	if(multiplayer.get_remote_sender_id() == 0):
		multResign.rpc();
		return
	spawnNotice("[center]Opponent has resigned.[/center]");
	return;



# Undo
##
func undoCapture() -> void:
	if( not EngineNode.uncaptureValid() ):
		return;
	##Undo Uncapture
	var captureSideToUndo = GDHexConst.SIDES.BLACK if EngineNode._getIsWhiteTurn() else GDHexConst.SIDES.WHITE;
	var cType = EngineNode.CaptureType();
	var cIndex = EngineNode.CaptureIndex();
	var newPos = activePieces[captureSideToUndo][cType][cIndex];
	var newPieceScene = preloadChessPiece(captureSideToUndo, cType, newPos);
	connectPieceToSignals(newPieceScene);

	var ref  = ChessPiecesNode\
	.get_child(captureSideToUndo)\
	.get_child(cType-1);
	
	LeftPanel.__undoCapture(captureSideToUndo);
	
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
func undoDefault(uType:int, uIndex:int, sideToUndo:int) -> void:
	var newPos = activePieces[sideToUndo][uType][uIndex];
	var pieceREF = ChessPiecesNode.get_child(sideToUndo).get_child(uType-1).get_child(uIndex);
	var from = cordinateToOrigin(pieceREF.__getPieceCords());
	pieceREF.__setPieceCords(newPos , cordinateToOrigin(newPos));
	repositionToFrom(from, newPos);
	return;
##
func undoPromoteOrDefault(uType:int, uIndex:int, sideToUndo:int) -> void:
	if(not EngineNode.unpromoteValid()):
		undoDefault(uType,uIndex,sideToUndo);
		return;
	##Undo Promotion
	var pType = EngineNode.unpromoteType();
	var pIndex = EngineNode.unpromoteIndex();
	var newPos = activePieces[sideToUndo][GDHexConst.PIECES.PAWN][pIndex];
	
	var ref = ChessPiecesNode.get_child(sideToUndo).get_child(pType-1);
	var refChildCount = ref.get_child_count(false);
	
	var From = ref.get_child(refChildCount-1).__getPieceCords();
	ref.get_child(refChildCount-1).queue_free();

	var newPieceScene = preloadChessPiece(sideToUndo, GDHexConst.PIECES.PAWN, newPos);
	connectPieceToSignals(newPieceScene);
	ref = ChessPiecesNode.get_child(sideToUndo).get_child(GDHexConst.PIECES.PAWN-1)
	ref.add_child(newPieceScene);
	ref.move_child(newPieceScene,pIndex);
	
	repositionToFrom(From,newPieceScene.__getPieceCords())
	return;
##
func syncUndo() -> void:
	var uType:int = EngineNode.undoType();
	var uIndex:int = EngineNode.undoIndex();
	var sideToUndo:int = GDHexConst.SIDES.WHITE if EngineNode._getIsWhiteTurn() else GDHexConst.SIDES.BLACK;
	
	activePieces = EngineNode.GDGetActivePieces();
	currentLegalMoves = EngineNode.GDGetMoves();
	
	undoPromoteOrDefault(uType, uIndex, sideToUndo);
	undoCapture();
	updateGUI_Elements();
	return;
##
func undoAI() -> void:
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
		setSide.rpc(not isWhite());
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
func _on_undo_pressed() -> void:
	if(threadActive):
		spawnNotice("[center]Please wait until AI has made its turn[/center]");
		return;
	
	if(EngineNode._getMoveHistorySize() < minimumUndoSizeReq):
		spawnNotice("[center]There is no history to undo.[/center]", 1.0);
		return;
	
	if(multiplayerConnected): 
		spawnNotice("[center]NOT available during multiplayer ... yet.[/center]", 1.0);
		return;
	
	EngineNode._undoLastMove(true);
	syncUndo();
	undoAI();
	return;

## Settings Button Pressed
func _on_settings_pressed() -> void:
	SettingsDialog.visible = true;
	SettingsDialog.z_index = 1;
	if(gameRunning):
		pieceSelectedLockOthers.emit();
	return;



#FEN BUILDING
func _on_fen_builder_clear_board() -> void:
	clearChessPieceNode();
	EngineNode.FenBuildCleanBB();
	return;
func _on_fen_builder_place_piece(type: GDHexConst.PIECES, isW: bool, pos: Vector2i) -> void:
	var side : int = GDHexConst.SIDES.WHITE if isW else GDHexConst.SIDES.BLACK;
	var newPiece : Node = preloadChessPiece(side, type, pos);
	ChessPiecesNode.get_child(side).get_child(type-1).add_child(newPiece);
	EngineNode.FenBuildAddToBB(type, isW, pos);
	return;
func _on_fen_builder_clear_piece(pos: Vector2i) -> void:
	##Inefficient but works
	for side : Node in ChessPiecesNode.get_children():
		for type : Node in side.get_children():
			for index : HexPiece in type.get_children():
				if(index.__getPieceCords() != pos):
					continue;
				print("\n",index.__getPieceSide())
				print(index.__getPieceType())
				print(index.__getPieceCords(),"\n")
				EngineNode.FenBuildRemoveFromBB(index.__getPieceCords(),index.__getPieceType(), index.__getPieceSide() == GDHexConst.SIDES.WHITE);
				type.remove_child(index);
				index.queue_free();
	return;



##
func hostShutdown(_reason : int) -> void:
	spawnNotice("[center]Host Shutdown[/center]")
	pass;
##
func clientShutdown(reason:int) -> void:
	if(reason == 0):
		spawnNotice("[center]Client Shutdown[/center]");
	elif(reason == 1):
		spawnNotice("[center]Disconected from server.[/center]");
	return;

#MULTIPLAYER
##
##
@rpc("any_peer", "call_remote", "reliable")
func receiveMove(cords:Vector2i, moveType:int, moveIndex:int, promoteTo:int=0):
	print(GDHexConst.getTimeUtil()," - ", multiplayer.get_unique_id(), " - Received Move: ", cords, " ", moveType, " ", moveIndex, " ", promoteTo);
	
	var toPos = currentLegalMoves[cords][moveType][moveIndex];
	repositionToFrom(cords, toPos);

	var t=0;
	var index = 0;
	var side = GDHexConst.SIDES.WHITE if (not isWhite()) else GDHexConst.SIDES.BLACK;
	var escapeloop = false;
	for pieceType in activePieces[side]:
		if(escapeloop): break;
		t = pieceType;
		index = 0;
		for piece in activePieces[side][pieceType]:
			if(piece == cords): escapeloop = true; break;
			index +=1;
	
	var ref = ChessPiecesNode.get_child(side).get_child(t-1).get_child(index);
	
	if (moveType == GDHexConst.MOVE_TYPES.PROMOTE):
		prepareChessPieceNode(side, promoteTo, toPos);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
	else:
		ref.__setPieceCords(toPos, cordinateToOrigin(toPos));
	
	EngineNode._makeMove(cords, moveType, moveIndex, promoteTo);
	syncToEngine();
	syncCheckMultiplayer.rpc(true);
	return;
##
@rpc("any_peer", "call_remote", "reliable")
func syncCheckMultiplayer(sendSync:bool):
	if(sendSync):
		print(GDHexConst.getTimeUtil()," - ",multiplayer.get_remote_sender_id()," sent a sync request to ", multiplayer.get_unique_id());
		syncCheckMultiplayer.rpc(false);
	else:
		print(GDHexConst.getTimeUtil()," - ", multiplayer.get_unique_id()," is in sync with ", multiplayer.get_remote_sender_id());

	if(isItMyTurn()):
		print(GDHexConst.getTimeUtil()," - ","My Turn: ", multiplayer.get_unique_id())
		pieceUnselectedUnlockOthers.emit();
		return;
	pieceSelectedLockOthers.emit();
	return;

##MULTIPLAYER GUI ON & OFF
func _on_mult_pressed() -> void:
	if(not multiplayerConnected and gameRunning):
		spawnNotice("[center]Finish the current game to start an online session[/center]")
		return;
	MultiplayerControl._showGUI();
	if(gameRunning and isItMyTurn()):
		pieceSelectedLockOthers.emit();
	return;
func _on_close_gui() -> void:
	if(gameRunning and isItMyTurn()):
		pieceUnselectedUnlockOthers.emit();
	return;

##MULTIPLAYER ON & OFF
func _on_multiplayer_enabled(ishost : bool) -> void:
	multiplayerConnected = true;
	isHost = ishost;
	RightPanel.__multSignalOn();
	return;
func _on_multiplayer_disabled() -> void:
	multiplayerConnected = false;
	isHost = false;
	RightPanel.__multSignalOff();
	return


func _on_mult_gui_shutdown_server_client(reason : int) -> void:
	if(gameRunning):
		resignCleanUp();
	if (isHost):
		hostShutdown(reason);
		return;
	clientShutdown(reason);
	return;

func _on_multiplayer_player_connected(_peer_id: Variant, _player_info: Variant) -> void:
	playerCount +=1;
	return;
func _on_multiplayer_player_disconnected(_peer_id: Variant) -> void:
	playerCount -=1;
	spawnNotice("[center]Opponent has disconnected[/center]")
	if(gameRunning and isHost):
		resignCleanUp();
	return;
