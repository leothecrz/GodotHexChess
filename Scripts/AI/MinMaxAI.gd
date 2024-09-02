extends Node;
class_name MinMaxAI;

const MIN_INT = -9223372036854775808;
const MAX_INT = 9223372036854775807;

const DIST_VALUE = 100;
const CHECK_VAL = 10000;
#skip ZERO and ignore king *(its always present) 
const PIECE_VALUES = [0, 1000, 5000, 10000, 7500, 50000, 0]


var side:int;
var maxDepth:int;

var TO:Vector2i;
var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

var counter = 0;

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

enum test {zero,one}

##
func Hueristic(hexEngine:HexEngine) -> int:
	#ENDSTATE
	if(hexEngine._getGameOverStatus()):
		if(hexEngine._getGameInCheck()):
			if(hexEngine._getIsWhiteTurn()): return MAX_INT;
			else: return MIN_INT;
		else: return 0; # StaleMate
	#Piece Comparison
	var value = 0;
	for piecetype in hexEngine._getActivePieces()[hexEngine.SIDES.BLACK]:
		for piece in hexEngine._getActivePieces()[hexEngine.SIDES.BLACK][piecetype]:
			value += PIECE_VALUES[piecetype];
	for piecetype in hexEngine._getActivePieces()[hexEngine.SIDES.WHITE]:
		for piece in hexEngine._getActivePieces()[hexEngine.SIDES.WHITE][piecetype]:
			value -= PIECE_VALUES[piecetype];
	#Check
	if(hexEngine._getGameInCheck()):
		if(hexEngine._getIsWhiteTurn()): 
			value += CHECK_VAL;
		else: 
			value -= CHECK_VAL;
	#Push King
	var WhiteKing:Vector2i = hexEngine._getActivePieces()[hexEngine.SIDES.WHITE][hexEngine.PIECES.KING][0];
	var BlackKing:Vector2i = hexEngine._getActivePieces()[hexEngine.SIDES.BLACK][hexEngine.PIECES.KING][0];
	var dist = hexEngine.getAxialCordDist(WhiteKing,Vector2i(0,0));
	value += dist * DIST_VALUE;
	dist = hexEngine.getAxialCordDist(BlackKing,Vector2i(0,0));
	value -= dist * DIST_VALUE;
	#Push Pawns
	for pawn:Vector2i in hexEngine._getActivePieces()[hexEngine.SIDES.WHITE][hexEngine.PIECES.PAWN]:
		if(pawn.x >= 0):
			value -= DIST_VALUE * hexEngine.getAxialCordDist(pawn, Vector2i(pawn.x, -1*hexEngine.HEX_BOARD_RADIUS))
		else:
			value -= DIST_VALUE * hexEngine.getAxialCordDist(pawn, Vector2i(pawn.x, (-1*hexEngine.HEX_BOARD_RADIUS)-pawn.x));
	for pawn:Vector2i in hexEngine._getActivePieces()[hexEngine.SIDES.BLACK][hexEngine.PIECES.PAWN]:
		if(pawn.x <= 0):
			## axial dist is negative
			value += DIST_VALUE * hexEngine.getAxialCordDist(pawn, Vector2i(pawn.x, hexEngine.HEX_BOARD_RADIUS));
		else:
			value += DIST_VALUE * hexEngine.getAxialCordDist(pawn, Vector2i(pawn.x, hexEngine.HEX_BOARD_RADIUS-pawn.x));;
	return value;

##
func minimax(depth:int, isMaxPlayer:bool, hexEngine:HexEngine, alpha:int, beta:int) -> int:
	if(depth == 0 or hexEngine._getGameOverStatus()):
			return Hueristic(hexEngine);
	counter +=1;
	var legalmoves = hexEngine._getMoves().duplicate(true);
	var escapeLoop = false;
	if(isMaxPlayer):
		var invalue = MIN_INT;
		for piece in legalmoves.keys():
			if (escapeLoop): break
			for movetype in legalmoves[piece]:
				if (escapeLoop): break
				var index:int = 0;
				for move in legalmoves[piece][movetype]:
					var WAB = hexEngine._duplicateWAB();
					var BAB = hexEngine._duplicateBAB();
					var BP = hexEngine._duplicateBP();
					var IP = hexEngine._duplicateIP();
					hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
					invalue = max(minimax(depth-1,false,hexEngine, alpha, beta), invalue);
					alpha = max(alpha, invalue);
					hexEngine._undoLastMove(false);
					hexEngine._restoreState(WAB,BAB,BP,IP,legalmoves);
					if(beta <= alpha):
						escapeLoop = true;
						break;
					index += 1;
		return invalue;
	var outvalue = MAX_INT;
	for piece in legalmoves.keys():
		if (escapeLoop): break
		for movetype in legalmoves[piece]:
			if (escapeLoop): break
			var index:int = 0;
			for move in legalmoves[piece][movetype]:
				var WAB = hexEngine._duplicateWAB();
				var BAB = hexEngine._duplicateBAB();
				var BP = hexEngine._duplicateBP();
				var IP = hexEngine._duplicateIP();
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				outvalue = min(minimax(depth-1,true,hexEngine, alpha, beta), outvalue);
				beta = min(beta, outvalue);
				hexEngine._undoLastMove(false);
				hexEngine._restoreState(WAB,BAB,BP,IP,legalmoves);
				if(beta <= alpha):
					escapeLoop = true;
					break;
				index += 1;
	return outvalue;

##
func lessThan(a,b):
	return a<b;

##
func greaterThan(a,b):
	return a>b;

##
func selectBestMove(piece:Vector2i, movetype:int, index:int, move:Vector2i):
	CORDS = piece;
	MOVETYPE = movetype;
	MOVEINDEX = index;
	TO = move;
	return

##
func _makeChoice(hexEngine:HexEngine):
	if(hexEngine._getGameOverStatus()): return;
	hexEngine._disableAIMoveLock();
	CORDS = Vector2i()
	var isMaxPlayer = side != hexEngine.SIDES.BLACK;
	var BestValue:int = MAX_INT if isMaxPlayer else MIN_INT;
	var function:Callable = lessThan if not isMaxPlayer else greaterThan;
	var legalmoves:Dictionary = hexEngine._getMoves().duplicate(true);
	var start = Time.get_ticks_msec();
	counter = 0;
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			var index:int = 0;
			for move in legalmoves[piece][movetype]:
				#var state:FrozenState = hexEngine._getFrozenState();
				var WAB = hexEngine._duplicateWAB();
				var BAB = hexEngine._duplicateBAB();
				var BP = hexEngine._duplicateBP();
				var IP = hexEngine._duplicateIP();
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				var val = minimax(maxDepth,isMaxPlayer,hexEngine, MIN_INT, MAX_INT);
				if (function.call(BestValue,val)):
					BestValue = val;
					selectBestMove(piece,movetype,index,move);
				hexEngine._undoLastMove(false);
				hexEngine._restoreState(WAB,BAB,BP,IP,legalmoves);
				#hexEngine._restoreFrozenState(state,legalmoves)
				#state.queue_free();
	
	print("Move Gen For Depth [%d] took %d" % [maxDepth, Time.get_ticks_msec() - start]);
	print("Moves Checked: ", counter);
	print("Best Value: ", BestValue);
	hexEngine._enableAIMoveLock();
	return
