extends Control
###
###
### STATE

enum RETURNS {ZERO, ONE, KNIGHT, ROOK, BISHOP, QUEEN}
@onready var CHOICE:RETURNS = RETURNS.QUEEN;

var cords:Vector2i;
var key:int;
var index:int;

###
###
### References
@onready var kButton = $BackGround/Control/KnightButton;
@onready var rButton = $BackGround/Control/RookButton;
@onready var bButton = $BackGround/Control/BishopButton;
@onready var qButton = $BackGround/Control/QueenButton;

###
###
### Signals
signal promotionAccepted(cords, key, index, CHOICE);

###
###
### Signal Reactions

##
func _on_accept_button_pressed():
	emit_signal("promotionAccepted", cords, key, index, CHOICE);
	return;

##
func _on_knight_button_pressed():
	if(CHOICE == RETURNS.KNIGHT):
		kButton.button_pressed = true;
	CHOICE = RETURNS.KNIGHT;
	return;

##
func _on_rook_button_pressed():
	if(CHOICE == RETURNS.ROOK):
		rButton.button_pressed = true;
	CHOICE = RETURNS.ROOK;
	return;

##
func _on_bishop_button_pressed():
	if(CHOICE == RETURNS.BISHOP):
		bButton.button_pressed = true;
	CHOICE = RETURNS.BISHOP;
	return;

##
func _on_queen_button_pressed():
	
	if(CHOICE == RETURNS.QUEEN):
		qButton.button_pressed = true;
	CHOICE = RETURNS.QUEEN;
	return;
