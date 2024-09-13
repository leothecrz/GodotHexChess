extends Node;
class_name MinMaxAI;

const MIN_INT = -9223372036854775808;
const MAX_INT = 9223372036854775807;

const DIST_VALUE = 10000;
const KING_DIST_VALUE = DIST_VALUE / 5;
const CHECK_VAL = 15000;

#skip ZERO and ignore king *(its always present) 
const PIECE_VALUES = [0, 1000, 3000, 5000, 3000, 9000, 0]

const PIECE_TYPE_COUNT = 6;

## State

var hashBoardValues:Dictionary;
var whiteTurnHashValue:int;
var blackTurnHashValue:int;

var transpositionTable:Dictionary;

var side:int;
var maxDepth:int;

var TO:Vector2i;
var CORDS:Vector2i;
var MOVETYPE:int;
var MOVEINDEX:int;
var PROMOTETO:int;

var counter = 0;
var statesEvaluated = 0;
var positionsFound = 0;

## Class


##
func _init(playswhite:bool, maxdepth:int):
	side = HexEngine.SIDES.WHITE if playswhite else HexEngine.SIDES.BLACK;
	maxDepth = maxdepth;
	## For Promote moves should check if knight or queen is best choice (WIP)
	PROMOTETO = 5;
	
	hashBoardValues = createTranspositionBoard(HexEngine.HEX_BOARD_RADIUS);
	transpositionTable = {};
	
	return;

##
func getPositionHash(ref:HexEngine, isWTurn:bool) -> int:
	var hash = whiteTurnHashValue if isWTurn else blackTurnHashValue;
	
	for side:Dictionary in ref._getActivePieces():
		for type:int in side.keys():
			for piece:Vector2i in side[type]:
				hash ^= hashBoardValues[piece][type-1];
	
	return hash;

## Create A hexagonal board with axial cordinates. (Q,R). Centers At 0,0.
func createTranspositionBoard(radius : int) -> Dictionary:
	var Board:Dictionary = Dictionary();
	var rng = RandomNumberGenerator.new();
	##DEBUG SEED
	rng.seed = 0
	
	whiteTurnHashValue = (rng.randi() << 32) | rng.randi();
	blackTurnHashValue = (rng.randi() << 32) | rng.randi();
	
	for q:int in range(-radius, radius+1): #[~r, r]
		var negativeQ : int = -1 * q;
		var minRow : int = max(-radius, (negativeQ-radius));
		var maxRow : int = min( radius, (negativeQ+radius));
		for r:int in range(minRow, maxRow+1):
			var posValues:Array = [];
			for n in range(PIECE_TYPE_COUNT):
				var high:int = rng.randi();
				var low:int = rng.randi();
				posValues.append( (high << 32) | low);
			Board[Vector2i(q,r)] = posValues;
			
	return Board;


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
	value += dist * KING_DIST_VALUE;
	dist = hexEngine.getAxialCordDist(BlackKing,Vector2i(0,0));
	value -= dist * KING_DIST_VALUE;
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

## Recursive Move Check
func NegativeMaximum(hexEngine:HexEngine, depth:int, multiplier:int, alpha:int, beta:int) -> int:
	counter += 1
	
	var positionHash:int = getPositionHash(hexEngine, multiplier < 0);
	var entry:TableEntry = transpositionTable.get(positionHash);
	if(entry && entry._getDepth() >= depth):
		positionsFound += 1;
		match entry._getType():
			TableEntry.ENTRY_TYPE.EXACT: return entry._getValue();
			TableEntry.ENTRY_TYPE.LOWER: alpha = max(alpha, entry._getValue())
			TableEntry.ENTRY_TYPE.UPPER: beta = min(beta, entry._getValue())
		if(alpha >= beta): return entry._getValue();
	
	if (depth == 0) or (hexEngine._getGameOverStatus()):
		return multiplier * Hueristic(hexEngine);
		
	var index:int = 0;
	var value = MIN_INT;
	var escapeLoop = false;
	var legalmoves = hexEngine._getMoves().duplicate(true);
	
	#Insert Move Ordering Here
	
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			index = 0;
			for move in legalmoves[piece][movetype]:
				var WAB = hexEngine._duplicateWAB();
				var BAB = hexEngine._duplicateBAB();
				var BP = hexEngine._duplicateBP();
				var InPi = hexEngine._duplicateIP();
				
				hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
				
				value = max(-NegativeMaximum(hexEngine, (depth-1), -multiplier, -beta, -alpha), value);
				alpha = max(alpha, value);
				
				hexEngine._undoLastMove(false);
				hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
				index += 1;
				
				if(alpha >= beta): escapeLoop = true; break;
			if (escapeLoop): break;
		if (escapeLoop): break;
	
	var type;
	if(value <= alpha):
		type = TableEntry.ENTRY_TYPE.UPPER;
	elif(value >= beta):
		type = TableEntry.ENTRY_TYPE.LOWER;
	else:
		type = TableEntry.ENTRY_TYPE.EXACT;
	transpositionTable[positionHash] = TableEntry.new(value, depth, type);
	
	return value;


## API


## allow AI to make its choice
func _makeChoice(hexEngine:HexEngine):
	if(hexEngine._getGameOverStatus()): 
		return;
	
	var start = Time.get_ticks_msec();
	var isMaxPlayer = (side == hexEngine.SIDES.BLACK);
	var BestValue:int = MIN_INT;
	var legalmoves:Dictionary = hexEngine._getMoves().duplicate(true);

	hexEngine._disableAIMoveLock();
	CORDS = Vector2i(-6,-6);
	counter = 0;
	positionsFound = 0;
	statesEvaluated = 0;
	
	#Insert Iterative Deepening Here
	for depth in range(1, maxDepth+1):
		for piece in legalmoves.keys():
			for movetype in legalmoves[piece]:
				var index:int = 0;
				for move in legalmoves[piece][movetype]:

					var WAB:Dictionary = hexEngine._duplicateWAB();
					var BAB:Dictionary = hexEngine._duplicateBAB();
					var BP:Dictionary = hexEngine._duplicateBP();
					var InPi:Dictionary = hexEngine._duplicateIP();
					
					hexEngine._makeMove(piece,movetype,index,hexEngine.PIECES.QUEEN);
					var val = NegativeMaximum(hexEngine, depth, 1 if isMaxPlayer else -1, MIN_INT, MAX_INT);
					
					if (BestValue < val):
						BestValue = val;
						selectBestMove(piece,movetype,index,move);
						print("Cords: (%d,%d), To: (%d,%d), Type: %d, Index: %d \n" % [CORDS.x,CORDS.y, TO.x,TO.y, MOVETYPE, MOVEINDEX]);
					
					hexEngine._undoLastMove(false);
					hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);

	
	print("Move Gen For Depth [%d+1] took %d" % [maxDepth, Time.get_ticks_msec() - start]);
	print("MinMax Calls: ", counter);
	print("Evals Made: ", statesEvaluated);
	print("Positions Found: ", positionsFound);
	print("Best Value: ", BestValue);
	
	hexEngine._enableAIMoveLock();
	return

class TableEntry:
	
	enum ENTRY_TYPE {EXACT, LOWER, UPPER};
	
	var value:int;
	var depth:int;
	var type:ENTRY_TYPE
	
	##
	func _init(val:int, dep:int, t:int):
		value = val;
		depth = dep;
		type = t;
		return;
	
	##
	func _getValue() -> int:
		return value;
	
	##
	func _getDepth() -> int:
		return depth;
	
	##	
	func _getType() ->int:
		return type;
	
