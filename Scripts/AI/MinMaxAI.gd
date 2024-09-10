extends Node;
class_name MinMaxAI;

#const MIN_INT = -9223372036854775808;
#const MAX_INT = 9223372036854775807;
const MIN_INT = -922337203685477580;
const MAX_INT = 922337203685477580;

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
var statesEvaluated = 0;

##
func _init(playswhite:bool, max_Depth:int):
	side = 1 if playswhite else 0;
	maxDepth = max_Depth;
	## For Promote moves should check if knight or queen is best choice (WIP)
	PROMOTETO = 5;
	return


### GETTERS


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


## Update Self


## Update the AI choice that will be read by the GUI
func selectBestMove(piece:Vector2i, movetype:int, index:int, move:Vector2i):
	CORDS = piece;
	MOVETYPE = movetype;
	MOVEINDEX = index;
	TO = move;
	return


## MINIMAX


## Measure Board State
func Hueristic(hexEngine:HexEngine) -> int:
	statesEvaluated += 1;
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
	counter +=1;
	if(depth == 0 or hexEngine._getGameOverStatus()):
			return Hueristic(hexEngine);
	
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
					var InPi = hexEngine._duplicateIP();
					
					hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
					invalue = max(minimax(depth-1,false,hexEngine, alpha, beta), invalue);
					alpha = max(alpha, invalue);
					
					hexEngine._undoLastMove(false);
					hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
					
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
				var InPi = hexEngine._duplicateIP();
				
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				
				outvalue = min(minimax(depth-1,true,hexEngine, alpha, beta), outvalue);
				beta = min(beta, outvalue);
				
				hexEngine._undoLastMove(false);
				hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
				
				if(beta <= alpha):
					escapeLoop = true;
					break;
				index += 1;
	return outvalue;


## API


## allow AI to make its choice
func _makeChoice(hexEngine:HexEngine):
	if(hexEngine._getGameOverStatus()): 
		return;
	
	var isMaxPlayer = (side == hexEngine.SIDES.BLACK);
	var BestValue:int = MIN_INT if isMaxPlayer else MAX_INT;
	
	var function:Callable = func(a, b): return a < b  if isMaxPlayer else func(a,b): return a > b ;
	
	var legalmoves:Dictionary = hexEngine._getMoves().duplicate(true);
	var start = Time.get_ticks_msec();
	
	hexEngine._disableAIMoveLock();
	CORDS = Vector2i()
	counter = 0;
	
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			var index:int = 0;
			for move in legalmoves[piece][movetype]:

				var WAB:Dictionary = hexEngine._duplicateWAB();
				var BAB:Dictionary = hexEngine._duplicateBAB();
				var BP:Dictionary = hexEngine._duplicateBP();
				var InPi:Dictionary = hexEngine._duplicateIP();
				
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				
				var val = minimax(maxDepth,!isMaxPlayer,hexEngine, MIN_INT, MAX_INT);
				
				if (function.call(BestValue,val)):
					BestValue = val;
					selectBestMove(piece,movetype,index,move);
				
				hexEngine._undoLastMove(false);
				hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
	
	print("Move Gen For Depth [%d+1] took %d" % [maxDepth, Time.get_ticks_msec() - start]);
	print("MinMax Calls: ", counter);
	print("Evals Made: ", statesEvaluated);
	print("Best Value: ", BestValue);
	
	print("Cords: (%d,%d), To: (%d,%d), Type: %d, Index: %d \n" % [CORDS.x,CORDS.y, TO.x,TO.y, MOVETYPE, MOVEINDEX]);
	
	hexEngine._enableAIMoveLock();
	return
