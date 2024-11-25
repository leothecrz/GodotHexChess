extends Control

@onready var BGRect:ColorRect = $MainBG;

@onready var SettingRect:ColorRect = $MainBG/Settings
@onready var CreditsRect:ColorRect = $MainBG/Credits

@onready var MSlider = $MainBG/Settings/MasterVolume;
@onready var SoSlider = $MainBG/Settings/SoundSlider;
@onready var MuSlider = $MainBG/Settings/Music;

@export var debounce_timer: Timer

var can_execute : bool = true
var choice : int = 0;

signal settingsUpdated(settingIndex:int, Choice:int);

##
func _on_debounce_timer_timeout():
	can_execute = true
	return;

##
func _exit_tree():
	debounce_timer.queue_free();
	return;

## SETUP MENU OPTIONS
func _ready():
	#TODO :: FIX
	debounce_timer = Timer.new();
	debounce_timer.timeout.connect(_on_debounce_timer_timeout)
	debounce_timer.one_shot = true;
	debounce_timer.wait_time = 0.1
	add_child(debounce_timer);
	return;

##
func _input(event:InputEvent):
	if (not visible):
		return;
	if (event is InputEventMouseButton) and (event.button_index == MOUSE_BUTTON_LEFT):
		if(not BGRect.get_rect().has_point(event.global_position)):
			_on_close_button_pressed();
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
func _on_master_volume_value_changed(value):
	if can_execute:
		settingsUpdated.emit(4, linear_to_db(value/100.0));
		can_execute = false;
		debounce_timer.start();
	return;

##
func _on_music_value_changed(value):
	if can_execute:
		var test = linear_to_db(value/100.0);
		settingsUpdated.emit(5, test);
		can_execute = false;
		debounce_timer.start();
	return

##
func _on_sound_slider_value_changed(value):
	if can_execute:
		settingsUpdated.emit(6, linear_to_db(value/100.0));
		can_execute = false;
		debounce_timer.start();
	return;

##
func _on_close_button_pressed():
	settingsUpdated.emit(7, 0);
	visible = false;
	return;


func _on_tab_bar_tab_changed(tab: int) -> void:
	match (tab):
		0:
			CreditsRect.visible = false;
			SettingRect.visible = true;
		1:
			CreditsRect.visible = true;
			SettingRect.visible = false;
	return;
