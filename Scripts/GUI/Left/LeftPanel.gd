extends Control
###
###
### State
@onready var inCheckLabel = $BG/InCheck/TurnSig;
@onready var HistoryNode = $BG/MoveHistory;
@onready var CaptureNode = $BG/Captures;
###
###
### User Created
##

func _updateHist(stir:Array):
	HistoryNode.setText(stir);

func _swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

func _getLabelState() -> bool:
	return inCheckLabel.visible;

func _undoCapture(side:int):
	CaptureNode._undoCapture(side);
	return;
func _pushCapture(side:int, captured:int):
	CaptureNode._pushCapture(side,captured);
	return;
func _resetCaptures():
	CaptureNode._resetCaptures();
	return;
