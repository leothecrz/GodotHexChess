extends ColorRect


const FRAME_TIME : float = 1.0;


@onready var text : RichTextLabel = $searchText;
@onready var OKbutton : Button = $OKSearch;
@onready var CancelButton : Button  = $CancelSearch;


var state : int = 0;
var elapsedTime : float = 0.0;


##Frames 
func setFrameOne():
	text.text = "\n\t\t\tConnecting";
	return;
func setFrameTwo():
	text.text = "\n\t\t\tConnecting.";
	return;
func setFrameThree():
	text.text = "\n\t\t\tConnecting..";
	return;
func setFrameFour():
	text.text = "\n\t\t\tConnecting...";
	return;
func nextFrame():
	match(state):
		0:setFrameOne();
		1:setFrameTwo();
		2:setFrameThree();
		3:setFrameFour();
	state +=1;
	if(state > 3):
		state = 0;
	return;
##ButtonsShow
func showOK():
	OKbutton.visible = true;
	CancelButton.visible = false;
	return;
func showCancel():
	OKbutton.visible = false;
	CancelButton.visible = true;
	return;
##External
func _failed():
	set_process(false);
	showOK();
	text.text = "\n[center]Connection Failed[/center]";
	return;
func _activate():
	showCancel()
	visible = true;
	set_process(true);
	return;
func _deactivate():
	visible = false;
	set_process(false);
	return;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false);
	return;
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	elapsedTime += delta;
	if(elapsedTime > FRAME_TIME):
		elapsedTime = 0;
		nextFrame();
	return;
