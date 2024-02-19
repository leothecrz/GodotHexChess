extends Node2D
### REFS
@onready var SpriteNode = $Sprite2D;
###
###
### STATE

var isSetup:bool;
var hexCords:Vector2i;
var hexKey:String;
var hexIndex:int;
var hexMove:Vector2i;

var defColor:Color;
###
###
### USER CREATED

##
func unHighlight() -> void:
	SpriteNode.set_modulate(defColor);
	return;

##
func highlight() -> void:
	if(!defColor):
		defColor = SpriteNode.modulate;
	SpriteNode.set_modulate(Color(1,1,1,1));
	return;
##
func __ready() -> void:
	return;
###
###
### GODOT Fucntions
func _ready():
	
	if(isSetup):
		__ready();
	else:
		queue_free();
	return;
####
