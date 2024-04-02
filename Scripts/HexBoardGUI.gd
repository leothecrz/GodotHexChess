extends Control




###
###
### State
@onready var centerPos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
@onready var offset = 35;
	# REF
@onready var MoveGUI = $MoveGUI;
@onready var BoardControler = $Background/Central;
@onready var GameDataNode = $ChessEngine;
@onready var ChessPiecesNode = $PiecesContainer;
@onready var LeftPanel = $LeftPanel;
	# Board Setup
var selectedSide:int;
var boardRotatedForWhite:bool;
	# Game Info
var activePieces:Array;
var currentLegalsMoves:Dictionary;




###
###
### Signals
signal gameSwitchedSides(newSideTurn);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();




###
###
### Scene Events

## Convert Axial Cordinates To Viewport Cords
##	i=y/(3/2*s);
##	j=(x-(y/sqrt(3)))/s*sqrt(3);
func axial_to_pixel(axial: Vector2i) -> Vector2:


	const xScale = 1.4;
	const yScale = 0.9395;
	var x = float(axial.x) * xScale;
	var y = (sqrt(3) * ( float(axial.y) + (float(axial.x) / 2) )) * yScale;
	
	return Vector2(x, y);



##
func spawnPiecesSubRoutine(side, typeindex, pieceType, piece, cords) -> void:
	var activeScene = preload("res://Scenes/chess_piece.tscn").instantiate();

	activeScene.side = side;
	activeScene.pieceType = pieceType;
	activeScene.pieceCords = piece;
	activeScene.isSetup = true;
	
	activeScene.transform.origin = centerPos + (offset * axial_to_pixel(cords));
	
	# TODO: FIX SCALE-ING
	activeScene.scale.x = 0.18;
	activeScene.scale.y = 0.18;
	
	ChessPiecesNode.get_child(side).get_child(typeindex).add_child(activeScene);

	activeScene.pieceSelected.connect(_chessPiece_OnPieceSelected);
	activeScene.pieceDeselected.connect(_chessPiece_OnPieceDeselected);
	
	gameSwitchedSides.connect(activeScene._on_Control_GameSwitchedSides);
	pieceSelectedLockOthers.connect(activeScene._on_Control_LockPiece);
	pieceUnselectedUnlockOthers.connect(activeScene._on_Control_UnlockPiece);
	return;

## Spawn all the pieces in 'activePieces' at there positions.
func spawnPieces() -> void:
	
	for i:int in range(activePieces.size()):
		var j:int = 0;
		for pieceType in activePieces[i]:
			for piece in activePieces[i][pieceType]:
				
				var cord = piece * (1 if boardRotatedForWhite else -1);
				
				spawnPiecesSubRoutine(i, j, pieceType, piece, cord);
				
			j = j+1;
	return;



##
func handleMoveCapture() -> void:

	print("Type: ",GameDataNode._getCaptureType(), ". Index: ", GameDataNode._getCaptureIndex());
	var i:int = 0;
	if(GameDataNode._getIsWhiteTurn()):
		i += 1;
	var j:int =  GameDataNode._getCaptureType() - 1;
	ChessPiecesNode.get_child(i).get_child(j).get_child(GameDataNode._getCaptureIndex()).queue_free();
	return;

##
func promotionInterupt(cords:Vector2i, key:String, index:int, pTo) -> void:
	
	## SWAP CHESS PIECE FROM PAWN TO PTO
	var ref:;
	var i:int = 0;
	if(GameDataNode._getIsWhiteTurn()):
		i += 1;
		
	for pawnIndex in range( activePieces[i]["P"].size() ):
		if (activePieces[i]["P"][pawnIndex] == cords):
			ref = ChessPiecesNode.get_child(i).get_child(0).get_child(pawnIndex);
			break;
	######### FIX
	spawnPiecesSubRoutine(ref.side, pTo-1, GameDataNode.getPieceType(pTo), ref.pieceCords, ref.pieceCords * 1 if boardRotatedForWhite else -1);
	ref.queue_free();
	
	handleMakeMove(cords, key, index, pTo, true);
	emit_signal("pieceUnselectedUnlockOthers");
	disconnect("promotionAccepted", promotionInterupt);
	get_child(get_child_count() - 1).queue_free();
	return;

##
#func handleMove(cords:Vector2i, moveType:String, moveIndex:int, _promoteTo:PIECES) -> void:
func handleMakeMove(cords:Vector2i, moveType:String, moveIndex:int, promoteTo:int=0, passInterupt=false) -> void:

	if(moveType == 'Promote' and not passInterupt):
		var dialog = preload("res://Scenes/PromotionDialog.tscn").instantiate();

		dialog.z_index = 1; #place on foreground
		dialog.cords = cords;
		dialog.key = moveType;
		dialog.index = moveIndex;
		dialog.promotionAccepted.connect(promotionInterupt); # signal connect

		add_child(dialog);
		
		return

	GameDataNode._makeMove(cords, moveType, moveIndex, promoteTo);
	
	activePieces = GameDataNode._getActivePieces()
	currentLegalsMoves = GameDataNode._getMoves()
	
	if(GameDataNode._getGameInCheck() != LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();

	if(GameDataNode._getCaptureValid()):
		handleMoveCapture();
	
	if(GameDataNode._getIsWhiteTurn()):
		emit_signal("gameSwitchedSides", 1);
	else:
		emit_signal("gameSwitchedSides", 0);

	if(GameDataNode._getGameOverStatus()):
		if(GameDataNode._getGameOverStatus() != LeftPanel._getLabelState()):
			LeftPanel._swapLabelState();
		if(GameDataNode._getGameInCheck()):
			LeftPanel._setCheckMateText(GameDataNode._getIsBlackTurn());
		else:
			LeftPanel._setStaleMateText();
	return;



##
func handleMovesSpawn(moves:Array, color:Color, key, cords):
	
	var centerPos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
	
	for i in range(moves.size()):
		var move = moves[i];
		
		#var kingCord```s = activePieces[0 if GameDataNode.__getIsBlackTurn() else 1]["K"][0];
		#if(move.x == kingCords.x && move.y == kingCords.y):
		#	continue;
		
		var activeScene = preload("res://Scenes/HexTile.tscn").instantiate();
		var cord = move if boardRotatedForWhite else (move * -1);
		
		
		activeScene.hexCords = cords;
		activeScene.hexKey = key;
		activeScene.hexIndex = i;
		activeScene.hexMove = move;
		activeScene.isSetup = true;

		activeScene.transform.origin = centerPos + (offset * axial_to_pixel(cord));
		activeScene.rotation_degrees = 90;
		activeScene.scale.x = 0.015;
		activeScene.scale.y = 0.015;
		activeScene.z_index = 1;
		
		MoveGUI.add_child(activeScene);
		
		activeScene.SpriteNode.set_modulate(color);
		
	pass;

##
func spawnChessMoves(moves:Dictionary, cords) -> void:
	for key in moves.keys():
		match key:
			"Promote":
				handleMovesSpawn(moves[key], Color(0,255,255,255), key, cords);
				pass
			"EnPassant":
				handleMovesSpawn(moves[key], Color(255,255,0,255), key, cords);
				pass
			"Capture":
				handleMovesSpawn(moves[key], Color(255,0,0,255), key, cords);
				pass
			"Moves":
				handleMovesSpawn(moves[key], Color(0,255,0,255), key, cords);
				pass
	return;



##
func  _chessPiece_OnPieceDeselected(cords:Vector2i, key:String, index:int) -> void:
	
	if(index >= 0):
		handleMakeMove(cords, key, index);

	for node in MoveGUI.get_children():
		MoveGUI.remove_child(node);
		node.queue_free();
	
	if(key != "Promote"):
		emit_signal("pieceUnselectedUnlockOthers");
	
	return;

##
func  _chessPiece_OnPieceSelected(_SIDE:int, _TYPE:int, CORDS:Vector2i) -> void:
	
	emit_signal("pieceSelectedLockOthers");
	
	var thisPiecesMoves = {};
	for key in currentLegalsMoves[CORDS].keys():
		thisPiecesMoves[key] = currentLegalsMoves[CORDS][key];
		
	spawnChessMoves(thisPiecesMoves, CORDS);
	
	return;



## New Game Button Pressed.
func _newGame_OnButtonPress() -> void:
	if(activePieces):
		return; # Ignore if pieces already set.
	
	if(!GameDataNode):	
		push_error("GUI HAS NO GAME DATA - ON READY FAIL");
		return;

	var isWhite = (selectedSide == 0);
	
	GameDataNode._initDefault();
	
	BoardControler.checkIfFlipBoard(isWhite);
	boardRotatedForWhite = isWhite;

	activePieces = GameDataNode._getActivePieces();
	currentLegalsMoves = GameDataNode._getMoves();
	spawnPieces();

	if(GameDataNode._getIsWhiteTurn()): emit_signal("gameSwitchedSides", 1);
	else: emit_signal("gameSwitchedSides", 0);

	return;
	
## Resign Button Pressed.
func _resign_OnButtonPress() -> void:
	
	GameDataNode._resign();
	activePieces.clear();
	currentLegalsMoves.clear();
	
	for colorNodes in ChessPiecesNode.get_children():
		for pieceNodes in colorNodes.get_children():
			for piece in pieceNodes.get_children():
				piece.queue_free();
	
	if(LeftPanel._getLabelState()):
		LeftPanel._swapLabelState();
	
	return;

## Undo Button Pressed
func _on_undo_pressed():
	GameDataNode._undoLastMove();
	return;



## Set item select value.
func _selectSide_OnItemSelect(index:int) -> void:
	selectedSide = index;
	return;



##TODO: Implement Resize - Cascade scale factor to gui elements
## Begining of resize cascade
func onResize() ->void:
	return;




###
###
### GODOT DEFAULTS
# Called when the node enters the scene tree for the first time.
func _ready():
	
	selectedSide = 0;
	get_tree().get_root().size_changed.connect(onResize);
	
	return;

