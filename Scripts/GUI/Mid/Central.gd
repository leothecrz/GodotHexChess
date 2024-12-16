extends Control;


### Vars
@onready var tileMap:TileMapLayer = $HexBoard;
@onready var turnSignal:Sprite2D = $TurnSig;
### State
var boardRotatedToWhite;


#PUBLIC
## Flip the board if POV player does not match selected player.
func __checkAndFlipBoard(isPOVWhite:bool):
	if(isPOVWhite != boardRotatedToWhite):
		boardRotatedToWhite = !boardRotatedToWhite;
		rotate_tilemap();
		$LetterLabels.__flip();
		$NumberLabels.__flip();
	return;

#INTERNAL
## Flip The Board (Not Pixel Perfect, Origin Of TileMap Need Fixing)
func rotate_tilemap():
	tileMap.scale.y *= -1;
	return;

func setSignalWhite():
	turnSignal.modulate = Color(1, 1, 1);
	return;
	
func setSignalBlack():
	turnSignal.modulate = Color(0, 0, 0);
	return;

#GODOT
func _ready():
	boardRotatedToWhite = true;
	tileMap.scale.y = -1;
	setSignalWhite();
	return;
