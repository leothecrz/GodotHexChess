extends Node;
class_name MinMaxAI;

var side:int;
var rng:RandomNumberGenerator;

var TO:Vector2i;
var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

var engineRef;
##
func _init(playswhite:bool):
	side = 1 if playswhite else 0;
	return

### GETTER

##
func _getCords():
	return CORDS;

##
func _getMoveType():
	return MOVETYPE

##
func _getMoveIndex():
	return MOVEINDEX;

##
func _getPromoteTo():
	return PROMOTETO;

##
func _getTo():
	return TO;


func Hueristic(hexEngine:HexEngine):
	return

###

func minimax(depth:int, isMaxPlayer:bool, hexEngine:HexEngine) -> int:
	if(depth == 0 or hexEngine._getGameOverStatus()):
			return Hueristic(hexEngine);
	
	if(isMaxPlayer):
		var value = -INF;
		## for each move:
		#value = max(value, minimax(depth-1, false, move, hexEngine));
		return value;
	var value = INF;
	## for each move:
	#value = min(value, minimax(depth-1, false, move, hexEngine));
	return value;


##
func _makeChoice(hexEngine:HexEngine):
	engineRef = hexEngine;
	
	#minimax()
	return
