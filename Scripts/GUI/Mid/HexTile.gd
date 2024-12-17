extends Node2D;
class_name HexTile

### REFS
@onready var SpriteNode:Sprite2D = $Sprite2D2;
### STATE
var isSetup:bool;
var hexIndex:int;
var hexKey:GDHexConst.MOVE_TYPES;
var hexCords:Vector2i;
var hexMove:Vector2i;
var defColor:Color;
### USER CREATED

#Public
##
func __setSetupVars(cords : Vector2i, key : GDHexConst.MOVE_TYPES, i : int, move : Vector2i, origin : Vector2, x : float):
	isSetup = true;
	transform.origin = origin;
	hexCords = cords;
	hexKey = key;
	hexIndex = i;
	hexMove = move;
	scale = Vector2(x,x);
	return;
## Indicate the hextile is being hovered over.
func __highlight() -> void:
	if(!defColor):
		defColor = SpriteNode.modulate;
	SpriteNode.set_modulate(Color("#B30089"));
	return;
## Reset highlight
func __unHighlight() -> void:
	SpriteNode.set_modulate(defColor);
	return;

# GODOT
## if setup info is given -> Setup HexTile
func onReady() -> void:
	rotation_degrees = 90;
	z_index = 1;
	return;

### GODOT Fucntions
func _ready():
	if(isSetup): 
		onReady();
		return; 
	queue_free();
	return;
