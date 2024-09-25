using Godot;
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

public partial class HexEngineSharp : Node
{
	public enum PIECES {ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING};
	public enum SIDES {BLACK, WHITE};
	public enum MOVE_TYPES {MOVES, CAPTURE, ENPASSANT, PROMOTE};
	public enum MATE_STATUS {NONE, CHECK, OVER};
	enum UNDO_FLAGS {ENPASSANT, CHECK, GAME_OVER };
	enum ENEMY_TYPES { PLAYER_TWO, RANDOM, MIN_MAX, NN }
	//	Defaults
	const int HEX_BOARD_RADIUS = 5;
	const int KING_INDEX = 0;
	const string DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;
	//	AttackBoardTest
	const string ATTACK_BOARD_TEST = "6/7/8/9/k9/10Q/9K/9/8/7/6 w - 1";
	const string ATTACKING_BOARD_TEST = "p5/7/8/9/10/k9K/10/9/8/7/5P w - 1";
	//	Variations
	const string VARIATION_ONE_FEN = "p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1";
	const string VARIATION_TWO_FEN = "6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1";
	//	State Tests
	const string EMPTY_BOARD   = "6/7/8/9/10/11/10/9/8/7/6 w - 1";
	const string BLACK_CHECK   = "1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1";
	const string BLOCKING_TEST = "6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1";
	const string UNDO_TEST_ONE   = "6/7/8/9/10/4p6/k2p2P2K/9/8/7/6 w - 1";
	const string UNDO_TEST_TWO   = "6/7/8/9/1P7/11/3p2P2K/9/8/7/k5 w - 1";
	const string UNDO_TEST_THREE   = "6/7/8/9/2R6/11/k2p2P2K/9/8/7/6 w - 1";
	const string KING_INTERACTION_TEST = "5P/7/8/9/10/k9K/10/9/8/7/p5 w - 1";
	const string ILLEGAL_ENPASSANT_TEST_ONE = "6/7/8/4K3/5P4/4p6/6r3/9/8/7/k5 w - 1";
	//	Piece Tests
	const string PAWN_TEST   = "6/7/8/9/10/5P5/10/9/8/7/6 w - 1";
	const string KNIGHT_TEST = "6/7/8/9/10/5N5/10/9/8/7/6 w - 1";
	const string BISHOP_TEST = "6/7/8/9/10/5B5/10/9/8/7/6 w - 1";
	const string ROOK_TEST   = "6/7/8/9/10/5R5/10/9/8/7/6 w - 1";
	const string QUEEN_TEST  = "6/7/8/9/10/5Q5/10/9/8/7/6 w - 1";
	const string KING_TEST   = "6/7/8/9/10/5K5/10/9/8/7/6 w - 1";
	//	CheckMate Test:
	const string CHECK_TEST_ONE   = "q6/7/8/9/10/k8K1/10/9/8/7/q5 w - 20";
	const string CHECK_TEST_TWO   = "6/7/8/9/10/11/10/9/8/7/6 w - 1";
	//	Vectors
	public static readonly Dictionary<string,Vector2I> ROOK_VECTORS = new Dictionary<string, Vector2I> { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0) } };
	public static readonly Dictionary<string,Vector2I> BISHOP_VECTORS = new Dictionary<string, Vector2I> { { "lfoward", new Vector2I(-2,1)}, { "rFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "lbackward", new Vector2I(1,1)}, { "rBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
	public static readonly Dictionary<string,Vector2I> KING_VECTORS = new Dictionary<string, Vector2I> { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0)}, { "dlfoward", new Vector2I(-2,1)}, { "drFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "dlbackward", new Vector2I(1,1)}, { "drBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
	public static readonly Dictionary<string,Vector2I> KNIGHT_VECTORS = new Dictionary<string, Vector2I> { { "left", new Vector2I(-1,-2)}, { "lRight", new Vector2I(1,-3)}, { "rRight", new Vector2I(2,-3)} };
	//	Templates
	public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> DEFAULT_MOVE_TEMPLATE = new Dictionary<MOVE_TYPES, List<Vector2I>> { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I>{}},  };
	public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> PAWN_MOVE_TEMPLATE = new Dictionary<MOVE_TYPES, List<Vector2I>> { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I> {}}, {MOVE_TYPES.ENPASSANT, new List<Vector2I> {}}, {MOVE_TYPES.PROMOTE, new List<Vector2I> {}} };
	//	UNSET
	const int DECODE_FEN_OFFSET = 70;
	const int TYPE_MASK = 0b0111;
	public static readonly int[] PAWN_START 	= {-4, -3, -2, -1, 0, 1, 2, 3, 4};
	public static readonly int[] PAWN_PROMOTE 	= {-5, -4, -3, -2, -1, 0, 1, 2 , 3, 4};

	//State
	//	Board
	private Dictionary<int, Dictionary<int,int>> HexBoard;
	private Dictionary<int, Dictionary<int,int>> WhiteAttackBoard;
	private Dictionary<int, Dictionary<int,int>> BlackAttackBoard;

	//BitBoard
	private Bitboard128[] WHITE_BB;
	private Bitboard128[] BLACK_BB;
	private Bitboard128 BIT_WHITE;
	private Bitboard128 BIT_BLACK;
	private Bitboard128 BIT_ALL;

	// Game Turn
	private bool isWhiteTurn = true;
	private int turnNumber = 1;

	// Pieces
	private Dictionary<Vector2I, List<Vector2I>> influencedPieces;
	private Dictionary<Vector2I, List<Vector2I>> lastInfluencedPieces;
	//var blockingPieces : Dictionary = {};
	private Dictionary<PIECES, List<Vector2I>>[] activePieces;

	// Moves
	private Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves;

	// Check & Mate
	private bool GameIsOver = false;
	private bool GameInCheck = false;
	private Vector2I GameInCheckFrom;
	private List<Vector2I> GameInCheckMoves;

	// Captures
	//var blackCaptures : Array = [];
	//var whiteCaptures : Array = [];

	private PIECES captureType = PIECES.ZERO;
	private int captureIndex = -1;
	private bool captureValid  = false;

	// UndoFlags and Data
	private bool uncaptureValid = false;
	private bool unpromoteValid = false;
	private PIECES unpromoteType = PIECES.ZERO;
	private int unpromoteIndex = -1;

	private PIECES undoType = PIECES.ZERO ;
	private int undoIndex = -1;
	private Vector2I undoTo;

	// EnPassant
	private Vector2I EnPassantCords;
	private Vector2I EnPassantTarget;
	private bool EnPassantCordsValid  = false;

	// Enemy
	private AIBase EnemyAI;
	private ENEMY_TYPES EnemyType = ENEMY_TYPES.PLAYER_TWO;
	private PIECES EnemyPromotedTo = PIECES.ZERO;
	// Enemy Bool
	public bool EnemyIsAI = false;
	public bool EnemyPlaysWhite = false;
	public bool EnemyPromoted =  false;
	public bool bypassMoveLock = false;
	// ENemy Info
	private int EnemyChoiceType;
	private int EnemyChoiceIndex;
	private Vector2I EnemyTo;

	// History
	private List<HistEntry> historyStack;

	//Bitboard
	public int startTime;
	public int stopTime;

	private MoveGenerator moveGenerator;

	//Statics


	public static int QRToIndex (int q, int r)
	{
		int normalq = q + 5;
		int i = 0;
		int index = 0;
		foreach(int size in Bitboard128.COLUMN_SIZES)
		{
			if (normalq == i)
				break; 
			index += size;
			i += 1;
		}
		
		if(q <= 0)
			index += 5 - r;
		else
			index += (Bitboard128.COLUMN_SIZES[normalq]-6) - r;
				
		return index;
	}
	public static Vector2I IndexToQR (int index){
		int accumulated_index = 0;
		int normalq = 0;
		int r;
		
		foreach (int size in Bitboard128.COLUMN_SIZES)
		{
			if( accumulated_index + size > index ) break;
			accumulated_index += size;
			normalq += 1;
		}
		
		if( normalq <= 5 )
			r = 5 - (index - accumulated_index);
		else
			r = (Bitboard128.COLUMN_SIZES[normalq] - 6) - (index - accumulated_index);
		
		var q = normalq - 5;
		return new Vector2I(q, r);
	}
	public static int getSAxialCordFrom(Vector2I cords)
	{
		return (-1 * cords.X) - cords.Y;
	}
	public static int getAxialCordDist(Vector2I from, Vector2I to)
	{
		var dif = new Vector3I(from.X-to.X, from.Y-to.Y, getSAxialCordFrom(from)-getSAxialCordFrom(to));
		return Math.Max( Math.Max( Math.Abs(dif.X), Math.Abs(dif.Y)), Math.Abs(dif.Z));
	}
	// public static void printActivePieces(Dictionary<PIECES, List<Vector2I>>[]AP)
	// {
	// 	for (int side = 0; side < AP.Length; side += 1)
	// 	{
	// 		GD.Print(Enum.GetNames(typeof (SIDES)).GetValue(side));
	// 		foreach(PIECES piece in AP[side].Keys)
	// 			GD.Print(Enum.GetName(typeof(PIECES), piece), " : ", AP[side][piece]);
	// 		GD.Print("\n");
	// 	}
	// }
	// set all values of given board to zero.
	public static void resetBoard(Dictionary<int, Dictionary<int,int>> board)
	{
		foreach( int key in board.Keys)
			foreach( int innerKey in board[key].Keys)
				board[key][innerKey] = 0;
		return;
	}
	// Count the amount of moves found
	public static int countMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> movesList)
	{
		int count = 0;
		foreach( Vector2I piece in movesList.Keys )
			foreach ( MOVE_TYPES moveType in movesList[piece].Keys )
				foreach ( Vector2I move in movesList[piece][moveType])
					count += 1;
		return count;
	}
	// Find Intersection Of Two Arrays. O(N^2)
	public T[] intersectOfTwoArrays<T>(T[] ARR, T[] ARR1)
	{
		List<T> intersection = new List<T>();
		foreach( T item in ARR)
			if (Array.Exists(ARR1, e => e.Equals(item)))
				intersection.Add(item);
		return intersection.ToArray();
	}
	// Find Items Unique Only To ARR. O(N^2)
	public T[] differenceOfTwoArrays<T>(T[] ARR, T[] ARR1)
	{
		List<T> diff = new List<T>();
		foreach( T item in ARR)
			if (!Array.Exists(ARR1, e => e.Equals(item)))
				diff.Add(item);
		return diff.ToArray();
	}
	// Print A Dictionary Board 
	// func printBoard(board: Dictionary):
	// 	var flipedKeys = board.keys();
	// 	flipedKeys.reverse();
	// 	for key in flipedKeys:
	// 		var rowString = [];
	// 		var offset = 12 - board[key].size();
	// 		for i in range(offset):
	// 			rowString.append("  ");

	// 		for innerKey in board[key].keys():
	// 			if board[key][innerKey] == 0:
	// 				rowString.append( "   " )
	// 			else:
	// 				rowString.append( str((" %02d" % board[key][innerKey] )) )
	// 			rowString.append(", ");
	// 		print("\n","".join(rowString),"\n");
	// 	return;


	// Internal Gets


	// Get int representation of piece.
	public static int getPieceInt(PIECES piece, bool isBlack)
	{
		int id = (int) piece;
		if(!isBlack)
			id += 8;
		return id;
	}
	// Strip the color bit information and find what piece is in use.
	public static PIECES getPieceType(int id)
	{
		int res = (id & TYPE_MASK);
		return (PIECES) res;
	}


	// Piece ID


	public static bool isPieceWhite(int id)
	{
		int mask = 0b1000;
		if ((id & mask) != 0)
			return true;
		return false;
	}
	public static bool isPieceFriendly(int val, bool isWhiteTrn)
	{
		return (isWhiteTrn == isPieceWhite(val));
	}
	public static bool isPieceKing(int id)
	{ 		
		return getPieceType(id) == PIECES.KING;
	}


	// Bitboards


	private void initiateStateBitboards()
	{
		int size = Enum.GetValues(typeof(PIECES)).Length - 1;
		WHITE_BB = new Bitboard128[size];
		BLACK_BB = new Bitboard128[size];
		for(int i=0; i<size; i+=1)
		{
			WHITE_BB[i] = new Bitboard128(0,0);
			BLACK_BB[i] = new Bitboard128(0,0);
		}
	}
	private void clearCombinedStateBitboards()
	{
		BIT_ALL = null;
		BIT_BLACK = null;
		BIT_WHITE = null;
	}
	private void clearStateBitboard()
	{
		for (int i=0 ; i <= WHITE_BB.Length; i+=1)
		{
			WHITE_BB[i] = null;
			BLACK_BB[i] = null;
		}

	}
	private void generateCombinedStateBitboards()
	{
		BIT_WHITE = Bitboard128.genTotalBitBoard(WHITE_BB);
		BIT_BLACK = Bitboard128.genTotalBitBoard(BLACK_BB);
		BIT_ALL = BIT_WHITE.OR(BIT_BLACK);
	}


	// Bitboard Checks


	// Checks BIT_ALL for the existence of a piece at index
	private bool bbIsIndexEmpty(int index)
	{
		Bitboard128 temp = Bitboard128.createSinglePieceBB(index);
		Bitboard128 result = BIT_ALL.AND(temp);
		bool status = result.IS_EMPTY();
		result = null;
		temp = null;
		return status;
	}
	// Assumes Piece Exists. Check on which side bitboard the piece exist on.
	private bool bbIsPieceWhite(int index)
	{
		Bitboard128 check = Bitboard128.createSinglePieceBB(index);
		Bitboard128 result = BIT_WHITE.AND(check);
		bool status = result.IS_EMPTY();
		result = null;
		check = null;
		return !status;
	}
	// Assumes Piece Exists. Check on which type bitboard the piece exist on. Checks Opponent bitboard.
	private PIECES bbPieceTypeOf(int index, bool isWhiteTrn)
	{
		int i = 0;
		Bitboard128 temp = Bitboard128.createSinglePieceBB(index);
		Bitboard128[] opponentBitBoards;
		if(isWhiteTrn)
			opponentBitBoards = BLACK_BB;
		else
			opponentBitBoards = WHITE_BB;

		foreach (Bitboard128 bb in opponentBitBoards)
		{
			i += 1;
			Bitboard128 result = temp.AND(bb);
			var status = result.IS_EMPTY();
			result = null;
			if (!status) break;
		}
		
		temp = null;
		return (PIECES) i;
	}

	// Bitboard Update


	// Update the selected sides type bitboard at (q,r)
	private void add_IPieceToBitBoardsOf(int q, int r, int piece, bool updateWhite)
	{
		int index = HexEngineSharp.QRToIndex(q,r);
		Bitboard128 insert = Bitboard128.createSinglePieceBB(index);
		int type = (int) getPieceType(piece);

		if(updateWhite)
		{
			var temp = WHITE_BB[type-1].OR(insert);
			WHITE_BB[type-1] = null;
			WHITE_BB[type-1] = temp;
		}
		else
		{
			var temp = BLACK_BB[type-1].OR(insert);
			BLACK_BB[type-1] = null;
			BLACK_BB[type-1] = temp;
		}
		
		insert = null;
		return;
	}
	// Update the bitboard at (q,r) using piece int
	private void add_IPieceToBitBoards(int q, int r, int piece)
	{
		add_IPieceToBitBoardsOf(q, r, piece, isPieceWhite(piece));
		return;
	}
	// Update the bitboard based on piece FEN STRING
	private void addS_PieceToBitBoards(int q, int r, string c)
	{
		bool isBlack = true;
		if(c == c.ToUpper())
		{
			isBlack = false;
			c = c.ToLower();
		}
		PIECES piece = HexEngineSharp.PIECES.ZERO;
		switch(c)
		{
			case "p": piece = HexEngineSharp.PIECES.PAWN; break;
			case "n": piece = HexEngineSharp.PIECES.KNIGHT; break;
			case "r": piece = HexEngineSharp.PIECES.ROOK; break;
			case "b": piece = HexEngineSharp.PIECES.BISHOP; break;
			case "q": piece = HexEngineSharp.PIECES.QUEEN; break;
			case "k": piece = HexEngineSharp.PIECES.KING; break;
		}
		add_IPieceToBitBoards(q,r, getPieceInt(piece, isBlack));
		return;
	}
	private void bbAddPieceOf(int index, bool isWhite, PIECES type)
	{
		Bitboard128[] activeBoard;
		if(isWhite)
			activeBoard = WHITE_BB;
		else
			activeBoard = BLACK_BB;
		var pos = (int) type - 1;
		var mask = Bitboard128.createSinglePieceBB(index);
		var result = activeBoard[pos].OR(mask);
		mask = null;
		activeBoard[pos] = null;
		activeBoard[pos] = result;
		return;
	}
	// Assumes Piece Exists. Clears index of selected side.
	private void bbClearIndexFrom(int index, bool isWhite)
	{
		PIECES type = bbPieceTypeOf(index, !isWhite);
		Bitboard128[] activeBoard; if(isWhite) activeBoard = WHITE_BB; else activeBoard = BLACK_BB;
		Bitboard128 mask = Bitboard128.createSinglePieceBB(index);
		int pos = (int) type - 1;
		Bitboard128 result = activeBoard[pos].XOR(mask);
		mask = null;
		activeBoard[pos] = null;
		activeBoard[pos] = result;
		return;
	}
	// Assumes Piece Exists. Clears index of selected side from selected type.
	private void bbClearIndexOf(int index, bool isWhite, PIECES type)
	{
		Bitboard128[] activeBoard;
		if(isWhite) activeBoard = WHITE_BB; else activeBoard = BLACK_BB;
		Bitboard128 mask = Bitboard128.createSinglePieceBB(index);
		int pos = (int) type - 1;
		var result = activeBoard[pos].XOR(mask);
		mask = null;
		activeBoard[pos] = null;
		activeBoard[pos] = result;
		return;
	}



	// PAWN Position


	public static bool isBlackPawnStart(Vector2I cords)
	{
		int r = -1;
		foreach( int q in PAWN_START){
			if( q > 0 )
				r -= 1;
			if((cords.X == q) && (cords.Y == r))
				return true;
		}
		return false;
	}
	public static bool isWhitePawnStart(Vector2I cords)
	{
		int r = 5;
		foreach( int q in PAWN_START){
			if ((cords.X == q) && (cords.Y == r))
				return true;
			if ( q < 0 )
				r -= 1;
		}
		return false;
	}
	public static bool isWhitePawnPromotion(Vector2I cords)
	{
		int r = 0;
		foreach ( int q in PAWN_PROMOTE)
		{
			if ((cords.X == q) && (cords.Y == r))
				return true;
			if(r > -5)
				r -= 1;
		}
		return false;
	}
	public static bool isBlackPawnPromotion(Vector2I cords)
	{
		int r = 5;
		foreach (int q in PAWN_PROMOTE)
		{
			if ((cords.X == q) && (cords.Y == r))
				return true;
			if(q >= 0)
				r -= 1;
		}
		return false;
	}


	// String Encoding


	// Turn a vector (q,r) into a string representation of the position.
	public static string encodeEnPassantFEN(int q, int r)
	{
		int rStr = 6 - r;
		int qStr = 5 + q;
		char qLetter = (char)(65 + qStr);
		return $"{qLetter}{rStr}";
	}
	// Turn a string represenation of board postiion to a vector2i.
	public static Vector2I decodeEnPassantFEN(string s)
	{
		int qStr = (int)s[0] - DECODE_FEN_OFFSET;
		int rStr = int.Parse(s.Substring(1));
		rStr += 6-(2*rStr);
		return new Vector2I(qStr, rStr);
	}


	// Turn Modification


	
	public void incrementTurnNumber()
	{
		turnNumber += 1;
		return;
	}
	public void decrementTurnNumber()
	{
		turnNumber -= 1;
		return;
	}
	public void swapPlayerTurn()
	{
		isWhiteTurn = !isWhiteTurn;
		return;
	}
	public void resetTurnFlags()
	{
		GameInCheck = false;
		captureValid = false;
		EnPassantCordsValid = false;
		return;
	}


	// U

	public void test()
	{
		GD.Print("TEST");
	}

}

class Bitboard128 
{
	const int INDEX_TRANSITION = 62;
	const int INDEX_OFFSET = 63;

	public static readonly int[] COLUMN_SIZES = {6,7,8,9,10,11,10,9,8,7,6};
	public static readonly int[] COLUMN_MIN_R = {0, -1, -2, -3, -4, -5, -5, -5, -5, -5, -5};
	public static readonly int[] COLUMN_MAX_R = {5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0};

	private int front;
	private int back;

	/* QUICK Powers of 2
	N must be below 64 */
	public static int get2PowerN (int n)
	{
		return 1 << n;
	}
	public static Bitboard128 createSinglePieceBB (int index)
	{
		int back = 0;
		int front = 0;
		if(index > Bitboard128.INDEX_TRANSITION)
		{
			front = get2PowerN( index - Bitboard128.INDEX_OFFSET );
			back = 0;
		}
		else
			back = get2PowerN( index );
		return new Bitboard128(front,back);
	}
	// Create and return the Bitwise-OR total of all BB
	public static Bitboard128 genTotalBitBoard (Bitboard128[] BBArray)
	{
		Bitboard128 returnBoard = new Bitboard128(0,0);
		Bitboard128 tempBoard;
		
		foreach (Bitboard128 BB in BBArray){
			tempBoard = returnBoard.OR(BB);
			returnBoard = tempBoard;
		}
		return returnBoard;
	}
	public static bool inBitboardRange(int qpos, int rpos)
	{
		return ( (-5 <= qpos) && (qpos <= 5) && (Bitboard128.COLUMN_MIN_R[qpos + 5] <= rpos) && (rpos <= Bitboard128.COLUMN_MAX_R[qpos + 5] ) );
	}
	public Bitboard128(int Front = 0 , int Back = 0)
	{
		front = Front;
		back = Back;
	}
	public int _getF()
	{
		return front;
	}
	public int _getB(){
		return back;
	}
	public Bitboard128 XOR(Bitboard128 to)
	{
		return new Bitboard128(front ^ to._getF(), back ^ to._getB());
	}
	public Bitboard128 OR(Bitboard128 to)

	{
		return new Bitboard128(front | to._getF(), back | to._getB());
	}
	public Bitboard128 AND(Bitboard128 to)
	{
		return new Bitboard128(front & to._getF(), back & to._getB());
	}
	public bool EQUAL(Bitboard128 to)
	{
		return ((front ^ to._getF()) == 0) && ((back ^ to._getB()) == 0);
	}
	public bool IS_EMPTY()
	{
		return (back == 0) && (front == 0);
	}
	public Bitboard128 _getCopy()
	{
		return new Bitboard128(_getF(), _getB());
	}
	public List<int> _getIndexes()
	{
		int b = _getB();
		int f = _getF();
		List<int> indexes = new List<int> {};
		int index = 0;
		while(b > 0b0){
			if ((b & 0b1) > 0)
				indexes.Add(index);
			b >>= 1;
			index += 1;
		}
		index = 63;
		while(f > 0b0){
			if ((f & 0b1) > 0)
				indexes.Add(index);
			f >>= 1;
			index += 1;
		}
		return indexes;
	}
	public override string ToString()
    {
        string frontBinary = Convert.ToString(front, 2).PadLeft(32, '0');
    	string backBinary = Convert.ToString(back, 2).PadLeft(63, '0');
    	return $"{frontBinary} {backBinary}";
    }
	public String ToStringNonBin()
	{
		return $"{front} {back}";
	}

}


class HistEntry
{
	private Vector2I from;
	private Vector2I to;

	private bool enPassant;
	private bool check;
	private bool over;
	private bool promote;
	private bool capture;
	private bool captureTopSneak;

	private int piece;
	private int pPiece;
	private int pIndex;
	private int cPiece;
	private int cIndex;

	public HistEntry(int PIECE, Vector2I FROM, Vector2I TO)
	{
		piece = PIECE;
		from = new Vector2I(FROM.X,FROM.Y);
		to = new Vector2I(TO.X,TO.Y);
		
		promote = false;
		enPassant = false;
		check = false;
		over = false;
		capture = false;
		captureTopSneak = false;
		return;
	}

	public void _flipPromote()
	{
		promote = !promote;
	}
	public bool _getPromote()
	{
		return promote;
	}
	public void _flipEnPassant()
	{
		enPassant = !enPassant;
	}
	public bool _getEnPassant()
	{
		return enPassant;
	}
	public void _flipCheck()
	{
		check = !check;
	}
	public bool _getCheck()
	{
		return check;
	}
	public void _flipOver()
	{ 
		over = !over;
	}
	public bool _getOver()
	{
		return over;
	}
	public void _flipCapture()
	{
		capture = !capture;
	}
	public bool _getCapture()
	{
		return capture;
	}
	public bool _getIsCaptureTopSneak()
	{
		return captureTopSneak;
	}
	public void _flipTopSneak()
	{
		captureTopSneak = !captureTopSneak;
	}
	public int _getCPieceType()
	{
		return cPiece;
	}
	public void _setCPieceType ( int type ){
		cPiece = type;
	}
	public int _getCIndex (){
		return cIndex;
	}
	public void _setCIndex ( int i )
	{
		cIndex = i;
	}
	public int _getPPieceType(){
		return pPiece;
	}
	public void _setPPieceType ( int type )
	{
		pPiece = type;
	}
	public int _getPIndex (){
		return pIndex;
	}
	public void _setPIndex ( int i ){
		pIndex = i;
	}
	public int _getPiece(){
		return piece;
	}
	public Vector2I _getFrom(){
		return from;
	}
	public Vector2I _getTo(){
		return to;
	}
	public override string ToString()
	{
		return $"P:{piece}, from:({from.X},{from.Y}), to:({to.X},{to.Y}) -- e:{enPassant} c:{check} o:{over} -- p:{promote} type:{pPiece} index:{pIndex} -- cap:{capture} top:{captureTopSneak} type:{cPiece} index:{cIndex}";
	}

}

