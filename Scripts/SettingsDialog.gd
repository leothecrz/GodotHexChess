extends Control

@onready var BGRect:ColorRect = $ColorRect;

func _input(event:InputEvent):
	if (not visible):
		return;
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		if(not BGRect.get_rect().has_point(event.global_position)):
			_on_close_button_pressed();
	return;

##
func _on_close_button_pressed():
	visible = false;
	pass # Replace with function body.

##
func _on_resolution_options_item_selected(index):
	pass # Replace with function body.

##
func _on_color_scheme_options_item_selected(index):
	pass # Replace with function body.

##
func _on_toggle_music_toggled(toggled_on):
	pass # Replace with function body.

##
func _on_toggle_sound_toggled(toggled_on):
	pass # Replace with function body.

##
func _on_master_volume_drag_ended(value_changed):
	pass # Replace with function body.

##
func _on_sound_slider_drag_ended(value_changed):
	pass # Replace with function body.

##
func _on_music_drag_ended(value_changed):
	pass # Replace with function body.
