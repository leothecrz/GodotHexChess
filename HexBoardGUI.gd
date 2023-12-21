extends Control

var selected = 0;

signal StartNewGame(isWhite:bool);

func _selectSide_OnItemSelect(index:int):
	selected = index;
	pass

func _newGame_OnButtonPress():
	print("buttonPressed");
	if selected == 0:
		#emit_signal("StartNewGame", true);
		StartNewGame.emit(true);
	else:
		#emit_signal("StartNewGame", false);
		StartNewGame.emit(false);
	
func _resign_OnButtonPress():
	pass

## GODOT DEFAULTS

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


