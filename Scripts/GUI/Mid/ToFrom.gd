extends Node;

@onready var FROM = $From;
@onready var TO = $To;

#PUBLIC
func __setVis(vis:bool) -> void:
	FROM.visible = vis;
	TO.visible = vis;
	return;

func __moveFrom(x : int, y : int):
	FROM.set_position(Vector2i(x,y));
	pass;
	
func __moveTo(x : int, y : int):
	TO.set_position(Vector2i(x,y));
	pass;
