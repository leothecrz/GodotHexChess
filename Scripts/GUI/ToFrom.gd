extends Node

@onready var FROM = $From;
@onready var TO = $To;

func setVis(vis:bool) -> void:
	FROM.visible = vis;
	TO.visible = vis;
	return;

func moveFrom(x : int, y : int):
	FROM.position = Vector2i(x,y);
	pass;
	
func moveTo(x : int, y : int):
	TO.position = Vector2i(x,y);
	pass;
