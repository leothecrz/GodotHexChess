extends Control

const defVal = ['A', 'B', 'C', 'D', 'E',
 "G 2", "H 3", "I 4", "J 5", "K 6"];

const flipedVal = ["K", "J", "I", "H", "G",
"E 10", "D 9", "C 8", "B 7", "A 6"];

@onready var sideWhite = true;

func _ready() -> void:
	setLabelsOf(defVal);
	pass;

func flip():
	if(sideWhite):
		setFlip();
	else:
		setDef();
	sideWhite != sideWhite;
	return;

func setDef():
	setLabelsOf(defVal);
	return;

func setFlip():
	setLabelsOf(flipedVal);
	return;

func setLabelsOf(labels:Array):
	var i = 0;
	for node:Node in get_children():
		if(not node is Label):
			continue;
		node.text = labels[i];
		i +=1;
	return;
