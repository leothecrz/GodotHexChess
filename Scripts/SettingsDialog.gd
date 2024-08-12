extends Control

@onready var BGRect:ColorRect = $ColorRect;

func _input(event:InputEvent):
	if (not visible):
		return;
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		if(not BGRect.get_rect().has_point(event.global_position)):
			_on_close_button_pressed();
	return;

func _on_close_button_pressed():
	visible = false;
	pass # Replace with function body.
