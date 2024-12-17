extends Control
class_name PromotionDialog
###
###
### STATE

@onready var CHOICE : GDHexConst.PIECES = GDHexConst.PIECES.QUEEN;

var cords:Vector2i;
var key:int;
var index:int;
var isSetup:bool = false;
var swap : bool = false;

###
###
### References
@onready var kButton = $BackGround/Control/NewKnight;
@onready var rButton = $BackGround/Control/NewRook;
@onready var bButton = $BackGround/Control/NewBishop;
@onready var qButton =$BackGround/Control/NewQueen;

###
###
### Signals
signal promotionAccepted(cords : Vector2i, key : GDHexConst.MOVE_TYPES, index : int, CHOICE : GDHexConst.PIECES);

func swapWAtlas():
	kButton.icon.region.position.y = 0;
	rButton.icon.region.position.y = 0;
	bButton.icon.region.position.y = 0;
	qButton.icon.region.position.y = 0;
	return;

func swapBAtlas():
	kButton.icon.region.position.y = 320;
	rButton.icon.region.position.y = 320;
	bButton.icon.region.position.y = 320;
	qButton.icon.region.position.y = 320;
	return;

func setupInitVars(pos:Vector2i, type:int, i:int, iswhite:bool):
	cords = pos;
	key = type;
	index = i;
	isSetup = true;
	swap = not iswhite;
	return;

func onReady():
	z_index = 1;
	if(swap): swapBAtlas();
	else: swapWAtlas();
	return;

func _ready():
	if(isSetup):
		onReady();
		return;
	queue_free();
	return;
###
###
### Signal Reactions

##
func _on_accept_button_pressed():
	promotionAccepted.emit(cords, key, index, CHOICE);
	queue_free();
	return;

func _on_new_rook_toggled(_toggled_on: bool) -> void:
	CHOICE = GDHexConst.PIECES.ROOK;
	return;


func _on_new_bishop_toggled(_toggled_on: bool) -> void:
	CHOICE = GDHexConst.PIECES.BISHOP;
	return;


func _on_new_knight_toggled(_toggled_on: bool) -> void:
	CHOICE = GDHexConst.PIECES.KNIGHT;
	return;


func _on_new_queen_toggled(_toggled_on: bool) -> void:
	CHOICE = GDHexConst.PIECES.QUEEN;
	return;
