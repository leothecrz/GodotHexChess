extends Control

@onready var MultiplayerSignal : ColorRect = $BG/Buttons/Mult/Border/MultOn;

func _multSignalOn():
	MultiplayerSignal.color = Color.GREEN;
	return;

func _multSignalOff():
	MultiplayerSignal.color = Color.BLACK;
	return;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
