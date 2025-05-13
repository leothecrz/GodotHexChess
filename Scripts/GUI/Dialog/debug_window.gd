extends Control



@onready var Output : RichTextLabel = $BG/OutputText;
@onready var FromTextEdit : TextEdit = $BG/Control/FROM;
@onready var DepthTextEdit : TextEdit = $BG/Control/DEPTH;
@onready var SubmitButton : Button = $BG/Control/Submit;



var FromFen : String = "";
var CheckDepth : int = 0;
var isCloseAble : bool = true;


signal closedPressed();
signal submitFenMoveCount(Depth:int, DefaultFEN:bool, FEN:String);



func __setOutputText(outputString:String):
	Output.text = "[center]" + outputString + "[/center]"
	return;



func _on_closed_pressed() -> void:
	if(not isCloseAble):
		return;
	closedPressed.emit();
	visible = false;
	return;


func _on_FromFen_text_changed():
	FromFen = FromTextEdit.text;
	return;


func _on_depthCheck_text_changed():
	if( DepthTextEdit.text.is_valid_int() and int(DepthTextEdit.text) > 0 ):
		CheckDepth = int(DepthTextEdit.text);
		SubmitButton.disabled = false;
		return;
	SubmitButton.disabled = true;
	return;


func _on_MoveCountDepthButton_pressed():
	__setOutputText("Awaiting Results...");
	submitFenMoveCount.emit(CheckDepth, FromFen.is_empty(), FromFen);
	return;



func _ready() -> void:
	__setOutputText("Select A TEST");
	return;
