class_name HexEngine
extends Node

### Hexagonal Chess Engine
##
## Purpose:
## Holds Game State
## Computes Game Logic
## Generates Moves
## Initiates AI Opponent
##

## USAGE
# Set Opponent
# If (AI): Set Type
# While(Not GameIsOver)
# 	Make Move
#	If (AI): passToAI

##TODO:
# FEN1 - Starting from a fen string requires that attack boards be created before anybody can go.
# FEN2 - Make it possible to start from fen string
# PlayerAction - Move Undo - Finished Untested.
# Test - Add tests
# AI1 - Random AI
# AI2 - MinMax AI
# AI3 - Neural Network AI
# Untested - Attacking King with King cause odd behaviour sometimes


### Constants


	#ENUMS
enum PIECES { ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES { BLACK, WHITE };

enum MOVE_TYPES { MOVES, CAPTURE, ENPASSANT, PROMOTE}
enum MATE_STATUS{ NONE, CHECK, OVER }

enum ENEMY_TYPES { PLAYER_TWO, RANDOM, MIN_MAX, NN }
	#Defaults
const HEX_BOARD_RADIUS = 5;
const KING_INDEX = 0;

const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;
	#AttackBoardTest
const ATTACK_BOARD_TEST = '6/7/8/9/k9/10Q/9K/9/8/7/6 w - 1';
const ATTACKING_BOARD_TEST = 'p5/7/8/9/10/k9K/10/9/8/7/5P w - 1';
	#Variations
const VARIATION_ONE_FEN = 'p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1';
const VARIATION_TWO_FEN = '6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1';
	#State Tests
const EMPTY_BOARD   = '6/7/8/9/10/11/10/9/8/7/6 w - 1';
const BLACK_CHECK   = '1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1';
const BLOCKING_TEST = '6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1';
const UNDO_TEST_ONE   = '6/7/8/9/10/4p6/k2p2P2K/9/8/7/6 w - 1';
const UNDO_TEST_TWO   = '6/7/8/9/1P7/11/3p2P2K/9/8/7/k5 w - 1';
const UNDO_TEST_THREE   = '6/7/8/9/2R6/11/k2p2P2K/9/8/7/6 w - 1';
const KING_INTERACTION_TEST = '5P/7/8/9/10/k9K/10/9/8/7/p5 w - 1';
	#Piece Tests
const PAWN_TEST   = '6/7/8/9/10/5P5/10/9/8/7/6 w - 1';
const KNIGHT_TEST = '6/7/8/9/10/5N5/10/9/8/7/6 w - 1';
const BISHOP_TEST = '6/7/8/9/10/5B5/10/9/8/7/6 w - 1';
const ROOK_TEST   = '6/7/8/9/10/5R5/10/9/8/7/6 w - 1';
const QUEEN_TEST  = '6/7/8/9/10/5Q5/10/9/8/7/6 w - 1';
const KING_TEST   = '6/7/8/9/10/5K5/10/9/8/7/6 w - 1';
	#CheckMate Test:
const CHECK_TEST_ONE   = 'q6/7/8/9/10/k8K1/10/9/8/7/q5 w - 20';
const CHECK_TEST_TWO   = '6/7/8/9/10/11/10/9/8/7/6 w - 1';

const ROOK_VECTORS   = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0) };
const BISHOP_VECTORS = { 'lfoward':Vector2i(-2,1), 'rFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'lbackward':Vector2i(1,1), 'rBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KING_VECTORS   = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0), 'dlfoward':Vector2i(-2,1), 'drFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'dlbackward':Vector2i(1,1), 'drBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KNIGHT_VECTORS = { 'left':Vector2i(-1,-2), 'lRight':Vector2i(1,-3), 'rRight':Vector2i(2,-3),}

const DEFAULT_MOVE_TEMPLATE : Dictionary = { MOVE_TYPES.MOVES:[], MOVE_TYPES.CAPTURE:[],  };
const PAWN_MOVE_TEMPLATE : Dictionary    = { MOVE_TYPES.MOVES:[], MOVE_TYPES.CAPTURE:[], MOVE_TYPES.ENPASSANT:[], MOVE_TYPES.PROMOTE:[], };

const DECODE_FEN_OFFSET = 70;
# ~( 0b1000 );
const TYPE_MASK = 0b0111;
### State


# Board
var HexBoard : Dictionary         = {};
var WhiteAttackBoard : Dictionary = {};
var BlackAttackBoard : Dictionary = {};

#### 
#BitBoard Testing
var WHITE_BB:Array;
var BLACK_BB:Array;
####

# Game Turn
var isWhiteTurn : bool = true;
var turnNumber : int   = 1;

# Pieces
var influencedPieces : Dictionary = {};
var blockingPieces : Dictionary = {};
var activePieces : Array = [];

# Moves
var legalMoves : Dictionary = {};

# Check & Mate
var GameIsOver : bool = false;
var GameInCheck : bool = false;
var GameInCheckFrom : Vector2i = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
var GameInCheckMoves : Array = [];

# Captures
var blackCaptures : Array = [];
var whiteCaptures : Array = [];

var captureType : PIECES = PIECES.ZERO;
var captureIndex : int = -1;
var captureValid : bool = false;

# UndoFlags and Data
var uncaptureValid: bool = false;
var unpromoteValid:bool = false;
var unpromoteType:PIECES = PIECES.ZERO;
var unpromoteIndex:int = 0;

var undoType:PIECES = PIECES.ZERO ;
var undoIndex:int = -1;
var undoTo:Vector2i = Vector2i();

# EnPassant
var EnPassantCords : Vector2i = Vector2i(-5,-5);
var EnPassantTarget : Vector2i = Vector2i(-5,-5);
var EnPassantCordsValid : bool = false;

# Enemy
var EnemyAI;
var EnemyType:ENEMY_TYPES = ENEMY_TYPES.PLAYER_TWO;
var EnemyPromotedTo:PIECES = PIECES.ZERO;

var EnemyIsAI = false;
var EnemyPlaysWhite = false;
var EnemyPromoted =  false;
var bypassMoveLock = false;


var EnemyChoiceType;
var EnemyChoiceIndex;
var EnemyTo;



# History
var moveHistory : Array = [];

### BITBOARD

##
func createBitBoards() -> void:
	WHITE_BB = [];
	BLACK_BB = [];
	for i in range(PIECES.size()-1):
		WHITE_BB.append(BitBoard.new(0,0));

	for i in range(PIECES.size()-1):
		BLACK_BB.append(BitBoard.new(0,0));
		
	return;

##
func destroyBitBoards() -> void:
	for BB in WHITE_BB:
		BB.free();
	for BB in BLACK_BB:
		BB.free();
	return;

##
func getWhitePiecesBitBoard() -> BitBoard:
	var returnBoard = BitBoard.new(0,0);
	var tempBoard;
	
	for BB in WHITE_BB:
		tempBoard = returnBoard.OR(BB);
		returnBoard.free();
		returnBoard = tempBoard;
	
	return returnBoard;

##
func getBlackPiecesBitBoard() -> BitBoard:
	var returnBoard = BitBoard.new(0,0);
	var tempBoard;
	
	for BB in BLACK_BB:
		tempBoard = returnBoard.OR(BB);
		returnBoard.free();
		returnBoard = tempBoard;
	
	return returnBoard;

##
func QRToIndex(q:int, r:int) -> int:
	var normalq = q + 5;
	var i = 0;
	var index = 0;
	for size in BitBoard.COLUMN_SIZES:
		if (normalq == i):
			break; 
		index += size;
		i += 1;
	
	if(q <= 0):
		index += 5 - r;
	else:
		index += (BitBoard.COLUMN_SIZES[normalq]-6) - r;
			
	return index;

func get2PowerN(n:int) -> int:
	return 1 << n;

##
func add_IPieceToBitBoards(q:int, r:int, piece:int) -> void:
	var index = QRToIndex(q,r);
	var type = getPieceType(piece);
	var back = get2PowerN( index );
	var front = 0;
	if(index > BitBoard.INDEX_TRANSITION):
		front = get2PowerN( index - BitBoard.INDEX_OFFSET );
		back = 0;
	var insert = BitBoard.new(front,back);
	
	if(isPieceWhite(piece)):
		var temp = WHITE_BB[type-1].OR(insert);
		WHITE_BB[type-1].free();
		WHITE_BB[type-1] = temp;
	else:
		var temp = BLACK_BB[type-1].OR(insert);
		BLACK_BB[type-1].free();
		BLACK_BB[type-1] = temp;
	insert.free();
	return;

##
func addS_PieceToBitBoards(q:int, r:int, char:String) -> void:
	var isBlack = true;
	if(char == char.to_upper()):
		isBlack = false;
		char = char.to_lower();
	var piece = PIECES.ZERO;
	match char:
		"p": piece = PIECES.PAWN;
		"n": piece = PIECES.KNIGHT;
		"r": piece = PIECES.ROOK;
		"b": piece = PIECES.BISHOP;
		"q": piece = PIECES.QUEEN;
		"k": piece = PIECES.KING;
	add_IPieceToBitBoards(q,r, getPieceInt(piece, isBlack));
	return;

### Board State


## Create A hexagonal board with axial cordinates. (Q,R). Centers At 0,0.
func createBoard(radius : int) -> Dictionary:
	var Board:Dictionary = Dictionary();
	for q:int in range(-radius, radius+1): #[~r, r]
		var negativeQ : int = -1 * q;
		var minRow : int = max(-radius, (negativeQ-radius));
		var maxRow : int = min( radius, (negativeQ+radius));
		Board[q] = Dictionary();
		for r:int in range(minRow, maxRow+1):
			Board[q][r] = PIECES.ZERO;
	return Board;

## Use the board to find the location of all pieces. 
## Intended to be ran only once at the begining.
func findPieces(board:Dictionary) -> Array:
	var pieceCords:Array = \
	[
		{ PIECES.PAWN:[],PIECES.KNIGHT:[],PIECES.ROOK:[],PIECES.BISHOP:[],PIECES.QUEEN:[],PIECES.KING:[] },
		{ PIECES.PAWN:[],PIECES.KNIGHT:[],PIECES.ROOK:[],PIECES.BISHOP:[],PIECES.QUEEN:[],PIECES.KING:[] }
	];
	
	for q in board.keys():
		for r in board[q].keys():
			
			var val:int = board[q][r];
			if val == PIECES.ZERO:
				continue;
			
			var pieceType:PIECES = getPieceType(val);
			var pos:Vector2i = Vector2i(q,r);
			var side = SIDES.WHITE if isPieceWhite(val) else SIDES.BLACK;
			
			pieceCords[side][pieceType].append(pos);
			
	return pieceCords;

## ADD A Piece To Board. At (Q,R) in 'board' decode 'val' and place it.
func addPieceToBoardAt( q:int, r:int, val:String, board:Dictionary) -> void:
	var isBlack = true;

	if(val == val.to_upper()):
		isBlack = false;
		val = val.to_lower();
	
	var piece = PIECES.ZERO;
	match val:
		"p":
			piece = PIECES.PAWN;
		"n":
			piece = PIECES.KNIGHT;
		"r":
			piece = PIECES.ROOK;
		"b":
			piece = PIECES.BISHOP;
		"q":
			piece = PIECES.QUEEN;
		"k":
			piece = PIECES.KING;
	
	board[q][r] = getPieceInt(piece, isBlack);
	return;

## Fill The Board by translating a fen string. DOES NOT FULLY VERIFY FEN STRING 
## (W I P)
func fillBoardwithFEN(fenString: String) -> Dictionary:
	
	var Board : Dictionary = createBoard(HEX_BOARD_RADIUS);
	createBitBoards();
	
	var fenSections : PackedStringArray = fenString.split(" ");
	if (fenSections.size() != 4):
		print("Invalid String");
		return {};
	
	var BoardColumns : PackedStringArray = fenSections[0].split("/");
	if (BoardColumns.size() != 11):
		print("Invalid String");
		return {};
	
	var regex:RegEx = RegEx.new();
	regex.compile("(?i)([pnrbqk]|[0-9]|/)*")
	var result = regex.search(fenString);
	if result && (result.get_string(0) != fenString.substr(0,fenString.find(" ",0))):
		print(result.get_string(0));
		print(fenString);
		print("Invalid String");
		return {};
	
	for q in range(-HEX_BOARD_RADIUS, HEX_BOARD_RADIUS+1):
		var mappedQ:int = q+HEX_BOARD_RADIUS;
		var activeRow:String = BoardColumns[mappedQ];
		var r1:int = max(-HEX_BOARD_RADIUS, -q-HEX_BOARD_RADIUS);
		var r2:int = min(HEX_BOARD_RADIUS, -q+HEX_BOARD_RADIUS);

		for i:int in range( activeRow.length() ):
			var activeChar:String = activeRow[i];

			if ( activeChar.is_valid_int() ):
				var pushDistance:int = int(activeChar);
				while ((i+1) < activeRow.length()) && (activeRow[i+1].is_valid_int()):
					i += 1;
					pushDistance *= 10;
					pushDistance += int(activeRow[i]);
				r1 += pushDistance;

			else:
				if(r1 <= r2):
					addPieceToBoardAt(q,r1,activeChar,Board);
					addS_PieceToBitBoards(q,r1,activeChar);
					r1 +=1 ;
				else:
					push_error("R1 Greater Than Max");
					return {};
	
	if(fenSections[1] == 'w'):
		isWhiteTurn = true;
	elif (fenSections[1] == 'b'):
		isWhiteTurn = false;
	else:
		return {};

	if(fenSections[2] != '-'):
		EnPassantCords = decodeEnPassantFEN(fenSections[2]);
		EnPassantCordsValid = true;
		# TODO: findEnPassantTarget();
		EnPassantTarget = Vector2i(-5,-5);
	else:
		EnPassantCords = Vector2i(-5,-5);
		EnPassantTarget = Vector2i(-5,-5);
		EnPassantCordsValid = false;

	turnNumber = fenSections[3].to_int()
	if(turnNumber < 1):
		turnNumber = 1;

	print("White:");
	for bb in WHITE_BB:
		print(bb);
	print("Black:");
	for bb in BLACK_BB:
		print(bb);
	print("")

	return Board;


### PIECE IDENTIFING


## Checks if the fourth bit is fliped.
func isPieceWhite(id: int) -> bool:
	var mask = 0b1000; #8
	if ((id & mask) != 0):
		return true;
	return false;

## Given the int value of a chess piece and the current turn determine if friendly.
func isPieceFriendly(val,isWhiteTrn) -> bool:
	return (isWhiteTrn == isPieceWhite(val));

## Given the int value of a chess piece determine if the piece is a king.
func isPieceKing(id:int) -> bool:
	return getPieceType(id) == PIECES.KING;


### PAWN POSITIONS


## Check if cords are in the black pawn start
## (-4, -1) (-3,-1) (-2,-1) (-1,-1) (0, -1) (1, -2) (2, -3) (3, -4) (4, -5)
func isBlackPawnStart(cords:Vector2i) -> bool:
	var r:int = -1;
	for q:int in range (-4,4+1):
		if( q > 0 ):
			r -= 1;
		if (cords.x == q) && (cords.y == r):
			return true;
	return false;

## Check if cords are in the white pawn start
func isWhitePawnStar(cords:Vector2i) ->bool:
	var r:int = 5;
	for q:int in range (-4,4+1):
		if (cords.x == q) && (cords.y == r):
			return true;
		if( q < 0 ):
			r -= 1;
			
	return false;

##
func isWhitePawnPromotion(cords:Vector2i)-> bool:
	var r:int = 0;
	for q:int in range(-5,5):
		
		if (cords.x == q) && (cords.y == r):
			return true;
		
		if(r > -5):
			r -= 1;
		
	return false;

##
func isBlackPawnPromotion(cords:Vector2i) -> bool:
	var r:int = 5;
	for q:int in range(-5,5):
		
		if (cords.x == q) && (cords.y == r):
			return true;
		
		if(q >= 0):
			r -= 1;
		
	return false;


### Internal GETS


## Get int representation of piece.
func getPieceInt(piece : PIECES, isBlack: bool) -> int:
	var id:int = piece
	if(!isBlack):
		id += 8;
	return id;

## Strip the color bit information and find what piece is in use.
func getPieceType(id:int) -> PIECES:
	var res = (id & TYPE_MASK);
	@warning_ignore("int_as_enum_without_cast")
	return res;


### ENPASSANT


## Turn a vector (q,r) into a string representation of the position.
func encodeEnPassantFEN(q:int, r:int) -> String:
	var rStr:int = 6 - r;
	var qStr:int = 5 + q;

	var qLetter = char(65 + qStr);
	return "%s%d" % [qLetter, rStr];

## Turn a string represenation of board postiion to a vector2i.
func decodeEnPassantFEN(s:String) -> Vector2i:
	var qStr:int = s.unicode_at(0) - DECODE_FEN_OFFSET; #"A".unicode_at(0) - 5;
	var rStr:int = int(s.substr(1,-1))
	rStr += 6-(2*rStr);
	return Vector2i(qStr, rStr);


### TURN MODIFICATION


##
func incrementTurnNumber():
	turnNumber += 1;
	return;

##
func decrementTurnNumber():
	turnNumber -= 1;
	return;

## Update Turn Counter and swap player turn
func swapPlayerTurn():
	isWhiteTurn = !isWhiteTurn;
	return;


### MOVE GENERATION


##Blocking Piece Search Logic
func checkForBlockingOnVector(piece: PIECES, dirSet:Dictionary, bp:Dictionary, cords:Vector2i):
	
	var isWhiteTrn:bool = isPieceWhite(HexBoard[cords.x][cords.y]);
	
	for direction in dirSet.keys():
		var activeVector:Vector2i = dirSet[direction];
		
		var dirBlockingPiece:Vector2i;
		
		var checkingQ:int = cords.x + activeVector.x;
		var checkingR:int = cords.y + activeVector.y;

		var LegalMoves:Array = [];
		while ( (HexBoard.has(checkingQ)) && (HexBoard[checkingQ].has(checkingR)) ): # CORDS ARE IN RANGE
			
			if ( HexBoard[checkingQ][checkingR] == PIECES.ZERO ):
				if(dirBlockingPiece):
					LegalMoves.append(Vector2i(checkingQ,checkingR)); ## Track legal moves for the blocking pieces

			else:
				if ( isPieceFriendly( HexBoard[checkingQ][checkingR], isWhiteTrn) ):
					if(dirBlockingPiece): break; ## Two friendly pieces in a row. No Danger
					else: dirBlockingPiece = Vector2i(checkingQ,checkingR); ## First piece found

				else: ##Unfriendly Piece Found
					var val = getPieceType(HexBoard[checkingQ][checkingR]);
					if ( (val == PIECES.QUEEN) or (val == piece) ):
						if(dirBlockingPiece):
							LegalMoves.append(Vector2i(checkingQ,checkingR));
							bp[dirBlockingPiece] = LegalMoves; ## store blocking piece moves
							
					break;

			checkingQ += activeVector.x;
			checkingR += activeVector.y;
	return;

## Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
func checkForBlockingPiecesFrom(cords:Vector2i) -> Dictionary:
	
	var blockingpieces:Dictionary = {};
	
	checkForBlockingOnVector(PIECES.ROOK, ROOK_VECTORS, blockingpieces, cords);
	checkForBlockingOnVector(PIECES.BISHOP, BISHOP_VECTORS, blockingpieces, cords);
		
	return blockingpieces;


## Calculate Pawn Capture Moves
func findCaptureMovesForPawn(pawn : Vector2i, qpos : int, rpos : int ) -> void:
	var move = Vector2i(qpos, rpos)
	if( HexBoard.has(qpos) && HexBoard[qpos].has(rpos)):
		if ( (HexBoard[qpos][rpos] != PIECES.ZERO) && (!isPieceFriendly(HexBoard[qpos][rpos], isWhiteTurn)) ):
			if ( isWhitePawnPromotion(move) if isWhiteTurn else isBlackPawnPromotion(move) ) :
				legalMoves[pawn][MOVE_TYPES.PROMOTE].append(move);
			else:
				legalMoves[pawn][MOVE_TYPES.CAPTURE].append(move);
		else:
			if( EnPassantCordsValid && (EnPassantCords.x == qpos) && (EnPassantCords.y == rpos) ):
				legalMoves[pawn][MOVE_TYPES.CAPTURE].append(move);
		updateAttackBoard(qpos, rpos, 1);
	return;

## Calculate Pawn Foward Moves
func findFowardMovesForPawn(pawn : Vector2i, fowardR : int ) -> void:
	var boolCanGoFoward = false;
	##Foward Move
	if (HexBoard[pawn.x].has(fowardR) && HexBoard[pawn.x][fowardR] == 0):
		if ( isWhitePawnPromotion(Vector2i(pawn.x,fowardR)) if isWhiteTurn else isBlackPawnPromotion(Vector2i(pawn.x,fowardR)) ) :
			legalMoves[pawn][MOVE_TYPES.PROMOTE].append(Vector2i(pawn.x, fowardR));
		else:
			legalMoves[pawn][MOVE_TYPES.MOVES].append(Vector2i(pawn.x, fowardR));
			boolCanGoFoward = true;
	
	##Double Move From Start
	if( boolCanGoFoward && ( isWhitePawnStar(pawn) if isWhiteTurn else isBlackPawnStart(pawn) ) ):
		var doubleF = pawn.y - 2 if isWhiteTurn else pawn.y + 2;
		if (HexBoard[pawn.x][doubleF] == 0):
			legalMoves[pawn][MOVE_TYPES.ENPASSANT].append(Vector2i(pawn.x, doubleF));

## Calculate Pawn Moves (TODO: Unfinished Promote)
func findMovesForPawn(PawnArray:Array)-> void:
	for i in range(PawnArray.size()):
		var pawn = PawnArray[i];
		legalMoves[pawn] = PAWN_MOVE_TEMPLATE.duplicate(true);

		var fowardR = pawn.y - 1 if isWhiteTurn else pawn.y + 1;
		var leftCaptureR = pawn.y if isWhiteTurn else pawn.y + 1;
		var rightCaptureR = pawn.y-1 if isWhiteTurn else pawn.y;

		##Foward Move
		findFowardMovesForPawn(pawn, fowardR);

		##Left Capture
		findCaptureMovesForPawn(pawn, pawn.x-1, leftCaptureR);

		##Right Capture
		findCaptureMovesForPawn(pawn, pawn.x+1, rightCaptureR);

		## Not Efficient FIX LATER
		if(  blockingPieces.has(pawn) ):
			var newLegalmoves = blockingPieces[pawn];
			for moveType in legalMoves[pawn].keys():
				legalMoves[pawn][moveType] = intersectOfTwoArrays(newLegalmoves, legalMoves[pawn][moveType]);

		## Not Efficient FIX LATER
		if( GameInCheck ):
			for moveType in legalMoves[pawn].keys():
				legalMoves[pawn][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[pawn][moveType]);

	return;

## Calculate Knight Moves
func findMovesForKnight(KnightArray:Array) -> void:
	for i in range(KnightArray.size()):

		var knight = KnightArray[i];
		legalMoves[knight] = DEFAULT_MOVE_TEMPLATE.duplicate(true);

		var invertAt2Counter = 0;
		for m in [-1,1,-1,1]:
			
			for dir in KNIGHT_VECTORS.keys():
				var activeVector:Vector2i = KNIGHT_VECTORS[dir];
				var checkingQ = knight.x + ((activeVector.x if (invertAt2Counter < 2) else activeVector.y) * m);
				var checkingR = knight.y + ((activeVector.y if (invertAt2Counter < 2) else activeVector.x) * m);
				
				if (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR)):
					if (HexBoard[checkingQ][checkingR] == 0) :
						legalMoves[knight][MOVE_TYPES.MOVES].append(Vector2i(checkingQ,checkingR));

					elif (!isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn)):
						legalMoves[knight][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ,checkingR));
					
					updateAttackBoard(checkingQ, checkingR, 1);

			invertAt2Counter += 1;
			
		## Not Efficient FIX LATER
		if(  blockingPieces.has(knight) ):
			var newLegalmoves = blockingPieces[knight];
			for moveType in legalMoves[knight].keys():
				legalMoves[knight][moveType] = intersectOfTwoArrays(newLegalmoves, legalMoves[knight][moveType]);

		## Not Efficient FIX LATER
		if( GameInCheck ):
			for moveType in legalMoves[knight].keys():
				legalMoves[knight][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[knight][moveType]);

	return;

## Calculate Rook Moves
func findMovesForRook(RookArray:Array) -> void:
	for i in range(RookArray.size()):
		var rook = RookArray[i];
		legalMoves[rook] = DEFAULT_MOVE_TEMPLATE.duplicate(true);
		
		for dir in ROOK_VECTORS.keys():
			var activeVector:Vector2i = ROOK_VECTORS[dir];
			var checkingQ:int = rook.x + activeVector.x;
			var checkingR:int = rook.y + activeVector.y;
			
			while (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
				
				if( HexBoard[checkingQ][checkingR] == 0):
					legalMoves[rook][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn)):
					legalMoves[rook][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					
					#King Escape Fix
					if(getPieceType(HexBoard[checkingQ][checkingR]) == PIECES.KING):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						if(HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
							updateAttackBoard(checkingQ, checkingR, 1);
					
					break;
				else:
					
					var pos = Vector2i(checkingQ,checkingR);
					if(influencedPieces.has(pos)):
						influencedPieces[pos].append(rook);
					else:
						influencedPieces[pos] = [rook];
						
					updateAttackBoard(checkingQ, checkingR, 1);
					break;
				
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
				##END WHILE	
				
		## Not Efficient TODO: FIX LATER
		if(  blockingPieces.has(rook) ):
			var newLegalmoves = blockingPieces[rook];
			for moveType in legalMoves[rook]:
				legalMoves[rook][moveType] = intersectOfTwoArrays(newLegalmoves, legalMoves[rook][moveType]);
		
		## Not Efficient TODO: FIX LATER
		if( GameInCheck ):
			for moveType in legalMoves[rook]:
				legalMoves[rook][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[rook][moveType]);
		
	return;

## Calculate Bishop Moves
func findMovesForBishop(BishopArray:Array) -> void:
	for i in range(BishopArray.size()):
		var bishop = BishopArray[i];
		
		legalMoves[bishop] = DEFAULT_MOVE_TEMPLATE.duplicate(true);
		
		for dir in BISHOP_VECTORS.keys():
			var activeVector:Vector2i = BISHOP_VECTORS[dir];
			var checkingQ:int = bishop.x + activeVector.x;
			var checkingR:int = bishop.y + activeVector.y;
			
			while (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
			
				if( HexBoard[checkingQ][checkingR] == 0):
					legalMoves[bishop][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[bishop][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					
					#King Escape Fix
					if(getPieceType(HexBoard[checkingQ][checkingR]) == PIECES.KING):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						#print("King Escape %d %d" % [checkingQ, checkingR]);
						if(HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
							updateAttackBoard(checkingQ, checkingR, 1);
					
					break;
				else:
					
					var pos = Vector2i(checkingQ,checkingR);
					if(influencedPieces.has(pos)):
						influencedPieces[pos].append(bishop);
					else:
						influencedPieces[pos] = [bishop];
					
					updateAttackBoard(checkingQ, checkingR, 1);
					break;
				
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
				##END WHILE	
	
		## Not Efficient FIX LATER
		if(  blockingPieces.has(bishop) ):
			var newLegalmoves = blockingPieces[bishop];
			for moveType in legalMoves[bishop].keys():
				legalMoves[bishop][moveType] = intersectOfTwoArrays(newLegalmoves, legalMoves[bishop][moveType]);
		
		## Not Efficient FIX LATER
		if( GameInCheck ):
			for moveType in legalMoves[bishop].keys():
				legalMoves[bishop][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[bishop][moveType]);

	return;

## Calculate Queen Moves
func findMovesForQueen(QueenArray:Array) -> void:
	
	var tempMoves:Dictionary = {};
	
	findMovesForRook(QueenArray);
	for i in range(QueenArray.size()):
		var queen = QueenArray[i];
		tempMoves[queen] = legalMoves[queen].duplicate(true);

	findMovesForBishop(QueenArray);
	for i in range(QueenArray.size()):
		var queen = QueenArray[i];

		for moveType in tempMoves[queen].keys():
			for move in tempMoves[queen][moveType]:
				legalMoves[queen][moveType].append(move);
	return;

## Calculate King Moves
func findMovesForKing(KingArray:Array) -> void:
	for i in range(KingArray.size()):
		var king = KingArray[i];
		legalMoves[king] = DEFAULT_MOVE_TEMPLATE.duplicate(true);

		for dir in KING_VECTORS.keys():
			var activeVector:Vector2i = KING_VECTORS[dir];
			var checkingQ:int = king.x + activeVector.x;
			var checkingR:int = king.y + activeVector.y;
			
			if(HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR)):
				updateAttackBoard(checkingQ, checkingR, 1);
				if(isWhiteTurn):
					if((BlackAttackBoard[checkingQ][checkingR] > 0)):
						continue;
				else:
					if((WhiteAttackBoard[checkingQ][checkingR] > 0)):
						continue;

				if( HexBoard[checkingQ][checkingR] == PIECES.ZERO ):
					legalMoves[king][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[king][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
		
		## Not Efficient FIX LATER
		if( GameInCheck ):
			legalMoves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[king][MOVE_TYPES.CAPTURE]);
			for moveType in legalMoves[king]:
				if(moveType == MOVE_TYPES.CAPTURE): continue;
				legalMoves[king][moveType] = differenceOfTwoArrays(legalMoves[king][moveType], GameInCheckMoves);

	return;

## Find the legal moves for a single player given an array of pieces
func findLegalMovesFor(activepieces:Array) -> void:
	
	var pieces:Dictionary = activepieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK];
	for pieceType in pieces.keys():
		
		var singleTypePieces:Array = pieces[pieceType];
		
		if singleTypePieces.size() == 0:
			continue;
			
		match pieceType:
			PIECES.PAWN:findMovesForPawn(singleTypePieces);
			PIECES.KNIGHT:findMovesForKnight(singleTypePieces);
			PIECES.ROOK:findMovesForRook(singleTypePieces);
			PIECES.BISHOP:findMovesForBishop(singleTypePieces);
			PIECES.QUEEN:findMovesForQueen(singleTypePieces);
			PIECES.KING:findMovesForKing(singleTypePieces);
	return;


## Check if an active piece appears in the capture moves of any piece.
func checkIFCordsUnderAttack(Cords:Vector2i, enemyMoves:Dictionary) -> bool:
	for piece:Vector2i in enemyMoves.keys():
		for move in enemyMoves[piece][MOVE_TYPES.CAPTURE]:
			if(move == Cords):
				return true;
		if(enemyMoves[piece].size() == 4):
			for move in enemyMoves[piece][MOVE_TYPES.PROMOTE]:
				if(move == Cords):
					return true;
	return false;
	
## Check what piece contains in their capture moves the cords piece.
func checkWHERECordsUnderAttack(Cords:Vector2i, enemyMoves:Dictionary) -> Vector2i:
	for piece:Vector2i in enemyMoves.keys():
		for move in enemyMoves[piece][MOVE_TYPES.CAPTURE]:
			if(move == Cords):
				return piece;
	return Vector2i();


##
func searchForPawnsAtk(pos:Vector2i, isWTurn:bool) -> Array:
	var leftCaptureR:int = 0 if isWTurn else  1;
	var rightCaptureR:int = -1 if isWTurn else 0;
	var qpos:int = pos.x - 1;
	var lst:Array = [];
	if( HexBoard.has(qpos) && HexBoard[qpos].has(leftCaptureR)):
		if(!isPieceFriendly(HexBoard[qpos][leftCaptureR], isWTurn)):
			if(getPieceType(HexBoard[qpos][leftCaptureR]) == PIECES.PAWN):
				lst.append(Vector2i(qpos, leftCaptureR));
	qpos = pos.x + 1;
	if( HexBoard.has(qpos) && HexBoard[qpos].has(rightCaptureR)):
		if(!isPieceFriendly(HexBoard[qpos][rightCaptureR], isWTurn)):
			if(getPieceType(HexBoard[qpos][rightCaptureR]) == PIECES.PAWN):
				lst.append(Vector2i(qpos, rightCaptureR));
	return lst;

##
func searchForKnightsAtk(pos:Vector2i, isWTurn:bool) -> Array:
	var lst:Array = [];
	var invertAt2Counter = 0;
	for m in [-1,1,-1,1]:
		for dir in KNIGHT_VECTORS.keys():
			var activeVector:Vector2i = KNIGHT_VECTORS[dir];
			var checkingQ = pos.x + ((activeVector.x if (invertAt2Counter < 2) else activeVector.y) * m);
			var checkingR = pos.y + ((activeVector.y if (invertAt2Counter < 2) else activeVector.x) * m);
			if (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR)):
				if(!isPieceFriendly(HexBoard[checkingQ][checkingR], isWTurn)):
					if(getPieceType(HexBoard[checkingQ][checkingR]) == PIECES.KNIGHT):
						lst.append(Vector2i(checkingQ, checkingR));
	return lst;

##	
func searchForSlidingAtk(pos:Vector2i, isWTurn:bool, checkForQueens:bool, initPiece:PIECES, VECTORS) -> Array:
	var lst:Array = [];
	var checkFor:Array = [initPiece];
	if(checkForQueens):
		checkFor.append(PIECES.QUEEN);
	
	for dir in VECTORS.keys():
		var activeVector:Vector2i = VECTORS[dir];
		var checkingQ:int = pos.x + activeVector.x;
		var checkingR:int = pos.y + activeVector.y;
		
		while (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
			if (HexBoard[checkingQ][checkingR] == 0): pass;
			elif (!isPieceFriendly(HexBoard[checkingQ][checkingR], isWTurn )):
				if (getPieceType(HexBoard[checkingQ][checkingR]) in checkFor):
					lst.append(Vector2i(checkingQ, checkingR));
				break;
			else: ## Blocked by friendly
				break;
			checkingQ += activeVector.x;
			checkingR += activeVector.y;
	return lst;

## (WIP) Search the board for attacking pieces on FROM cords
func searchForMyAttackers(from:Vector2i, isWhiteTrn:bool) -> Array:
	var side = SIDES.BLACK if isWhiteTrn else SIDES.WHITE;
	var hasQueens = activePieces[side][PIECES.QUEEN].size() > 0;
	var attackers:Array = [];
	if (activePieces[side][PIECES.PAWN].size() > 0): 
		attackers.append_array(searchForPawnsAtk(from, isWhiteTrn));
	if (activePieces[side][PIECES.KNIGHT].size() > 0):
		attackers.append_array(searchForKnightsAtk(from, isWhiteTrn));
	if (activePieces[side][PIECES.ROOK].size() > 0 or hasQueens): 
		attackers.append_array(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.ROOK, ROOK_VECTORS));
	if (activePieces[side][PIECES.BISHOP].size() > 0 or hasQueens): 
		attackers.append_array(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.BISHOP, BISHOP_VECTORS));
	return attackers;


### ATTACK BOARD


## Based on the turn determine the appropriate board to update.
func updateAttackBoard(q:int, r:int, mod:int) -> void:
	if(isWhiteTurn):
		WhiteAttackBoard[q][r] += mod;
	else:
		BlackAttackBoard[q][r] += mod;
	return;

## Based on the turn determine the appropriate board to update.
func updateOpposingAttackBoard(q:int, r:int, mod:int) -> void:
	if(!isWhiteTurn):
		WhiteAttackBoard[q][r] += mod;
	else:
		BlackAttackBoard[q][r] += mod;
	return;

##
func removePawnAttacks(cords:Vector2i) -> void:
	##FIX
	var leftCaptureR = cords.y if isWhiteTurn else cords.y + 1;
	var rightCaptureR = cords.y-1 if isWhiteTurn else cords.y;
	
	##Left Capture
	if( HexBoard.has(cords.x-1) && HexBoard[cords.x-1].has(leftCaptureR)):
		updateAttackBoard(cords.x-1, leftCaptureR, -1);
	##Right Capture
	if( HexBoard.has(cords.x+1) && HexBoard[cords.x+1].has(rightCaptureR)):
		updateAttackBoard(cords.x+1, rightCaptureR, -1);
	return;

## 
func removeAttacksFrom(cords:Vector2i, id:PIECES) -> void:
	
	if(id == PIECES.PAWN):
		removePawnAttacks(cords);
		return;
			
	for moveType in legalMoves[cords].keys():
		for move in legalMoves[cords][moveType]:
			updateAttackBoard(move.x,move.y,-1);
	
	return;

##
func removeCapturedFromATBoard(pieceType:PIECES, cords:Vector2i):
	isWhiteTurn = !isWhiteTurn;
	
	var movedPiece = [{ pieceType : [Vector2i(cords)] }];
	if(isWhiteTurn):
		movedPiece.insert(0, {});
		
	var savedMoves = legalMoves.duplicate(true);
	legalMoves.clear();
	findLegalMovesFor(movedPiece);
	removeAttacksFrom(cords, pieceType);
	legalMoves = savedMoves;
	
	isWhiteTurn = !isWhiteTurn;
	return;


### In CHECK MOVES


# 
func fillRookCheckMoves(kingCords:Vector2i, moveToCords:Vector2i):
	var deltaQ = kingCords.x - moveToCords.x;
	var deltaR = kingCords.y - moveToCords.y;
	var direction:Vector2i = Vector2i(0,0);

	if(deltaQ > 0):
		direction.x = 1;
	elif (deltaQ < 0):
		direction.x = -1;
	
	if(deltaR > 0):
		direction.y = 1;
	elif (deltaR < 0):
		direction.y = -1;

	while( true ):
		
		GameInCheckMoves.append(moveToCords);
		moveToCords.x += direction.x;
		moveToCords.y += direction.y;

		if ( HexBoard.has(moveToCords.x) && HexBoard[moveToCords.x].has(moveToCords.y)	):
			if(HexBoard[moveToCords.x][moveToCords.y] != 0):
				break;
		else: break;
	return;

#
func fillBishopCheckMoves(kingCords:Vector2i, moveToCords:Vector2i):
	var deltaQ = kingCords.x - moveToCords.x;
	var deltaR = kingCords.y - moveToCords.y;
	var direction:Vector2i = Vector2i(0,0);

	if(deltaQ > 0):
		if(deltaR < 0):
			if(abs(deltaQ) < abs(deltaR)):
				direction = Vector2i(1,-2);
			else:
				direction = Vector2i(2,-1);
		elif (deltaR > 0):
			direction = Vector2i(1,1);

	elif (deltaQ < 0):
		if(deltaR > 0):
			if(abs(deltaQ) < abs(deltaR)):
				direction = Vector2i(-1,2);
			else:
				direction = Vector2i(-2,1);
		elif (deltaR < 0):
			direction = Vector2i(-1,-1);
		
	while( true ):

		GameInCheckMoves.append(moveToCords);
		moveToCords.x += direction.x;
		moveToCords.y += direction.y;

		if ( HexBoard.has(moveToCords.x) && HexBoard[moveToCords.x].has(moveToCords.y)	):
			if(HexBoard[moveToCords.x][moveToCords.y] != 0):
				break;
		else: break;
	return;

##
# SUB Routine
func fillInCheckMoves(pieceType:PIECES, cords:Vector2i, kingCords:Vector2i, clear:bool):
	GameInCheckFrom = Vector2i(cords.x, cords.y);
	if clear: GameInCheckMoves.clear();
	GameInCheck = true;
	
	match pieceType:
		PIECES.KING:
			pass; # No Blocking Moves
		PIECES.PAWN, PIECES.KNIGHT: # Can not be blocked
			GameInCheckMoves.append(cords);
		PIECES.ROOK:
			fillRookCheckMoves(kingCords, cords);
		PIECES.BISHOP:
			fillBishopCheckMoves(kingCords, cords);
		PIECES.QUEEN:
			if(
				(cords.x == kingCords.x) or # same Q
					(cords.y == kingCords.y) or # same R
					(cords.x+cords.y) == (kingCords.x+kingCords.y) ): # same s
				fillRookCheckMoves(kingCords, cords);
			else:
				fillBishopCheckMoves(kingCords, cords);
	pass;


### 


##
func resetFlags() -> void:
	GameInCheck = false;
	captureValid = false;
	EnPassantCordsValid = false;
	return;

##
func handleMoveCapture(moveTo, pieceType) -> bool:
	captureType = getPieceType(HexBoard[moveTo.x][moveTo.y]);
	captureValid = true;

	## ENPASSANT FIX
	var revertEnPassant:bool = false;
	if(pieceType == PIECES.PAWN && HexBoard[moveTo.x][moveTo.y] == 0):
		moveTo.y += 1 if isWhiteTurn else -1;
		captureType = getPieceType(HexBoard[moveTo.x][moveTo.y]);
		HexBoard[moveTo.x][moveTo.y] = 0;
		revertEnPassant = true;

	var i:int = 0;
	for pieceCords in activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE][captureType]:
		if(moveTo == pieceCords):
			captureIndex = i;
			break;
		i = i+1;
	activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE][captureType].remove_at(i);

	removeCapturedFromATBoard(captureType, moveTo);

	## ENPASSANT FIX
	if(revertEnPassant):
		moveTo.y += -1 if isWhiteTurn else 1;

	#Add To Captures
	if(isWhiteTurn): whiteCaptures.append(captureType);
	else: blackCaptures.append(captureType);
	return revertEnPassant;

##
func handleMove(cords:Vector2i, moveType, moveIndex:int, promoteTo:PIECES) -> void:
	var pieceVal:int = HexBoard[cords.x][cords.y]
	var previousPieceVal = pieceVal;
	var selfColor:int = SIDES.WHITE if isWhiteTurn else SIDES.BLACK;
	var pieceType:PIECES = getPieceType(pieceVal);
	var moveTo = legalMoves[cords][moveType][moveIndex];
	var moveHistMod = "";

	HexBoard[cords.x][cords.y] = PIECES.ZERO;

	match moveType:
		MOVE_TYPES.PROMOTE:
			
			if(moveTo.x != cords.x):
				handleMoveCapture(moveTo, pieceType);
				moveHistMod = "/%d,%d" % [captureType,captureIndex];
			
			var i:int = 0;
			for pieceCords in activePieces[selfColor][pieceType]:
				if(cords == pieceCords):
					break;
				i = i+1;
			
			activePieces[selfColor][pieceType].remove_at(i);
			pieceType = getPieceType(promoteTo);
			pieceVal = getPieceInt(pieceType, !isWhiteTurn);
			activePieces[selfColor][pieceType].push_back(moveTo);

			moveHistMod = moveHistMod + (" +%s,%d" % [pieceType, i]);
			pass;

		MOVE_TYPES.ENPASSANT:
			var newECords = legalMoves[cords][MOVE_TYPES.ENPASSANT][0];
			EnPassantCords = Vector2i(newECords.x,newECords.y + (1 if isWhiteTurn else -1));
			EnPassantTarget = moveTo;
			EnPassantCordsValid = true;
			
			moveHistMod = "E";
			pass;

		MOVE_TYPES.CAPTURE:
			if handleMoveCapture(moveTo, pieceType):
				moveHistMod = "-%d,%d" % [captureType,captureIndex];
			else:
				moveHistMod = "/%d,%d" % [captureType,captureIndex];
			pass;

		MOVE_TYPES.MOVES: pass;

	HexBoard[moveTo.x][moveTo.y] = pieceVal;

	var histPreview = ("%s %s %s %s" % [pieceVal,encodeEnPassantFEN(cords.x,cords.y),encodeEnPassantFEN(moveTo.x,moveTo.y),moveHistMod]);
	
	# Update Piece List
	for i in range(activePieces[selfColor][pieceType].size()):
		if (activePieces[selfColor][pieceType][i] == cords):
			activePieces[selfColor][pieceType][i] = moveTo;
			break;

	removeAttacksFrom(cords, getPieceType(previousPieceVal));
	
	handleMoveState(moveTo, cords, histPreview);

	return;

func _restoreFrozenState(state:FrozenState, moves:Dictionary):
	WhiteAttackBoard = state.WABoard.duplicate(true);
	BlackAttackBoard = state.BABoard.duplicate(true);
	blockingPieces = state.BPieces.duplicate(true);
	influencedPieces = state.IPieces.duplicate(true);
	legalMoves = moves.duplicate(true);
	return;

func _restoreState(WABoard:Dictionary, BABoard:Dictionary, BPieces:Dictionary, IPieces:Dictionary, moves:Dictionary):
	WhiteAttackBoard = WABoard.duplicate(true);
	BlackAttackBoard = BABoard.duplicate(true);
	blockingPieces = BPieces.duplicate(true);
	influencedPieces = IPieces.duplicate(true);
	legalMoves = moves.duplicate(true);
	return;

##
func _getFrozenState():
	return FrozenState.new(WhiteAttackBoard,BlackAttackBoard,blockingPieces,influencedPieces);
##
func _duplicateWAB():
	return WhiteAttackBoard.duplicate(true);

##
func _duplicateBAB():
	return BlackAttackBoard.duplicate(true);
	
##
func _duplicateBP():
	return blockingPieces.duplicate(true);
	
##
func _duplicateIP():
	return influencedPieces.duplicate(true);

## SUB Routine
func generateNextLegalMoves():
	if(isWhiteTurn):
		resetBoard(WhiteAttackBoard);
	else:
		resetBoard(BlackAttackBoard);
	
	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	influencedPieces.clear();
	findLegalMovesFor(activePieces);
	
	pass;

## SUB Routine
func setupActiveForSingle(type:PIECES, cords:Vector2i, lastCords:Vector2i):
	var movedPiece = [{ type : [Vector2i(cords)] }];
	
	if (influencedPieces.has(lastCords)):
		for item in influencedPieces[lastCords]:
			var inPieceType = getPieceType(HexBoard[item.x][item.y]);
			if movedPiece[0].has(inPieceType):
				movedPiece[0][inPieceType].append(item);
			else:
				movedPiece[0][inPieceType] = [item];
	
	if(isWhiteTurn):
		movedPiece.insert(0, {});
		
	return movedPiece;

##
func handleMoveState(cords:Vector2i, lastCords:Vector2i, historyPreview:String):
	var pieceType:PIECES = getPieceType(HexBoard[cords.x][cords.y]);
	var movedPiece = setupActiveForSingle(pieceType, cords, lastCords);
	var kingCords:Vector2i = activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE][PIECES.KING][0];
	var mateStatus = "";

	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	findLegalMovesFor(movedPiece);

	if(checkIFCordsUnderAttack(kingCords, legalMoves)):
		mateStatus = "C"
		fillInCheckMoves(pieceType, cords, kingCords, true);
		
		#print(('black' if isWhiteTurn else 'white').to_upper(), " is in check.");
		#print("Game In Check Moves: ", GameInCheckMoves);

	incrementTurnNumber();
	swapPlayerTurn();
	generateNextLegalMoves()

	var pieceCount = 0; 
	for side in activePieces:
		for type in side.keys():
			for piece in side[type]:
				pieceCount+=1;
				
	if(pieceCount <= 2):
		GameIsOver = true;

	## Check For Mate and Stale Mate	
	var moveCount = countMoves(legalMoves);
	if( moveCount <= 0):
		mateStatus = "O"
		if(GameInCheck):
			#print("Check Mate")
			pass;
		else:
			#print("Stale Mate")
			pass;
		
		GameIsOver = true;
	
	moveHistory.append("%s %s" % [historyPreview, mateStatus])
	return;


### UNDO


##
# SUB Routine
func undoSubCleanFlags(splits:PackedStringArray, from:Vector2i, to:Vector2i):
	var i = 3;
	while (i < splits.size()):
		var flag:String = splits[i];
		match flag:
			"":
				i += 1;
				continue;
			"C":
				GameInCheck = false;
			"O":
				GameIsOver = false;
			"E":
				EnPassantCordsValid = false;
				
			_ when flag[0] == '/':
				var cleanFlag:String = flag.get_slice('/', 1);
				var idAndIndex = cleanFlag.split(',');
				var id = int(idAndIndex[0]);
				var index = int(idAndIndex[1]);
				if(index > 20):
					print();
					pass;
				HexBoard[to.x][to.y] = getPieceInt(id, isWhiteTurn) ;
				if (OK != activePieces\
				[SIDES.BLACK if isWhiteTurn else SIDES.WHITE]\
				[id]\
				.insert( index, Vector2i(to) )):
					print("0Failed TO Insert: ", index, " size:", activePieces\
				[SIDES.BLACK if isWhiteTurn else SIDES.WHITE]\
				[id].size());
				uncaptureValid = true;
				@warning_ignore("int_as_enum_without_cast")
				captureType = id;
				captureIndex = index;

			_ when flag[0] == '-':
				var cleanFlag:String = flag.get_slice('-', 1);
				var idAndIndex = cleanFlag.split(',');
				
				var id = int(idAndIndex[0]);
				var index = int(idAndIndex[1]);
			
				to.y += 1 if isWhiteTurn else -1;
				
				HexBoard[to.x][to.y] = getPieceInt(id, isWhiteTurn);
				activePieces\
				[SIDES.BLACK if isWhiteTurn else SIDES.WHITE]\
				[id]\
				.insert( index, Vector2i(to) );

				uncaptureValid = true;
				@warning_ignore("int_as_enum_without_cast")
				captureType = id;
				captureIndex = index;
				#signal gui // finished?

			_ when flag[0] == '+':
				var cleanFlag:String = flag.get_slice('+', 1);
				var idAndIndex = cleanFlag.split(',');
				var id = int(idAndIndex[0]);
				var index = int(idAndIndex[1]);
				
				HexBoard[from.x][from.y] = getPieceInt(PIECES.PAWN, !isWhiteTurn);
				
				activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][id].pop_back(); ## WILL MAYBE FAIL IF MULTIPLE PROMOTIONS HAPPEN
				activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.PAWN].insert( index, Vector2i(from) )
				unpromoteValid = true;
				@warning_ignore("int_as_enum_without_cast")
				unpromoteType = id;
				unpromoteIndex = index;
		i += 1;
		continue;

##
# SUB Routine
# Moves should be generated by caller function afterwards
func undoSubFixState():
	#Early Escape
	if(moveHistory.size() <= 0):
		return;
		
	var currentMove = moveHistory[moveHistory.size()-1];
	var splits = currentMove.split(" ");
	var i = 3;
	while (i < splits.size()):
		var flag = splits[i];
		match flag:
			"C":
				# GET IN CHECK DATA
				var kingCords:Vector2i = activePieces[SIDES.BLACK if !isWhiteTurn else SIDES.WHITE][PIECES.KING][KING_INDEX];
				var attacker = searchForMyAttackers(kingCords, isWhiteTurn);
				
				GameInCheckMoves.clear();
				GameInCheck = true;
				
				for atk in attacker:
					var pieceType:PIECES = getPieceType(HexBoard[atk.x][atk.y]);
					fillInCheckMoves(pieceType, atk, kingCords, false);
				
				# GET IN CHECK DATA
				pass;
				
			"E":
				#print("Undo onto EnPassant")
				EnPassantCordsValid = true;
				# GET EnPASSANT DATA
				var from:Vector2i = decodeEnPassantFEN(splits[1]);
				var to:Vector2i = decodeEnPassantFEN(splits[2]);
				var side = SIDES.BLACK if ((from - to).y) < 0 else SIDES.WHITE;
				EnPassantTarget = to;
				EnPassantCords = Vector2i(to.x, to.y - (1 if side == SIDES.BLACK else -1));
				# GET EnPASSANT DATA
				pass;
			
			_: pass;
		i += 1;
	pass;


### UTILITY


##
func getSAxialCordFrom(cords:Vector2i) -> int:
	return (-1 * cords.x) - cords.y;

func getAxialCordDist(from:Vector2i,to:Vector2i):
	var dif = Vector3i(from.x-to.x, from.y-to.y, getSAxialCordFrom(from)-getSAxialCordFrom(to));
	return max(abs(dif.x),abs(dif.y),abs(dif.z));

##
func printActivePieces():
	for side in activePieces.size():
		print(SIDES.find_key(side))
		for piece in activePieces[side]:
			print(PIECES.find_key(piece), " : ", activePieces[side][piece]);
		print("");

## set all values of given board to zero.
func resetBoard(board:Dictionary) -> void:
	for key in board.keys():
		for innerKey in board[key].keys():
			board[key][innerKey] = 0;
	return;

## Count the amount of moves found
func countMoves(movesList:Dictionary) -> int:
	var count:int = 0;
	
	for piece:Vector2i in movesList.keys():
		for moveType in movesList[piece]:
			for move:Vector2i in movesList[piece][moveType]:
				count += 1;
	
	return count;

## Find Intersection Of Two Arrays. O(N^2)
func intersectOfTwoArrays(ARR:Array, ARR1:Array):
	var intersection = [];
	for item in ARR:
		if (ARR1.has(item)):
			intersection.append(item);
	return intersection;

## Find Items Unique Only To ARR. O(N^2)
func differenceOfTwoArrays(ARR:Array, ARR1:Array):
	var intersection = [];
	for item in ARR:
		if ( not ARR1.has(item)):
			intersection.append(item);
	return intersection;

## Print HexBoard 
func printBoard(board: Dictionary):
	var flipedKeys = board.keys();
	flipedKeys.reverse();
	for key in flipedKeys:
		var rowString = [];
		var offset = 12 - board[key].size();
		for i in range(offset):
			rowString.append("  ");

		for innerKey in board[key].keys():
			if board[key][innerKey] == 0:
				rowString.append( "   " )
			else:
				rowString.append( str((" %02d" % board[key][innerKey] )) )
			rowString.append(", ");
		print("\n","".join(rowString),"\n");
	return;

##
func debugPrintOne(run:bool) -> void:
	if(!run):
		return;
	print("Board : ")
	printBoard(HexBoard);
	print("W.A.B. : ")
	printBoard(WhiteAttackBoard);
	print("B.A.B. : ")
	printBoard(BlackAttackBoard);
	return;

##
func debugPrintTwo(run:bool) -> void:
	if(!run):
		return;
	print("History: \n", moveHistory[moveHistory.size()-1], "\n");
	print("Active Pieces: \n", activePieces, "\n");
	print("HexBoard: ")
	printBoard(HexBoard)
	print("\n\n")
	return;

##
func debugPrintThree(run:bool) -> void:
	if(!run):
		return;
	print("Moves:")
	for key in legalMoves.keys():
		print(key, " : ", legalMoves[key]);
	print("\n\n")
	return;


## initiate the engine with a new game
func initiateEngine(FEN_STRING) -> bool:
	HexBoard = fillBoardwithFEN(FEN_STRING);
	if HexBoard == {}:
		print("Invalid FEN");
		return false;
	
	bypassMoveLock = false;
	
	WhiteAttackBoard = createBoard(HEX_BOARD_RADIUS);
	BlackAttackBoard = createBoard(HEX_BOARD_RADIUS);

	blackCaptures.clear();
	whiteCaptures.clear();
	legalMoves.clear();
	blockingPieces.clear();
	GameInCheckMoves.clear();

	GameIsOver = false;
	GameInCheck = false;
	captureValid = false;
	GameInCheckFrom = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
	
	### Should be removed when 'fillBoardwithFEN' can find TARGET
	EnPassantCordsValid = false;
	EnPassantCords = Vector2i(-5,-5);
	EnPassantTarget = Vector2i(-5,-5);
	###Should be removed when 'fillBoardwithFEN' can find TARGET
	
	activePieces = findPieces(HexBoard);
	findLegalMovesFor(activePieces);
	
	if(EnemyIsAI):
		match EnemyType:
			ENEMY_TYPES.RANDOM:
				EnemyAI = RandomAI.new(EnemyPlaysWhite);
			ENEMY_TYPES.MIN_MAX:
				EnemyAI = MinMaxAI.new(EnemyPlaysWhite, 2);
			ENEMY_TYPES.NN:
				EnemyAI = RandomAI.new(EnemyPlaysWhite);
				pass;
				
	return true;


###
##  API INTERACTIONS
###


# NON-GETTER FUNCTIONS


## Enemy is shorter than opponent
func _setEnemy(type:ENEMY_TYPES, isWhite:bool) -> void:
	EnemyType = type;
	if(EnemyType < ENEMY_TYPES.RANDOM):
		EnemyIsAI = false;
	else:
		EnemyIsAI = true;
	EnemyPlaysWhite = isWhite;
	return;

func _disableAIMoveLock():
	bypassMoveLock = false;
	return;
	
func _enableAIMoveLock():
	bypassMoveLock = true;
	return;

## MAKE MOVE PUBLIC CALL
func _makeMove(cords:Vector2i, moveType, moveIndex:int, promoteTo:PIECES) -> void:
	# TODO:: HANDLE INPROPER INPUT FEEDBACK
	if(GameIsOver or !legalMoves.has(cords) ):
		return;

	if(EnemyIsAI and ((EnemyPlaysWhite == isWhiteTurn) and bypassMoveLock)):
		print("NOT YOUR TURN")
		return

	#for key in legalMoves.keys():
	#	print(key, legalMoves[key]);
	#print("")

	resetFlags();
	handleMove(cords, moveType, moveIndex, promoteTo);
	
	debugPrintOne(false)
	debugPrintTwo(false);
	debugPrintThree(false);
	return;

## Pass To AI
func _passToAI() -> void:
	if(GameIsOver):
		return;
	
	EnemyAI._makeChoice(self);
	
	EnemyChoiceType = getPieceType(HexBoard[EnemyAI._getCords().x][EnemyAI._getCords().y])
	EnemyChoiceIndex = 0;
	for pieceCords in activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][EnemyChoiceType]:
		if(pieceCords == EnemyAI._getCords()): break;
		EnemyChoiceIndex += 1;
	
	EnemyTo = EnemyAI._getTo();
	EnemyPromoted = EnemyAI._getMoveType() == MOVE_TYPES.PROMOTE;
	EnemyPromotedTo = EnemyAI._getPromoteTo();
	
	resetFlags();
	handleMove(EnemyAI._getCords(), EnemyAI._getMoveType(), EnemyAI._getMoveIndex(), EnemyAI._getPromoteTo())
	
	debugPrintOne(false)
	debugPrintTwo(false);
	debugPrintThree(false);
	return;

## RESIGN PUBLIC 
func _resign():
	destroyBitBoards();
	if(GameIsOver):
		return;
		
	GameIsOver = true;
	print("%s WINS BY RESIGN" % ("White" if not isWhiteTurn else "Black"));
	print(moveHistory);
	return

## Undo Move PUBLIC CALL
func _undoLastMove(genMoves:bool=true) -> bool:
	if(moveHistory.size() < 1):
		return false;
	
	uncaptureValid = false;
	unpromoteValid = false;
	decrementTurnNumber();
	swapPlayerTurn();
	
	var currentMove:String = moveHistory.pop_back();
	var splits:PackedStringArray = currentMove.split(" ");
	
	var pieceVal:int = int(splits[0]);
	var UndoNewFrom:Vector2i = decodeEnPassantFEN(splits[1]);
	var UndoNewTo:Vector2i = decodeEnPassantFEN(splits[2]);
	
	var pieceType = getPieceType(pieceVal);
	var selfColor = SIDES.WHITE if isWhiteTurn else SIDES.BLACK;
	var index:int = 0;
	
	##Default Undo
	HexBoard[UndoNewFrom.x][UndoNewFrom.y] = pieceVal;
	HexBoard[UndoNewTo.x][UndoNewTo.y] = PIECES.ZERO;
	
	for pieceCords in activePieces[selfColor][pieceType]:
		if(pieceCords == UndoNewTo):
			activePieces[selfColor][pieceType][index] = UndoNewFrom;
			break;
		index += 1;
	
	#if (index < activePieces[selfColor][pieceType].size() ): # After a promotion pawn does not exist to move back

	undoType = pieceType;
	undoIndex = index;
	undoSubCleanFlags(splits, UndoNewFrom, UndoNewTo);
	undoSubFixState();
	
	if(genMoves):
		generateNextLegalMoves();
	return true;

## START DEFAULT GAME PUBLIC CALL
func _initDefault() -> bool:
	return initiateEngine(DEFAULT_FEN_STRING);


# GETTERS


##
func _getEnemyTo():
	return EnemyTo;

##
func _getEnemyChoiceType():
	return EnemyChoiceType;

##
func _getEnemyChoiceIndex():
	return EnemyChoiceIndex;

##
func _getEnemyType() -> ENEMY_TYPES:
	return EnemyType;

##
func _getEnemyIsWhite() -> bool:
	return EnemyPlaysWhite;

##
func _getIsEnemyAI() -> bool:
	return EnemyIsAI;

##
func _getEnemyPromoted() -> bool:
	return EnemyPromoted;

##
func _getEnemyPTo() -> PIECES:
	return EnemyPromotedTo;

## Get Is Game Over
func _getGameOverStatus() -> bool:
	return GameIsOver;

## Get Is White Turn
func _getIsWhiteTurn() -> bool:
	return isWhiteTurn;

## Get Is Black Turn
func _getIsBlackTurn() -> bool:
	return !isWhiteTurn;

## Get Active Pieces
func _getActivePieces() -> Array:
	return activePieces;

##	Get Moves
func _getMoves() -> Dictionary:
	return legalMoves;

## Get Game In Check 
func _getGameInCheck() -> bool:
	return GameInCheck;

## Get Capture Valid
func _getCaptureValid() -> bool:
	return captureValid;

## Get Capture Type
func _getCaptureType() -> PIECES:
	return captureType;

## Get Capture Index
func _getCaptureIndex() -> int:
	return captureIndex;

## Get Uncapture Valid Flag
func _getUncaptureValid() -> bool:
	return uncaptureValid;

## Get Unpromote Valid Flag
func _getUnpromoteValid() -> bool:
	return unpromoteValid;

## Get Unpromote Type
func _getUnpromoteType() -> PIECES:
	return unpromoteType;

## Get Unpromote Index
func _getUnpromoteIndex() -> int:
	return unpromoteIndex;

## Get Undo Type
func _getUndoType() -> PIECES:
	return undoType;

## Get Undo Index
func _getUndoIndex() -> int:
	return undoIndex;

##
func _getMoveHistorySize() -> int:
	return moveHistory.size();
