extends Control
###
###
### State
@onready var inCheckLabel = $BG/InCheck/TurnSig;
@onready var HistoryNode = $BG/MoveHistory;
###
###
### User Created
##

func _updateHist(str:Array):
	HistoryNode.setText(str);

func _swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

func _getLabelState() -> bool:
	return inCheckLabel.visible;
	
