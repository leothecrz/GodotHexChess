extends Node2D

##Const
const HEX_BOARD_RADIUS = 5;
const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" 
###

##State
@onready var HexBoard:Dictionary = {}
@onready var isWhiteTurn:bool = true;
@onready var turnNumber:int = 1;
@onready var EnPassantCords:String = "-";
###

##Print HexBoard UNFINISHED FORMATING
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

#Get int representation of piece.
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

# Checks if the fourth bit is fliped.
func isPieceBlack(id: int) -> bool:
	var mask = 1 << 3;
	if ((id & mask) != 0):
		return true;
	return false;

#Strip the color bit information and find what piece is in use.
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

#Create A hexagonal board with axial cordinates.
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
func boardToFenString(board:Dictionary, isWhiteTurn:bool, enPCord:String, turnCount:int) -> String:
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
			
	if (isWhiteTurn):
		FENSTRING.append(" w ") 
	else:
		FENSTRING.append(" b" );
		
	FENSTRING.append(enPCord);
	FENSTRING.append(" ")
	FENSTRING.append(turnCount);
		
	return "".join(FENSTRING);

## Use the board to find the location of all pieces. Intended to be
## ran only once at the begining.
func findPieces(board:Dictionary):
	
	

##
## GODOT Fucntions 
##


# Called when the node enters the scene tree for the first time.
func _ready():
	HexBoard = fillBoardwithFEN(DEFAULT_FEN_STRING);
	printBoard(HexBoard);
	print(boardToFenString(HexBoard, isWhiteTurn, "-", turnNumber));
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
