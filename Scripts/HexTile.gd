extends Node2D
#### REFS
@onready var SpriteNode = $Sprite2D;
####

#### STATE
var initializationInformation:Array;
var defColor:Color;
####

#### USER CREATED

func unHighlight() -> void:
	SpriteNode.set_modulate(defColor);
	return;

func highlight() -> void:
	if(!defColor):
		defColor = SpriteNode.modulate;
	SpriteNode.set_modulate(CONSTANTS.HexHighlightColor);
	return;

func __ready() -> void:
	
	return;
####

#### GODOT Fucntions
# Called when the node enters the scene tree for the first time.
func _ready():
	
	if(initializationInformation):
		__ready();
	else:
		queue_free();
	return;
####
