extends Node

###Const
const HEX_BOARD_RADIUS = 5;

const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" 

const VARIATION_ONE_FEN = 'p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1'
const VARIATION_TWO_FEN = '6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1'

const EMPTY_BOARD = '6/7/8/9/10/11/10/9/8/7/6 w - 1'
const BLACK_CHECK = '1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1'
const BLOCKING_TEST = '6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1'
###

###State
var HexBoard:Dictionary = {}
var activePieces:Dictionary = {};
var currentLegalMoves:Dictionary = {};
var blockingPieces:Dictionary = {};

var turnNumber:int = 1;
var EnPassantCords:Vector2i = Vector2i(-5,-5);
var isWhiteTurn:bool = true;

var boardASFen:String = "";
###


## Find Intersection Of Two Arrays
func intersectOfTwoArrays(ARR:Array, ARR1:Array):
	var intersection = [];
	for item in ARR:
		if (ARR1.has(item)):
			intersection.append(item);
	return intersection;


## Print HexBoard UNFINISHED FORMATING
func printBoard(board: Dictionary):
	for key in board.keys():
		var rowString = [];
		
		var offset = 12 - board[key].size();
		for i in range(offset):
			rowString.append("  ");
		var tempArray = board[key].keys();
		tempArray.reverse();
		for innerKey in tempArray:
		#for innerKey in board[key].keys():
			if board[key][innerKey] == 0:
				rowString.append( "   " )
			else:
				rowString.append( str((" %02d" % board[key][innerKey] )) )
			
			rowString.append(", ");
		
		print("\n","".join(rowString),"\n");


## Get int representation of piece.
func getPieceInt(piece : String, isBlack: bool) -> int:
	var id:int = 0;
	match piece:
		"p":
			id = 1;
		"n":
			id = 2;
		"r":
			id = 3;
		"b":
			id = 4;
		"q":
			id = 5;
		"k":
			id = 6;
		_:
			push_error("Unknow Piece Type");
	if(isBlack):
		id += 8;		
	return id;


## Checks if the fourth bit is fliped.
func isPieceBlack(id: int) -> bool:
	var mask = 1 << 3;
	if ((id & mask) != 0):
		return true;
	return false;


## Strip the color bit information and find what piece is in use.
func getPieceType(id:int) -> String:
	var mask = ~(1 << 3);
	var res = (id & mask);
	match res:
		1:
			return "P";
		2:
			return "N";
		3:
			return "R";
		4:
			return "B";
		5:
			return "Q";
		6:
			return "K";
		_:
			push_error("Unknow PieceType. Invalid Use");
			return "";


## Create A hexagonal board with axial cordinates.
func createBoard(radius : int):
	var Board = {}
	var i : int = 1;
	for q in range(-radius, radius+1):
		var negativeQ : int = -1 * q;
		var minRow : int = max(-radius, (negativeQ-radius));
		var maxRow :int = min(radius, (negativeQ+radius));
		#print("Min: ", minRow, " Max: ", maxRow);
		Board[q] = {};
		for r in range(minRow, maxRow+1):
			#print("Q: ",q, " R: ", r," ", i);
			i = i+1;
			Board[q][r] = 0;
	#print(Board, "\n");
	return Board;


## ADD A Piece To Board
func addPieceToBoardAt( q:int, r:int, val:String, board:Dictionary) -> void:
	var isBlack = true;
	if(val == val.to_upper()):
		isBlack = false;
		val = val.to_lower();
	board[q][r] = getPieceInt(val, isBlack)	;
	return;


## Fill The Board by translating a fen string
func fillBoardwithFEN(fenString: String) -> Dictionary:
	const hexRadius = 5;
	var Board = createBoard(hexRadius);
	
	var fenSections:PackedStringArray = fenString.split(" ");
	if (fenSections.size() != 4):
		print("Invalid String");
		return {};
	#print(fenSections);
	
	var BoardColumns:PackedStringArray = fenSections[0].split("/");
	if (BoardColumns.size() != 11):
		print("Invalid String");
		return {};
	#print(BoardColumns);
	
	for q in range(-hexRadius, hexRadius+1):
		var mappedQ:int = q+hexRadius;
		var activeRow:String = BoardColumns[mappedQ];
		var r1:int = max(-hexRadius, -q-hexRadius);
		var r2:int = min(hexRadius, -q+hexRadius);

		for i:int in range(activeRow.length()):
			var activeChar:String = activeRow[i];

			if (activeChar.is_valid_int()):
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
	return Board;


## Fill The FEN STIRNG by translating the board
func boardToFenString(board:Dictionary, isWhiteTrn:bool, enPCord:String, turnCount:int) -> String:
	var FENSTRING = [ "" ];
	for i in range(board.keys().size()):
		var key = board.keys()[i]
		var emptySpaces:int = 0;
		for innerKey in board[key].keys():
			var val:int = board[key][innerKey];
			if(val == 0):
				emptySpaces += 1;
				continue;
				
			else:		
				if(emptySpaces != 0):
					FENSTRING.append( emptySpaces );
					emptySpaces = 0;
				
				var piece = getPieceType(val);
				if( isPieceBlack(val) ):
					FENSTRING.append( piece.to_lower() );
				else:
					FENSTRING.append( piece );
		###ENDFOR
		
		if(emptySpaces != 0):
			FENSTRING.append( emptySpaces );
			emptySpaces = 0;
			
		if(i < board.keys().size() - 1):
			FENSTRING.append("/")
			
	if (isWhiteTrn):
		FENSTRING.append(" w ") 
	else:
		FENSTRING.append(" b" );
		
	FENSTRING.append(enPCord);
	FENSTRING.append(" ")
	FENSTRING.append(turnCount);
		
	return "".join(FENSTRING);


## Use the board to find the location of all pieces. Intended to be
## ran only once at the begining.
func findPieces(board:Dictionary) -> Dictionary:
	var pieceCords = { 
	 'black':{ "P":[],
		"N":[],
		"R":[],
		"B":[],
		"Q":[],
		"K":[] },
	 'white':{"P":[],
		"N":[],
		"R":[],
		"B":[],
		"Q":[],
		"K":[] 
	 }};
	
	for q in board.keys():
		for r in board[q].keys():
			var val = board[q][r];
			
			if val == 0:
				continue;
			
			var type = getPieceType(val);	
			if(isPieceBlack(val)):
				pieceCords['black'][type].append(Vector2i(q, r));
			else:
				pieceCords['white'][type].append(Vector2i(q, r));
			
	return pieceCords;


## Update Turn Counter and swap player turn
func swapPlayerTurn():
	isWhiteTurn = !isWhiteTurn;
	turnNumber += 1;


## Given the int value of a chess piece and the current turn determine if friendly.
func isPieceFriendly(val,isWhiteTrn):
	if isWhiteTrn:
		return !isPieceBlack(val);
	else:
		return isPieceBlack(val);


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


## Calculate Pawn Moves (TODO: Unfinished Promote)
func findMovesForPawn(PawnArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary)-> Dictionary:
	var pawnMoves:Dictionary = { 'Promote':[], 'EnPassant':[],'Capture':[], 'Moves':[] };
	
	for i in range(PawnArray.size()):
		var pawn = PawnArray[i];
		
		pawnMoves['Promote'].append([]);
		pawnMoves['EnPassant'].append([]);
		pawnMoves['Capture'].append([]);
		pawnMoves['Moves'].append([]);
		
		var boolCanGoFoward = false;
		var fowardR = pawn.y - 1 if isWhiteTrn else pawn.y + 1;
		var leftCaptureR = pawn.y if isWhiteTrn else pawn.y + 1; 
		var rightCaptureR = pawn.y-1 if isWhiteTrn else pawn.y;
		
		##Foward Move
		if (board[pawn.x].has(fowardR) && board[pawn.x][fowardR] == 0):
			pawnMoves['Moves'][i].append(Vector2i(pawn.x, fowardR));
			boolCanGoFoward = true;
		
		##Double Move From Start
		if( boolCanGoFoward && ( isWhitePawnStar(pawn) if (isWhiteTrn) else isBlackPawnStart(pawn) ) ):
			var doubleF = pawn.y - 2 if isWhiteTrn else pawn.y + 2;
			if (board[pawn.x][doubleF] == 0):
				pawnMoves['EnPassant'][i].append(Vector2i(pawn.x, doubleF));
		
		##Left Capture
		if( board.has(pawn.x-1) && board[pawn.x-1].has(leftCaptureR) && !isPieceFriendly(board[pawn.x-1][leftCaptureR], isWhiteTrn) ):
			pawnMoves['Capture'][i].append(Vector2i(pawn.x-1, leftCaptureR));
		
		##Right Capture
		if( board.has(pawn.x+1) && board[pawn.x+1].has(rightCaptureR) && !isPieceFriendly(board[pawn.x+1][rightCaptureR], isWhiteTrn) ):
			pawnMoves['Capture'][i].append(Vector2i(pawn.x+1, rightCaptureR));
	
		## Not Efficient FIX LATER
		if(  blockingpieces.has(pawn) ):
			var newLegalmoves = blockingpieces[pawn];
			for moveType in pawnMoves.keys():
				pawnMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, pawnMoves[moveType][i]);
	return pawnMoves;


## Calculate Knight Moves
func findMovesForKnight(KnightArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary) -> Dictionary:
	var knightMoves:Dictionary = { 'Capture':[], 'Moves':[] };
	
	var directionVectors = { 
	 'left':Vector2i(-1,-2),
	 'lRight':Vector2i(1,-3),
	 'rRight':Vector2i(2,-3),
	}
	
	for i in range(KnightArray.size()):
		var knight = KnightArray[i];
		knightMoves['Capture'].append([]);
		knightMoves['Moves'].append([]);
		var invertAt2Counter = 0;
		for m in [-1,1,-1,1]:
			invertAt2Counter += 1;
			for dir in directionVectors.keys():
				var activeVector:Vector2i = directionVectors[dir];
				var checkingQ:int = knight.x if (invertAt2Counter < 2) else knight.y + (activeVector.x * m);
				var checkingR:int = knight.y if (invertAt2Counter < 2) else knight.x + (activeVector.y * m);	
				
				if (board.has(checkingQ) && board[checkingQ].has(checkingR)):
					if (board[checkingQ][checkingR] == 0) :
						knightMoves['Moves'][i].append(Vector2(checkingQ,checkingR));
					elif (!isPieceFriendly(board[checkingQ][checkingR], isWhiteTrn)):
						knightMoves['Capture'][i].append(Vector2(checkingQ,checkingR));
						
		## Not Efficient FIX LATER
		if(  blockingpieces.has(knight) ):
			var newLegalmoves = blockingpieces[knight];
			for moveType in knightMoves.keys():
				knightMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, knightMoves[moveType][i]);
	return knightMoves;


## Calculate Rook Moves
func findMovesForRook(RookArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary) -> Dictionary:
	
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
		rookMoves['Capture'].append([]);
		rookMoves['Moves'].append([]);
		
		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = rook.x + activeVector.x;
			var checkingR:int = rook.y + activeVector.y;	
			
			while (board.has(checkingQ) && board[checkingQ].has(checkingR) ):
				
				if( board[checkingQ][checkingR] == 0):
					rookMoves['Moves'][i].append(Vector2i(checkingQ, checkingR));
				elif( isPieceFriendly(board[checkingQ][checkingR], isWhiteTrn)):
					break;
				else:
					rookMoves['Capture'][i].append(Vector2i(checkingQ, checkingR));
					break;
				
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
				##END WHILE	
				
		## Not Efficient FIX LATER
		if(  blockingpieces.has(rook) ):
			var newLegalmoves = blockingpieces[rook];
			for moveType in rookMoves.keys():
				rookMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, rookMoves[moveType][i]);
		
	return rookMoves;


## Calculate Bishop Moves
func findMovesForBishop(BishopArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary) -> Dictionary:
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
		bishopMoves['Capture'].append([]);
		bishopMoves['Moves'].append([]);
		
		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = bishop.x + activeVector.x;
			var checkingR:int = bishop.y + activeVector.y;	
			
			while (board.has(checkingQ) && board[checkingQ].has(checkingR) ):
				
				if( board[checkingQ][checkingR] == 0):
					bishopMoves['Moves'][i].append(Vector2i(checkingQ, checkingR));
				elif( isPieceFriendly(board[checkingQ][checkingR], isWhiteTrn)):
					break;
				else:
					bishopMoves['Capture'][i].append(Vector2i(checkingQ, checkingR));
					break;
				
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
				##END WHILE	
	
		## Not Efficient FIX LATER
		if(  blockingpieces.has(bishop) ):
			var newLegalmoves = blockingpieces[bishop];
			for moveType in bishopMoves.keys():
				bishopMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, bishopMoves[moveType][i]);
		
	return bishopMoves;


## Calculate Queen Moves
func findMovesForQueen(QueenArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary) -> Dictionary:
	var queenMoves:Dictionary = { 'Capture':[], 'Moves':[] };
	
	var rookMoves = findMovesForRook(QueenArray, isWhiteTrn, board, blockingpieces);
	var bishopMoves = findMovesForBishop(QueenArray, isWhiteTrn, board, blockingpieces);
	
	for i in range(QueenArray.size()):
		var queen = QueenArray[i];
		queenMoves['Capture'].append([]);
		queenMoves['Moves'].append([]);
		
		queenMoves['Capture'][i].append( rookMoves['Capture'][i] + bishopMoves['Capture'][i] )
		queenMoves['Moves'][i].append( rookMoves['Moves'][i] + bishopMoves['Moves'][i] )
		
		## Not Efficient FIX LATER
		if(  blockingpieces.has(queen) ):
			var newLegalmoves = blockingpieces[queen];
			for moveType in queenMoves.keys():
				queenMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, queenMoves[moveType][i]);
		
	return queenMoves;


## Calculate King Moves
func findMovesForKing(KingArray:Array, isWhiteTrn:bool, board:Dictionary, blockingpieces:Dictionary) -> Dictionary:
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
		kingMoves['Capture'].append([]);
		kingMoves['Moves'].append([]);
		
		for dir in directionVectors.keys():
			var activeVector:Vector2i = directionVectors[dir];
			var checkingQ:int = king.x + activeVector.x;
			var checkingR:int = king.y + activeVector.y;	
			
			if(board.has(checkingQ) && board[checkingQ].has(checkingR)):
				if( board[checkingQ][checkingR] == 0):
					kingMoves['Moves'][i].append(Vector2i(checkingQ, checkingR));
				elif( !isPieceFriendly(board[checkingQ][checkingR], isWhiteTrn) ) :
					kingMoves['Capture'][i].append(Vector2i(checkingQ, checkingR));
		
		## Not Efficient FIX LATER
		if(  blockingpieces.has(king) ):
			var newLegalmoves = blockingpieces[king];
			for moveType in kingMoves.keys():
				kingMoves[moveType][i] = intersectOfTwoArrays(newLegalmoves, kingMoves[moveType][i]);
		
	return kingMoves;


## Find the legal moves for a single player
func findLegalMovesFor(board:Dictionary, cords:Dictionary, isWhiteTrn:bool, blockingpieces:Dictionary) -> Dictionary:
	
	var pieces:Dictionary = cords['white'] if isWhiteTrn else cords['black'];
	
	var legalMoves:Dictionary = {};
	
	for pieceType in pieces.keys():
		var singleTypePieces:Array = pieces[pieceType];
		#print(singleTypePieces);
		if singleTypePieces.size() == 0:
			continue;
		
		match pieceType:
			"P":
				legalMoves[pieceType] = findMovesForPawn(singleTypePieces, isWhiteTrn, board, blockingpieces);
				
			"N":
				legalMoves[pieceType] = findMovesForKnight(singleTypePieces, isWhiteTrn, board, blockingpieces);
				
			"R":
				legalMoves[pieceType] = findMovesForRook(singleTypePieces, isWhiteTrn, board, blockingpieces);
				
			"B":
				legalMoves[pieceType] = findMovesForBishop(singleTypePieces, isWhiteTrn, board, blockingpieces);
				
			"Q":
				legalMoves[pieceType] = findMovesForQueen(singleTypePieces, isWhiteTrn, board, blockingpieces);
				
			"K":
				legalMoves[pieceType] = findMovesForKing(singleTypePieces, isWhiteTrn, board, blockingpieces);
	#print("\n")
	return legalMoves;


## Count the amount of moves found
func countMoves(movesList:Dictionary) -> int:
	var count:int = 0;
	
	for piece:String in movesList.keys():
		for moveType:String in movesList[piece].keys():
			#print("MoveType: ", moveType, " : ", movesList[piece][moveType]);
			for pieceArray:Array in movesList[piece][moveType]:
				count += pieceArray.size();
				#print(pieceArray);
	
	return count;


## Check if
func checkIfCordsUnderAttack(Cords:Vector2i, enemyMoves:Dictionary) -> bool:
	for pieceType:String in enemyMoves.keys():
		for pieceArray in enemyMoves[pieceType]['Capture']:
			for move in pieceArray:
				if(move == Cords):
					return true;
	return false;


## Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
func checkForBlockingPiecesFrom(Cords:Vector2i, board:Dictionary) -> Dictionary:
	var Directions = [{ ##Rook
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
	
	var isWhiteTrn = !isPieceBlack(board[Cords.x][Cords.y]);
	var blockingpieces = {};
	
	for i in range(Directions.size()):
		var dirSet:Dictionary = Directions[i];
		for dir in dirSet.keys():
			var dirBlockingPiece:Vector2i;
			var activeVector:Vector2i = dirSet[dir];
			var checkingQ:int = Cords.x + activeVector.x;
			var checkingR:int = Cords.y + activeVector.y;	
			var legalMoves:Array = [];
			while (board.has(checkingQ) && board[checkingQ].has(checkingR) ):
				
				
				if (board[checkingQ][checkingR] != 0):
					
					if (isPieceFriendly( board[checkingQ][checkingR], isWhiteTrn)):
						if(dirBlockingPiece):
							break; ## Two friendly pieces in a row. No Danger 
						else:
							dirBlockingPiece = Vector2i(checkingQ,checkingR); ## First Piece Found
					else: ##Unfriendly
						var val = getPieceType(board[checkingQ][checkingR]);
						if( (val == "R") if (i == 0) else (val == "B")):
							if(dirBlockingPiece):
								blockingpieces[dirBlockingPiece] = legalMoves; 
								break; ## Is a blocking piece
							else:
								break; ## In Check.
				else:
					if(dirBlockingPiece): ## Track legal paths for blocking pieces
						legalMoves.append(Vector2i(checkingQ,checkingR));
							
				checkingQ += activeVector.x;
				checkingR += activeVector.y;
	
	return blockingpieces;


## 
func makeMove(_piece:String, _type:String, _pieceIndex:int, _moveIndex:int):
	pass;


##
func startDefaultGame(whiteGoesFirst:bool) -> Array:
	HexBoard = fillBoardwithFEN(DEFAULT_FEN_STRING);
	#print(HexBoard.keys())
	#for key in HexBoard.keys():
	#	print(HexBoard[key].keys());
	printBoard(HexBoard);
	
	activePieces = findPieces(HexBoard);
	isWhiteTurn = whiteGoesFirst;
	turnNumber = 1;
	currentLegalMoves = findLegalMovesFor(HexBoard, activePieces, isWhiteTurn, {});
	return [activePieces, currentLegalMoves];

##
## GODOT Fucntions 
##

# Called when the node enters the scene tree for the first time.
func _ready():
	#startDefaultGame(true);
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


