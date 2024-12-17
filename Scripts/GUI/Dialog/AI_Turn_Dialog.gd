extends Control

@onready var SpriteController = $SpriteHolder;

@export var SPIN_SPEED = 200;

# Called when the node enters the scene tree for the first time.
func _ready():
	SpriteController.rotation_degrees = 0;
	z_index = 1;
	return;


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var nextDegree:float = SpriteController.rotation_degrees;
	nextDegree += (SPIN_SPEED * delta);
	if (nextDegree >= 360):
		nextDegree = 0;
	SpriteController.rotation_degrees = nextDegree;
	return;
