extends Control

##
# Entry Point of Game
##

## Error Codes
## 1 No Game Data Node


### Const


const SQRT_THREE_DIV_TWO = sqrt(3) / 2;
const xScale = 1.4;
const yScale = 0.9395;


### State


	# Position References
@onready var VIEWPORT_CENTER_POSITION = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
@onready var PIXEL_OFFSET = 35;

	# Node Ref
@onready var GameDataNode:HexEngine = $ChessEngine;
@onready var MoveGUI = $MoveGUI;
@onready var ChessPiecesNode = $PiecesContainer;
@onready var LeftPanel = $LeftPanel;
@onready var SettingsDialog = $SettingsDialog;

@onready var BoardControler = $Background/Central;

@onready var SideSelect = $PlayerColumn/ColumnBack/GameButtons/SideSelect;
@onready var EnemySelect = $PlayerColumn/ColumnBack/GameButtons/EnemySelect;

	# State
@onready var errorAttempts:int = 0;
@onready var GameStartTime = 0;

	# Board Setup
var selectedSide:int;
var isRotatedWhiteDown:bool = true;

	# Temp State
var activePieces:Array;
var currentLegalsMoves:Dictionary;
var isUndoing = false;

### Signals


signal gameSwitchedSides(newSideTurn);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();


## Utility


## Connect Signal From Root
func connectResizeToRoot() -> void:
	get_tree().get_root().size_changed.connect(onResize);
	return;

##TODO: Implement Resize - Cascade scale factor to gui elements
## Begining of resize cascade
func onResize() ->void:
	VIEWPORT_CENTER_POSITION = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
	return;

## Convert Axial Cordinates To Viewport Cords
##	i=y/(3/2*s);
##	j=(x-(y/sqrt(3)))/s*sqrt(3);
func axial_to_pixel(axial: Vector2i) -> Vector2:
	
	var x = float(axial.x) * xScale;
	var y = ( SQRT_THREE_DIV_TWO * ( float(axial.y * 2) + float(axial.x) ) ) * yScale;
	
	return Vector2(x, y);

##
func runEngineTest() -> void:
	var Tester = EngineTest.new();
	Tester.runSweep(GameDataNode);
	Tester.queue_free();
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
	newPieceScene.scale.x = 0.18;
	newPieceScene.scale.y = 0.18;
	
	return newPieceScene;

## Hand piece data to new scene. Connect scene to piece controller. Add to container.
func spawnPiecesSubRoutine(side:int, typeindex:int, pieceType, piece:Vector2i) -> void:
	var newPieceScene = preloadChessPiece(side, pieceType, piece);
	ChessPiecesNode.get_child(side).get_child(typeindex).add_child(newPieceScene,);
	connectPieceToSignals(newPieceScene);
	return;

## Spawn all the pieces in 'activePieces' at their positions.
func spawnPieces() -> void:
	for side:int in range(activePieces.size()):
		var index:int = 0;
		for pieceType in activePieces[side]:
			for piece in activePieces[side][pieceType]:
				spawnPiecesSubRoutine(side, index, pieceType, piece);
			index += 1;
	return;


## MOVE RESPONCE


## Destroy gui element of captured piece
func handleMoveCapture() -> void:	
	var i:int = GameDataNode.SIDES.WHITE if(GameDataNode._getIsWhiteTurn()) else GameDataNode.SIDES.BLACK;
	var j:int =  GameDataNode._getCaptureType() - 1;
	var ref:Node = ChessPiecesNode.get_child(i).get_child(j).get_child(GameDataNode._getCaptureIndex())
	ref.get_parent().remove_child(ref); ## 
	ref.queue_free();
	return;

## Despawn the pawn gui element, spawn 'pto' gui element for promoted type.
func promotionInterupt(cords:Vector2i, key:int, index:int, pTo) -> void:
	var ref:Node;
	var i:int = GameDataNode.SIDES.WHITE if (GameDataNode._getIsWhiteTurn()) else GameDataNode.SIDES.BLACK;
	for pawnIndex in range( activePieces[i][GameDataNode.PIECES.PAWN].size() ):
		if (activePieces[i][GameDataNode.PIECES.PAWN][pawnIndex] == cords):
			ref = ChessPiecesNode.get_child(i).get_child(GameDataNode.PIECES.PAWN-1).get_child(pawnIndex);
			break;
	
	spawnPiecesSubRoutine(ref.side, pTo-1, GameDataNode.getPieceType(pTo), ref.pieceCords);
	
	ref.queue_free();
	
	submitMove(cords, key, index, pTo, false);
	emit_signal("pieceUnselectedUnlockOthers");
	get_child(get_child_count() - 1).queue_free();
	
	allowAITurn();
	return;

## Get new state data from engine
func updateGUI_Elements() -> void:
	if(GameDataNode._getGameInCheck() != LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();

	if(GameDataNode._getIsWhiteTurn()):
		emit_signal("gameSwitchedSides", GameDataNode.SIDES.WHITE);
		BoardControler.setSignalWhite();
	else:
		emit_signal("gameSwitchedSides", GameDataNode.SIDES.BLACK);
		BoardControler.setSignalBlack();

	if(GameDataNode._getGameOverStatus()):
		if(GameDataNode._getGameOverStatus() != LeftPanel._getLabelState()):
			LeftPanel._swapLabelState();
		if(GameDataNode._getGameInCheck()):
			LeftPanel._setCheckMateText(GameDataNode._getIsBlackTurn());
		else:
			LeftPanel._setStaleMateText();
	return;


## Handle post move gui updates
func postMove() -> void:
	activePieces = GameDataNode._getActivePieces()
	currentLegalsMoves = GameDataNode._getMoves()
	
	if(GameDataNode._getCaptureValid()):
		handleMoveCapture();
	
	updateGUI_Elements();
	return;

## Interupt a promotion submission to get promotion type
func submitMoveInterupt(cords, moveType, moveIndex) -> void:
	var dialog = preload("res://Scenes/PromotionDialog.tscn").instantiate();
	dialog.z_index = 1; #place on foreground
	dialog.cords = cords;
	dialog.key = moveType;
	dialog.index = moveIndex;
	dialog.promotionAccepted.connect(promotionInterupt); # signal connect
	add_child(dialog);
	return;

## Sumbit a move to the engine and update state
func submitMove(cords:Vector2i, moveType, moveIndex:int, promoteTo:int=0, passInterupt=true) -> void:
	
	
	if(moveType == GameDataNode.MOVE_TYPES.PROMOTE and passInterupt):
		submitMoveInterupt(cords, moveType, moveIndex);
		return
	GameDataNode._makeMove(cords, moveType, moveIndex, promoteTo);
	postMove();
	return;

## Setup and display a legal move on GUI
func spawnMove(moves:Array, color:Color, key, cords):
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
		activeScene.scale.x = 0.015;
		activeScene.scale.y = 0.015;
		activeScene.z_index = 1;
		activeScene.isSetup = true;
		
		MoveGUI.add_child(activeScene);
		
		activeScene.SpriteNode.set_modulate(color);
	return;

## Spawn the moves from the given 'moves' dictionary for the piece 'cords'
func spawnMoves(moves:Dictionary, cords) -> void:
	for key in moves.keys():
		match key:
			GameDataNode.MOVE_TYPES.MOVES: 			spawnMove(moves[key], Color.WHITE, key, cords);
			GameDataNode.MOVE_TYPES.CAPTURE: 		spawnMove(moves[key], Color.DARK_RED, key, cords);
			GameDataNode.MOVE_TYPES.PROMOTE: 		spawnMove(moves[key], Color.DARK_KHAKI, key, cords);
			GameDataNode.MOVE_TYPES.ENPASSANT: 		spawnMove(moves[key], Color.SEA_GREEN, key, cords);
	return;

##
func allowAITurn():
	if(  not GameDataNode._getIsEnemyAI() ):
		return;
	if( GameDataNode._getGameOverStatus() ): ##TODO Handle AI GAME END
		return
	
	GameDataNode._passToAI();
	
	var i:int = GameDataNode.SIDES.BLACK if(GameDataNode._getIsWhiteTurn()) else GameDataNode.SIDES.WHITE;
	var j:int =  GameDataNode._getEnemyChoiceType() - 1;
	var k:int = GameDataNode._getEnemyChoiceIndex();
	var ref:Node = ChessPiecesNode.get_child(i).get_child(j).get_child(k);
	var to:Vector2i = GameDataNode._getEnemyTo();
	
	if (GameDataNode._getEnemyPromoted()):
		spawnPiecesSubRoutine(i,GameDataNode._getEnemyPTo()-1, GameDataNode._getEnemyPTo(), to);
		ref.get_parent().remove_child(ref);
		ref.queue_free();
		pass;
	else:
		ref._setPieceCords(to, VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(to*(1 if isRotatedWhiteDown else -1))));
	
	postMove();
	return;

## CLICK AND DRAG (MOUSE) API


## Submit a move to engine or Deselect 
func  _chessPiece_OnPieceDESELECTED(cords:Vector2i, key, index:int) -> void:
	var isNotPromoteMove = key != GameDataNode.MOVE_TYPES.PROMOTE;
	for node in MoveGUI.get_children():
		MoveGUI.remove_child(node);
		node.queue_free();
		
	if (isNotPromoteMove): emit_signal("pieceUnselectedUnlockOthers");
	
	if (index >= 0):
		submitMove(cords, key, index);
		if(isNotPromoteMove):
			allowAITurn();
	return;

## Lock Other Pieces
## Sub :: Spawn Piece's Moves 
func  _chessPiece_OnPieceSELECTED(_SIDE:int, _TYPE:int, CORDS:Vector2i) -> void:
	emit_signal("pieceSelectedLockOthers");
	
	var thisPiecesMoves = {};
	for key in currentLegalsMoves[CORDS].keys():
		thisPiecesMoves[key] = currentLegalsMoves[CORDS][key];
	spawnMoves(thisPiecesMoves, CORDS);
	return;


## BUTTONS


## New Game Button Pressed.
# Sub : Calls Spawn Pieces
func _newGame_OnButtonPress() -> void:
	if(activePieces):
		# TODO: Throw up warning "Game is ALREADY running, end and start another?(y/n)"
		return; 

	GameDataNode._initDefault();
	activePieces = GameDataNode._getActivePieces();
	currentLegalsMoves = GameDataNode._getMoves();
	spawnPieces();
	emit_signal("gameSwitchedSides", GameDataNode.SIDES.WHITE);
	
	GameStartTime = Time.get_ticks_msec();
	
	if(GameDataNode._getIsEnemyAI() and GameDataNode._getEnemyIsWhite()):
		allowAITurn();
		pass;
	
	return;

## Resign Button Pressed.
func _resign_OnButtonPress() -> void:
	GameDataNode._resign();
	activePieces.clear();
	currentLegalsMoves.clear();
	BoardControler.setSignalWhite();
	
	for colorNodes in ChessPiecesNode.get_children():
		for pieceNodes in colorNodes.get_children():
			for piece in pieceNodes.get_children():
				piece.queue_free();
	
	if(LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();
	return;

## Undo Button Pressed
func _on_undo_pressed():
	if(not GameDataNode._undoLastMove()):
		print("Undo Failed");
		## TODO ALERT THAT UNDO IMPOSSIBLE
		return;
	
	if(isUndoing):
		return;
	isUndoing = true;
	
	var uType = GameDataNode._getUndoType();
	var uIndex = GameDataNode._getUndoIndex();
	var sideToUndo = GameDataNode.SIDES.WHITE if GameDataNode._getIsWhiteTurn() else GameDataNode.SIDES.BLACK;
	
	activePieces = GameDataNode._getActivePieces();
	currentLegalsMoves = GameDataNode._getMoves();
	
	if(not GameDataNode._getUnpromoteValid()): ## DEFAULT UNDO
		var newPos = activePieces[sideToUndo][uType][uIndex];
		var pieceREF = ChessPiecesNode.get_child(sideToUndo).get_child(uType-1).get_child(uIndex);
		pieceREF._setPieceCords(newPos , VIEWPORT_CENTER_POSITION + (PIXEL_OFFSET * axial_to_pixel(newPos * (1 if isRotatedWhiteDown else -1))));
	else: 
		print("Undo Promotion")
		var pType = GameDataNode._getUnpromoteType(); # promoted type
		var pIndex = GameDataNode._getUnpromoteIndex(); # pawn index
		var newPos = activePieces[sideToUndo][GameDataNode.PIECES.PAWN][pIndex] ;
		
		var ref = ChessPiecesNode.get_child(sideToUndo).get_child(pType-1);
		var refChildCount = ref.get_child_count(false);
		ref.get_child(refChildCount-1).queue_free();
		
		var newPieceScene = preloadChessPiece(sideToUndo, GameDataNode.PIECES.PAWN, newPos);
		connectPieceToSignals(newPieceScene);
		ref = ChessPiecesNode.get_child(sideToUndo).get_child(GameDataNode.PIECES.PAWN-1)
		ref.add_child(newPieceScene);
		ref.move_child(newPieceScene,pIndex);
		
		
		
	if(GameDataNode._getUncaptureValid()):
		print("Undo Uncapture")
		var captureSideToUndo = GameDataNode.SIDES.BLACK if GameDataNode._getIsWhiteTurn() else GameDataNode.SIDES.WHITE;
		var cType = GameDataNode._getCaptureType();
		var cIndex = GameDataNode._getCaptureIndex();
		
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
	
	updateGUI_Elements();
	
	isUndoing = false;
	return;

## RUN TEST DEBUG FUNCTION
func _on_run_test_pressed():
	runEngineTest();
	return;

##
func _on_settings_pressed():
	SettingsDialog.visible = true;
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
	
	GameDataNode._setEnemy(GameDataNode._getEnemyType(), selectedSide != 0);
	#print("Type: ", GameDataNode._getEnemyType());
	#print("IsWhite: ", GameDataNode._getEnemyIsWhite());
	return;

##
func _on_enemy_select_item_selected(index:int) -> void:
	if(activePieces):
		# TODO: Throw up warning "Game is ALREADY running, cant change enemy during game "
		EnemySelect._setSelected(GameDataNode._getEnemyType());
		return; 
		
	var type = index - 1 if (index > 1) else index;
	GameDataNode._setEnemy(type, selectedSide != 0);
	#print("Type: ", GameDataNode._getEnemyType());
	#print("IsWhite: ", GameDataNode._getEnemyIsWhite());
	return;


### GODOT DEFAULTS


## First Method Called
func _ready():
	selectedSide = 0;
	connectResizeToRoot();
	return;


