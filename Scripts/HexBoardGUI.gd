extends Control

### State
var selected:int;
@onready var BoardControler = $ColorRect/Central;
@onready var GameDataNode = $GameData;
@onready var ChessPiecesNode = $ChessPieces;

var activePieces:Dictionary;
var currentLegalsMoves:Dictionary;
var boardRotatedForWhite:bool;
###

###Signals
	
###

### Scene Events
##
func _selectSide_OnItemSelect(index:int):
	selected = index;
	pass

##
func axial_to_pixel(axial: Vector2i) -> Vector2:
	var x = 1.41 * float(axial.x);
	var y = (sqrt(3) * (float(axial.y) + float(axial.x) / 2)) * 0.94;
	return Vector2(x, y);

##
func spawnPieces():
	var pos = Vector2(1152/2, 648/2);
	var offset = 32;
	
	for side in activePieces.keys():
		for pieceType in activePieces[side].keys():
			for piece in activePieces[side][pieceType]:
				
				var activeScene = preload("res://chess_piece.tscn").instantiate();
				activeScene.initState = [side, pieceType, $ChessPieces];
				var cord = piece if boardRotatedForWhite else (piece * -1);
				activeScene.transform.origin = pos + (offset * axial_to_pixel(cord));
				activeScene.scale.x = 0.15;
				activeScene.scale.y = 0.15;
				
				ChessPiecesNode.add_child(activeScene);
				activeScene.clickedOnChessPiece.connect(ChessPiecesNode._handleChessPieceClick);
				#print(piece);
	pass

##
func _newGame_OnButtonPress():
	
	if(activePieces):
		return;
	
	var boardState = [];
	print( "New Game Signal Received" );
	if(GameDataNode):	
		var isWhite = (selected == 0);
		boardState = GameDataNode.startDefaultGame(isWhite);
		BoardControler.checkIfFlipBoard(isWhite);
		boardRotatedForWhite = isWhite;
		
		activePieces = boardState[0];
		currentLegalsMoves = boardState[1];
		spawnPieces();
		
	else:
		push_error("ChildNodeNotFound");
	
	return;

##
func _resign_OnButtonPress():
	
	activePieces.clear();
	currentLegalsMoves.clear();
	
	for node in ChessPiecesNode.get_children():
		ChessPiecesNode.remove_child(node);
	
	pass


###
## GODOT DEFAULTS

# Called when the node enters the scene tree for the first time.
func _ready():
	selected = 0;
	pass # Replace with function body.
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


