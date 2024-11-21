extends AudioStreamPlayer

var placeStream : AudioStream;
var pickUpStream : AudioStream;

func _playPlace():
	if(stream != placeStream):
		stream = placeStream;
	play()
	return;

func _playPickUp():
	if(stream != pickUpStream):
		stream = pickUpStream;
	play()
	return;

func _ready() -> void:
	placeStream = load("res://SFX/piece-placemen_rmx2.mp3");
	
	return;
