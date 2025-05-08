extends Control;

### State
@onready var inCheckLabel = $BG/InCheck/TurnSig;
@onready var HistoryNode = $BG/MoveHistory;
@onready var CaptureNode = $BG/Captures;

@onready var menu:PopupMenu = $BG/MenuBar/FEN;

@onready var tesingMenu:PopupMenu = $BG/MenuBar/Test;

#Public

func __resignCleanUp():
	__resetCaptures();
	__updateHist([]);
	if(__getLabelState()):
		__swapLabelState();
	return;

##
func __updateHist(stir:Array):
	HistoryNode.setText(stir);
##
func __swapLabelState() -> void:
	inCheckLabel.visible = !inCheckLabel.visible;
	return;

func __checkFenBuild() -> void:
	if menu.is_item_checkable(2):
		menu.set_item_checked(2,not menu.is_item_checked(2));
		return;
	return;

func __checkSelfAtk() -> void:
	if tesingMenu.is_item_checkable(3):
		tesingMenu.set_item_checked(3,not tesingMenu.is_item_checked(3));
		return;
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
