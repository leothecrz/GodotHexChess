extends Node;
class_name MinMaxAI;


var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

func _getCords():
	return CORDS;

func _getMoveType():
	return MOVETYPE

func _getMoveIndex():
	return MOVEINDEX;

func _getPromoteTo():
	return PROMOTETO;

func _makeChoice(Engine):
	print(Engine);
	return
