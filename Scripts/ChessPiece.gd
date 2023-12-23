extends Node2D

@onready var spriteNode = $ChessSprite;

### Signals
signal clickedOnChessPiece(cords);
###

### State
var chessTexture : AtlasTexture = preload("res://Textures/chessPiece.tres");
var initState:Array;

# Click and drag
var offset = 0;
var status = "";
var textureSize = Vector2();
var mousePos = Vector2();
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

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if (status != "dragging") and event.is_pressed():
			var evenPos =  event.global_position;
			var myPos = global_position;
			
			var rect = Rect2(myPos.x - textureSize.x / 2,
			 myPos.y - textureSize.y / 2,
			 textureSize.x,
			 textureSize.y);
			
			if rect.has_point(evenPos):
				print(rect);
				emit_signal("clickedOnChessPiece", self);
				status = "clicked";
				offset = myPos - evenPos;
				
		elif status == "dragging" and not event.is_pressed():
			status = "released"
			
	if status == "clicked" and event is InputEventMouseMotion:
		status = "dragging"
	
	mousePos = event.global_position;
	pass
	

# Called when the node enters the scene tree for the first time.
func _ready():
	
	if(initState):
		setupSelf();
		textureSize = spriteNode.get_texture().get_size() * scale;
		return;
	else:
		push_error("Piece Was Given No State");
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	
	if status == "dragging":
		global_position = mousePos + offset
	
	
	pass
