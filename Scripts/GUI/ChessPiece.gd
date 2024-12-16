extends Node2D;
class_name HexPiece;

#### REFS
@onready var spriteNode = $ChessSprite;
@onready var collisionNode = $Area2D;
####

#### Signals
signal pieceSelected(SIDE:int, TYPE:String, CORDS:Vector2i);
signal pieceDeselected(SIDE:int, TYPE:String, CORDS:Vector2i, MOVE);
####

#### State
@onready var chessTexture : AtlasTexture = preload("res://Textures/chessPieceTwo.tres");

var locked : bool = true;
var anotherSelected : bool = false;
var isSetup : bool;
var side:int;
var pieceType:int;

# Click and drag
enum STATES 
{
	DRAGGING,
	CLICKED,
	UNSET
}
var status:STATES = STATES.UNSET;

var pieceCords:Vector2i = Vector2i();
var textureSize:Vector2 = Vector2();
var mousePos:Vector2 = Vector2();
var offset:Vector2 = Vector2();
var preDragPosition:Vector2;
var hexTile:Node = null;
####

#### CREATED
# Move to cords
func moveTo(cords:Vector2):
	transform.origin = cords;
	return;
# Update the hextile
func setHextile(newTile):
	hexTile = newTile;
	return;


func __getPieceCords():
	return pieceCords;
# Move to cords
func __setPieceCords(cords:Vector2i, pos:Vector2):
	pieceCords = cords;
	transform.origin = pos;
	return;
#
func __setSetupVars(s : int, type : int, piece : Vector2i, origin : Vector2, x : float):
	isSetup = true;
	side = s;
	pieceType = type;
	pieceCords = piece;
	transform.origin = origin;
	scale = Vector2(x,x);
	return;

# Given 'initdata' get appropiate texture
func setupSelf() -> void:
	var x = 320;
	var y = 0 if (side != 0) else 320;
	
	match pieceType:
		6: x *= 0;
		5: x *= 1;
		4: x *= 2;
		2: x *= 3;
		3: x *= 4;
		1: x *= 5;
	
	var initialRegion:Rect2 = Rect2(x,y,320,320);
	var newChessTexture: AtlasTexture = AtlasTexture.new();
	
	newChessTexture.atlas = chessTexture.atlas;
	newChessTexture.region = initialRegion;
	
	spriteNode.texture = newChessTexture;
	
	return;

# Called When Scene is initilized with 'initdata'
func onReady() -> void:
	setupSelf();
	textureSize = spriteNode.get_texture().get_size() * scale;
	return;
####



#### GODOT Functions
# Called when the node enters the scene tree for the first time.
func _ready() ->void:
	if(isSetup):
		onReady();
		return;
	queue_free();
	return;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	if (status == STATES.DRAGGING):
		global_position = mousePos + offset;
	return;

#
func pressedAndNotDragging(eventPos):
	var eventPosition =  eventPos;
	var currentPiecePosition = global_position;
	var pieceHitbox = Rect2(currentPiecePosition.x - textureSize.x / 2, currentPiecePosition.y - textureSize.y / 2,
	 textureSize.x,textureSize.y);
	
	if pieceHitbox.has_point(eventPosition):
		status = STATES.CLICKED;
		pieceSelected.emit(side, pieceType, pieceCords);
		collisionNode.monitoring = true;
		offset = currentPiecePosition - eventPosition;
		preDragPosition = global_position;
	return;
#
func notPressedAndDragging():
	#print(hexTile);
	if(hexTile):
		#print("\nSuccess\n")
		
		moveTo(hexTile.transform.origin);
		pieceCords = hexTile.hexMove;
		
		pieceDeselected.emit(hexTile.hexCords, hexTile.hexKey, hexTile.hexIndex);
		
	else:
		#print("\nCanceled\n")
		moveTo(preDragPosition);
		pieceDeselected.emit(Vector2i(), 0, -1);
		
	status = STATES.UNSET;
	preDragPosition = Vector2();
	return;
# Called when an input event is detected.
func _input(event) -> void:
	if(locked or anotherSelected):
		return;
		
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		if (status != STATES.DRAGGING) and (event.is_pressed()):
			pressedAndNotDragging(event.global_position);
		elif (status == STATES.DRAGGING) and (not event.is_pressed()):
			notPressedAndDragging();
		
	if (status == STATES.CLICKED) and (event is InputEventMouseMotion):
		status = STATES.DRAGGING;
		
	if (event is InputEventMouseMotion):
		mousePos = event.global_position;
	return;


# Called when the Layer 1 collision hextile area leaves
func _on_area_2d_area_exited(area:Area2D):
	if(area.get_parent() == hexTile):
		hexTile.__unHighlight();
		setHextile(null);
	return;
# Called when Layer 1 collides with hextile area
func _on_area_2d_area_entered(area:Area2D):
	if(anotherSelected):
		return;
	if(hexTile):
		hexTile.__unHighlight();
	setHextile(area.get_parent());
	hexTile.__highlight();
	return;

# Called when a move is submitted and active pieces need to be swapped.
func _on_Control_GameSwitchedSides(newSide):
	locked = (newSide != side);
	if (locked):
		set_process(false);
	else:
		set_process(true);
	return;

#
func _on_Control_LockPiece():
	anotherSelected = (status != STATES.CLICKED);
	return;
#
func _on_Control_UnlockPiece():
	anotherSelected = false;
	return;
####
