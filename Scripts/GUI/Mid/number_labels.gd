extends Control;

const defVal = [
'1', '2', '3', '4', '5',
'6','7','8','9','10',
'11','11','11','11','11','11'
];
const flipedVal = [
'11', '10', '9', '8', '7',
'6','5','4','3','2',
'1','1','1','1','1','1'
];

@onready var sideWhite = true;

#PUBLIC
func __flip():
	if(sideWhite):
		setFlip();
	else:
		setDef();
	sideWhite = !sideWhite;
	return;

#INTERNAL
func setDef():
	setLabelsOf(defVal);
	pass;

func setFlip():
	setLabelsOf(flipedVal);
	pass;

func setLabelsOf(labels:Array):
	var i = 0;
	for node:Node in get_children():
		if(not node is Label):
			continue;
		node.text = labels[i];
		i +=1;
	return;

#GODOT
func _ready() -> void:
	setLabelsOf(defVal);
	pass;