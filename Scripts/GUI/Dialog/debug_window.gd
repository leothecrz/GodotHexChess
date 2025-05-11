extends Control



@onready var Output : RichTextLabel = $BG/OutputText;


var FromFen : String = "";
var CheckDepth : int = 0;



signal closedPressed();



func __setOutputText(outputString:String):
	Output.text = "[center]" + outputString + "[/center]"
	return;



func _on_closed_pressed() -> void:
	closedPressed.emit();
	visible = false;
	return;


func _on_FromFen_text_changed():
	pass # Replace with function body.


func _on_depthCheck_text_changed():
	pass # Replace with function body.


func _on_MoveCountDepthButton_pressed():
	pass # Replace with function body.



func _ready() -> void:
	__setOutputText("Select A TEST");
	return;

func _process(delta: float) -> void:
	pass
