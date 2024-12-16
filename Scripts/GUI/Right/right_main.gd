extends Control;


@onready var MultiplayerSignal : ColorRect = $BG/Buttons/Mult/Border/MultOn;
@onready var sideSelect = $BG/Options/SideSelect;
@onready var enemySelect = $BG/Options/EnemySelect;
@onready var resignButton = $BG/Buttons/ResignButton;


#PUBLIC
## Resign Button
func __setResignOn():
	resignButton.text = "Resign";
	return;
func __setResignOff():
	resignButton.text = "Clean Up";
	return;
## SETS
func __setSide(type : int):
	sideSelect.__setSelected(type);
	return;
func __setEnemy(enemy : int):
	enemySelect.__setSelected(enemy);
	return;
## GETS
func __getSelectedSide() -> int:
	return sideSelect.selected;
func __getSelectedEnemy() -> int:
	return enemySelect.selected;
## Mult signal
func __multSignalOn() -> void:
	MultiplayerSignal.color = Color.GREEN;
	return;
func __multSignalOff() -> void:
	MultiplayerSignal.color = Color.BLACK;
	return;


#GODOT
func _ready() -> void:
	return;