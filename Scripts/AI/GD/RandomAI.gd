extends Node;
class_name RandomAI;

var side:int;
var rng:RandomNumberGenerator;

var TO:Vector2i;
var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

##
func _init(playswhite:bool):
	PROMOTETO = HexEngine.PIECES.QUEEN;
	side = 1 if playswhite else 0;
	rng = RandomNumberGenerator.new()
	rng.randomize();
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


###


##
func _makeChoice(hexEngine:HexEngine):
	var allowedMoveTypes = [];
	var moves;
	
	while(allowedMoveTypes.size() < 1):
		CORDS = hexEngine._getMoves().keys()[rng.randi_range(0, hexEngine._getMoves().size() - 1)];
		moves = hexEngine._getMoves()[CORDS];
		for key in moves.keys():
			if (moves[key].size() > 0):
				allowedMoveTypes.append(key);
	
	var hasSelectedType = false;
	while(not hasSelectedType):
		var i = rng.randi_range(0, allowedMoveTypes.size() - 1);
		MOVETYPE = allowedMoveTypes[i];
		if(moves[MOVETYPE].size() > 0):
			hasSelectedType = true;
	
	moves = moves[MOVETYPE];
	MOVEINDEX = rng.randi_range(0, moves.size() - 1);
	TO = moves[MOVEINDEX];
	
	return
