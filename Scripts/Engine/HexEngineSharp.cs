using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

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
	public static readonly int[] KNIGHT_MULTIPLERS = {-1, 1, -1, 1};
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
	private Dictionary<Vector2I, List<Vector2I>> blockingPieces;
	private Dictionary<PIECES, List<Vector2I>>[] activePieces = null;
	// Moves
	private Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves = null;
	// Check & Mate
	private bool GameIsOver = false ;
	private bool GameInCheck = false;
	private Vector2I GameInCheckFrom;
	private List<Vector2I> GameInCheckMoves;
	// Captures
	//var blackCaptures : Array = [];
	//var whiteCaptures : Array = [];
	private PIECES captureType  = PIECES.ZERO;
	private int captureIndex  = -1;
	private bool captureValid   = false;
	// UndoFlags and Data
	private bool uncaptureValid  = false;
	private bool unpromoteValid  = false;
	private PIECES unpromoteType  = PIECES.ZERO;
	private int unpromoteIndex   = -1;
	private PIECES undoType = PIECES.ZERO;
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
	//Testing
	public int startTime;
	public int stopTime;
	//MoveGen
	private static MoveGenerator moveGenerator = new MoveGenerator();



	//Static Functions


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
	public List<T> intersectOfTwoList<T>(List<T> ARR, List<T> ARR1)
	{
		return ARR.Intersect(ARR1).ToList<T>();
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
	public List<T> differenceOfTwoList<T>(List<T> ARR, List<T> ARR1)
	{
		// T[] diffArray = differenceOfTwoArrays(ARR.ToArray(), ARR1.ToArray() )
		// return new List<T> (diffArray);
		return ARR.Except(ARR1).ToList();
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
	private  static bool charIsInt(char activeChar)
	{
		return (48 <= activeChar) && (activeChar <= 57);
	}
	public static Dictionary<MOVE_TYPES, List<Vector2I>> DeepCopyMoveTemplate(Dictionary<MOVE_TYPES, List<Vector2I>> original)
	{
		var copy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
		foreach (var kvp in original)
		{
			var newList = new List<Vector2I>(kvp.Value);
			copy.Add(kvp.Key, newList);
		}
		return copy;
	}
	public static Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> DeepCopyLegalMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> original)
	{
		var copy = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>>();
		foreach (var kvp in original)
		{
			var innerDictionaryCopy = new Dictionary<MOVE_TYPES, List<Vector2I>>();

			foreach (var innerKvp in kvp.Value)
			{
				var newList = new List<Vector2I>(innerKvp.Value);

				innerDictionaryCopy.Add(innerKvp.Key, newList);
			}
			copy.Add(kvp.Key, innerDictionaryCopy);
		}
		return copy;
	}
	public static Dictionary<MOVE_TYPES, List<Vector2I>> DeepCopyInnerDictionary(
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves,
		Vector2I key)
	{
		if (!legalMoves.TryGetValue(key, out var innerDictionary))
		{
			return null;
		}

		var innerDictionaryCopy = new Dictionary<MOVE_TYPES, List<Vector2I>>();

		foreach (var kvp in innerDictionary)
		{
			var newList = new List<Vector2I>(kvp.Value);

			innerDictionaryCopy.Add(kvp.Key, newList);
		}

		return innerDictionaryCopy;
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

	// Use the board to find the location of all pieces. 
	// Intended to be ran only once at the begining.
	private Dictionary<PIECES,List<Vector2I>>[] bbfindPieces()
	{
		Dictionary<PIECES,List<Vector2I>>[] pieceCords = new Dictionary<PIECES,List<Vector2I>>[] 
		{
			new Dictionary<PIECES, List<Vector2I>>()
			{ 
				{PIECES.PAWN, new List<Vector2I> {}},
				{PIECES.KNIGHT, new List<Vector2I> {}},
				{PIECES.ROOK, new List<Vector2I> {}},
				{PIECES.BISHOP, new List<Vector2I> {}},
				{PIECES.QUEEN, new List<Vector2I> {}},
				{PIECES.KING, new List<Vector2I> {}} 
			},
			new Dictionary<PIECES, List<Vector2I>>()
			{ 
				{PIECES.PAWN, new List<Vector2I> {}},
				{PIECES.KNIGHT, new List<Vector2I> {}},
				{PIECES.ROOK, new List<Vector2I> {}},
				{PIECES.BISHOP, new List<Vector2I> {}},
				{PIECES.QUEEN, new List<Vector2I> {}},
				{PIECES.KING, new List<Vector2I> {}} 
			}
		};
		
		int type = 0;
		foreach( Bitboard128 bb in BLACK_BB )
		{
			type += 1;
			List<int> pieceIndexes = bb._getIndexes();
			foreach(int i in pieceIndexes)
				pieceCords[(int)HexEngineSharp.SIDES.BLACK][(PIECES)type].Add(HexEngineSharp.IndexToQR(i));
		}
		type = 0;
		foreach( Bitboard128 bb in WHITE_BB)
		{
		 	type += 1;
		 	List<int> pieceIndexes = bb._getIndexes();
		 	foreach(int i in pieceIndexes)
		 		pieceCords[(int)SIDES.WHITE][(PIECES)type].Add(HexEngineSharp.IndexToQR(i));
		}

		return pieceCords;
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
			Bitboard128 temp = WHITE_BB[type-1].OR(insert);
			WHITE_BB[type-1] = null;
			WHITE_BB[type-1] = temp;
		}
		else
		{
			Bitboard128 temp = BLACK_BB[type-1].OR(insert);
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
	private void addS_PieceToBitBoards(int q, int r, char c)
	{
		bool isBlack = true;
		if(c < 'a')
		{
			isBlack = false;
			c = (char) ( c + 32 );
		}
		PIECES piece = HexEngineSharp.PIECES.ZERO;
		switch(c)
		{
			case 'p': piece = HexEngineSharp.PIECES.PAWN; break;
			case 'n': piece = HexEngineSharp.PIECES.KNIGHT; break;
			case 'r': piece = HexEngineSharp.PIECES.ROOK; break;
			case 'b': piece = HexEngineSharp.PIECES.BISHOP; break;
			case 'q': piece = HexEngineSharp.PIECES.QUEEN; break;
			case 'k': piece = HexEngineSharp.PIECES.KING; break;
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


	// Attack Board

	private Dictionary<int,Dictionary<int,int>> createAttackBoard(int radius)
	{
		var rDictionary = new Dictionary<int,Dictionary<int,int>> {};

		for( int q=-radius; q <= radius; q +=1 )
		{
			int negQ = q * -1;
			int minRow = Math.Max(-radius, (negQ-radius));
			int maxRow = Math.Min(radius, (negQ+radius));
			rDictionary.Add(q, new Dictionary<int, int> {});
			for(int r = minRow; r<= maxRow; r += 1 )
				rDictionary[q].Add(r, 0);
		}


		return rDictionary;
	}
	// Based on the turn determine the appropriate board to update.
	private void updateAttackBoard(int q, int r, int mod)
	{
		if(isWhiteTurn)
			WhiteAttackBoard[q][r] += mod;
		else
			BlackAttackBoard[q][r] += mod;
		return;
	}
	// Based on the turn determine the appropriate board to update.
	private void updateOpposingAttackBoard(int q, int r, int mod)
	{
		if(!isWhiteTurn)
			WhiteAttackBoard[q][r] += mod;
		else
			BlackAttackBoard[q][r] += mod;
		return;
	}
	private void removePawnAttacks(Vector2I cords)
	{
		//FIX
		var leftCaptureR = isWhiteTurn ?  cords.Y : cords.Y + 1;
		var rightCaptureR = isWhiteTurn ? cords.Y-1 : cords.Y;
		//Left Capture
		if( Bitboard128.inBitboardRange(cords.X-1, leftCaptureR) )
			updateAttackBoard(cords.X-1, leftCaptureR, -1);
		//Right Capture
		if( Bitboard128.inBitboardRange(cords.X+1, rightCaptureR) )
			updateAttackBoard(cords.X+1, rightCaptureR, -1);
		return;
	}
	private void removeAttacksFrom(Vector2I cords, PIECES id) 
	{
		if(id == PIECES.PAWN)
		{
			removePawnAttacks(cords);
			return;
		}
				
		foreach( MOVE_TYPES moveType in legalMoves[cords].Keys)
			foreach( Vector2I move in legalMoves[cords][moveType])
				updateAttackBoard(move.X,move.Y,-1);
		
		return;
	}
	// private void removeCapturedFromATBoard(PIECES pieceType, Vector2I cords)
	// {
	// 	isWhiteTurn = !isWhiteTurn;
		
	// 	var movedPiece = [{ pieceType : [Vector2i(cords)] }];
	// 	if(isWhiteTurn):
	// 		movedPiece.insert(0, {});
			
	// 	var savedMoves = legalMoves.
	// 	legalMoves.clear();
	// 	//bbfindLegalMovesFor(movedPiece);
	// 	removeAttacksFrom(cords, pieceType);
	// 	legalMoves = savedMoves;
		
	// 	isWhiteTurn = !isWhiteTurn;
	// 	return;
	// }


	//  Board Search


	// BoardState


	// Fill The Board by translating a fen string. DOES NOT FULLY VERIFY FEN STRING -- (W I P)
	private bool fillBoardwithFEN(string fenString)
	{
		//Board Status
		initiateStateBitboards();
		
		string [] fenSections =  fenString.Split(' ');
		if (fenSections.Length != 4)
		{
			GD.PushError("Not Enough Fen Sections");
			return false;
		}

		string[] BoardColumns = fenSections[0].Split('/');
		if (BoardColumns.Length != 11)
		{
			GD.PushError("Not all Hexboard columns are defined");
			return false;
		}
			
		Regex regex = new Regex("(?i)([pnrbqk]|[0-9]|/)*");
		Match result = regex.Match(fenString);
		if (!result.Success)
		{
			GD.PushError("Regex fail");
			return false;
		}
		if( result.Value != fenSections[0] )
		{
			GD.PushError( $"{result.Value} {fenString} Invalid Board Description");
			return false;
		}
	
		for(int q=-HEX_BOARD_RADIUS; q <= HEX_BOARD_RADIUS; q+=1)
		{
			int mappedQ = q + HEX_BOARD_RADIUS;
			string activeRow = BoardColumns[mappedQ];
			
			int r1 = Math.Max(-HEX_BOARD_RADIUS, -q-HEX_BOARD_RADIUS);
			int r2 = Math.Min(HEX_BOARD_RADIUS, -q+HEX_BOARD_RADIUS);

			for(int i=0; i < activeRow.Length; i += 1 )
			{
				char activeChar = activeRow[i];
				if( charIsInt(activeChar) )
				{
					int pushDistance = (int) activeChar - '0';
					while ( (i+1 < activeRow.Length) && charIsInt(activeRow[i+1]))
					{
						i += 1;
						pushDistance *= 10;
						pushDistance += (int)(activeRow[i] - '0');
					}
					r1 += pushDistance;
				}
				else
				{
					if(r1 <= r2)
					{
						addS_PieceToBitBoards(q,r1,activeChar);
						r1 +=1 ;
					}
					else
					{
						GD.PushError("R1 Error");
						return false;
					}
				}
			}
		}
		generateCombinedStateBitboards();
		
		//Is White Turn
		if(fenSections[1] == "w")
			isWhiteTurn = true;
		else if (fenSections[1] == "b")
			isWhiteTurn = false;
		else
		{
			GD.PushError("Regex fail");
			return false;
		}
		//EnPassant Cords
		if(fenSections[2] != "-")
		{
			EnPassantCordsValid = true;
			EnPassantTarget = decodeEnPassantFEN(fenSections[2]);
			EnPassantCords = new Vector2I(EnPassantTarget.X, EnPassantTarget.Y + (isWhiteTurn ? -1 : 1));
		}
		else
		{
			EnPassantCords = new Vector2I(-5,-5);
			EnPassantTarget = new Vector2I(-5,-5);
			EnPassantCordsValid = false;
		}
		// Turn Number
		turnNumber = fenSections[3].ToInt();
		if(turnNumber < 1)
			turnNumber = 1;
			
		return true;
	}


	// Move Gen


	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private void bbcheckForBlockingOnVector(PIECES piece, Dictionary<string,Vector2I> dirSet, Dictionary<Vector2I, List<Vector2I>> bp, Vector2I cords)
		{
			var index = HexEngineSharp.QRToIndex(cords.X,cords.Y);
			var isWhiteTrn = bbIsPieceWhite(index);
			
			foreach( string direction in dirSet.Keys )
			{
				List<Vector2I> LegalMoves = new List<Vector2I> {};
				
				Vector2I dirBlockingPiece = new Vector2I(HEX_BOARD_RADIUS+1, HEX_BOARD_RADIUS+1);
				Vector2I activeVector = dirSet[direction];
				
				int checkingQ = cords.X + activeVector.X;
				int checkingR = cords.Y + activeVector.Y;
				
				while ( Bitboard128.inBitboardRange(checkingQ,checkingR) )
				{
					index = HexEngineSharp.QRToIndex(checkingQ,checkingR);
					if( bbIsIndexEmpty(index) )
						if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
							LegalMoves.Add(new Vector2I(checkingQ,checkingR)); // Track legal moves for the blocking pieces
					else
					{
						if( bbIsPieceWhite(index) == isWhiteTrn ) // Friend Piece
							if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1) break; // Two friendly pieces in a row. No Danger
							else dirBlockingPiece = new Vector2I(checkingQ,checkingR); // First piece found

						else //Unfriendly Piece Found	
						{
							PIECES val = bbPieceTypeOf(index, isWhiteTrn);
							if ( (val == PIECES.QUEEN) || (val == piece) )
								if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
									LegalMoves.Add(new Vector2I(checkingQ,checkingR));
									bp[dirBlockingPiece] = LegalMoves; // store blocking piece moves
							break;
						}
					}

					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			return;
		}
	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private Dictionary<Vector2I, List<Vector2I>> bbcheckForBlockingPiecesFrom(Vector2I cords)
	{
		var blockingpieces = new Dictionary<Vector2I, List<Vector2I>>{};
		bbcheckForBlockingOnVector(PIECES.ROOK, ROOK_VECTORS, blockingpieces, cords);
		bbcheckForBlockingOnVector(PIECES.BISHOP, BISHOP_VECTORS, blockingpieces, cords);
		return blockingpieces;
	}
	

	// Pawn Moves

	
	private bool EnPassantLegal()
	{
		Vector2I kingCords = activePieces[(int)(isWhiteTurn ? SIDES.WHITE:SIDES.BLACK)][PIECES.KING][KING_INDEX];
		Vector2I targetPos = new Vector2I(EnPassantCords.X, EnPassantCords.Y + ( isWhiteTurn ? 1 : -1));
		
		foreach( Vector2I piece in lastInfluencedPieces[targetPos])
		{
			int index = HexEngineSharp.QRToIndex(piece.X,piece.Y);
			if(bbIsPieceWhite(index) == isWhiteTurn) continue;
			PIECES type = bbPieceTypeOf(index, isWhiteTurn);
			if(type == PIECES.ROOK || type == PIECES.QUEEN)
			{
				if ( piece.X == kingCords.X ) return false;
				else if ( piece.Y == kingCords.Y ) return false;
				else if ( getSAxialCordFrom(piece) == getSAxialCordFrom(kingCords) ) return false;
			}
			if(type == PIECES.BISHOP || type == PIECES.QUEEN)
			{
				var differenceS = getSAxialCordFrom(piece) - getSAxialCordFrom(kingCords);
				if(piece.X - kingCords.X == piece.Y - kingCords.Y) return false;
				else if(piece.X - kingCords.X == differenceS ) return false;
				else if(piece.Y - kingCords.Y == differenceS ) return false;
			}
		}
		return true;
	}
	// Calculate Pawn Capture Moves
	private void bbfindCaptureMovesForPawn(Vector2I pawn, int qpos, int rpos)
	{
		if ( ! Bitboard128.inBitboardRange(qpos, rpos) ) return;
			
		Vector2I move = new Vector2I(qpos, rpos);
		int index = HexEngineSharp.QRToIndex(qpos,rpos);
		
		if ( bbIsIndexEmpty(index) )
			if( EnPassantCordsValid && (EnPassantCords.X == qpos) && (EnPassantCords.Y == rpos) )
				if( EnPassantLegal() )
					legalMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		else
			if(bbIsPieceWhite(index) != isWhiteTurn)
				if ( isWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					legalMoves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					legalMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		
		updateAttackBoard(qpos, rpos, 1);
		return;
	}
	// Calculate Pawn Foward Moves
	private void bbfindFowardMovesForPawn(Vector2I pawn, int fowardR)
	{
		Vector2I move = new Vector2I(pawn.X,fowardR);
		bool boolCanGoFoward = false;
		// Foward Move
		if (Bitboard128.inBitboardRange(pawn.X, fowardR))
		{
			int index = HexEngineSharp.QRToIndex(pawn.X,fowardR);
			if(bbIsIndexEmpty(index))
				if ( isWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					legalMoves[pawn][MOVE_TYPES.PROMOTE].Add(move);
				else
					legalMoves[pawn][MOVE_TYPES.MOVES].Add(move);
					boolCanGoFoward = true;
		}
		//Double Move From Start
		if( boolCanGoFoward && ( isWhiteTurn ? isWhitePawnStart(pawn) : isBlackPawnStart(pawn) ) )
		{
			int doubleF = isWhiteTurn ? pawn.Y - 2 : pawn.Y + 2;
			int index = HexEngineSharp.QRToIndex(pawn.X, doubleF);
			if (bbIsIndexEmpty(index))
				legalMoves[pawn][MOVE_TYPES.ENPASSANT].Add(new Vector2I(pawn.X, doubleF));
		}
		return;
	}
	// Calculate Pawn Moves
	private void bbfindMovesForPawn(List<Vector2I> PawnArray)
	{
		foreach ( Vector2I pawn in PawnArray)
		{
			legalMoves[pawn] = DeepCopyMoveTemplate(PAWN_MOVE_TEMPLATE);

			int fowardR = isWhiteTurn ? pawn.Y - 1 : pawn.Y + 1;
			int leftCaptureR = isWhiteTurn ? pawn.Y : pawn.Y + 1;
			int rightCaptureR = isWhiteTurn? pawn.Y-1 : pawn.Y;

			//Foward Move
			bbfindFowardMovesForPawn(pawn, fowardR);

			//Left Capture
			bbfindCaptureMovesForPawn(pawn, pawn.X-1, leftCaptureR);

			//Right Capture
			bbfindCaptureMovesForPawn(pawn, pawn.X+1, rightCaptureR);

			// Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(pawn) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[pawn];
				foreach( MOVE_TYPES moveType in legalMoves[pawn].Keys)
					legalMoves[pawn][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[pawn][moveType]);
			}
			// Not Efficient FIX LATER
			if( GameInCheck )
				foreach( MOVE_TYPES moveType in legalMoves[pawn].Keys)
					legalMoves[pawn][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[pawn][moveType]);
		}
		return;
	}


	// Knight Moves


	//Calculate Knight Moves
	private void  bbfindMovesForKnight(List<Vector2I> KnightArray)
	{
		foreach( Vector2I knight in KnightArray)
		{
			legalMoves[knight] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			var invertAt2Counter = 0;
			foreach( int m in KNIGHT_MULTIPLERS )
			{
				foreach( string dir in KNIGHT_VECTORS.Keys )
				{
					Vector2I activeVector = KNIGHT_VECTORS[dir];
					int checkingQ = knight.X + (( (invertAt2Counter < 2) ? activeVector.X : activeVector.Y) * m);
					int checkingR = knight.Y + (( (invertAt2Counter < 2) ? activeVector.Y : activeVector.X) * m);
					if (Bitboard128.inBitboardRange(checkingQ,checkingR))
					{
						int index = HexEngineSharp.QRToIndex(checkingQ,checkingR);
						updateAttackBoard(checkingQ, checkingR, 1);
						if (bbIsIndexEmpty(index)) 
							legalMoves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
						else if(bbIsPieceWhite(index) != isWhiteTurn)
							legalMoves[knight][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ,checkingR));
					}
				}
				invertAt2Counter += 1;
			}
				
			//Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(knight) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[knight];
				foreach( MOVE_TYPES moveType in legalMoves[knight].Keys)
					legalMoves[knight][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[knight][moveType]);
			}
			// Not Efficient FIX LATER
			if( GameInCheck )
				foreach(MOVE_TYPES moveType in legalMoves[knight].Keys)
					legalMoves[knight][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[knight][moveType]);
		}
		return;
	}


	// Rook Moves


	// Calculate Rook Moves
	private void bbfindMovesForRook(List<Vector2I> RookArray)
	{
		foreach( Vector2I rook in RookArray)
		{
			legalMoves[rook] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			foreach(string dir in ROOK_VECTORS.Keys)
			{

				Vector2I activeVector = ROOK_VECTORS[dir];
				int checkingQ = rook.X + activeVector.X;
				int checkingR = rook.Y + activeVector.Y;
				while (Bitboard128.inBitboardRange(checkingQ,checkingR))
				{
					var index = HexEngineSharp.QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1);
					if( bbIsIndexEmpty(index) )
						legalMoves[rook][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
					else
					{
						Vector2I pos = new Vector2I(checkingQ,checkingR);
						if(influencedPieces.ContainsKey(pos)) influencedPieces[pos].Add(rook);
						else influencedPieces[pos] = new List<Vector2I> {rook};
						
						if( bbIsPieceWhite(index) != isWhiteTurn ) //Enemy
						{ 
							legalMoves[rook][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
							//King Escape Fix
							if( bbPieceTypeOf(index, isWhiteTurn) == PIECES.KING )
							{
								checkingQ += activeVector.X;
								checkingR += activeVector.Y;
								if(Bitboard128.inBitboardRange(checkingQ, checkingR))
									updateAttackBoard(checkingQ, checkingR, 1);
							}
						}
						break;
					}
					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			// Not Efficient TODO: FIX LATER
			if(  blockingPieces.ContainsKey(rook) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[rook];
				foreach( MOVE_TYPES moveType in legalMoves[rook].Keys)
					legalMoves[rook][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[rook][moveType]);
			}
			/// Not Efficient TODO: FIX LATER
			if( GameInCheck )
				foreach( MOVE_TYPES moveType in legalMoves[rook].Keys)
					legalMoves[rook][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[rook][moveType]);
		}
		return;
	}


	// Bishop Moves


	// Calculate Bishop Moves
	private void bbfindMovesForBishop(List<Vector2I> BishopArray)
	{
		foreach( Vector2I bishop in BishopArray)
		{
			legalMoves[bishop] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			foreach( string dir in BISHOP_VECTORS.Keys)
			{
				Vector2I activeVector = BISHOP_VECTORS[dir];
				int checkingQ = bishop.X + activeVector.X;
				int checkingR = bishop.X + activeVector.Y;
				while ( Bitboard128.inBitboardRange(checkingQ,checkingR) )
				{
					var index = HexEngineSharp.QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1);
					if( bbIsIndexEmpty(index) )
						legalMoves[bishop][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
					else
					{
						Vector2I pos = new Vector2I(checkingQ,checkingR);
						if(influencedPieces.ContainsKey(pos))
							influencedPieces[pos].Add(bishop);
						else
							influencedPieces[pos] = new List<Vector2I> {bishop};
						
						if( bbIsPieceWhite(index) != isWhiteTurn ) // Enemy
						{
							legalMoves[bishop][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
							//King Escape Fix
							if(bbPieceTypeOf(index, isWhiteTurn) == PIECES.KING)
							{
								checkingQ += activeVector.X;
								checkingR += activeVector.Y;
								if( Bitboard128.inBitboardRange(checkingQ,checkingR) )
									updateAttackBoard(checkingQ, checkingR, 1);
							}
						}
						break;
					}
					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			// Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(bishop) )
			{
				var newLegalmoves = blockingPieces[bishop];
				foreach( MOVE_TYPES moveType in legalMoves[bishop].Keys)
					legalMoves[bishop][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[bishop][moveType]);
			}
			// Not Efficient FIX LATER
			if( GameInCheck )
				foreach(MOVE_TYPES moveType in legalMoves[bishop].Keys)
					legalMoves[bishop][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[bishop][moveType]);
		}
		return;
	}


	// Queen Moves


	// Calculate Queen Moves
	private void bbfindMovesForQueen(List<Vector2I> QueenArray)
	{
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> tempMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> {};
		
		bbfindMovesForRook(QueenArray);
		foreach(Vector2I queen in QueenArray)
			tempMoves[queen] =  DeepCopyInnerDictionary(legalMoves, queen);

		bbfindMovesForBishop(QueenArray);
		
		foreach( Vector2I queen in QueenArray)
			foreach( MOVE_TYPES moveType in tempMoves[queen].Keys)
				foreach( Vector2I move in tempMoves[queen][moveType])
					legalMoves[queen][moveType].Add(move);
		return;
	}


	// King Moves


	// Calculate King Moves
	private void  bbfindMovesForKing(List<Vector2I> KingArray)
	{
		foreach( Vector2I king in KingArray)
		{
			legalMoves[king] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);

			foreach( string dir in KING_VECTORS.Keys)
			{
				Vector2I activeVector = KING_VECTORS[dir];
				int checkingQ = king.X + activeVector.X;
				int checkingR = king.Y + activeVector.Y;
				
				if(Bitboard128.inBitboardRange(checkingQ,checkingR))
				{
					updateAttackBoard(checkingQ, checkingR, 1);
					if(isWhiteTurn)
						if((BlackAttackBoard[checkingQ][checkingR] > 0))
							continue;
					else
						if((WhiteAttackBoard[checkingQ][checkingR] > 0))
							continue;
					int index = HexEngineSharp.QRToIndex(checkingQ,checkingR);
					if( bbIsIndexEmpty(index) )
						legalMoves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));

					else if( bbIsPieceWhite(index) != isWhiteTurn )
						legalMoves[king][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
				}
			}

			// Not Efficient FIX LATER
			if( GameInCheck )
			{
				legalMoves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoList(GameInCheckMoves, legalMoves[king][MOVE_TYPES.CAPTURE]);
				foreach( MOVE_TYPES moveType in legalMoves[king].Keys)
				{
					if(moveType == MOVE_TYPES.CAPTURE) continue;
					legalMoves[king][moveType] = differenceOfTwoList(legalMoves[king][moveType], GameInCheckMoves);
				}
			}
		}
		return;
	}


	// Move


	// Find the legal moves for a single player given an array of pieces
	private void bbfindLegalMovesFor(Dictionary<PIECES, List<Vector2I>>[] ap)
	{
		//startTime = Time.get_ticks_usec();
		Dictionary<PIECES, List<Vector2I>> pieces = ap[(int)(isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)];
		foreach ( PIECES pieceType in pieces.Keys )
		{
			List<Vector2I> singleTypePieces = pieces[pieceType];
			
			if(singleTypePieces.Count() == 0)
				continue;
				
			switch (pieceType)
			{
				case PIECES.PAWN: bbfindMovesForPawn(singleTypePieces); break;
				case PIECES.KNIGHT: bbfindMovesForKnight(singleTypePieces); break;
				case PIECES.ROOK: bbfindMovesForRook(singleTypePieces); break;
				case PIECES.BISHOP: bbfindMovesForBishop(singleTypePieces); break;
				case PIECES.QUEEN: bbfindMovesForQueen(singleTypePieces); break;
				case PIECES.KING: bbfindMovesForKing(singleTypePieces); break;
			}
		}
		//stopTime = Time.get_ticks_usec();
		return;
	}



	// Undo


	//Init


	// API


	// Get


	// Test

	public void test()
	{
		fillBoardwithFEN(DEFAULT_FEN_STRING);
		foreach(Bitboard128 bb in WHITE_BB)
			GD.Print(bb);
		GD.Print(" ");
		foreach(Bitboard128 bb in BLACK_BB)
			GD.Print(bb);
		GD.Print("\n");
	}

}

class Bitboard128 
{
	const int INDEX_TRANSITION = 62;
	const int INDEX_OFFSET = 63;

	public static readonly int[] COLUMN_SIZES = {6,7,8,9,10,11,10,9,8,7,6};
	public static readonly int[] COLUMN_MIN_R = {0, -1, -2, -3, -4, -5, -5, -5, -5, -5, -5};
	public static readonly int[] COLUMN_MAX_R = {5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0};

	private ulong front;
	private ulong back;

	/* QUICK Powers of 2
	N must be below 65 */
	public static ulong get2PowerN (int n)
	{
		return ((ulong) 1) << n;
	}
	public static Bitboard128 createSinglePieceBB (int index)
	{
		ulong back;
		ulong front = 0;
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
		front = (ulong) Front;
		back = (ulong) Back;
	}

	public Bitboard128(ulong Front = 0 , ulong Back = 0)
	{
		front = Front;
		back = Back;
	}

	public ulong _getF()
	{
		return front;
	}
	public ulong _getB(){
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
		ulong b = _getB();
		ulong f = _getF();
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
        string frontBinary = Convert.ToString((long)front, 2).PadLeft(32, '0');
    	string backBinary = Convert.ToString((long)back, 2).PadLeft(INDEX_OFFSET, '0');
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

