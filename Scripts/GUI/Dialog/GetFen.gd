extends ColorRect

signal OKButtonPressed(str:String, strict:bool, selfref:Node);

var checkStatus = false;

func _on_ok_pressed() -> void:
	var lbl:TextEdit = $ColorRect/TextEnter;
	OKButtonPressed.emit(lbl.text, checkStatus, self);
	return;


func _on_cancel_pressed() -> void:
	queue_free();
	return


func _on_verify_check_box_toggled(toggled_on: bool) -> void:
	checkStatus = toggled_on;
	return;
