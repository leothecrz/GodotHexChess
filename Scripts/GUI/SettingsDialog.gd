extends Control

@onready var BGRect:ColorRect = $ColorRect;

@onready var MSlider = $ColorRect/MasterVolume;
@onready var SoSlider = $ColorRect/SoundSlider;
@onready var MuSlider = $ColorRect/Music;

@export var debounce_timer: Timer

var can_execute = true

func _on_debounce_timer_timeout():
	can_execute = true
	return;

func _exit_tree():
	debounce_timer.queue_free();
	return;

func _ready():
	debounce_timer = Timer.new();
	add_child(debounce_timer);
	debounce_timer.timeout.connect(_on_debounce_timer_timeout)
	debounce_timer.one_shot = true;
	debounce_timer.wait_time = 0.1
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
func _on_credits_button_pressed():
	pass # Replace with function body.



##
func _on_master_volume_value_changed(value):
	if can_execute:
		settingsUpdated.emit(4, linear_to_db(value/100.0));
		can_execute = false;
		debounce_timer.start();

##
func _on_music_value_changed(value):
	if can_execute:
		var test = linear_to_db(value/100.0);
		settingsUpdated.emit(5, test);
		can_execute = false;
		debounce_timer.start();

##
func _on_sound_slider_value_changed(value):
	if can_execute:
		settingsUpdated.emit(6, linear_to_db(value/100.0));
		can_execute = false;
		debounce_timer.start();

##
func _on_close_button_pressed():
	settingsUpdated.emit(7, 0);
	visible = false;
	return;
