extends Node


## Hexagonal Chess Engine
##
## Holds Game State
## Computes if game is in check or over.
## Computes legal moves for acting player.

##TODO:
# 1 - Starting from a fen string requires that attack boards be created before anybody can go.
# 2 - Pawn Promotion
# 3 - Pawn EnPassant Capture
# 4 - Move Undo
# # - Captures that expose king to attack should not be allowed - NOT POSSIBLE - NOT A PROBLEM
# 6 - Add test
# 7 - Random AI
# 8 - MinMax AI
# 9 - Neural Network AI
# 10 - Attacking King with King cause odd behaviour



### Constants
	#ENUMS
enum PIECES{ ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES{ BLACK, WHITE };
	#Defaults
const HEX_BOARD_RADIUS = 5;
const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;
	#AttackBoardTest
const ATTACK_BOARD_TEST = '6/7/8/9/k9/10Q/9K/9/8/7/6 w - 1';
const ATTACKING_BOARD_TEST = 'p5/7/8/9/10/k9K/10/9/8/7/5P w - 1';
	#Variations
const VARIATION_ONE_FEN = 'p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1';
const VARIATION_TWO_FEN = '6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1';
	#State Tests
const EMPTY_BOARD = '6/7/8/9/10/11/10/9/8/7/6 w - 1';
const BLACK_CHECK = '1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1';
const BLOCKING_TEST = '6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1';
	#Piece Tests
const PAWN_TEST = '6/7/8/9/10/5P5/10/9/8/7/6 w - 1';
const KNIGHT_TEST = '6/7/8/9/10/5N5/10/9/8/7/6 w - 1';
const BISHOP_TEST = '6/7/8/9/10/5B5/10/9/8/7/6 w - 1';
const ROOK_TEST = '6/7/8/9/10/5R5/10/9/8/7/6 w - 1';
const QUEEN_TEST = '6/7/8/9/10/5Q5/10/9/8/7/6 w - 1';
const KING_TEST = '6/7/8/9/10/5K5/10/9/8/7/6 w - 1';
	#CheckMate Test:
const CHECK_IN_ONE = '6/7/8/9/k9/2QK7/10/9/8/7/6 w - 1';
const CHECK_IN_TWO = '2B3/7/8/9/10/R10/10/9/8/2p4/2k1K1 w - 1';

const ROOK_VECTORS = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0) };
const BISHOP_VECTORS = { 'lfoward':Vector2i(-2,1), 'rFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'lbackward':Vector2i(1,1), 'rBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KING_VECTORS = { 'foward':Vector2i(0,-1), 'lFoward':Vector2i(-1,0,), 'rFoward':Vector2i(1,-1), 'backward':Vector2i(0,1), 'lBackward':Vector2i(-1,1), 'rBackward':Vector2i(1,0), 'dlfoward':Vector2i(-2,1), 'drFoward':Vector2i(-1,-1), 'left':Vector2i(-1,2), 'dlbackward':Vector2i(1,1), 'drBackward':Vector2i(2,-1), 'right':Vector2i(1,-2) };
const KNIGHT_VECTORS = { 'left':Vector2i(-1,-2), 'lRight':Vector2i(1,-3), 'rRight':Vector2i(2,-3),}

const DEFAULT_MOVE_TEMPLATE : Dictionary = { 'Capture':[], 'Moves':[] };
const PAWN_MOVE_TEMPLATE : Dictionary = { 'Promote':[], 'EnPassant':[],'Capture':[], 'Moves':[] };

### State
	# Board
var HexBoard : Dictionary = {};
var WhiteAttackBoard : Dictionary = {};
var BlackAttackBoard : Dictionary = {};

	# Game Turn
var isWhiteTurn : bool = true;
var turnNumber : int = 1;

	# Pieces
var influencedPieces : Dictionary = {};
var blockingPieces : Dictionary = {};
var activePieces : Array = [];

	# Moves
var legalMoves : Dictionary = {};

	# Check & Mate
var GameIsOver = false;
var GameInCheck : bool = false;
var GameInCheckFrom : Vector2i = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
var GameInCheckMoves : Array = [];

	# Captures
var blackCaptures : Array = [];
var whiteCaptures : Array = [];

var captureType : PIECES = PIECES.ZERO;
var captureIndex = -1;
var captureValid : bool = false;

var uncaptureValid: bool = false;

	# EnPassant
var EnPassantCords : Vector2i = Vector2i(-5,-5);
var EnPassantTarget : Vector2i = Vector2i(-5,-5);
var EnPassantCordsValid : bool = false;

	# History
var moveHistory : Array = [];

var undoSpawnedPiece : bool = false;




### Internal

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
			
			if( isPieceBlack(val) ): 
				pieceCords[SIDES.BLACK][pieceType].append(pos);
			else: 
				pieceCords[SIDES.WHITE][pieceType].append(pos);
			
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
		#findEnPassantTarget();
	else:
		EnPassantCords = Vector2i(-5,-5);
		EnPassantTarget = Vector2i(-5,-5);
		EnPassantCordsValid = false;

	turnNumber = fenSections[3].to_int()
	if(turnNumber < 1):
		turnNumber = 1;

	return Board;

### PIECE IDENTIFING

## Checks if the fourth bit is fliped.
func isPiecewhite(id: int) -> bool:
	var mask = 0b1000; #8
	if ((id & mask) != 0):
		return true;
	return false;


## Checks if the fourth bit is fliped.
func isPieceBlack(id: int) -> bool:
	return !isPiecewhite(id);


## Given the int value of a chess piece and the current turn determine if friendly.
func isPieceFriendly(val,isWhiteTrn) -> bool:
	return (isWhiteTrn != isPieceBlack(val));


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




### GETS

## Get int representation of piece.
func getPieceInt(piece : PIECES, isBlack: bool) -> int:
	var id:int = piece
	if(!isBlack):
		id += 8;		
	return id;

## Strip the color bit information and find what piece is in use.
func getPieceType(id:int) -> PIECES:
	var mask = ~( 0b1000 );
	var res = (id & mask);
	if(res > PIECES.KING):
		push_error("Invalid Type");
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

	if(s.length() < 2):
		return Vector2i();

	var qStr:int = s.unicode_at(0) - "A".unicode_at(0) - 5;
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
	
	var isWhiteTrn:bool = !isPieceBlack(HexBoard[cords.x][cords.y]);
	
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
				legalMoves[pawn]['Promote'].append(move);
			else:
				legalMoves[pawn]['Capture'].append(move);
		else:
			if( EnPassantCordsValid && (EnPassantCords.x == qpos) && (EnPassantCords.y == rpos) ):
				legalMoves[pawn]['Capture'].append(move);
		updateAttackBoard(qpos, rpos, 1);
	return;

## Calculate Pawn Foward Moves
func findFowardMovesForPawn(pawn : Vector2i, fowardR : int ) -> void:
	var boolCanGoFoward = false;
	##Foward Move
	if (HexBoard[pawn.x].has(fowardR) && HexBoard[pawn.x][fowardR] == 0):
		if ( isWhitePawnPromotion(Vector2i(pawn.x,fowardR)) if isWhiteTurn else isBlackPawnPromotion(Vector2i(pawn.x,fowardR)) ) :
			legalMoves[pawn]['Promote'].append(Vector2i(pawn.x, fowardR));
		else:
			legalMoves[pawn]['Moves'].append(Vector2i(pawn.x, fowardR));
			boolCanGoFoward = true;
	
	##Double Move From Start
	if( boolCanGoFoward && ( isWhitePawnStar(pawn) if isWhiteTurn else isBlackPawnStart(pawn) ) ):
		var doubleF = pawn.y - 2 if isWhiteTurn else pawn.y + 2;
		if (HexBoard[pawn.x][doubleF] == 0):
			legalMoves[pawn]['EnPassant'].append(Vector2i(pawn.x, doubleF));

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
						legalMoves[knight]['Moves'].append(Vector2i(checkingQ,checkingR));

					elif (!isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn)):
						legalMoves[knight]['Capture'].append(Vector2i(checkingQ,checkingR));
					
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
					legalMoves[rook]['Moves'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn)):
					legalMoves[rook]['Capture'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					
					#King Escape Fix
					if(getPieceType(HexBoard[checkingQ][checkingR]) == PIECES.KING):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						print("King Escape %d %d" % [checkingQ, checkingR]);
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
					legalMoves[bishop]['Moves'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[bishop]['Capture'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					
					#King Escape Fix
					if(getPieceType(HexBoard[checkingQ][checkingR]) == PIECES.KING):
						checkingQ += activeVector.x;
						checkingR += activeVector.y;
						print("King Escape %d %d" % [checkingQ, checkingR]);
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
				if(isWhiteTurn):
					if((BlackAttackBoard[checkingQ][checkingR] > 0)):
						continue;
				else:
					if((WhiteAttackBoard[checkingQ][checkingR] > 0)):
						continue;

				if( HexBoard[checkingQ][checkingR] == PIECES.ZERO ):
					legalMoves[king]['Moves'].append(Vector2i(checkingQ, checkingR));

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[king]['Capture'].append(Vector2i(checkingQ, checkingR));
				
				updateAttackBoard(checkingQ, checkingR, 1);
		
		## Not Efficient FIX LATER
		if( GameInCheck ):
			legalMoves[king]['Capture'] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[king]['Capture']);
			for moveType in legalMoves[king]:
				if(moveType == 'Capture'): continue;
				legalMoves[king][moveType] = differenceOfTwoArrays(legalMoves[king][moveType], GameInCheckMoves);

	return;


## Find the legal moves for a single player given an  of pieces
func findLegalMovesFor(activepieces:Array) -> void:
	
	var pieces:Dictionary = activepieces[SIDES.WHITE] if isWhiteTurn else activepieces[SIDES.BLACK];
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
func checkIfCordsUnderAttack(Cords:Vector2i, enemyMoves:Dictionary) -> bool:
	for piece:Vector2i in enemyMoves.keys():
		for move in enemyMoves[piece]['Capture']:
			if(move == Cords):
				return true;
	return false;




### ATTACK BOARD
## Based on the turn determine the appropiate board to update.
func updateAttackBoard(q:int, r:int, mod:int) -> void:
	if(isWhiteTurn):
		WhiteAttackBoard[q][r] += mod;
	else:
		BlackAttackBoard[q][r] += mod;
	return;

## Based on the turn determine the appropiate board to update.
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




##
func resetFlags() -> void:
	GameInCheck = false;
	captureValid = false;
	EnPassantCordsValid = false;
	return;

##
func handleMoveCapture(moveTo, pieceType) -> void:
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
	return;

##
func handleMove(cords:Vector2i, moveType:String, moveIndex:int, promoteTo:PIECES) -> void:
	var pieceVal:int = HexBoard[cords.x][cords.y]
	var previousPieceVal = pieceVal;
	var selfColor:int = SIDES.WHITE if isWhiteTurn else SIDES.BLACK;

	var pieceType:PIECES = getPieceType(pieceVal);
	var moveTo = legalMoves[cords][moveType][moveIndex];

	var moveHistMod = "";

	HexBoard[cords.x][cords.y] = PIECES.ZERO;

	match moveType:
		'Promote':
			print("1: ", activePieces);
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
			activePieces[selfColor][pieceType].append(moveTo);
			pieceVal = getPieceInt(pieceType, !isWhiteTurn);
			moveHistMod = moveHistMod + (" +%s" % pieceType);
			print("2: ",activePieces)
			pass;

		'EnPassant':
			EnPassantCords = legalMoves[cords]['Moves'][0];
			EnPassantTarget = moveTo;
			EnPassantCordsValid = true;

			moveHistMod = "E";
			pass;

		'Capture':
			handleMoveCapture(moveTo, pieceType);
			moveHistMod = "/%d,%d" % [captureType,captureIndex];
			pass;

		'Moves': pass;

	HexBoard[moveTo.x][moveTo.y] = pieceVal;

	var histPreview = ("%s %s %s %s" % [previousPieceVal,encodeEnPassantFEN(cords.x,cords.y),encodeEnPassantFEN(moveTo.x,moveTo.y),moveHistMod]);
	
	# Update Piece List
	for i in range(activePieces[selfColor][pieceType].size()):
		if (activePieces[selfColor][pieceType][i] == cords):
			activePieces[selfColor][pieceType][i] = moveTo;
			break

	removeAttacksFrom(cords, getPieceType(previousPieceVal));
	checkState(moveTo, cords, histPreview);

	return;

# 
func fillRookCheckMoves(queenCords:Vector2i, moveToCords:Vector2i):
	var deltaQ = queenCords.x - moveToCords.x;
	var deltaR = queenCords.y - moveToCords.y;
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
func fillBishopCheckMoves(queenCords:Vector2i, moveToCords:Vector2i):
	var deltaQ = queenCords.x - moveToCords.x;
	var deltaR = queenCords.y - moveToCords.y;
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
func checkState(cords:Vector2i, lastCords:Vector2i, historyPreview:String):

	var pieceType:PIECES = getPieceType(HexBoard[cords.x][cords.y]);
	var movedPiece = [{ pieceType : [Vector2i(cords)] }];
	if (influencedPieces.has(lastCords)):
		for item in influencedPieces[lastCords]:
			var inPieceType = getPieceType(HexBoard[item.x][item.y]);
			if movedPiece[0].has(inPieceType):
				movedPiece[0][inPieceType].append(item);
			else:
				movedPiece[0][inPieceType] = [item]; 
	if(isWhiteTurn):
		movedPiece.insert(0, {});
		

	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	findLegalMovesFor(movedPiece);

	var queenCords:Vector2i = activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE][PIECES.KING][0];
	var mateStatus = "";
	if(checkIfCordsUnderAttack(queenCords, legalMoves)):
		print(('black' if isWhiteTurn else 'white').to_upper(), " is in check.");
		GameInCheckFrom = Vector2i(cords.x, cords.y);
		GameInCheckMoves.clear();
		
		match pieceType:
			PIECES.KING:
				pass; # No Blocking Moves
			PIECES.PAWN, PIECES.KNIGHT: # Can not be blocked
				GameInCheckMoves.append(cords);
			PIECES.ROOK:
				fillRookCheckMoves(queenCords, cords);
			PIECES.BISHOP:
				fillBishopCheckMoves(queenCords, cords);
			PIECES.QUEEN:
				if( 
					(cords.x == queenCords.x) or # same Q
			 		(cords.y == queenCords.y) or # same R
			 		(cords.x+cords.y) == (queenCords.x+queenCords.y) ): # same s
					fillRookCheckMoves(queenCords, cords);
				else:
					fillBishopCheckMoves(queenCords, cords);
		
		GameInCheck = true;
		mateStatus = "C"
		print("Game In Check Moves: ", GameInCheckMoves);

	incrementTurnNumber();
	swapPlayerTurn();

	if(isWhiteTurn):
		resetBoard(WhiteAttackBoard);
	else:
		resetBoard(BlackAttackBoard);
	
	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][PIECES.KING][0]);
	legalMoves.clear();
	influencedPieces.clear();
	findLegalMovesFor(activePieces);


	## Check For Mate and Stale Mate	
	var moveCount = countMoves(legalMoves);
	if( moveCount <= 0):
		mateStatus = "O"
		if(GameInCheck):
			print("Check Mate")
		else:
			print("Stale Mate")
		
		GameIsOver = true;
	
	print("Move Count: ", moveCount);
	moveHistory.append("%s %s" % [historyPreview, mateStatus])
	
	#print("Board : ")
	#printBoard(HexBoard);
	#print("W.A.B. : ")
	#printBoard(WhiteAttackBoard);
	#print("B.A.B. : ")
	#printBoard(BlackAttackBoard);
	return;


### 
###
### UTILITY

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
		for moveType:String in movesList[piece]:
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

# Find Items Unique Only To ARR. O(N^2)
func differenceOfTwoArrays(ARR:Array, ARR1:Array):
	var intersection = [];
	for item in ARR:
		if ( not ARR1.has(item)):
			intersection.append(item);
	return intersection;




###
###
### API INTERACTIONS

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



## START DEFAULT PUBLIC CALL
func _initDefault() -> void:
	
	HexBoard = fillBoardwithFEN(DEFAULT_FEN_STRING);
	WhiteAttackBoard = createBoard(HEX_BOARD_RADIUS);
	BlackAttackBoard = createBoard(HEX_BOARD_RADIUS);

	blackCaptures.clear();
	whiteCaptures.clear();

	blockingPieces.clear();

	captureValid = false;
	
	isWhiteTurn = true;
	turnNumber = 1;
	
	GameInCheckFrom = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
	GameInCheckMoves.clear();
	GameIsOver = false;
	GameInCheck = false;

	EnPassantCords = Vector2i(-5,-5);
	EnPassantTarget = Vector2i(-5,-5);
	EnPassantCordsValid = false;

	activePieces = findPieces(HexBoard);
	legalMoves.clear();
	findLegalMovesFor(activePieces);
	
	return;

## MAKE MOVE PUBLIC CALL
func _makeMove(cords:Vector2i, moveType:String, moveIndex:int, promoteTo:PIECES) -> void:
	
	if(GameIsOver):
		return;

	if(not legalMoves.has(cords)):
		return;

	resetFlags();
	handleMove(cords, moveType, moveIndex, promoteTo);
	
	return;

## RESIGN PUBLIC CALL
func _resign():
	GameIsOver = true;
	print("%s WINS BY RESIGN" % ("White" if isWhiteTurn else "Black"));

	return

## Undo Move PUBLIC CALL
func _undoLastMove() -> void:
	
	if(moveHistory.size() < 1):
		print("No move history");
		return;
	
	var currentMove:String = moveHistory.pop_back();
	var splits:PackedStringArray = currentMove.split(" ");
	
	print(splits);
	var pieceVal:int = getPieceInt(int(splits[0]), !isWhiteTurn);
	var newTo:Vector2i = decodeEnPassantFEN(splits[1]);
	var newFrom:Vector2i = decodeEnPassantFEN(splits[2]);
	
	HexBoard[newFrom.x][newFrom.y] = pieceVal;
	HexBoard[newTo.x][newTo.y] = PIECES.ZERO;
	
	var i = 3;
	while (i < splits.size()):
		var flag:String = splits[i];
		print(flag);
		match flag:
			"C":
				GameInCheck = false;
				pass;

			"O":
				GameIsOver = false;
				pass;

			"E":
				EnPassantCordsValid = false;
				pass;

			_ when flag[0] == '/':
				var cleanFlag:String = flag.get_slice('/', 0);
				var idAndIndex = cleanFlag.split(',');
				var id = int(idAndIndex[0]);
				var index = int(idAndIndex[1]);
				
				HexBoard[newTo.x][newTo.y] = getPieceInt(id, isWhiteTurn);
				activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK][captureType].insert(index, Vector2i(newTo) );
				
				uncaptureValid = true;
				captureType = id;
				captureIndex = index;
				#signal gui // finished?
				pass;
			
			_ when flag[0] == '+':
				HexBoard[newFrom.x][newFrom.y] = getPieceInt(PIECES.PAWN, !isWhiteTurn);
				#signal gui
				
				pass;
				
		i += 1;
		continue;
	
	if(moveHistory.size() > 0):
		currentMove = moveHistory.pop_back();
		splits = currentMove.split(" ");
		
		i = 3;
		while (i < splits.size()):
			var flag = splits[i];
			
			match flag:
				"C":
					GameInCheck = true;
					# GET IN CHECK DATA
					
					pass;
				"E":
					EnPassantCordsValid = true;
					# GET EnPASSANT DATA
					
					pass;
					
			i += 1;
		pass;
	
	decrementTurnNumber();
	swapPlayerTurn();
	
	return;
