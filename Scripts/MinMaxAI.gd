extends Node;
class_name MinMaxAI;

var side:int;
var maxDepth;
var rng:RandomNumberGenerator;

var TO:Vector2i;
var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

const PIECE_VALUES = [0, 10, 50, 100, 75, 500, 0]

##
func _init(playswhite:bool, max_Depth:int):
	side = 1 if playswhite else 0;
	maxDepth = max_Depth;
	## For Promote moves should check if knight or queen is best choice (WIP)
	PROMOTETO = 5;
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

##
func Hueristic(hexEngine:HexEngine) -> int:
	if(hexEngine._getGameOverStatus()):
		if(hexEngine._getGameInCheck()):
			if(hexEngine._getIsWhiteTurn()): return INF;
			else: return -INF;
		else: return 0; # StaleMate
	
	var value = 0;		
	
	for piecetype in hexEngine._getActivePieces()[hexEngine.SIDES.BLACK]:
		for piece in hexEngine._getActivePieces()[hexEngine.SIDES.BLACK][piecetype]:
			value += PIECE_VALUES[piecetype];
	
	for piecetype in hexEngine._getActivePieces()[hexEngine.SIDES.WHITE]:
		for piece in hexEngine._getActivePieces()[hexEngine.SIDES.WHITE][piecetype]:
			value -= PIECE_VALUES[piecetype];
	
	return value;

###

func minimax(depth:int, isMaxPlayer:bool, hexEngine:HexEngine) -> int:
	if(depth == 0 or hexEngine._getGameOverStatus()):
			return Hueristic(hexEngine);
	
	var legalmoves = hexEngine._getMoves();
	
	if(isMaxPlayer):
		var value = -INF;
		for piece in legalmoves.keys():
			for movetype in legalmoves[piece]:
				var index:int = 0;
				for move in legalmoves[piece][movetype]:
					hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
					value = max(minimax(depth-1,false,hexEngine), value)
					hexEngine._undoLastMove();
		## for each move:
		#value = max(value, minimax(depth-1, false, move, hexEngine));
		return value;
	var value = INF;
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			var index:int = 0;
			for move in legalmoves[piece][movetype]:
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				value = min(minimax(depth-1,true,hexEngine), value)
				hexEngine._undoLastMove();
	## for each move:
	#value = min(value, minimax(depth-1, false, move, hexEngine));
	return value;


##
func _makeChoice(hexEngine:HexEngine):
	if(hexEngine._getGameOverStatus()): return;
	hexEngine._disableAIMoveLock();
	CORDS = Vector2i()
	var BestValue = INF if side == hexEngine.SIDES.WHITE else -INF;
	var isMaxPlayer = side == hexEngine.SIDES.BLACK;
	var legalmoves:Dictionary = hexEngine._getMoves();
	
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			var index:int = 0;
			for move in legalmoves[piece][movetype]:
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				var val = minimax(maxDepth,isMaxPlayer,hexEngine)
				print("MinMaxValue: ", val);
				print("MoveID: ", piece, " ", movetype, " ", index, "\n");
				if (BestValue < val):
					BestValue = val;
					CORDS = piece;
					MOVETYPE = movetype;
					MOVEINDEX = index;
				hexEngine._undoLastMove();
	
	TO = legalmoves[CORDS][MOVETYPE][MOVEINDEX];
	hexEngine._enableAIMoveLock();
	return
