extends Control

@onready var inCheckLabel:RichTextLabel = $ColumnBack/InCheck/CheckLabel;

func swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

func getLabelState() -> bool:
	return inCheckLabel.visible;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
