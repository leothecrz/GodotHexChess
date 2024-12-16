extends AudioStreamPlayer

@export var placeStream : AudioStream;
@export var pickUpStream : AudioStream;

##PUBLIC
func __playPlaceSFX():
	if(stream != placeStream):
		stream = placeStream;
	play()
	return;

func __playPickUp():
	if(stream != pickUpStream):
		stream = pickUpStream;
	play()
	return;
##INTERNAL
##GODOT
func _ready() -> void:
	return;
