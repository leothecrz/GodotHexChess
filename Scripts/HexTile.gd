extends Node2D
### REFS
@onready var SpriteNode:Sprite2D = $Sprite2D;

###
###
### STATE
var isSetup:bool;
var hexIndex:int;
var hexCords:Vector2i;
var hexMove:Vector2i;
var defColor:Color;
var hexKey:int = -1;
###
###
### USER CREATED

## Indicate the hextile is being hovered over.
func highlight() -> void:
	if(!defColor):
		defColor = SpriteNode.modulate;
	SpriteNode.set_modulate(Color(1,1,1,1));
	return;

## Reset highlight
func unHighlight() -> void:
	SpriteNode.set_modulate(defColor);
	return;

## if setup info is given -> Setup HexTile
func __ready() -> void:
	return;

###
###
### GODOT Fucntions
func _ready():
	if(isSetup): __ready();
	else: queue_free();
	return;
