extends Control
###
###
### Vars
@onready var tileMap:TileMapLayer = $HexBoard;
@onready var turnSignal:Sprite2D = $TurnSig;
##

###
###
### State
var boardRotatedToWhite;
###
###
### USER CREATED
## Flip the board if POV player does not match selected player.
func checkAndFlipBoard(isPOVWhite:bool):
	if(isPOVWhite != boardRotatedToWhite):
		boardRotatedToWhite = !boardRotatedToWhite;
		rotate_tilemap();
	return;

## Flip The Board (Not Pixel Perfect, Origin Of TileMap Need Fixing)
func rotate_tilemap():
	tileMap.scale.y *= -1;
	return;

func setSignalWhite():
	turnSignal.modulate = Color(1, 1, 0.514);
	return;
	
func setSignalBlack():
	turnSignal.modulate = Color(0.125, 0.18, 0.663);
	return;

###
###
### GODOT Functions
func _ready():
	boardRotatedToWhite = true;
	setSignalWhite();
	tileMap.scale.y = -1;
	
	#tileMap.position.x = -30;
	#tileMap.position.y = 0;
	
	return;
