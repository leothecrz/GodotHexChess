extends Node2D
#### REFS
@onready var SpriteNode = $Sprite2D;
####

#### STATE
var initializationInformation:Array;
####

#### USER CREATED
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
