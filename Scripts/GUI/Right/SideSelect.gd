extends OptionButton;
##PUBLIC
func __setSelected(index: int):
	selected = index;
	return;
	
##GODOT
func _ready() -> void:
	get_popup().transparent = true;
	return;

