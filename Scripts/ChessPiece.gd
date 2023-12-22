extends Node2D

@onready var spriteNode = $ChessSprite;

### State
var chessTexture : AtlasTexture = preload("res://Textures/chessPiece.tres");
var initState:Array;
###

func setupSelf() -> void:
	var x;
	var y = 0;
	if(initState[0] == 'black'):
		#print("Black ", initState[1]);
		y += 320;
		pass
	else:
		#print("White ", initState[1]);
		pass
	
	match initState[1]:
		"K":
			x = 320 * 0;
			pass;
		"Q":
			x = 320 * 1;
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
	pass


### GODOT Functions

# Called when the node enters the scene tree for the first time.
func _ready():
	
	if(initState):
		setupSelf();
		return;
	else:
		push_error("Piece Was Given No State");
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
