extends Node2D

#### REFS
@onready var spriteNode = $ChessSprite;
@onready var collisionNode = $Area2D;
####

#### Signals
signal pieceSelected(data:Array);
signal pieceDeselected(data:Array);
####

#### State
var locked = true;
var anotherSelected = false;
var chessTexture:AtlasTexture = preload("res://Textures/chessPiece.tres");
var initState:Array;
	# Click and drag
enum STATES 
{
	DRAGGING,
	CLICKED,
	UNSET
}
var status:STATES = STATES.UNSET;
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

# Given 'initdata' get appropiate texture
func setupSelf() -> void:
	var x;
	var y = 0;
	if(initState[0] == 0):
		y += 320;
	
	match initState[1]:
		"K":
			x =  0;
		"Q":
			x = 320;
		"B":
			x = 320 * 2;
		"N":
			x = 320 * 3;
		"R":
			x = 320 * 4;
		"P":
			x = 320 * 5;
	
	var initialRegion:Rect2 = Rect2(x,y,320,320);
	var newChessTexture: AtlasTexture = AtlasTexture.new();
	
	newChessTexture.atlas = chessTexture.atlas;
	newChessTexture.region = initialRegion;
	
	spriteNode.texture = newChessTexture;
	
	return;

# Called When Scene is initilized with 'initdata'
func __ready() -> void:
	setupSelf();
	textureSize = spriteNode.get_texture().get_size() * scale;
	return;
####

#### GODOT Functions
# Called when the node enters the scene tree for the first time.
func _ready() ->void:
	if(initState):
		__ready();
	else:
		queue_free();
	return;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	if status == STATES.DRAGGING:
		global_position = mousePos + offset;
	return;

# Called when an input event is detected.
func _input(event) -> void:
	
	if(locked):
		return;
		
	if(anotherSelected):
		return;
		
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		
		if (status != STATES.DRAGGING) and (event.is_pressed()):
			var eventPosition =  event.global_position;
			var currentPiecePosition = global_position;
			var pieceHitbox = Rect2(currentPiecePosition.x - textureSize.x / 2,
			 currentPiecePosition.y - textureSize.y / 2,
			 textureSize.x,
			 textureSize.y);
			
			if pieceHitbox.has_point(eventPosition):
				status = STATES.CLICKED;
				emit_signal("pieceSelected", initState);
				collisionNode.monitoring = true;
				offset = currentPiecePosition - eventPosition;
				preDragPosition = global_position;
				
		elif status == STATES.DRAGGING and not event.is_pressed():
			print(hexTile);
			if(hexTile):
				print("\nSuccess\n")
				moveTo(hexTile.transform.origin);
				initState[2] = hexTile.heldMove[4];
				emit_signal("pieceDeselected", initState, hexTile.heldMove);
				
			else:
				print("\nCanceled\n")
				moveTo(preDragPosition);
				emit_signal("pieceDeselected", initState, []);
				
			status = STATES.UNSET;
			preDragPosition = Vector2();
			
	if status == STATES.CLICKED and event is InputEventMouseMotion:
		status = STATES.DRAGGING;
	
	mousePos = event.global_position;
	return;

# Called when the Layer 1 collision hextile area leaves
func _on_area_2d_area_exited(area:Area2D):
	if(area.get_parent() == hexTile):
		hexTile.unHighlight();
		setHextile(null);
	return;

# Called when Layer 1 collides with hextile area
func _on_area_2d_area_entered(area:Area2D):
	
	setHextile(area.get_parent());
	hexTile.highlight();
	return;

# Called when a move is submitted and active pieces need to be swapped.
func _on_Control_GameSwitchedSides(newSide):
	var mySide = initState[0];
	locked = false if (newSide == mySide) else true;
	
	if locked:
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
