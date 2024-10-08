extends Control

# Entry Point of Game

## Error Codes
## 1 No Game Data Node


### Const
const SQRT_THREE_DIV_TWO = sqrt(3) / 2;
enum PIECES { ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES { BLACK, WHITE };
enum MOVE_TYPES { MOVES, CAPTURE, ENPASSANT, PROMOTE}

### State
	# Position References
@onready var VIEWPORT_CENTER_POSITION = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
@onready var PIXEL_OFFSET = 35;
@onready var AXIAL_X_SCALE = 1.4;
@onready var AXIAL_Y_SCALE = 0.9395;
@onready var PIECE_SCALE = 0.18;
@onready var MOVE_SCALE = 0.015;

	# Node Ref
@onready var BoardControler = $StaticGUI/Mid;
@onready var LeftPanel = $StaticGUI/Left

@onready var SideSelect = $StaticGUI/Right/BG/Options/SideSelect
@onready var EnemySelect = $StaticGUI/Right/BG/Options/EnemySelect

@onready var EngineNode:HexEngineSharp = $HCE;

@onready var BGMusicPlayer = $BGMusic;

@onready var TAndFrom = $PosGUI;
@onready var MoveGUI = $MoveGUI;
@onready var ChessPiecesNode = $PiecesContainer;

@onready var SettingsDialog = $SettingsDialog;



	# State
var GameStartTime:int = 0;
var minHistSize:int = 1;
	# Board Setup
var selectedSide:int = 0;
var isRotatedWhiteDown:bool = true;
	# Temp State
var activePieces;
var currentLegalMoves:Dictionary;
	#Threads
var MasterAIThread:Thread;
var ThreadActive:bool = false;
	#References
var tempDialog:AcceptDialog = null;
var ThinkingDialogRef:Node;



### Signals
signal gameSwitchedSides(newSideTurn);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();



## Utility
## Convert Axial Cordinates To Viewport Cords
##	i=y/(3/2*s);
##	j=(x-(y/sqrt(3)))/s*sqrt(3);
func axial_to_pixel(axial: Vector2i) -> Vector2:
	var x = float(axial.x) * AXIAL_X_SCALE;
	var y = ( SQRT_THREE_DIV_TWO * ( float(axial.y * 2) + float(axial.x) ) ) * AXIAL_Y_SCALE;
	return Vector2(x, y);

## Activate The engines 
func runEngineTest() -> void:	
	EngineNode._test(0);
	return;


## MENUBAR
func _on_history_id_pressed(id: int) -> void:
	if(activePieces):
		return;
	pass # Replace with function body.
func _on_fen_id_pressed(id: int) -> void:
	if(activePieces):
		return;
	pass # Replace with function body.
func _on_test_id_pressed(id: int) -> void:
	if(activePieces):
		return;
	match ( id ):
		1:
			runEngineTest();
			return;
		_:
			return;
	return;
	
	

## DISPLAY PIECES
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
func preloadChessPiece(side:int, pieceType, piece:Vector2i) -> Node:
	var newPieceScene:Node = preload("res://Scenes/chess_piece.tscn").instantiate();
	var cords = piece * (1 if isRotatedWhiteDown else -1);
	
	newPieceScene.side = side;
	newPieceScene.pieceType = pieceType;
	newPieceScene.pieceCords = piece;
	newPieceScene.isSetup = true;
	newPieceScene.transform.origin = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(cords));
	
	# TODO: FIX SCALE-ING
	newPieceScene.scale.x = PIECE_SCALE;
	newPieceScene.scale.y = PIECE_SCALE;
	
	return newPieceScene;

## Hand piece data to new scene. Connect scene to piece controller. Add to container.
func prepareChessPieceNode(side:int, typeindex:int, pieceType, piece:Vector2i) -> void:
	var newPieceScene = preloadChessPiece(side, pieceType, piece);
	ChessPiecesNode.get_child(side).get_child(typeindex).add_child(newPieceScene,);
	connectPieceToSignals(newPieceScene);
	return;

## Spawn all the pieces in 'activePieces' at their positions.
func spawnActivePieces() -> void:
	for side:int in range(activePieces.size()):
		var index:int = 0;
		for pieceType in activePieces[side]:
			for piece in activePieces[side][pieceType]:
				prepareChessPieceNode(side, index, pieceType, piece);
			index += 1;
	return;



## MOVE RESPONCE
## Destroy gui element of captured piece
func updateScenceTree_OfCapture() -> void:	
	var i:int = SIDES.WHITE if(EngineNode._getIsWhiteTurn()) else SIDES.BLACK;
	var j:int =  EngineNode._getCaptureType() - 1;
	var index = EngineNode._getCaptureIndex()
	
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
	
	prepareChessPieceNode(ref.side, pTo-1, EngineNode.getPieceType(pTo), ref.pieceCords);

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
	#activePieces = GameDataNode._getActivePieces()
	activePieces = EngineNode._getActivePieces();
	#currentLegalMoves = GameDataNode._getMoves()
	currentLegalMoves = EngineNode._getMoves();
	#if(GameDataNode._getCaptureValid()):
	if(EngineNode._getCaptureValid()):
		updateScenceTree_OfCapture();
	updateGUI_Elements();
	return;



## Move Submit
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
		
	#GameDataNode._makeMove(cords, moveType, moveIndex, promoteTo);
	EngineNode._makeMove(cords, moveType, moveIndex, promoteTo);
	
	TAndFrom.setVis(true);
	var from = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(cords) * (1 if isRotatedWhiteDown else -1));
	TAndFrom.moveFrom(from.x,from.y);
	var toV = currentLegalMoves[cords][moveType][moveIndex];
	var to =  VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(toV) * (1 if isRotatedWhiteDown else -1));
	TAndFrom.moveTo(to.x,to.y)

	syncToEngine();
	return;



## Move GUI
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
		activeScene.transform.origin = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(cord));
		activeScene.rotation_degrees = 90;
		activeScene.z_index = 1;
		activeScene.isSetup = true;
		
		activeScene.scale.x = MOVE_SCALE;
		activeScene.scale.y = MOVE_SCALE;
		
		MoveGUI.add_child(activeScene);
		
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



## AI Moves
##
func syncMasterAIThreadToMain():
	if(MasterAIThread.is_started()):
		MasterAIThread.wait_to_finish();
		
	if(ThinkingDialogRef):
		ThinkingDialogRef.queue_free();
	
	var i:int = SIDES.BLACK if(EngineNode._getIsWhiteTurn()) else SIDES.WHITE;
	var j:int =  EngineNode._getEnemyChoiceType() - 1;
	var k:int = EngineNode._getEnemyChoiceIndex();
	var ref:Node = ChessPiecesNode.get_child(i);
	ref = ref.get_child(j)
	ref = ref.get_child(k);
	var to:Vector2i = EngineNode._getEnemyTo();
	
	TAndFrom.setVis(true);
	var from = VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(ref._getPieceCords()) * (1 if isRotatedWhiteDown else -1));
	TAndFrom.moveFrom(from.x,from.y);
	var toV =  VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(to) * (1 if isRotatedWhiteDown else -1));
	TAndFrom.moveTo(toV.x,toV.y)
	
	if (EngineNode._getEnemyPromoted()):
		prepareChessPieceNode(i,EngineNode._getEnemyPTo()-1, EngineNode._getEnemyPTo(), to);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
	else:
		ref._setPieceCords(to, VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(to*(1 if isRotatedWhiteDown else -1))));
	
	syncToEngine();
	
	pieceUnselectedUnlockOthers.emit();
	return;

##
func passAIToNewThread():
	#GameDataNode._passToAI();
	EngineNode._passToAI();
	syncMasterAIThreadToMain.call_deferred();
	return;

##
func allowAITurn():
	#if(  not GameDataNode._getIsEnemyAI() ):
	if(  not EngineNode._getIsEnemyAI() ):
		return;
	#if( GameDataNode._getGameOverStatus() ): ##TODO Handle AI GAME END
	if( EngineNode._getGameOverStatus() ):
		return
	
	pieceSelectedLockOthers.emit();
	
	TAndFrom.setVis(false);
	ThinkingDialogRef = preload("res://Scenes/AI_Turn_Diolog.tscn").instantiate();
	ThinkingDialogRef.z_index = 1;
	add_child(ThinkingDialogRef);
	
	MasterAIThread.start(passAIToNewThread);
	
	return;



## CLICK AND DRAG (MOUSE) API
## Submit a move to engine or Deselect 
func  _chessPiece_OnPieceDESELECTED(cords:Vector2i, key, index:int) -> void:
	var isNotPromoteMove = key != MOVE_TYPES.PROMOTE;
	for node in MoveGUI.get_children():
		MoveGUI.remove_child(node);
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



## DIALOGS
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

##
func killDialog():
	if(tempDialog != null):
		tempDialog.queue_free()
		tempDialog = null;
	return;

##
func forceNewGame():
	killDialog();
	_resign_OnButtonPress();
	startGame();
	return;

## Throw up warning "Game is ALREADY running, end and start another?(y/n)"
func forcedNewGameDialog():
	setConfirmTempDialog(ConfirmationDialog.new(),\
	"There is a game already running. Start Another?",\
	forceNewGame);
	return;

##
func resignCleanUp():
	if(tempDialog): tempDialog.queue_free();
	#GameDataNode._resign();
	EngineNode._resign();
	activePieces.clear();
	currentLegalMoves.clear();
	BoardControler.setSignalWhite();
	TAndFrom.setVis(false);
	
	for colorNodes in ChessPiecesNode.get_children():
		for pieceNodes in colorNodes.get_children():
			for piece in pieceNodes.get_children():
				piece.queue_free();
	LeftPanel._updateHist([]);
	if(LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();
	return;



## BUTTONS HELPERS
##
func startGame() -> void:
	
	#GameDataNode._initDefault();
	EngineNode._initDefault();
	
	#activePieces = GameDataNode._getActivePieces();
	activePieces = EngineNode._getActivePieces();
	
	#var GDMOVES = GameDataNode._getMoves();
	currentLegalMoves = EngineNode._getMoves();
	
	spawnActivePieces();
	
	emit_signal("gameSwitchedSides", SIDES.WHITE);
	
	GameStartTime = Time.get_ticks_msec();
	#if(GameDataNode._getIsEnemyAI() and GameDataNode._getEnemyIsWhite()):
	if( EngineNode._getIsEnemyAI() and EngineNode._getEnemyIsWhite() ):
		allowAITurn();
		
	return;

##
func undoCapture():
	#if( not GameDataNode._getUncaptureValid() ):
	if( not EngineNode._getUncaptureValid() ):
		return;
	##Undo Uncapture
	var captureSideToUndo = SIDES.BLACK if EngineNode._getIsWhiteTurn() else SIDES.WHITE;
	#var captureSideToUndo = GameDataNode.SIDES.BLACK if GameDataNode._getIsWhiteTurn() else GameDataNode.SIDES.WHITE;
	var cType = EngineNode._getCaptureType();
	var cIndex = EngineNode._getCaptureIndex();
	#var cType = GameDataNode._getCaptureType();
	#var cIndex = GameDataNode._getCaptureIndex();
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
	#if(not GameDataNode._getUnpromoteValid()): ## DEFAULT UNDO
	if(not EngineNode._getUnpromoteValid()):
		newPos = activePieces[sideToUndo][uType][uIndex];
		var pieceREF = ChessPiecesNode.get_child(sideToUndo).get_child(uType-1).get_child(uIndex);
		pieceREF._setPieceCords(newPos , VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(newPos * (1 if isRotatedWhiteDown else -1))));
		return;
	##Undo Promotion
	#var pType = GameDataNode._getUnpromoteType(); # promoted type
	#var pIndex = GameDataNode._getUnpromoteIndex(); # pawn index
	var pType = EngineNode._getUnpromoteType();
	var pIndex = EngineNode._getUnpromoteIndex();
	newPos = activePieces[sideToUndo][PIECES.PAWN][pIndex] ;
	var ref = ChessPiecesNode.get_child(sideToUndo).get_child(pType-1);
	var refChildCount = ref.get_child_count(false);
	ref.get_child(refChildCount-1).queue_free();
	
	var newPieceScene = preloadChessPiece(sideToUndo, PIECES.PAWN, newPos);
	connectPieceToSignals(newPieceScene);
	ref = ChessPiecesNode.get_child(sideToUndo).get_child(PIECES.PAWN-1)
	ref.add_child(newPieceScene);
	ref.move_child(newPieceScene,pIndex);
	return;

##
func syncUndo():
	var uType:int = EngineNode._getUndoType();
	var uIndex:int = EngineNode._getUndoIndex();
	var sideToUndo:int = SIDES.WHITE if EngineNode._getIsWhiteTurn() else SIDES.BLACK;
	
	activePieces = EngineNode._getActivePieces();
	currentLegalMoves = EngineNode._getMoves();
	
	undoPromoteOrDefault(uType, uIndex, sideToUndo);
	undoCapture();
	updateGUI_Elements();
	return;

##
func undoAI():
	#if(not GameDataNode._getIsEnemyAI()):
	if(not EngineNode._getIsEnemyAI()):
		return;
	#GameDataNode._undoLastMove();
	EngineNode._undoLastMove(true);
	syncUndo();
	return



## BUTTONS
## New Game Button Pressed.
# Sub : Calls Spawn Pieces
func _newGame_OnButtonPress() -> void:
	if(activePieces):
		forcedNewGameDialog();
		return;
	startGame();
	return;

## Resign Button Pressed.
func _resign_OnButtonPress() -> void:
	if(not activePieces):
		return;
	if(EngineNode._getGameOverStatus()):
	#if(GameDataNode._getGameOverStatus()):
		resignCleanUp();
		return;
	setConfirmTempDialog(ConfirmationDialog.new(), "Resign the match?", resignCleanUp);
	return;

## Undo Button Pressed
func _on_undo_pressed():
	#if(GameDataNode._getMoveHistorySize() < minHistSize):
	if(EngineNode._getMoveHistorySize() < minHistSize):
		setConfirmTempDialog(ConfirmationDialog.new(), "There is NO history to undo.", killDialog);
		return;
	#GameDataNode._undoLastMove();
	EngineNode._undoLastMove(true);
	syncUndo();
	undoAI();
	return;

## Settings Button Pressed
func _on_settings_pressed():
	SettingsDialog.visible = true;
	SettingsDialog.z_index = 1;
	if(activePieces):
		pieceSelectedLockOthers.emit();
	return;



## MENUS
## Set item select value.
func _selectSide_OnItemSelect(index:int) -> void:
	if(activePieces):
		# TODO: Throw up warning "Game is ALREADY running, cant change sides during game "
		SideSelect._setSelected(selectedSide);
		return; 
	selectedSide = index;
	
	var isUserPlayingW = (selectedSide == 0);
	BoardControler.checkAndFlipBoard(isUserPlayingW);
	isRotatedWhiteDown = isUserPlayingW;
	
	#GameDataNode._setEnemy(GameDataNode._getEnemyType(), selectedSide != 0);
	EngineNode._setEnemy(EngineNode._getEnemyType(), selectedSide != 0);
	#print("Type: ", GameDataNode._getEnemyType());
	#print("IsWhite: ", GameDataNode._getEnemyIsWhite());
	return;

##
func _on_enemy_select_item_selected(index:int) -> void:
	if(activePieces):
		#EnemySelect._setSelected(GameDataNode._getEnemyType());
		EnemySelect._setSelected(EngineNode._getEnemyType());
		return; 
		
	var type:int = index;
	if(index > 1):
		type = index - 1;
	#GameDataNode._setEnemy(type, selectedSide != 0);
	EngineNode._setEnemy(type, selectedSide != 0);
	
	minHistSize = 1;
	if(type == 0):
		minHistSize += 1;
	return;



## SETTINGS
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
	if(activePieces):
		pieceUnselectedUnlockOthers.emit();
	return

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



### GODOT DEFAULTS


## First Method Called
func _ready():
	MasterAIThread = Thread.new();
	#SET The default settings
	#Find Possible Resolutions Give to Settings
	#Find ColorSchemes
	return;
