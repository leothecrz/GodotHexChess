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
	#Vectors
const ROOK_VECTORS   = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0) };
const BISHOP_VECTORS = { 'lfoward':Vector2i(-2,1), 'rFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'lbackward':Vector2i(1,1), 'rBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KING_VECTORS   = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0), 'dlfoward':Vector2i(-2,1), 'drFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'dlbackward':Vector2i(1,1), 'drBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KNIGHT_VECTORS = { 'left':Vector2i(-1,-2), 'lRight':Vector2i(1,-3), 'rRight':Vector2i(2,-3),}
	#Templates
const DEFAULT_MOVE_TEMPLATE : Dictionary = { MOVE_TYPES.MOVES:[], MOVE_TYPES.CAPTURE:[],  };
const PAWN_MOVE_TEMPLATE : Dictionary    = { MOVE_TYPES.MOVES:[], MOVE_TYPES.CAPTURE:[], MOVE_TYPES.ENPASSANT:[], MOVE_TYPES.PROMOTE:[], };
	#UNSET
const DECODE_FEN_OFFSET = 70;
const TYPE_MASK = 0b0111;
const PAWN_QS = [-4,-3,-2,-1,0,1,2,3,4,5];


### State


# Board
var HexBoard : Dictionary         = {};
var WhiteAttackBoard : Dictionary = {};
var BlackAttackBoard : Dictionary = {};

#BitBoard
var WHITE_BB:Array;
var BLACK_BB:Array;
var BIT_WHITE:BitBoard;
var BIT_BLACK:BitBoard;
var BIT_ALL:BitBoard;

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

var EnemyIsAI:bool = false;
var EnemyPlaysWhite:bool = false;
var EnemyPromoted:bool =  false;
var bypassMoveLock:bool = false;

var EnemyChoiceType:int;
var EnemyChoiceIndex:int;
var EnemyTo:Vector2i;

# History
var moveHistory : Array = [];

### BITBOARD
var startTime:int;
var stopTime:int;

##
func createBitBoards() -> void:
	WHITE_BB.clear();
	BLACK_BB.clear();
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
	BIT_BLACK.free();
	BIT_WHITE.free();
	BIT_ALL.free();
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
func getAllPiecesBitBoard() -> BitBoard:
	var returnBoard = BitBoard.new(0,0);
	var tempBoard;
	
	for BB in BLACK_BB:
		tempBoard = returnBoard.OR(BB);
		returnBoard.free();
		returnBoard = tempBoard;
		
	for BB in WHITE_BB:
		tempBoard = returnBoard.OR(BB);
		returnBoard.free();
		returnBoard = tempBoard;
	return returnBoard;

## Get the index of (q,r)
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

##
func IndexToQR(index: int) -> Vector2i:
	var accumulated_index:int = 0;
	var normalq:int = 0;
	
	for size in BitBoard.COLUMN_SIZES:
		if( accumulated_index + size > index ): break;
		accumulated_index += size;
		normalq += 1;
	
	var r: int;
	if( normalq <= 5 ):
		r = 5 - (index - accumulated_index)
	else:
		r = (BitBoard.COLUMN_SIZES[normalq] - 6) - (index - accumulated_index)
	
	var q = normalq - 5
	return Vector2i(q, r)

## QUICK Powers of 2
func get2PowerN(n:int) -> int:
	return 1 << n;

##
func add_IPieceToBitBoardsOf(q:int, r:int, piece:int, iswhite:bool) -> void:
	var index = QRToIndex(q,r);
	var type = getPieceType(piece);
	var insert = createSinglePieceBB(index);
	
	if(iswhite):
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
func add_IPieceToBitBoards(q:int, r:int, piece:int) -> void:
	add_IPieceToBitBoardsOf(q, r, piece, isPieceWhite(piece));
	return;

##
func addS_PieceToBitBoards(q:int, r:int, c:String) -> void:
	var isBlack = true;
	if(c == c.to_upper()):
		isBlack = false;
		c = c.to_lower();
	var piece = PIECES.ZERO;
	match c:
		"p": piece = PIECES.PAWN;
		"n": piece = PIECES.KNIGHT;
		"r": piece = PIECES.ROOK;
		"b": piece = PIECES.BISHOP;
		"q": piece = PIECES.QUEEN;
		"k": piece = PIECES.KING;
	add_IPieceToBitBoards(q,r, getPieceInt(piece, isBlack));
	return;

##
func createSinglePieceBB(index:int) -> BitBoard:
	var back = 0;
	var front = 0;
	if(index > BitBoard.INDEX_TRANSITION):
		front = get2PowerN( index - BitBoard.INDEX_OFFSET );
		back = 0;
	else:
		back = get2PowerN( index );
	return BitBoard.new(front,back);

##
func clearCombinedBIT() -> void:
	BIT_ALL.free();
	BIT_BLACK.free();
	BIT_WHITE.free();
	return;

##
func calculateCombinedBIT() -> void:
	BIT_WHITE = getWhitePiecesBitBoard();
	BIT_BLACK = getBlackPiecesBitBoard();
	BIT_ALL = BIT_WHITE.OR(BIT_BLACK);
	#print("White BB:\n", BIT_WHITE);
	#print("White:");
	#for bb in WHITE_BB:
		#print(bb);
	#print(" ")
	#print("Black BB:\n", BIT_BLACK);
	#print("Black:");
	#for bb in BLACK_BB:
		#print(bb);
	#print("ALL BB:\n", BIT_ALL);
	#print("\n")
	return;

## Assumes that a piece exist in the given index
func bbIsPieceWhite(index:int) -> bool:
	var check = createSinglePieceBB(index);
	var result = BIT_WHITE.AND(check);
	var status = result.IS_EMPTY();
	result.free();
	check.free();
	if(status):
		return false;
	return true;

##
func bbIsIndexEmpty(index:int) -> bool:
	var temp:BitBoard = createSinglePieceBB(index);
	var result:BitBoard = temp.AND(BIT_ALL);
	var status:bool = result.IS_EMPTY();
	
	
	result.free();
	temp.free();
	return status;

## Assumes Piece Exists
func bbPieceTypeOf(index:int, isWhiteTrn:bool) -> PIECES:
	var i = 0;
	var temp:BitBoard = createSinglePieceBB(index);
	var opponentBitBoards:Array = BLACK_BB if isWhiteTrn else WHITE_BB;

	for bb:BitBoard in opponentBitBoards:
		i += 1
		var result:BitBoard = temp.AND(bb);
		var status = result.IS_EMPTY();
		result.free();
		if (not status) : break;
	
	temp.free();
	return i;

##
func bbClearIndexFrom(index:int, isWhite:bool):
	var type:PIECES = bbPieceTypeOf(index, !isWhite);
	var activeBoard:Array = WHITE_BB if isWhite else BLACK_BB;
	var mask = createSinglePieceBB(index);
	var result = activeBoard[type-1].XOR(mask);
	mask.free();
	activeBoard[type-1].free();
	activeBoard[type-1] = result;
	return;

##
func bbClearIndexOf(index:int, isWhite:bool, type:PIECES):
	var activeBoard:Array = WHITE_BB if isWhite else BLACK_BB;
	var mask = createSinglePieceBB(index);
	var result = activeBoard[type-1].XOR(mask);
	mask.free();
	activeBoard[type-1].free();
	activeBoard[type-1] = result;
	return;

func bbAddPieceOf(index:int, isWhite:bool, type:PIECES):
	var activeBoard = WHITE_BB if isWhite else BLACK_BB;
	var mask = createSinglePieceBB(index);
	var result = activeBoard[type-1].OR(mask);
	mask.free();
	activeBoard[type-1].free();
	activeBoard[type-1] = result;
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
func bbfindPieces() -> Array:
	var pieceCords:Array = \
	[
		{ PIECES.PAWN:[],PIECES.KNIGHT:[],PIECES.ROOK:[],PIECES.BISHOP:[],PIECES.QUEEN:[],PIECES.KING:[] },
		{ PIECES.PAWN:[],PIECES.KNIGHT:[],PIECES.ROOK:[],PIECES.BISHOP:[],PIECES.QUEEN:[],PIECES.KING:[] }
	];
	
	var type:int = 0;
	for bb:BitBoard in BLACK_BB:
		type += 1;
		var pieceIndexes:Array = bb._getIndexes();
		for i in pieceIndexes:
			pieceCords[SIDES.BLACK][type].append(IndexToQR(i));
	
	type = 0;
	for bb:BitBoard in WHITE_BB:
		type += 1;
		var pieceIndexes:Array = bb._getIndexes();
		for i in pieceIndexes:
			pieceCords[SIDES.WHITE][type].append(IndexToQR(i));
		
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
func fillBoardwithFEN(fenString: String) -> bool:
	#Board Status
	createBitBoards();
	
	var fenSections : PackedStringArray = fenString.split(" ");
	if (fenSections.size() != 4):
		print("Not Enough Fen Sections");
		return false;
		
	var BoardColumns : PackedStringArray = fenSections[0].split("/");
	if (BoardColumns.size() != 11):
		print("Not all Hexboard columns are defined");
		return false;
		
	var regex:RegEx = RegEx.new();
	regex.compile("(?i)([pnrbqk]|[0-9]|/)*")
	
	var result = regex.search(fenString);
	if (result):
		if( result.get_string() != fenSections[0] ):
			print(result.get_string());
			print(fenString);
			print("Invalid Board Description");
			return false;

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
					addS_PieceToBitBoards(q,r1,activeChar);
					r1 +=1 ;
				else:
					push_error("R1 Greater Than Max");
					return false;
	calculateCombinedBIT();
	
	#for bb:BitBoard in WHITE_BB:
		#print(bb._getIndexes());
	#
	#for bb:BitBoard in BLACK_BB:
		#print(bb._getIndexes());
	
	##Is White Turn
	if(fenSections[1] == 'w'):
		isWhiteTurn = true;
	elif (fenSections[1] == 'b'):
		isWhiteTurn = false;
	else:
		return false;

	#EnPassant Cords
	if(fenSections[2] != '-'):
		EnPassantCordsValid = true;
		EnPassantTarget = decodeEnPassantFEN(fenSections[2]);
		EnPassantCords = Vector2i(EnPassantTarget.x, EnPassantTarget.y + (-1 if isWhiteTurn else 1));
	else:
		EnPassantCords = Vector2i(-5,-5);
		EnPassantTarget = Vector2i(-5,-5);
		EnPassantCordsValid = false;

	## Turn Number
	turnNumber = fenSections[3].to_int()
	if(turnNumber < 1):
		turnNumber = 1;
		
	return true;


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
	#for q:int in range (-4,4+1):
	for q:int in PAWN_QS:
		if( q > 0 ):
			r -= 1;
		if (cords.x == q) && (cords.y == r):
			return true;
	return false;

## Check if cords are in the white pawn start
func isWhitePawnStar(cords:Vector2i) ->bool:
	var r:int = 5;
	#for q:int in range (-4,4+1):
	for q:int in PAWN_QS:
		if (cords.x == q) && (cords.y == r):
			return true;
		if( q < 0 ):
			r -= 1;
			
	return false;

##
func isWhitePawnPromotion(cords:Vector2i)-> bool:
	var r:int = 0;
	for q:int in PAWN_QS:
		
		if (cords.x == q) && (cords.y == r):
			return true;
		
		if(r > -5):
			r -= 1;
		
	return false;

##
func isBlackPawnPromotion(cords:Vector2i) -> bool:
	var r:int = 5;
	for q:int in PAWN_QS:
		
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

## Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
func bbcheckForBlockingOnVector(piece: PIECES, dirSet:Dictionary, bp:Dictionary, cords:Vector2i):
	var index = QRToIndex(cords.x,cords.y);
	var isWhiteTrn = bbIsPieceWhite(index);
	
	for direction in dirSet.keys():
		var LegalMoves:Array = [];
		
		var dirBlockingPiece:Vector2i;
		var activeVector:Vector2i = dirSet[direction];
		
		var checkingQ:int = cords.x + activeVector.x;
		var checkingR:int = cords.y + activeVector.y;
		
		while ( BitBoard.inBitBoardRange(checkingQ,checkingR) ):
			index = QRToIndex(checkingQ,checkingR);
			if( bbIsIndexEmpty(index) ):
				if(dirBlockingPiece):
					LegalMoves.append(Vector2i(checkingQ,checkingR)); ## Track legal moves for the blocking pieces
			else:
				if( bbIsPieceWhite(index) == isWhiteTrn ): # Friend Piece
					if(dirBlockingPiece): break; ## Two friendly pieces in a row. No Danger
					else: dirBlockingPiece = Vector2i(checkingQ,checkingR); ## First piece found

				else: ##Unfriendly Piece Found
					var val = bbPieceTypeOf(index, isWhiteTrn)
					if ( (val == PIECES.QUEEN) or (val == piece) ):
						if(dirBlockingPiece):
							LegalMoves.append(Vector2i(checkingQ,checkingR));
							bp[dirBlockingPiece] = LegalMoves; ## store blocking piece moves
					break;

			checkingQ += activeVector.x;
			checkingR += activeVector.y;
	return;

## Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
func bbcheckForBlockingPiecesFrom(cords:Vector2i) -> Dictionary:
	var blockingpieces:Dictionary = {};
	bbcheckForBlockingOnVector(PIECES.ROOK, ROOK_VECTORS, blockingpieces, cords);
	bbcheckForBlockingOnVector(PIECES.BISHOP, BISHOP_VECTORS, blockingpieces, cords);
	return blockingpieces;


## Calculate Pawn Capture Moves
func bbfindCaptureMovesForPawn(pawn : Vector2i, qpos : int, rpos : int ) -> void:
	if ( not BitBoard.inBitBoardRange(qpos, rpos) ):
		return;
		
	var move = Vector2i(qpos, rpos)
	var index = QRToIndex(qpos,rpos);
	
	if ( bbIsIndexEmpty(index) ):
		if( EnPassantCordsValid and (EnPassantCords.x == qpos) and (EnPassantCords.y == rpos) ):
			legalMoves[pawn][MOVE_TYPES.CAPTURE].append(move);
	else:
		if(bbIsPieceWhite(index) != isWhiteTurn):
			if ( isWhitePawnPromotion(move) if isWhiteTurn else isBlackPawnPromotion(move) ) :
				legalMoves[pawn][MOVE_TYPES.PROMOTE].append(move); ## PROMOTE CAPTURE
			else:
				legalMoves[pawn][MOVE_TYPES.CAPTURE].append(move);
	
	updateAttackBoard(qpos, rpos, 1);
	return;

## Calculate Pawn Foward Moves
func bbfindFowardMovesForPawn(pawn : Vector2i, fowardR : int ) -> void:
	var move:Vector2i = Vector2i(pawn.x,fowardR);
	var boolCanGoFoward:bool = false;
	##Foward Move
	if (BitBoard.inBitBoardRange(pawn.x, fowardR)):
		var index:int = QRToIndex(pawn.x,fowardR);
		if(bbIsIndexEmpty(index)):
			if ( isWhitePawnPromotion(move) if (isWhiteTurn) else isBlackPawnPromotion(move) ) :
				legalMoves[pawn][MOVE_TYPES.PROMOTE].append(move);
			else:
				legalMoves[pawn][MOVE_TYPES.MOVES].append(move);
				boolCanGoFoward = true;
	##Double Move From Start
	if( boolCanGoFoward && ( isWhitePawnStar(pawn) if isWhiteTurn else isBlackPawnStart(pawn) ) ):
		var doubleF = pawn.y - 2 if isWhiteTurn else pawn.y + 2;
		var index:int = QRToIndex(pawn.x, doubleF);
		if (bbIsIndexEmpty(index)):
			legalMoves[pawn][MOVE_TYPES.ENPASSANT].append(Vector2i(pawn.x, doubleF));
	return;

## Calculate Pawn Moves (TODO: Unfinished Promote)
func bbfindMovesForPawn(PawnArray:Array)-> void:
	for i in range(PawnArray.size()):
		var pawn = PawnArray[i];
		legalMoves[pawn] = PAWN_MOVE_TEMPLATE.duplicate(true);

		var fowardR = pawn.y - 1 if isWhiteTurn else pawn.y + 1;
		var leftCaptureR = pawn.y if isWhiteTurn else pawn.y + 1;
		var rightCaptureR = pawn.y-1 if isWhiteTurn else pawn.y;

		##Foward Move
		bbfindFowardMovesForPawn(pawn, fowardR);

		##Left Capture
		bbfindCaptureMovesForPawn(pawn, pawn.x-1, leftCaptureR);

		##Right Capture
		bbfindCaptureMovesForPawn(pawn, pawn.x+1, rightCaptureR);

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
func bbfindMovesForKnight(KnightArray:Array) -> void:
	for i in range(KnightArray.size()):
		var knight = KnightArray[i];
		legalMoves[knight] = DEFAULT_MOVE_TEMPLATE.duplicate(true);
		var invertAt2Counter = 0;
		for m in [-1,1,-1,1]:
			for dir in KNIGHT_VECTORS.keys():
				var activeVector:Vector2i = KNIGHT_VECTORS[dir];
				var checkingQ = knight.x + ((activeVector.x if (invertAt2Counter < 2) else activeVector.y) * m);
				var checkingR = knight.y + ((activeVector.y if (invertAt2Counter < 2) else activeVector.x) * m);
				if (BitBoard.inBitBoardRange(checkingQ,checkingR)):
					var index = QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1);
					if (bbIsIndexEmpty(index)) :
						legalMoves[knight][MOVE_TYPES.MOVES].append(Vector2i(checkingQ,checkingR));
					elif(bbIsPieceWhite(index) != isWhiteTurn):
						legalMoves[knight][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ,checkingR));
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
func bbfindMovesForRook(RookArray:Array) -> void:
	for i in range(RookArray.size()):
		var rook = RookArray[i];
		legalMoves[rook] = DEFAULT_MOVE_TEMPLATE.duplicate(true);
		for dir in ROOK_VECTORS.keys():
			var activeVector:Vector2i = ROOK_VECTORS[dir];
			var checkingQ:int = rook.x + activeVector.x;
			var checkingR:int = rook.y + activeVector.y;			
			while (BitBoard.inBitBoardRange(checkingQ,checkingR)):
				var index = QRToIndex(checkingQ,checkingR);
				if( bbIsIndexEmpty(index) ):
					legalMoves[rook][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
				
				elif( bbIsPieceWhite(index) != isWhiteTurn ): #Enemy
					legalMoves[rook][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					#King Escape Fix
					if( bbPieceTypeOf(index, isWhiteTurn) == PIECES.KING ):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						if(BitBoard.inBitBoardRange(checkingQ, checkingR)):
							updateAttackBoard(checkingQ, checkingR, 1);
					break;
				else: ## TODO :: INFLUENCED PIECES CAN BE A BIT BOARD
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
func bbfindMovesForBishop(BishopArray:Array) -> void:
	for i in range(BishopArray.size()):
		var bishop = BishopArray[i];
		legalMoves[bishop] = DEFAULT_MOVE_TEMPLATE.duplicate(true);
		for dir in BISHOP_VECTORS.keys():
			var activeVector:Vector2i = BISHOP_VECTORS[dir];
			var checkingQ:int = bishop.x + activeVector.x;
			var checkingR:int = bishop.y + activeVector.y;
			while ( BitBoard.inBitBoardRange(checkingQ,checkingR) ):
				var index = QRToIndex(checkingQ,checkingR);
				if( bbIsIndexEmpty(index) ):
					legalMoves[bishop][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
				
				elif( bbIsPieceWhite(index) != isWhiteTurn ):
					legalMoves[bishop][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					#King Escape Fix
					if(bbPieceTypeOf(index, isWhiteTurn) == PIECES.KING):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						if( BitBoard.inBitBoardRange(checkingQ,checkingR) ):
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
func bbfindMovesForQueen(QueenArray:Array) -> void:
	
	var tempMoves:Dictionary = {};
	
	bbfindMovesForRook(QueenArray);
	for i in range(QueenArray.size()):
		var queen = QueenArray[i];
		tempMoves[queen] = legalMoves[queen].duplicate(true);

	bbfindMovesForBishop(QueenArray);
	for i in range(QueenArray.size()):
		var queen = QueenArray[i];

		for moveType in tempMoves[queen].keys():
			for move in tempMoves[queen][moveType]:
				legalMoves[queen][moveType].append(move);
	return;

## Calculate King Moves
func bbfindMovesForKing(KingArray:Array) -> void:
	for i in range(KingArray.size()):
		var king = KingArray[i];
		legalMoves[king] = DEFAULT_MOVE_TEMPLATE.duplicate(true);

		for dir in KING_VECTORS.keys():
			var activeVector:Vector2i = KING_VECTORS[dir];
			var checkingQ:int = king.x + activeVector.x;
			var checkingR:int = king.y + activeVector.y;
			
			if(BitBoard.inBitBoardRange(checkingQ,checkingR)):
				updateAttackBoard(checkingQ, checkingR, 1);
				if(isWhiteTurn):
					if((BlackAttackBoard[checkingQ][checkingR] > 0)):
						continue;
				else:
					if((WhiteAttackBoard[checkingQ][checkingR] > 0)):
						continue;
				var index = QRToIndex(checkingQ,checkingR);
				if( bbIsIndexEmpty(index) ):
					legalMoves[king][MOVE_TYPES.MOVES].append(Vector2i(checkingQ, checkingR));

				elif( bbIsPieceWhite(index) != isWhiteTurn ):
					legalMoves[king][MOVE_TYPES.CAPTURE].append(Vector2i(checkingQ, checkingR));
		
		## Not Efficient FIX LATER
		if( GameInCheck ):
			legalMoves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[king][MOVE_TYPES.CAPTURE]);
			for moveType in legalMoves[king]:
				if(moveType == MOVE_TYPES.CAPTURE): continue;
				legalMoves[king][moveType] = differenceOfTwoArrays(legalMoves[king][moveType], GameInCheckMoves);

	return;

## Find the legal moves for a single player given an array of pieces
func bbfindLegalMovesFor(activepieces:Array) -> void:
	startTime = Time.get_ticks_usec();
	var pieces:Dictionary = activepieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK];
	for pieceType in pieces.keys():
		
		var singleTypePieces:Array = pieces[pieceType];
		
		if singleTypePieces.size() == 0:
			continue;
			
		match pieceType:
			PIECES.PAWN:bbfindMovesForPawn(singleTypePieces);
			PIECES.KNIGHT:bbfindMovesForKnight(singleTypePieces);
			PIECES.ROOK:bbfindMovesForRook(singleTypePieces);
			PIECES.BISHOP:bbfindMovesForBishop(singleTypePieces);
			PIECES.QUEEN:bbfindMovesForQueen(singleTypePieces);
			PIECES.KING:bbfindMovesForKing(singleTypePieces);
	stopTime = Time.get_ticks_usec();
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
func bbsearchForPawnsAtk(pos:Vector2i, isWTurn:bool) -> Array:
	var leftCaptureR:int = 0 if isWTurn else  1;
	var rightCaptureR:int = -1 if isWTurn else 0;
	var qpos:int = pos.x - 1;
	var lst:Array = [];
	if( BitBoard.inBitBoardRange(qpos, leftCaptureR) ):
		var index = QRToIndex(qpos, leftCaptureR);
		if( not bbIsIndexEmpty(index) and (bbIsPieceWhite(index) != isWTurn)):
			if(bbPieceTypeOf(index, isWTurn) == PIECES.PAWN):
				lst.append(Vector2i(qpos, leftCaptureR));
	qpos = pos.x + 1;
	if( BitBoard.inBitBoardRange(qpos, rightCaptureR) ):
		var index = QRToIndex(qpos, rightCaptureR);
		if( not bbIsIndexEmpty(index) and bbIsPieceWhite(index) != isWTurn):
			if(bbPieceTypeOf(index, isWTurn) == PIECES.PAWN):
				lst.append(Vector2i(qpos, rightCaptureR));
	return lst;

##
func bbsearchForKnightsAtk(pos:Vector2i, isWTurn:bool) -> Array:
	var lst:Array = [];
	var invertAt2Counter = 0;
	for m in [-1,1,-1,1]:
		for dir in KNIGHT_VECTORS.keys():
			var activeVector:Vector2i = KNIGHT_VECTORS[dir];
			var checkingQ = pos.x + ((activeVector.x if (invertAt2Counter < 2) else activeVector.y) * m);
			var checkingR = pos.y + ((activeVector.y if (invertAt2Counter < 2) else activeVector.x) * m);
			if (BitBoard.inBitBoardRange(checkingQ,checkingR)):
				var index = QRToIndex(checkingQ, checkingR);
				if( not bbIsIndexEmpty(index) and bbIsPieceWhite(index) != isWTurn):
					if(bbPieceTypeOf(index, isWTurn) == PIECES.KNIGHT):
						lst.append(Vector2i(checkingQ, checkingR));
	return lst;

##	
func bbsearchForSlidingAtk(pos:Vector2i, isWTurn:bool, checkForQueens:bool, initPiece:PIECES, VECTORS) -> Array:
	var lst:Array = [];
	var checkFor:Array = [initPiece];
	if(checkForQueens):
		checkFor.append(PIECES.QUEEN);
	
	for dir in VECTORS.keys():
		var activeVector:Vector2i = VECTORS[dir];
		var checkingQ:int = pos.x + activeVector.x;
		var checkingR:int = pos.y + activeVector.y;
		while ( BitBoard.inBitBoardRange(checkingQ, checkingR) ):
			var index = QRToIndex(checkingQ, checkingR);
			if (bbIsIndexEmpty(index)): pass;
			elif (bbIsPieceWhite(index) != isWTurn):
				if (bbPieceTypeOf(index, isWTurn) in checkFor):
					lst.append(Vector2i(checkingQ, checkingR));
				break;
			else: ## Blocked by friendly
				break;
			checkingQ += activeVector.x;
			checkingR += activeVector.y;
	return lst;

## (WIP) Search the board for attacking pieces on FROM cords
func bbsearchForMyAttackers(from:Vector2i, isWhiteTrn:bool) -> Array:
	var side = SIDES.BLACK if isWhiteTrn else SIDES.WHITE;
	var hasQueens = activePieces[side][PIECES.QUEEN].size() > 0;
	var attackers:Array = [];
	if (activePieces[side][PIECES.PAWN].size() > 0): 
		attackers.append_array(bbsearchForPawnsAtk(from, isWhiteTrn));
	if (activePieces[side][PIECES.KNIGHT].size() > 0):
		attackers.append_array(bbsearchForKnightsAtk(from, isWhiteTrn));
	if (activePieces[side][PIECES.ROOK].size() > 0 or hasQueens): 
		attackers.append_array(bbsearchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.ROOK, ROOK_VECTORS));
	if (activePieces[side][PIECES.BISHOP].size() > 0 or hasQueens): 
		attackers.append_array(bbsearchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.BISHOP, BISHOP_VECTORS));
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
	if( BitBoard.inBitBoardRange(cords.x-1, leftCaptureR) ):
		updateAttackBoard(cords.x-1, leftCaptureR, -1);
	##Right Capture
	if( BitBoard.inBitBoardRange(cords.x+1, rightCaptureR) ):
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
	bbfindLegalMovesFor(movedPiece);
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
		if( BitBoard.inBitBoardRange(moveToCords.x, moveToCords.y) ):
			if(not bbIsIndexEmpty(QRToIndex(moveToCords.x, moveToCords.y))):
				break;
		else: 
			break;
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
		if ( BitBoard.inBitBoardRange(moveToCords.x, moveToCords.y) ):
			if(not bbIsIndexEmpty(QRToIndex(moveToCords.x, moveToCords.y))):
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
func resetTurnFlags() -> void:
	GameInCheck = false;
	captureValid = false;
	EnPassantCordsValid = false;
	return;

##
func handleMoveCapture(moveTo, pieceType) -> bool:
	var revertEnPassant:bool = false;
	var moveToIndex = 	QRToIndex(moveTo.x,moveTo.y);
	captureType = bbPieceTypeOf(moveToIndex, isWhiteTurn);
	captureValid = true;

	## ENPASSANT FIX
	#
	if(pieceType == PIECES.PAWN && bbIsIndexEmpty(moveToIndex)):
		moveTo.y += 1 if isWhiteTurn else -1;
		moveToIndex = 	QRToIndex(moveTo.x,moveTo.y);
		captureType = bbPieceTypeOf(moveToIndex, isWhiteTurn);
		revertEnPassant = true;

	bbClearIndexOf(QRToIndex(moveTo.x,moveTo.y),!isWhiteTurn,captureType);
		
	var opColor = SIDES.BLACK if isWhiteTurn else SIDES.WHITE;
	var i:int = 0;
	for pieceCords in activePieces[opColor][captureType]:
		if(moveTo == pieceCords):
			captureIndex = i;
			break;
		i = i+1;
	activePieces[opColor][captureType].remove_at(i);

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
	var pieceType = bbPieceTypeOf(QRToIndex(cords.x,cords.y), !isWhiteTurn);
	var pieceVal = getPieceInt(pieceType, !isWhiteTurn)
	var previousPieceVal = pieceVal;
	
	var selfColor:int = SIDES.WHITE if isWhiteTurn else SIDES.BLACK;
	var moveTo = legalMoves[cords][moveType][moveIndex];
	var moveHistMod = "";

	var index = QRToIndex(cords.x,cords.y);
	bbClearIndexFrom(index, isWhiteTurn);

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

		MOVE_TYPES.ENPASSANT:
			var newECords = legalMoves[cords][MOVE_TYPES.ENPASSANT][0];
			EnPassantCords = Vector2i(newECords.x,newECords.y + (1 if isWhiteTurn else -1));
			EnPassantTarget = moveTo;
			EnPassantCordsValid = true;
			moveHistMod = "E";

		MOVE_TYPES.CAPTURE:
			if handleMoveCapture(moveTo, pieceType):
				moveHistMod = "-%d,%d" % [captureType,captureIndex];
			else:
				moveHistMod = "/%d,%d" % [captureType,captureIndex];

		MOVE_TYPES.MOVES: pass;

	add_IPieceToBitBoardsOf(moveTo.x,moveTo.y,pieceType,isWhiteTurn);
	
	var histPreview = ("%s %s %s %s" % [pieceVal,encodeEnPassantFEN(cords.x,cords.y),encodeEnPassantFEN(moveTo.x,moveTo.y),moveHistMod]);
	
	# Update Piece List
	for i in range(activePieces[selfColor][pieceType].size()):
		if (activePieces[selfColor][pieceType][i] == cords):
			activePieces[selfColor][pieceType][i] = moveTo;
			break;

	removeAttacksFrom(cords, getPieceType(previousPieceVal));
	
	handleMoveState(moveTo, cords, histPreview);

	return;

##
func _restoreFrozenState(state:FrozenState, moves:Dictionary):
	WhiteAttackBoard = state.WABoard.duplicate(true);
	BlackAttackBoard = state.BABoard.duplicate(true);
	blockingPieces = state.BPieces.duplicate(true);
	influencedPieces = state.IPieces.duplicate(true);
	legalMoves = moves.duplicate(true);
	return;

##
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
	
	blockingPieces = bbcheckForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	influencedPieces.clear();
		
	bbfindLegalMovesFor(activePieces);
	
	pass;

## SUB Routine
func setupActiveForSingle(type:PIECES, cords:Vector2i, lastCords:Vector2i):
	var movedPiece = [{ type : [Vector2i(cords)] }];
	
	if (influencedPieces.has(lastCords)):
		for item in influencedPieces[lastCords]:
			var inPieceType = bbPieceTypeOf(QRToIndex(item.x,item.y), !isWhiteTurn)
			if movedPiece[0].has(inPieceType):
				movedPiece[0][inPieceType].append(item);
			else:
				movedPiece[0][inPieceType] = [item];
	
	if(isWhiteTurn):
		movedPiece.insert(0, {});
		
	return movedPiece;

##
func handleMoveState(cords:Vector2i, lastCords:Vector2i, historyPreview:String):
	var pieceType = bbPieceTypeOf(QRToIndex(cords.x,cords.y), !isWhiteTurn);
	var movedPiece = setupActiveForSingle(pieceType, cords, lastCords);
	var kingCords:Vector2i = activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE][PIECES.KING][0];
	var mateStatus = "";

	blockingPieces = bbcheckForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	bbfindLegalMovesFor(movedPiece);

	if(checkIFCordsUnderAttack(kingCords, legalMoves)):
		mateStatus = "C"
		fillInCheckMoves(pieceType, cords, kingCords, true);
		#print(('black' if isWhiteTurn else 'white').to_upper(), " is in check.");
		#print("Game In Check Moves: ", GameInCheckMoves);
	
	clearCombinedBIT();
	calculateCombinedBIT();

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
				bbAddPieceOf(QRToIndex(to.x, to.y,), !isWhiteTurn, id);
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
				
				bbAddPieceOf(QRToIndex(to.x, to.y,), !isWhiteTurn, id);
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
				
				bbAddPieceOf(QRToIndex(to.x, to.y,), isWhiteTurn, PIECES.PAWN);
				bbClearIndexOf(QRToIndex(to.x, to.y,), isWhiteTurn, id);
				
				activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][id].pop_back();
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
				var kingCords:Vector2i = activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][KING_INDEX];
				var attacker = bbsearchForMyAttackers(kingCords, isWhiteTurn);
				
				GameInCheckMoves.clear();
				GameInCheck = true;
				
				for atk in attacker:
					var pieceType:PIECES = bbPieceTypeOf(QRToIndex(atk.x, atk.y), isWhiteTurn)
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
func printActivePieces(AP):
	for side in AP.size():
		print(SIDES.find_key(side))
		for piece in AP[side]:
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

## Print A Dictionary Board 
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
func initiateEngineAI() -> void:
	if(not EnemyIsAI):
		return;
	match EnemyType:
		ENEMY_TYPES.RANDOM:
			EnemyAI = RandomAI.new(EnemyPlaysWhite);
		ENEMY_TYPES.MIN_MAX:
			EnemyAI = MinMaxAI.new(EnemyPlaysWhite, 1);
		ENEMY_TYPES.NN:
			print("NN Agent not yet implemented, using RNG")
			EnemyAI = RandomAI.new(EnemyPlaysWhite);
	return;

## initiate the engine with a new game
func initiateEngine(FEN_STRING) -> bool:
	if ( not fillBoardwithFEN(FEN_STRING) ):
		print("Invalid FEN");
		return false;
	
	WhiteAttackBoard = createBoard(HEX_BOARD_RADIUS);
	BlackAttackBoard = createBoard(HEX_BOARD_RADIUS);

	blackCaptures.clear();
	whiteCaptures.clear();
	legalMoves.clear();
	blockingPieces.clear();
	GameInCheckMoves.clear();

	bypassMoveLock = false;
	GameIsOver = false;
	GameInCheck = false;
	captureValid = false;
	GameInCheckFrom = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
	
	activePieces = bbfindPieces();

	generateNextLegalMoves();
	
	initiateEngineAI();
	
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
# TODO:: HANDLE IN PROPER INPUT FEEDBACK
func _makeMove(cords:Vector2i, moveType, moveIndex:int, promoteTo:PIECES) -> void:

	if(GameIsOver):
		push_warning("Game Is Over")
		return;

	if(not legalMoves.has(cords)):
		push_warning("Game Is Over")
		return;

	if(EnemyIsAI):
		if (bypassMoveLock and (EnemyPlaysWhite == isWhiteTurn)):
			push_error("It is not your turn. Is AI Turn: %s" % (EnemyPlaysWhite == isWhiteTurn) );
			return;

	resetTurnFlags();
	handleMove(cords, moveType, moveIndex, promoteTo);
	
	return;

## Pass To AI
func _passToAI() -> void:
	if(GameIsOver):
		return;
	
	EnemyAI._makeChoice(self);
	
	EnemyChoiceType = bbPieceTypeOf(QRToIndex(EnemyAI._getCords().x,EnemyAI._getCords().y),  !isWhiteTurn);
	
	EnemyTo = EnemyAI._getTo();
	
	EnemyPromoted = EnemyAI._getMoveType() == MOVE_TYPES.PROMOTE;
	EnemyPromotedTo = EnemyAI._getPromoteTo();
	
	EnemyChoiceIndex = 0;
	for pieceCords in activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][EnemyChoiceType]:
		if(pieceCords == EnemyAI._getCords()): break;
		EnemyChoiceIndex += 1;
	
	resetTurnFlags();
	
	handleMove(EnemyAI._getCords(), EnemyAI._getMoveType(), EnemyAI._getMoveIndex(), EnemyAI._getPromoteTo())
	return;

## RESIGN PUBLIC 
func _resign():
	destroyBitBoards();
	if(GameIsOver):
		return;
	GameIsOver = true;
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
	bbClearIndexOf(QRToIndex(UndoNewTo.x,UndoNewTo.y), isWhiteTurn, pieceType);
	bbAddPieceOf(QRToIndex(UndoNewFrom.x,UndoNewFrom.y), isWhiteTurn, pieceType);
	
	for pieceCords in activePieces[selfColor][pieceType]:
		if(pieceCords == UndoNewTo):
			activePieces[selfColor][pieceType][index] = UndoNewFrom;	#if (index < activePieces[selfColor][pieceType].size() ): # After a promotion pawn does not exist to move back
			break;
		index += 1;
	
	undoType = pieceType;
	undoIndex = index;
	undoSubCleanFlags(splits, UndoNewFrom, UndoNewTo);
	undoSubFixState();
	
	clearCombinedBIT();
	calculateCombinedBIT();
	
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
