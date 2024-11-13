extends Control


@onready var whiteCapture = $ColorRect/WCapture;
@onready var blackCapture = $ColorRect/BCapture;

func _resetCaptures():
	whiteCapture.text = "W Captures:\n";
	blackCapture.text = "B Captures:\n";
	return;

func _pushCapture(side:int, captured:int):
	var toUpdate = whiteCapture if (side == 0) else blackCapture;
	var text = toUpdate.text;
	match(captured):
		1:text += "P, ";
		2:text += "N, ";
		3:text += "R, ";
		4:text += "B, ";
		5:text += "Q, ";
	toUpdate.text = text;
	return;

func _undoCapture(side:int):
	if(side == 0):
		whiteCapture.text = whiteCapture.text.left(-3);
		return;
	blackCapture.text = blackCapture.text.left(-3);
	return;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
