extends Control;

### State
@onready var inCheckLabel = $BG/InCheck/TurnSig;
@onready var HistoryNode = $BG/MoveHistory;
@onready var CaptureNode = $BG/Captures;

#Public
##
func __updateHist(stir:Array):
	HistoryNode.setText(stir);
##
func __swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

##
func __getLabelState() -> bool:
	return inCheckLabel.visible;
##
func __undoCapture(side:int):
	CaptureNode.__undoCapture(side);
	return;
##
func __pushCapture(side:int, captured:int):
	CaptureNode.__pushCapture(side,captured);
	return;
##
func __resetCaptures():
	CaptureNode.__resetCaptures();
	return;
