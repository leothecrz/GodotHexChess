extends Control

## Vars
@onready var tileMap:TileMap = $BoardTiles;
##

##State
var boardRotatedToWhite;
##

##
func checkIfFlipBoard(isWhite:bool):
	if(isWhite && !boardRotatedToWhite):
		boardRotatedToWhite = !boardRotatedToWhite;
		rotate_tilemap();
		return;
	if(!isWhite && boardRotatedToWhite):
		boardRotatedToWhite = !boardRotatedToWhite;
		rotate_tilemap();
		return;
	pass

## Flip The Board (Not Pixel Perfect, Origin Of TileMap Need Fixing)
func rotate_tilemap():
	tileMap.scale.y *= -1;
	pass

##GODOT Functions
# Called when the node enters the scene tree for the first time.
func _ready():
	boardRotatedToWhite = true;
	tileMap.scale.y = -1;
	#tileMap.position.x = -30;
	tileMap.position.y = 0;
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
