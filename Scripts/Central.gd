extends Control
###
###
### Vars
@onready var tileMap:TileMap = $BoardTiles;
##

###
###
### State
var boardRotatedToWhite;

###
###
### USER CREATED
## Flip the board if POV player does not match selected player.
func checkIfFlipBoard(isPOVWhite:bool):
	if(isPOVWhite != boardRotatedToWhite):
		boardRotatedToWhite = !boardRotatedToWhite;
		rotate_tilemap();
	return;

## Flip The Board (Not Pixel Perfect, Origin Of TileMap Need Fixing)
func rotate_tilemap():
	tileMap.scale.y *= -1;
	return;

###
###
### GODOT Functions
func _ready():
	boardRotatedToWhite = true;
	tileMap.scale.y = -1;
	
	#tileMap.position.x = -30;
	#tileMap.position.y = 0;
	
	return;

func _process(delta):
	return;
