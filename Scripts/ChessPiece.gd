extends Node2D

@onready var spriteNode = $ChessSprite;

#### Signals

signal pieceSelected(data:Array);
signal pieceDeselected(data:Array);

####

#### State

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

####



#### CREATED

func setupSelf() -> void:
	var x;
	var y = 0;
	if(initState[0] == 'black'):
		y += 320;
		pass
	
	match initState[1]:
		"K":
			x =  0;
			pass;
		"Q":
			x = 320;
			pass;
		"B":
			x = 320 * 2;
			pass;
		"N":
			x = 320 * 3;
			pass;
		"R":
			x = 320 * 4;
			pass;
		"P":
			x = 320 * 5;
			pass;
	
	var initialRegion:Rect2 = Rect2(x,y,320,320);
	var newChessTexture: AtlasTexture = AtlasTexture.new();
	newChessTexture.atlas = chessTexture.atlas;
	newChessTexture.region = initialRegion;
	spriteNode.texture = newChessTexture;
	return;

####

#### GODOT Functions

# Called when an input event is detected.
func _input(event) -> void:
	
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		
		if (status != STATES.DRAGGING) and (event.is_pressed()):
			var eventPosition =  event.global_position;
			var currentPiecePosition = global_position;
			var pieceHitbox = Rect2(currentPiecePosition.x - textureSize.x / 2,
			 currentPiecePosition.y - textureSize.y / 2,
			 textureSize.x,
			 textureSize.y);
			
			if pieceHitbox.has_point(eventPosition):
				var pieceCords = initState[2];
				emit_signal("pieceSelected", initState);
				
				status = STATES.CLICKED;
				offset = currentPiecePosition - eventPosition;
				
		elif status == STATES.DRAGGING and not event.is_pressed():
			emit_signal("pieceDeselected", initState);
			status = STATES.UNSET;
			
	if status == STATES.CLICKED and event is InputEventMouseMotion:
		status = STATES.DRAGGING;
	
	mousePos = event.global_position;
	return;


# Called when the node enters the scene tree for the first time.
func _ready() ->void:
	if(initState):
		setupSelf();
		textureSize = spriteNode.get_texture().get_size() * scale;
		return;
	else:
		push_error("Piece Was Given No State");
	return;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	if status == STATES.DRAGGING:
		global_position = mousePos + offset
	return;

####
