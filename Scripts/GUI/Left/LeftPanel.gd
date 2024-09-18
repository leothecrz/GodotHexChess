extends Control
###
###
### State
@onready var inCheckLabel:RichTextLabel = $ColumnBack/InCheck/CheckLabel;

###
###
### User Created
##
func onResize() -> void:
	print("Left Pannel Resize")
	return;

func _swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

##
func _getLabelState() -> bool:
	return inCheckLabel.visible;

##
func setLabelText(input:String) -> void:
	inCheckLabel.text = input;
	return;

##
func _setInCheckText() -> void:
	setLabelText("\n\n\n[center][font_size=40]You Are\nIn Check[/font_size][/center]");
	return;

##
func _setStaleMateText() -> void:
	setLabelText("\n\n\n[center][font_size=40]STALEMATE[/font_size][/center]");
	return;

##
func _setCheckMateText(whiteWon:bool) -> void:
	var winnerText:String = "White" if whiteWon else "Black"
	setLabelText("\n\n\n[center][font_size=36]CHECKMATE\n%s Wins![/font_size][/center]" % winnerText);
	return;

###
###
### GODOT
func _ready():
	pass # Replace with function body.

func _process(_delta):
	pass
