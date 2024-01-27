extends Control

#### State
@onready var offset = 35;
@onready var BoardControler = $ColorRect/Central;
@onready var GameDataNode = $GameState;
@onready var ChessPiecesNode = $PiecesContainer;
@onready var MoveGUI = $MoveGUI;

var selectedSide:int;
var activePieces:Dictionary;
var currentLegalsMoves:Dictionary;
var boardRotatedForWhite:bool;
####

####Signals
signal gameSwitchedSides(newSideTurn);
signal pieceSelectedLockOthers();
signal pieceUnselectedUnlockOthers();
####

#### Scene Events
# Convert Axial Cordinates To Viewport Cords
func axial_to_pixel(axial: Vector2i) -> Vector2:
	const xScale = 1.4;
	const yScale = 0.94;
	
	var x = xScale * float(axial.x);
	var y = (sqrt(3) * (float(axial.y) + float(axial.x) / 2)) * yScale;
	
	return Vector2(x, y);

# Spawn all the pieces in 'activePieces' at there positions.
func spawnPieces() -> void:
	
	var centerPos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
	var i:int = 0;
	for side in activePieces.keys():
		var j:int = 0;
		for pieceType in activePieces[side].keys():
			for piece in activePieces[side][pieceType]:
				
				var cord = piece if boardRotatedForWhite else (piece * -1);
				var activeScene = preload("res://Scenes/chess_piece.tscn").instantiate();
				activeScene.initState = [side, pieceType, piece];
				
				activeScene.transform.origin = centerPos + (offset * axial_to_pixel(cord));
				
				activeScene.scale.x = 0.18;
				activeScene.scale.y = 0.18;
				
				#ChessPiecesNode.add_child(activeScene);
				ChessPiecesNode.get_child(i).get_child(j).add_child(activeScene);
				activeScene.pieceSelected.connect(_chessPiece_OnPieceSelected);
				activeScene.pieceDeselected.connect(_chessPiece_OnPieceDeselected);
				
				gameSwitchedSides.connect(activeScene._on_Control_GameSwitchedSides);
				pieceSelectedLockOthers.connect(activeScene._on_Control_LockPiece);
				pieceUnselectedUnlockOthers.connect(activeScene._on_Control_UnlockPiece);
			j = j+1;
		i = i+1;
	return;

#
func handleMoveCapture() -> void:
	print(GameDataNode.getCaptureType(), GameDataNode.getCaptureIndex());
	var i:int = 0;
	if(GameDataNode.getIsWhiteTurn()):
		i += 1;
	var j:int = 0;
	match GameDataNode.getCaptureType():
		"P": j = 0;
		"N": j = 1;
		"R": j = 2;
		"B": j = 3;
		"Q": j = 4;
		"K": j = 5;
	ChessPiecesNode.get_child(i).get_child(j).get_child(GameDataNode.getCaptureIndex()).queue_free();
	return;

#
func handleMakeMove(piece, data) -> void:
	
	GameDataNode.makeMove(piece, data[0], data[1], data[2]);
	activePieces = GameDataNode.getActivePieces()
	currentLegalsMoves = GameDataNode.getMoves()
	
	if(GameDataNode.getCaptureValid()):
		handleMoveCapture();
	
	
	if(GameDataNode.getIsWhiteTurn()):
		emit_signal("gameSwitchedSides", "white");
	else:
		emit_signal("gameSwitchedSides", "black");
		
	return;

#
func handleMovesSpawn(moves:Array, color:Color, key, index):
	
	var centerPos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2);
	
	for i in range(moves.size()):
		var move = moves[i]
		
		var activeScene = preload("res://Scenes/HexTile.tscn").instantiate();
		
		var cord = move if boardRotatedForWhite else (move * -1);
		
		activeScene.initializationInformation = [key, index, i, move];
		activeScene.transform.origin = centerPos + (offset * axial_to_pixel(cord));
		activeScene.rotation_degrees = 90;
		activeScene.scale.x = 0.015;
		activeScene.scale.y = 0.015;
		
		MoveGUI.add_child(activeScene);
		
		activeScene.SpriteNode.set_modulate(color);
		
	pass;

#
func spawnChessMoves(moves:Dictionary, index) -> void:
	for key in moves.keys():
		match key:
			"Promote":
				handleMovesSpawn(moves[key], Color(0,255,255,255), key, index);
				pass
			"EnPassant":
				handleMovesSpawn(moves[key], Color(255,255,0,255), key, index);
				pass
			"Capture":
				handleMovesSpawn(moves[key], Color(255,0,0,255), key, index);
				pass
			"Moves":
				handleMovesSpawn(moves[key], Color(0,255,0,255), key, index);
				pass
	return;

#
func  _chessPiece_OnPieceDeselected(piece:Array, data:Array) -> void:
	
	print("Piece: ",piece);
	print("Hex Data: ", data);
	
	if (data.size() > 0):
		handleMakeMove(piece[1], data);

	for node in MoveGUI.get_children():
		MoveGUI.remove_child(node);
		node.queue_free();
	
	emit_signal("pieceUnselectedUnlockOthers");	
	return;

#
func  _chessPiece_OnPieceSelected(piece:Array) -> void:
	
	var side = piece[0];
	var pieceType = piece[1];
	var pieceCords = piece[2];
	
	var pieceArray:Array =  activePieces[side][pieceType];
	var pos = pieceArray.find(pieceCords);
	var typeMoves = currentLegalsMoves[pieceType];
	
	var thisPiecesMoves = {};
	for key in typeMoves.keys():
		thisPiecesMoves[key] = typeMoves[key][pos];
	
	print("LegalMoves: ", thisPiecesMoves);
	spawnChessMoves(thisPiecesMoves, pos);
	
	emit_signal("pieceSelectedLockOthers");
	
	return;

# New Game Button Pressed.
func _newGame_OnButtonPress() -> void:
	if(activePieces):
		return; # Ignore if pieces already set.
	if(!GameDataNode):	
		push_error("GUI HAS NO GAME DATA - ON READY FAIL");
		return;

	var isWhite = (selectedSide == 0);
	
	GameDataNode.startDefaultGame(isWhite);
	BoardControler.checkIfFlipBoard(isWhite);
	boardRotatedForWhite = isWhite;

	activePieces = GameDataNode.getActivePieces();
	currentLegalsMoves = GameDataNode.getMoves();
	spawnPieces();

	if(GameDataNode.getIsWhiteTurn()): emit_signal("gameSwitchedSides", "white");
	else: emit_signal("gameSwitchedSides", "black");

	return;

# Resign Button Pressed.
func _resign_OnButtonPress() -> void:
	activePieces.clear();
	currentLegalsMoves.clear();
	
	for node in ChessPiecesNode.get_children():
		for innerNode in node.get_children():
			innerNode.queue_free();
	
	return;

# Set item select value.
func _selectSide_OnItemSelect(index:int) -> void:
	selectedSide = index;
	return;

#TODO: Implement Resize
func onResize() ->void:
	return;
####

#### GODOT DEFAULTS
# Called when the node enters the scene tree for the first time.
func _ready():
	selectedSide = 0;
	
	get_tree().get_root().size_changed.connect(onResize);
	
	return;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	return;
####
