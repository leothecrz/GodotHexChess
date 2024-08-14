extends Control

@onready var BGRect:ColorRect = $ColorRect;


@onready var MSlider = $ColorRect/MasterVolume;
@onready var SoSlider = $ColorRect/SoundSlider;
@onready var MuSlider = $ColorRect/Music;

func _ready():
	## SETUP MENU OPTIONS
	pass;

func _input(event:InputEvent):
	if (not visible):
		return;
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		if(not BGRect.get_rect().has_point(event.global_position)):
			_on_close_button_pressed();
	return;

signal settingsUpdated(settingIndex:int, Choice:int);

##
func _on_close_button_pressed():
	visible = false;
	return;

##
func _on_resolution_options_item_selected(index):
	settingsUpdated.emit(0, index);
	return;

##
func _on_color_scheme_options_item_selected(index):
	settingsUpdated.emit(1, index);
	return;

##
func _on_toggle_music_toggled(toggled_on):
	settingsUpdated.emit(2, 1 if toggled_on else 0);
	return;
	
##
func _on_toggle_sound_toggled(toggled_on):
	settingsUpdated.emit(3, 1 if toggled_on else 0);
	return;

##
func _on_master_volume_drag_ended(value_changed):
	if(value_changed):
		settingsUpdated.emit(4, MSlider.value);
	return;

##
func _on_music_drag_ended(value_changed):
	if(value_changed):
		settingsUpdated.emit(5, MuSlider.value);
	return;
	
##
func _on_sound_slider_drag_ended(value_changed):
	if(value_changed):
		settingsUpdated.emit(6, SoSlider.value);
	return;

##
func _on_credits_button_pressed():
	pass # Replace with function body.
