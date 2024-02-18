extends Node

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
# 10 - 

### Constants
enum PIECES{ ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES{ BLACK, WHITE };
	#Defaults
const HEX_BOARD_RADIUS = 5;
const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;
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
const ATTACKING_BOARD_TEST = 'p5/7/8/9/10/k9K/10/9/8/7/5P w - 1';
###
###
### State

	# Board
var HexBoard:Dictionary = {};
var WhiteAttackBoard:Dictionary = {};
var BlackAttackBoard:Dictionary = {};
	# Game Turn
var isWhiteTurn:bool = true;
var turnNumber:int = 1;
	# Pieces
var blockingPieces:Dictionary = {};
var activePieces:Array = [];
	# Moves
var legalMoves:Dictionary = {};
	# Check & Mate
var GameInCheck:bool = false;
var GameInCheckFrom:Vector2i = Vector2i(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
var GameInCheckMoves:Array = [];
var GameIsOver = false;
	# Captures
var blackCaptures:Array = [];
var whiteCaptures:Array = [];

var captureType:String = "";
var captureIndex = -1;
var captureValid:bool = false;
	# EnPassant
var EnPassantCords:Vector2i = Vector2i(-5,-5);
var EnPassantTarget:Vector2i = Vector2i(-5,-5);
var EnPassantCordsValid:bool = false;
	# History
var moveHistory:Array = [];
###
###
### Internal

## Create A hexagonal board with axial cordinates. (Q,R). Centers At 0,0.
func createBoard(radius : int):
	var Board:Dictionary = {}
	var i:int = 1;
	for q:int in range(-radius, radius+1):
		var negativeQ : int = -1 * q;
		var minRow : int = max(-radius, (negativeQ-radius));
		var maxRow : int = min( radius, (negativeQ+radius));
		Board[q] = Dictionary();
		for r:int in range(minRow, maxRow+1):
			i = i+1;
			Board[q][r] = 0;
	return Board;

## Get int representation of piece.
func decodePieceStringToInt(piece:String, isBlack:bool) -> int:
	var id:int = 0;
	
	match piece.to_lower():
		"p": id=PIECES.PAWN;
		"n": id=PIECES.KNIGHT;
		"r": id=PIECES.ROOK;
		"b": id=PIECES.BISHOP;
		"q": id=PIECES.QUEEN;
		"k": id=PIECES.KING;
	
	if(isBlack):
		id += 8;		

	return id;

## Get int representation of piece.
func getPieceInt(piece : String, isBlack: bool) -> int:
	var id:int = 0;
	match piece.to_lower():
		"p":
			id = PIECES.PAWN;
		"n":
			id = PIECES.KNIGHT;
		"r":
			id = PIECES.ROOK;
		"b":
			id = PIECES.BISHOP;
		"q":
			id = PIECES.QUEEN;
		"k":
			id = PIECES.KING;
		_:
			push_error("Unknow Piece Type");
	if(isBlack):
		id += 8;		
	return id;

## Strip the color bit information and find what piece is in use.
func getPieceType(id:int) -> String:
	var mask = ~(1 << 3);
	var res = (id & mask);
	match res:
		PIECES.PAWN:
			return "P";
		PIECES.KNIGHT:
			return "N";
		PIECES.ROOK:
			return "R";
		PIECES.BISHOP:
			return "B";
		PIECES.QUEEN:
			return "Q";
		PIECES.KING:
			return "K";
		_:
			push_error("Unknow PieceType. Invalid Use");
			return "";

## Checks if the fourth bit is fliped.
func isPieceBlack(id: int) -> bool:
	var mask = 1 << 3; #8
	if ((id & mask) != 0):
		return true;
	return false;

## ADD A Piece To Board. At (Q,R) in 'board' decode 'val' and place it.
func addPieceToBoardAt( q:int, r:int, val:String, board:Dictionary) -> void:
	var isBlack = true;

	if(val == val.to_upper()):
		isBlack = false;
		val = val.to_lower();
	
	board[q][r] = decodePieceStringToInt(val, isBlack)	;
	return;

## Fill The Board by translating a fen string. DOES NOT FULLY VERIFY FEN STRING 
## (W I P)
func fillBoardwithFEN(fenString: String) -> Dictionary:
	var Board = createBoard(HEX_BOARD_RADIUS);
	
	var fenSections:PackedStringArray = fenString.split(" ");
	if (fenSections.size() != 4):
		print("Invalid String");
		return {};
	
	var BoardColumns:PackedStringArray = fenSections[0].split("/");
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

	## TODO 3
	return Board;

## Update Turn Counter and swap player turn
func swapPlayerTurn():
	isWhiteTurn = !isWhiteTurn;
	turnNumber += 1;
	return;

## Given the int value of a chess piece and the current turn determine if friendly.
func isPieceFriendly(val,isWhiteTrn):
	#if isWhiteTrn:
	#	return !isPieceBlack(val);
	#else:
	#	return isPieceBlack(val);
	return (isWhiteTrn != isPieceBlack(val));

## Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
func checkForBlockingPiecesFrom(Cords:Vector2i) -> Dictionary:
	
	var Directions:Array = [
		{ ##Rook
	 'foward':Vector2i(0,-1),
	 'lFoward':Vector2i(-1,0,),
	 'rFoward':Vector2i(1,-1),
	 'backward':Vector2i(0,1),
	 'lBackward':Vector2i(-1,1),
	 'rBackward':Vector2i(1,0)
	}, { ##Bishop
	 'lfoward':Vector2i(-2,1),
	 'rFoward':Vector2i(-1,-1),
	 'left':Vector2i(-1,2),
	 'lbackward':Vector2i(1,1),
	 'rBackward':Vector2i(2,-1),
	 'right':Vector2i(1,-2)
	}];
	
	var isWhiteTrn:bool = !isPieceBlack(HexBoard[Cords.x][Cords.y]);
	var blockingpieces:Dictionary = {};
	
	for i:int in range(Directions.size()):
		var dirSet:Dictionary = Directions[i];

		for direction in dirSet.keys():
			var dirBlockingPiece:Vector2i;
			var activeVector:Vector2i = dirSet[direction];

			var checkingQ:int = Cords.x + activeVector.x;
			var checkingR:int = Cords.y + activeVector.y;	

			var LegalMoves:Array = [];

			while ( HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
				
				if (HexBoard[checkingQ][checkingR] != 0):
					
					if (isPieceFriendly( HexBoard[checkingQ][checkingR], isWhiteTrn)):
						if(dirBlockingPiece):
							break; ## Two friendly pieces in a row. No Danger 
						else:
							dirBlockingPiece = Vector2i(checkingQ,checkingR); ## First Piece Found
							
					else: ##Unfriendly
						var val = getPieceType(HexBoard[checkingQ][checkingR]);
						if( (val == "Q") or ((val == "R") if (i == 0) else (val == "B")) ):
							if(dirBlockingPiece):
								LegalMoves.append(Vector2i(checkingQ,checkingR));
								blockingpieces[dirBlockingPiece] = LegalMoves; 
								break; ## Is a blocking piece
							else:
								break; ## In Check.
						else:
							break; ## Piece Type Cant Be Blocked
				else:
					if(dirBlockingPiece): ## Track legal paths for blocking pieces
						LegalMoves.append(Vector2i(checkingQ,checkingR));
							
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
	
	return blockingpieces;

## Use the board to find the location of all pieces. 
## Intended to be ran only once at the begining.
func findPieces(board:Dictionary) -> Array:
	var pieceCords:Array = [
	{ 
		"P":[],
		"N":[],
		"R":[],
		"B":[],
		"Q":[],
		"K":[] 
	},{ 
		"P":[],
		"N":[],
		"R":[],
		"B":[],
		"Q":[],
		"K":[] 
	}];
	
	for q in board.keys():
		for r in board[q].keys():
			var val:int = board[q][r];	
			if val == 0:
				continue;
			
			var pieceType = getPieceType(val);	
			if( isPieceBlack(val) ): pieceCords[SIDES.BLACK][pieceType].append(Vector2i(q, r));
			else: pieceCords[SIDES.WHITE][pieceType].append(Vector2i(q, r));
			
	return pieceCords;

## Check if cords are in the black pawn start
func isBlackPawnStart(cords:Vector2i) -> bool:
	#print(cords);
	var r:int = -1;
	for q:int in range (-4,4+1):
		if( q > 0 ):
			r -= 1;
		if (cords.x == q) && (cords.y == r):
			return true;
	return false;

## Check if cords are in the white pawn start
func isWhitePawnStar(cords:Vector2i) ->bool:
	#print(cords);
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

## Calculate Pawn Moves (TODO: Unfinished Promote)
func findMovesForPawn(PawnArray:Array)-> void:
	
	var pawnMoves:Dictionary = { 'Promote':[], 'EnPassant':[],'Capture':[], 'Moves':[] };

	for i in range(PawnArray.size()):
		var pawn = PawnArray[i];

		legalMoves[pawn] = pawnMoves.duplicate(true);
		
		var boolCanGoFoward = false;
		var fowardR = pawn.y - 1 if isWhiteTurn else pawn.y + 1;
		var leftCaptureR = pawn.y if isWhiteTurn else pawn.y + 1; 
		var rightCaptureR = pawn.y-1 if isWhiteTurn else pawn.y;
		
		##Foward Move
		if (HexBoard[pawn.x].has(fowardR) && HexBoard[pawn.x][fowardR] == 0):
			if ( isWhitePawnPromotion(Vector2i(pawn.x,fowardR)) if isWhiteTurn else isBlackPawnPromotion(Vector2i(pawn.x,fowardR)) ) :
				legalMoves[pawn]['Promote'].append(Vector2i(pawn.x, fowardR));
			else:
				legalMoves[pawn]['Moves'].append(Vector2i(pawn.x, fowardR));
				boolCanGoFoward = true;
		
		##Double Move From Start
		if( boolCanGoFoward && ( isWhitePawnStar(pawn) if (isWhiteTurn) else isBlackPawnStart(pawn) ) ):
			var doubleF = pawn.y - 2 if isWhiteTurn else pawn.y + 2;
			if (HexBoard[pawn.x][doubleF] == 0):
				legalMoves[pawn]['EnPassant'].append(Vector2i(pawn.x, doubleF));

		##Left Capture
		if( HexBoard.has(pawn.x-1) && HexBoard[pawn.x-1].has(leftCaptureR)):
			if (HexBoard[pawn.x-1][leftCaptureR] != 0 && !isPieceFriendly(HexBoard[pawn.x-1][leftCaptureR], isWhiteTurn) ):
				if ( isWhitePawnPromotion(Vector2i(pawn.x-1,leftCaptureR)) if isWhiteTurn else isBlackPawnPromotion(Vector2i(pawn.x-1,leftCaptureR)) ) :
					legalMoves[pawn]['Promote'].append(Vector2i(pawn.x-1, leftCaptureR));
				else:
					legalMoves[pawn]['Capture'].append(Vector2i(pawn.x-1, leftCaptureR));
			else:
				if(EnPassantCordsValid):
					if(EnPassantCords.x == pawn.x-1 && EnPassantCords.y == leftCaptureR):
						legalMoves[pawn]['Capture'].append(Vector2i(pawn.x-1, leftCaptureR));
						pass;
			updateAttackBoard(pawn.x-1, leftCaptureR, 1);

		##Right Capture
		if( HexBoard.has(pawn.x+1) && HexBoard[pawn.x+1].has(rightCaptureR)):
			if (HexBoard[pawn.x+1][rightCaptureR] != 0 && !isPieceFriendly(HexBoard[pawn.x+1][rightCaptureR], isWhiteTurn) ):
				if ( isWhitePawnPromotion(Vector2i(pawn.x+1,rightCaptureR)) if isWhiteTurn else isBlackPawnPromotion(Vector2i(pawn.x+1,rightCaptureR)) ) :
					legalMoves[pawn]['Promote'].append(Vector2i(pawn.x+1, rightCaptureR));
				else:
					legalMoves[pawn]['Capture'].append(Vector2i(pawn.x+1, rightCaptureR));
			else:
				if(EnPassantCordsValid):
					if(EnPassantCords.x == pawn.x+1 && EnPassantCords.y == rightCaptureR):
						legalMoves[pawn]['Capture'].append(Vector2i(pawn.x+1, rightCaptureR));
						pass;
			updateAttackBoard(pawn.x+1, rightCaptureR, 1);

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

	var knightMoves:Dictionary = { 'Capture':[], 'Moves':[] };	
	var directionVectors = { 
	 'left':Vector2i(-1,-2),
	 'lRight':Vector2i(1,-3),
	 'rRight':Vector2i(2,-3),
	}
	
	for i in range(KnightArray.size()):

		var knight = KnightArray[i];
		legalMoves[knight] = knightMoves.duplicate(true);

		var invertAt2Counter = 0;
		for m in [-1,1,-1,1]:
			
			for dir in directionVectors.keys():
				var activeVector:Vector2i = directionVectors[dir];
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
			for moveType in knightMoves.keys():
				legalMoves[knight][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[knight][moveType]);

	return;

## Calculate Rook Moves
func findMovesForRook(RookArray:Array) -> void:
	
	var rookMoves:Dictionary = { 'Capture':[], 'Moves':[] };
	var directionVectors = { 
	 'foward':Vector2i(0,-1),
	 'lFoward':Vector2i(-1,0,),
	 'rFoward':Vector2i(1,-1),
	 'backward':Vector2i(0,1),
	 'lBackward':Vector2i(-1,1),
	 'rBackward':Vector2i(1,0)
	}
	
	for i in range(RookArray.size()):
		var rook = RookArray[i];
		legalMoves[rook] = rookMoves.duplicate(true);
		
		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = rook.x + activeVector.x;
			var checkingR:int = rook.y + activeVector.y;	
			
			while (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
				
				if( HexBoard[checkingQ][checkingR] == 0):
					legalMoves[rook]['Moves'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn)):
					legalMoves[rook]['Capture'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					break;
				else:
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
			for moveType in rookMoves.keys():
				legalMoves[rook][moveType] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[rook][moveType]);
		
	return;

## Calculate Bishop Moves
func findMovesForBishop(BishopArray:Array) -> void:
	var bishopMoves:Dictionary = { 'Capture':[], 'Moves':[] };
	var directionVectors = { 
	 'lfoward':Vector2i(-2,1),
	 'rFoward':Vector2i(-1,-1),
	 'left':Vector2i(-1,2),
	 'lbackward':Vector2i(1,1),
	 'rBackward':Vector2i(2,-1),
	 'right':Vector2i(1,-2)
	}
	
	for i in range(BishopArray.size()):
		var bishop = BishopArray[i];
		
		legalMoves[bishop] = bishopMoves.duplicate(true);
		
		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = bishop.x + activeVector.x;
			var checkingR:int = bishop.y + activeVector.y;	
			
			while (HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR) ):
			
				if( HexBoard[checkingQ][checkingR] == 0):
					legalMoves[bishop]['Moves'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[bishop]['Capture'].append(Vector2i(checkingQ, checkingR));
					updateAttackBoard(checkingQ, checkingR, 1);
					break;
				else:
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
	
	findMovesForRook(QueenArray);

	var tempMoves:Dictionary = {};
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
	var kingMoves:Dictionary = { 'Capture':[], 'Moves':[] };
	
	var directionVectors = { 
	 'foward':Vector2i(0,-1),
	 'lFoward':Vector2i(-1,0,),
	 'rFoward':Vector2i(1,-1),
	 'backward':Vector2i(0,1),
	 'lBackward':Vector2i(-1,1),
	 'rBackward':Vector2i(1,0),
	 'dlfoward':Vector2i(-2,1),
	 'drFoward':Vector2i(-1,-1),
	 'left':Vector2i(-1,2),
	 'dlbackward':Vector2i(1,1),
	 'drBackward':Vector2i(2,-1),
	 'right':Vector2i(1,-2)
	}
	
	for i in range(KingArray.size()):
		var king = KingArray[i];
		legalMoves[king] = kingMoves.duplicate(true);

		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = king.x + activeVector.x;
			var checkingR:int = king.y + activeVector.y;	
			
			if(HexBoard.has(checkingQ) && HexBoard[checkingQ].has(checkingR)):
				if(isWhiteTurn):
					if((BlackAttackBoard[checkingQ][checkingR] > 0)):
						continue;
				else:
					if((WhiteAttackBoard[checkingQ][checkingR] > 0)):
						continue;

				if( HexBoard[checkingQ][checkingR] == 0):
					legalMoves[king]['Moves'].append(Vector2i(checkingQ, checkingR));

				elif( !isPieceFriendly(HexBoard[checkingQ][checkingR], isWhiteTurn) ):
					legalMoves[king]['Capture'].append(Vector2i(checkingQ, checkingR));
				
				updateAttackBoard(checkingQ, checkingR, 1);
		
		## Not Efficient FIX LATER
		if( GameInCheck ):
			legalMoves[king]['Capture'] = intersectOfTwoArrays(GameInCheckMoves, legalMoves[king]['Capture']);
			for moveType in kingMoves.keys():
				if(moveType == 'Capture'): continue;
				legalMoves[king][moveType] = differenceOfTwoArrays(legalMoves[king][moveType], GameInCheckMoves);

	return;

## Find the legal moves for a single player
func findLegalMovesFor(activepieces:Array) -> void:
	
	var pieces:Dictionary = activepieces[SIDES.WHITE] if isWhiteTurn else activepieces[SIDES.BLACK];
	for pieceType in pieces.keys():
		
		var singleTypePieces:Array = pieces[pieceType];
		if singleTypePieces.size() == 0: 
			continue;
		match pieceType:
			"P":findMovesForPawn(singleTypePieces);
			"N":findMovesForKnight(singleTypePieces);
			"R":findMovesForRook(singleTypePieces);
			"B":findMovesForBishop(singleTypePieces);
			"Q":findMovesForQueen(singleTypePieces);
			"K":findMovesForKing(singleTypePieces);

	return;

## Check if
func checkIfCordsUnderAttack(Cords:Vector2i, enemyMoves:Dictionary) -> bool:
	for piece:Vector2i in enemyMoves.keys():
		for move in enemyMoves[piece]['Capture']:
			if(move == Cords):
				return true;
	return false;

## 
func updateAttackBoard(q:int, r:int, mod:int) -> void:
	#print("UPDATE: %d,%d by %d" % [q,r,mod]);
	if(isWhiteTurn):
		WhiteAttackBoard[q][r] += mod;
	else:
		BlackAttackBoard[q][r] += mod;
	return;

## 
func updateOpAttackBoard(q:int, r:int, mod:int) -> void:
	if(!isWhiteTurn):
		WhiteAttackBoard[q][r] += mod;
	else:
		BlackAttackBoard[q][r] += mod;
	return;

##
func encodeEnPassantFEN(q:int, r:int) -> String:
	var rStr:int = 6 - r;
	var qStr:int = 5 + q;

	var qLetter = char(65 + qStr);
	return "%s%d" % [qLetter, rStr];

##
func decodeEnPassantFEN(s:String) -> Vector2i:

	if(s.length() < 2):
		return Vector2i();

	var qStr:int = s.unicode_at(0) - "A".unicode_at(0) - 5;
	var rStr:int = int(s.substr(1,-1))
	rStr += 6-(2*rStr);

	return Vector2i(qStr, rStr);

##
func resetFlags() -> void:
	
	if(GameInCheck): GameInCheck = false;
	if(captureValid): captureValid = false;
	if(EnPassantCordsValid): EnPassantCordsValid = false;
	return;

## 
func removeAttacksFrom(cords:Vector2i, id:String) -> void:
	
	if(not legalMoves.has(cords)):
		return;
	
	if(id == "P"):
		##FIX
		var fowardR = cords.y - 1 if isWhiteTurn else cords.y + 1;
		var leftCaptureR = cords.y if isWhiteTurn else cords.y + 1; 
		var rightCaptureR = cords.y-1 if isWhiteTurn else cords.y;
		
		##Left Capture
		if( HexBoard.has(cords.x-1) && HexBoard[cords.x-1].has(leftCaptureR)):
			updateAttackBoard(cords.x-1, leftCaptureR, -1);
		##Right Capture
		if( HexBoard.has(cords.x+1) && HexBoard[cords.x+1].has(rightCaptureR)):
			updateAttackBoard(cords.x+1, rightCaptureR, -1);
			
	else:
		for moveType in legalMoves[cords].keys():
			for move in legalMoves[cords][moveType]:
				updateAttackBoard(move.x,move.y,-1);
	
	return;

##
func removeCapturedFromATBoard(pieceType:String, cords:Vector2i):

	var movedPiece = [{ pieceType : [Vector2i(cords)] }];

	isWhiteTurn = !isWhiteTurn;

	if(isWhiteTurn):
		movedPiece.insert(0, {});

	legalMoves.clear();
	findLegalMovesFor(movedPiece);

	#if(pieceType == "P"):
		### FIX
		#for move in legalMoves[cords]['Capture']:
			#updateAttackBoard(move.x,move.y,-1);
	#else:
		#for moveType in legalMoves[cords].keys():
			#for move in legalMoves[cords][moveType]:
				#updateAttackBoard(move.x,move.y,-1);
	removeAttacksFrom(cords, pieceType);
	
	isWhiteTurn = !isWhiteTurn;

	return;

##
func handleMove(cords:Vector2i, moveType:String, moveIndex:int, _promoteTo:PIECES) -> void:

	var pieceVal:int = HexBoard[cords.x][cords.y] 
	var selfColor:int = SIDES.WHITE if isWhiteTurn else SIDES.BLACK;
	
	var pieceType:String = getPieceType(pieceVal);
	var moveTo = legalMoves[cords][moveType][moveIndex];

	var moveHistMod = "";

	HexBoard[cords.x][cords.y] = 0;
	match moveType:
		'Promote':
			#TODO
			pass;

		'EnPassant':
			EnPassantCords = legalMoves[cords]['Moves'][0];
			print("EPCords: ", EnPassantCords);
			EnPassantTarget = moveTo;
			EnPassantCordsValid = true;
			pass;

		'Capture':
			captureType = getPieceType(HexBoard[moveTo.x][moveTo.y]);
			captureValid = true;
	
			## ENPASSANT FIX
			var revertEnPassant:bool = false;
			if(pieceType == "P" && HexBoard[moveTo.x][moveTo.y] == 0):
				moveTo.y += 1 if isWhiteTurn else -1;
				captureType = getPieceType(HexBoard[moveTo.x][moveTo.y]);
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



			moveHistMod = "/%s" % captureType;

			pass;

		'Moves':
			pass;
	HexBoard[moveTo.x][moveTo.y] = pieceVal;

	moveHistory.append("%s %s %s %s" % [pieceType,encodeEnPassantFEN(cords.x,cords.y),encodeEnPassantFEN(moveTo.x,moveTo.y),moveHistMod]);

	# Update Piece List
	for i in range(activePieces[selfColor][pieceType].size()):
		if (activePieces[selfColor][pieceType][i] == cords):
			activePieces[selfColor][pieceType][i] = moveTo;
			i = activePieces[selfColor][pieceType].size();

	#printBoard(HexBoard);

	removeAttacksFrom(cords, getPieceType(pieceVal));
	checkState(moveTo);

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

## Count the amount of moves found
func countMoves(movesList:Dictionary) -> int:
	var count:int = 0;
	
	for piece:Vector2i in movesList.keys():
		for moveType:String in movesList[piece]:
			for move:Vector2i in movesList[piece][moveType]:
				count += 1;
	
	return count;

##
func resetBoard(attackBoard:Dictionary) -> void:
	for key in attackBoard.keys():
		for innerKey in attackBoard[key].keys():
			attackBoard[key][innerKey]=0;	
	return;

##
func checkState(cords:Vector2i):

	var pieceType:String = getPieceType(HexBoard[cords.x][cords.y]);
	var movedPiece = [{ pieceType : [Vector2i(cords)] }];
	if(isWhiteTurn):
		movedPiece.insert(0, {});
	var queenCords:Vector2i = activePieces[SIDES.BLACK if isWhiteTurn else SIDES.WHITE]['K'][0];

	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK]['K'][0]);
	legalMoves.clear();
	findLegalMovesFor(movedPiece);
	
	if(checkIfCordsUnderAttack(queenCords, legalMoves)):
		print(('black' if isWhiteTurn else 'white').to_upper(), " is in check.");
		GameInCheckFrom = Vector2i(cords.x, cords.y);
		GameInCheckMoves.clear();
		
		match pieceType:
			"K":
				pass; # No Blocking Moves
			"P", "N":
				GameInCheckMoves.append(cords);
			"R":
				fillRookCheckMoves(queenCords, cords);
			"B":
				fillBishopCheckMoves(queenCords, cords);
			"Q":
				fillRookCheckMoves(queenCords, cords);
				fillBishopCheckMoves(queenCords, cords);
		
		GameInCheck = true;
		print("Game In Check Moves: ", GameInCheckMoves);

	swapPlayerTurn();

	if(isWhiteTurn):
		resetBoard(WhiteAttackBoard);
	else:
		resetBoard(BlackAttackBoard);

	blockingPieces = checkForBlockingPiecesFrom(activePieces[SIDES.WHITE if isWhiteTurn else SIDES.BLACK]['K'][0]);
	#print("Blocking Pieces: ", blockingPieces);
	legalMoves.clear();
	findLegalMovesFor(activePieces);

	var moveCount = countMoves(legalMoves);
	print("Move Count: ", moveCount);
	if( moveCount <= 0):
		if(GameInCheck):
			print("CheckMate")
		else:
			print("Stale Mate")
		GameIsOver = true;

	return;

### 
###
### UTILITY

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

##
func _undoLastMove() -> void:
	
	if(moveHistory.size() < 1):
		print("No move history");
		return;
	
	turnNumber -= 1;
	var currentMove = moveHistory.pop_back();
	var splits = currentMove.split(" ");
	#moveHistory.append("%s %s %s %s" % [pieceType,encodeEnPassantFEN(cords.x,cords.y),encodeEnPassantFEN(moveTo.x,moveTo.y),moveHistMod]);
	var pieceVal = getPieceInt(splits[0], !isWhiteTurn);
	var newTo = decodeEnPassantFEN(splits[1]);
	var newFrom = decodeEnPassantFEN(splits[2]);
	
	
	
	return;

##
func _getIsWhiteTurn() -> bool:
	return isWhiteTurn;

##
func _getIsBlackTurn() -> bool:
	return !isWhiteTurn;

##
func _getActivePieces() -> Array:
	return activePieces;

##	
func _getMoves() -> Dictionary:
	return legalMoves;

##
func _getGameInCheck() -> bool:
	return GameInCheck;

##
func _getCaptureValid() -> bool:
	return captureValid;

## 
func _getCaptureType() -> String:
	return captureType;

##
func _getCaptureIndex() -> int:
	return captureIndex;

## Print HexBoard UNFINISHED FORMATING
func printBoard(board: Dictionary):
	for key in board.keys():
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

## Default Game
func _initDefault() -> void:
	
	HexBoard = fillBoardwithFEN(DEFAULT_FEN_STRING);
	WhiteAttackBoard = createBoard(HEX_BOARD_RADIUS);
	BlackAttackBoard = createBoard(HEX_BOARD_RADIUS);
	printBoard(HexBoard);

	legalMoves.clear();
	blackCaptures.clear();
	whiteCaptures.clear();
	captureValid = false;
	blockingPieces.clear();

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
	findLegalMovesFor(activePieces);
	return;

## 
func _makeMove(cords:Vector2i, moveType:String, moveIndex:int, promoteTo:PIECES) -> void:
	
	if(GameIsOver):
		return;

	if(not legalMoves.has(cords)):
		return;

	resetFlags();
	handleMove(cords, moveType, moveIndex, promoteTo);

	#print(activePieces, "\n");
	#for key in legalMoves.keys():
	#	print(key, " : ", legalMoves[key]);

	return;

##
func _resign():
	GameIsOver = true;
	if(isWhiteTurn):
		print("Black WINS BY RESIGN");
	else:
		print("White WINS BY RESIGN");

	print(moveHistory);

	return

###
###
### GODOT Functions 
func _ready():
	pass
###
