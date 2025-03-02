using Godot;

using System;
using System.Linq;
using System.Collections.Generic;

namespace HexChess
{
public class HexConst
{
		// ENUMS
		public enum PIECES {ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING};
		public enum SIDES {BLACK, WHITE};
		public enum MOVE_TYPES {MOVES, CAPTURE, ENPASSANT, PROMOTE};
		public enum ENEMY_TYPES { PLAYER_TWO, RANDOM, NN, MIN_MAX };
		//public enum MATE_STATUS {NONE, CHECK, OVER};
		//public enum UNDO_FLAGS {NONE, ENPASSANT, CHECK, GAME_OVER };
		// Const
		public const int KING_INDEX = 0;
		public const int HEX_BOARD_RADIUS = 5;
		public const int ILLEGAL_CORDS = 6;
		public const int DECODE_FEN_OFFSET = 70;
		public const int TYPE_MASK = 0b0111;
		public const int SIDE_MASK = 0b1000;
		// Vectors
		public static readonly Dictionary<string,Vector2I> ROOK_VECTORS 	= new() { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0) } };
		public static readonly Dictionary<string,Vector2I> BISHOP_VECTORS 	= new() { { "lfoward", new Vector2I(-2,1)}, { "rFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "lbackward", new Vector2I(1,1)}, { "rBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
		public static readonly Dictionary<string,Vector2I> KING_VECTORS 	= new() { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0)}, { "dlfoward", new Vector2I(-2,1)}, { "drFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "dlbackward", new Vector2I(1,1)}, { "drBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
		public static readonly Dictionary<string,Vector2I> KNIGHT_VECTORS 	= new() { { "left", new Vector2I(-1,-2)}, { "lRight", new Vector2I(1,-3)}, { "rRight", new Vector2I(2,-3)} };
		// Templates
		public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> DEFAULT_MOVE_TEMPLATE = new() { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I>{}},  };
		public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> PAWN_MOVE_TEMPLATE 	= new() { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I> {}}, {MOVE_TYPES.ENPASSANT, new List<Vector2I> {}}, {MOVE_TYPES.PROMOTE, new List<Vector2I> {}} };
		// Positions
		public static readonly int[] PAWN_START 		= {    -4, -3, -2, -1, 0, 1, 2, 3, 4   };
		public static readonly int[] PAWN_PROMOTE 		= {-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5};
		public static readonly int[] KNIGHT_MULTIPLERS 	= {-1, 1, -1, 1};
		

		/// <summary>
		/// Creates a dictionary with PIECES as the Key and an empty Vector2I list as the held value. 
		/// </summary>
		/// <returns> The created dictionary </returns>
		public static Dictionary<PIECES, List<Vector2I>> InitiatePIECESDictionaryMoveList()
		{
			return new()
			{ 
				{PIECES.PAWN, new(){}},
				{PIECES.KNIGHT, new(){}},
				{PIECES.ROOK, new (){}},
				{PIECES.BISHOP, new(){}},
				{PIECES.QUEEN, new(){}},
				{PIECES.KING, new(){}} 
			};
		}

		/// <summary>
		/// Create a 2D int key dictionary with a int as the held value. Dictionary is jagged. 
		/// </summary>
		/// <param name="radius">The number of hexagons fron the center to the edge.</param>
		/// <returns> QR Dictionary with r radius. </returns>
		public static Dictionary<int,Dictionary<int,int>> CreateQRDictionary(int radius)
	{
		var rDictionary = new Dictionary<int,Dictionary<int,int>>(2*radius);
		for( int q=-radius; q <= radius; q +=1 )
		{
			int negQ = q * -1;
			int minRow = Math.Max(-radius, negQ-radius);
			int maxRow = Math.Min(radius, negQ+radius);
			rDictionary.Add(q, new Dictionary<int, int>(maxRow-minRow));
			for(int r = minRow; r<= maxRow; r += 1 )
				rDictionary[q].Add(r, 0);
		}
		return rDictionary;
	}
		


		/// <summary> Given (q,r) find the mapped index for a r=5 hex board. (-5,5) = 0. (-5,0) = 5. (5,0) = 85 (5,-5) = 90. 91 Total positions. </summary>
		/// <param name="q">The Cross Axis</param>
		/// <param name="r">The Vertical Axis</param>
		/// <returns>index of given (q,r)</returns>
		public static int QRToIndex (int q, int r)
		{
			int normalq = q + 5;
			int index = 0;
			int i = 0;
			foreach(int size in Bitboard128.COLUMN_SIZES)
			{
				if (normalq == i) break; 
				index += size;
				i += 1;
			}
			
			if(q <= 0)
				index += 5 - r;
			else
				index += Bitboard128.COLUMN_SIZES[normalq] - 6 - r;
					
			return index;
		}
		/// <summary>
		/// Given an index find the mapped QR cordinates for a r=5 hex board. 0 = (-5,5). 5 = (-5,0). 85 = (5,0). 90 = (5,-5). 91 Total positions.
		/// </summary>
		/// <param name="index"> Index to to check</param>
		/// <returns></returns>
		public static int QRToIndex(Vector2I vec)
		{
			return QRToIndex(vec.X, vec.Y);
		}
		public static Vector2I IndexToQR (int index)
		{
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
				r = Bitboard128.COLUMN_SIZES[normalq] - 6 - (index - accumulated_index);
			
			var q = normalq - 5;
			return new Vector2I(q, r);
		}
		/// <summary>
		/// Given a QR pair determine the corresponding S cordinate to complete 3 value axial cordinates.
		/// </summary>
		/// <param name="cords">QR Pair</param>
		/// <returns> Value of determined S cordinate</returns>
		public static int SAxialCordFrom(Vector2I cords)
		{
			return (-1 * cords.X) - cords.Y;
		}
		public static int AxialCordDist(Vector2I from, Vector2I to)
		{
			var dif = new Vector3I(from.X-to.X, from.Y-to.Y, SAxialCordFrom(from)-SAxialCordFrom(to));
			return Math.Max( Math.Max( Math.Abs(dif.X), Math.Abs(dif.Y)), Math.Abs(dif.Z));
		}
		public static void CleanPrintAP(Dictionary<PIECES, List<Vector2I>>[]AP)
		{
			for (int side = 0; side < AP.Length; side += 1)
			{
				GD.Print(Enum.GetNames(typeof (SIDES)).GetValue(side));
				foreach(PIECES piece in AP[side].Keys)
					GD.Print(Enum.GetName(typeof(PIECES), piece), " : ", AP[side][piece]);
				GD.Print("\n");
			}
		}
		/// <summary>
		/// set all values of given board to zero.
		/// </summary>
		/// <param name="board"></param>
		public static void ZeroBoard(Dictionary<int, Dictionary<int,int>> board)
		{
			foreach( int key in board.Keys)
				foreach( int innerKey in board[key].Keys)
					board[key][innerKey] = 0;
			return;
		}
		/// <summary>
		/// Given a formatted move list count all found moves.
		/// </summary>
		/// <param name="movesList">Formatted Move List</param>
		/// <returns>Move Count</returns>
		public static int CountMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> movesList)
		{
			int count = 0;
			foreach( Vector2I piece in movesList.Keys )
				foreach ( MOVE_TYPES moveType in movesList[piece].Keys )
					foreach ( Vector2I move in movesList[piece][moveType])
						count += 1;
			return count;
		}
		// Find Intersection Of Two Arrays. O(N^2)
		public static T[] intersectOfTwoArrays<T>(T[] ARR, T[] ARR1)
		{
			List<T> intersection = new List<T>();
			foreach( T item in ARR)
				if (Array.Exists(ARR1, e => e.Equals(item)))
					intersection.Add(item);
			return intersection.ToArray();
		}
		public static List<T> intersectOfTwoList<T>(List<T> ARR, List<T> ARR1)
		{
			if(ARR.Count == 0 || ARR1.Count == 0)
				return new List<T>();
			return ARR.Intersect(ARR1).ToList<T>();
		}
		// Find Items Unique Only To ARR. O(N^2)
		public static T[] differenceOfTwoArrays<T>(T[] ARR, T[] ARR1)
		{
			List<T> diff = new List<T>();
			foreach( T item in ARR)
				if (!Array.Exists(ARR1, e => e.Equals(item)))
					diff.Add(item);
			return diff.ToArray();
		}
		public static List<T> differenceOfTwoList<T>(List<T> ARR, List<T> ARR1)
		{
			// T[] diffArray = differenceOfTwoArrays(ARR.ToArray(), ARR1.ToArray() )
			// return new List<T> (diffArray);
			return ARR.Except(ARR1).ToList();
		}
		public static void CleanPrintBoard(Dictionary<int, Dictionary<int, int>> board)
		{
			// Get the keys of the board and reverse them
			var flippedKeys = board.Keys.ToList();
			flippedKeys.Reverse();

			// Loop through each row
			foreach (var key in flippedKeys)
			{
				// Prepare a string list to build the row output
				List<string> rowString = new List<string>();

				// Calculate the offset and pad the row with spaces
				int offset = 12 - board[key].Count;
				for (int i = 0; i < offset; i++)
				{
					rowString.Add("  ");
				}

				// Loop through the inner dictionary (columns)
				foreach (var innerKey in board[key].Keys)
				{
					// If the board value is 0, append empty spaces; otherwise, format the value
					if (board[key][innerKey] == 0)
					{
						rowString.Add("   "); // Empty space
					}
					else
					{
						rowString.Add(string.Format(" {0:00}", board[key][innerKey])); // Format with leading zeros
					}
					rowString.Add(", ");
				}

				// Print the row
				Console.WriteLine();
				Console.WriteLine(string.Join("", rowString));
				Console.WriteLine();
			}
		}
		
		/// <summary>
		/// Strip the color bit and get what piece it is.
		/// </summary>
		/// <param name="id"> int represenation of piece </param>
		/// <returns>(PIECES) of given piece</returns>
		public static PIECES MaskPieceTypeFrom(int id)
		{
			int res = id & TYPE_MASK;
			return (PIECES) res;
		}
		public static bool IsCharInt(char activeChar)
		{
			return ('0' <= activeChar) && (activeChar <= '9');
		}
		
		public static Vector2I GetBishopVector(Vector2I from, Vector2I to)
		{
			var deltaQ = from.X - to.X;
			var deltaR = from.Y - to.Y;
			var direction = new Vector2I(0,0);
			if(deltaQ > 0)
				if(deltaR < 0)
					if(Math.Abs(deltaQ) < Math.Abs(deltaR))
						direction = new Vector2I(1,-2);
					else
						direction = new Vector2I(2,-1);
				else if (deltaR > 0)
					direction = new Vector2I(1,1);
			else if (deltaQ < 0)
				if(deltaR > 0)
					if(Math.Abs(deltaQ) < Math.Abs(deltaR))
						direction = new Vector2I(-1,2);
					else
						direction = new Vector2I(-2,1);
				else if (deltaR < 0)
					direction = new Vector2I(-1,-1);
			return direction;
		}
		public static Vector2I GetRookVector(Vector2I from, Vector2I to)
		{
			var deltaQ = from.X - to.X;
			var deltaR = from.Y - to.Y;
			var direction = new Vector2I(
				(deltaQ > 0) ? 1 : ( (deltaQ < 0) ? -1 : 0 ),
				(deltaR > 0) ? 1 : ( (deltaR < 0) ? -1 : 0 )
				);
			return direction;
		}

		public static bool IsOnBishopVector(Vector2I from, Vector2I to)
		{
			Vector2I delta = to - from;
			var deltaS = SAxialCordFrom(delta);
			if((delta.X == delta.Y) && (deltaS / delta.X == -2))
				return true;
			else if ((delta.X == deltaS) && delta.Y / delta.X == -2)
				return true;
			else if ((delta.Y == deltaS) && delta.X / delta.Y == -2)
				return true;
			return false;
		}

		public static bool IsOnRookVector(Vector2I from ,Vector2I to)
		{
			if(from.X == to.X)
				return true;
			if(from.Y == to.Y)
				return true;
			if(SAxialCordFrom(from) == SAxialCordFrom(to))
				return true;
			return false;
		}

		public static List<Vector2I> GetAxialPath(Vector2I from, Vector2I to)
		{			
			Vector2I vector = Vector2I.Zero;
			if(IsOnRookVector(from, to))
				vector = GetRookVector(from, to);
			if(vector == Vector2I.Zero && IsOnBishopVector(from,to))
				vector = GetBishopVector(from, to);

			List<Vector2I> path = new();
			if(vector == Vector2I.Zero)	
				return path;

			while(from != to)
			{
				path.Add(to);
				to += vector;
			}
			return path;
		}



		// Copy Data



		public static Dictionary<MOVE_TYPES, List<Vector2I>> DeepCopyMoveTemplate(Dictionary<MOVE_TYPES, List<Vector2I>> original)
		{
			var copy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
			foreach (var kvp in original)
			{
				var newList = new List<Vector2I>();
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
				return null;
			
			var innerDictionaryCopy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
			foreach (var kvp in innerDictionary)
			{
				var newList = new List<Vector2I>(kvp.Value);
				innerDictionaryCopy.Add(kvp.Key, newList);
			}
			return innerDictionaryCopy;
		}
		public static Dictionary<Vector2I, Vector2I> DeepCopyPinning(Dictionary<Vector2I, Vector2I> original)
		{
			return new Dictionary<Vector2I, Vector2I>(original);
		}
		


		// Strings



		public static string PrettyPrintLegalMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves)
		{
			// Check if the dictionary is null or empty
			if (legalMoves == null || legalMoves.Count == 0)
			{
				GD.Print("null");
				return "No Moves";
			}

			string outstring = "";

			// Iterate through the outer dictionary (keys are Vector2I, values are inner dictionaries)
			foreach (var outerKvp in legalMoves)
			{
				var outerKey = outerKvp.Key; // Vector2I
				var innerDictionary = outerKvp.Value; // Dictionary<MOVE_TYPES, List<Vector2I>>

				// Start the print of the outer dictionary in the specified format
				outstring += $"({FormatVector2I(outerKey)}): {{ ";

				// Iterate through the inner dictionary (keys are MOVE_TYPES, values are lists of Vector2I)
				foreach (var innerKvp in innerDictionary)
				{
					var moveType = innerKvp.Key; // MOVE_TYPES
					var vectorList = innerKvp.Value; // List<Vector2I>

					// Print the MoveType and the list of Vector2I in the required format
					outstring += $"{(int)moveType}: [{FormatVector2IList(vectorList)}], ";
				}
				outstring = outstring.Substr(0, outstring.Length-2);
				// Close the outer dictionary print
				outstring += " }, ";
			}
			return "{ " + outstring + " }";
		}
		public static string FormatVector2I(Vector2I vector)
		{
			return $"{vector.X}, {vector.Y}";
		}
		public static string FormatVector2IList(List<Vector2I> vectorList)
		{
			if (vectorList == null || vectorList.Count == 0) return "";
			return string.Join(", ", vectorList.Select(v => $"({FormatVector2I(v)})"));
		}

		public static void PrettyPrintATKBOARD(Dictionary<int, Dictionary<int,int>> board)
		{
			if (board == null || board.Count == 0)
			{
				GD.Print("The board is empty.");
				return;
			}
			String outString = "";
			// Loop over each row (r) in the range -Radius to +Radius.
			for (int r = -5; r <= 5; r++)
			{
				// Calculate the starting and ending columns for the current row.
				int qStart = Math.Max(-5, -5 - r);
				int qEnd = Math.Min(5, 5 - r);

				// Print leading spaces for alignment.
				outString += new string(' ', Math.Abs(r)*2);

				// Loop over each column (q) in the range for the current row.
				for (int q = qStart; q <= qEnd; q++)
				{
					if (board.ContainsKey(r) && board[r].ContainsKey(q))
					{
						outString += ($" {board[r][q]:D2} "); // Print cell value, zero-padded for alignment.
					}
					else
					{
						outString += " .. "; // Empty space for missing cells.
					}
				}

				outString += "\n"; // Move to the next row.
			}
			GD.Print(outString);
		}



		// ID



		public static bool isPieceWhite(int id)
		{
			int mask = SIDE_MASK;
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
			return MaskPieceTypeFrom(id) == PIECES.KING;
		}



		// Positions



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



		//Encoding



		/// <summary>
		/// Turn a vector (q,r) into a string representation of the position.
		/// </summary>
		/// <param name="q"></param>
		/// <param name="r"></param>
		/// <returns></returns>
		public static string EncodeFEN(int q, int r)
		{
			int rStr = 6 - r;
			int qStr = 5 + q;
			char qLetter = (char)(65 + qStr);
			return $"{qLetter}{rStr}";
		}
		/// <summary>
		/// Turn a string represenation of board postiion to a vector2i of (q,r).
		/// </summary>
		/// <param name="s"></param>
		/// <returns></returns>
		public static Vector2I DecodeFEN(string s)
		{
			int qStr = (int)s[0] - DECODE_FEN_OFFSET;
			int rStr = int.Parse(s.Substring(1));
			rStr += 6-(2*rStr);
			return new Vector2I(qStr, rStr);
		}
		/// <summary>
		/// Given a PIECES value and a side get the char representation of the piece.
		/// </summary>
		/// <param name="p">Type</param>
		/// <param name="isW">Is piece on side w</param>
		/// <returns></returns>
		public static char PieceToChar(PIECES p, bool isW)
		{
			char returnChar = ' ';
			switch(p)
			{
				case PIECES.PAWN: returnChar = 'p'; break;
				case PIECES.KNIGHT: returnChar = 'n'; break;
				case PIECES.ROOK: returnChar = 'r'; break;
				case PIECES.BISHOP: returnChar = 'b'; break;
				case PIECES.QUEEN: returnChar = 'q'; break;
				case PIECES.KING: returnChar = 'k'; break;
			}
			if(isW)
				returnChar -= (char)('a'-'A');
			return returnChar;
		}

		/// <summary>
		/// Given a PIECES value and a side get the Integer representation of the piece.
		/// </summary>
		/// <param name="piece"></param>
		/// <param name="isBlack"></param>
		/// <returns></returns>
		public static int ToPieceInt(PIECES piece, bool isBlack)
		{
			int id = (int) piece;
			if(!isBlack) id += SIDE_MASK;
			return id;
		}



		// Attack Search 



		/// <summary>
		/// Check if an active piece appears in the capture moves of any piece.
		/// </summary>
		/// <param name="Cords"></param>
		/// <param name="enemyMoves"></param>
		/// <param name="fromList"></param>
		/// <returns></returns>
		public static bool IsUnderAttack(Vector2I Cords, Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> enemyMoves, out List<Vector2I> fromList)
		{
			fromList = new();
			var isunder = false;
			foreach( Vector2I piece in enemyMoves.Keys)
			{
				foreach( Vector2I move in enemyMoves[piece][MOVE_TYPES.CAPTURE] )
					if(move == Cords)
					{
						fromList.Add(piece);
						isunder = true;
					}
						
				if(enemyMoves[piece].Count == 4) // is pawn moves
					foreach( Vector2I move in enemyMoves[piece][MOVE_TYPES.PROMOTE])
						if(move == Cords)
						{
							fromList.Add(piece);
							isunder = true;
						}
			}
			return isunder;
		}
		/// <summary>
		/// Check what, if any, piece contains in their capture moves the cords piece.
		/// </summary>
		/// <param name="Cords"></param>
		/// <param name="enemyMoves"></param>
		/// <returns></returns>
		public static Vector2I UnderAttackFrom(Vector2I Cords, Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> enemyMoves)
		{
			foreach( Vector2I piece in enemyMoves.Keys)
				foreach( Vector2I move in enemyMoves[piece][MOVE_TYPES.CAPTURE] )
					if(move == Cords)
						return piece;
			return new Vector2I(ILLEGAL_CORDS, ILLEGAL_CORDS);
		}



		//Deep Copy 
		
		
	
		public static Dictionary<int, Dictionary<int, int>> DeepCopyBoard(Dictionary<int, Dictionary<int, int>> original)
		{
			var copy = new Dictionary<int, Dictionary<int, int>>();
			foreach (var outerPair in original)
			{
				var innerCopy = new Dictionary<int, int>(outerPair.Value);
				copy.Add(outerPair.Key, innerCopy);
			}
			return copy;
		}
		public static Dictionary<Vector2I, List<Vector2I>> DeepCopyPieces(Dictionary<Vector2I, List<Vector2I>> original)
		{
			var copy = new Dictionary<Vector2I, List<Vector2I>>();
			foreach (var outerPair in original)
			{
				var listCopy = new List<Vector2I>(outerPair.Value.Select(v => new Vector2I(v.X, v.Y)));
				copy.Add(outerPair.Key, listCopy);
			}
			return copy;
		}




		// Memory Optimization



		public static readonly List<Vector2I> EmptyVector2IList = new();

		

		//Hueristic Functions



		private const long CHECK_VAL = 1500;
		private const long NOPAWNPEN_VAL = 500;
		//skip ZERO and ignore king *(its always present) 
		private static readonly long[] PIECE_VALUES = new long[] {0, 100, 300, 500, 300, 900, 0};
		private static readonly long [][] PIECE_BOARDS = 
			{
				Array.Empty<long>(), //ZERO
				new long[] { //PAWNS 
					        0,  0, 25, 30, 50,  0,
					       5,  5,  0, 25, 30, 50,  0,
					     0, 10,  0,  0, 10, 20, 50,  0,
					    0,  0, 10,  0,  0,  5, 20, 50,  0,
					  0,   0,  0,-20, 20, 20, 5, 10, 50,  0,
					 0,   0,  0,  0,-20, 20, 0, 5, 5, 50,  0,
					  0,   0,  0,-20, 20, 20, 5, 10, 50,  0,
					    0,  0, 10,  0,  0,  5, 20, 50,  0,
					     0, 10,  0,  0, 10, 20, 50,  0,
					       5,  5,  0, 25, 30, 50,  0,
					        0,  0, 25, 30, 50,  0 },
				new long[] { //KNIGHT
					         -50,-40,-30,-30,-40,-50,
					        -40,-20,  0,  5,  0,-20,-40,
					      -30,  0, 10,  0,  0, 10,  0,-30,
					     -30,  5,  0, 20, 20, 20,  0,  5,-30,
					   -40,  0,  0, 20, 40, 40, 20,  0  ,0,-40,
					 -50,-20,  0, 20, 40, 50, 40, 20,  0,-20,-50,
					   -40,  0,  0, 20, 40, 40, 20,  0,  0,-40,
					     -30,  5,  0, 20, 20, 20,  0,  5,-30,
					       -30,  0, 10,  0,  0, 10,  0,-30,
					         -40,-20,  0,  5,  0,-20,-40,
					          -50,-40,-30,-30,-40,-50, },
				new long[] { //ROOK
					             5,  0,  0,  0,  0,  5,
					           0,  0,  0,  5,  0, 10,  0,
					         5,  0,  0,  0,  5, 10,  0,  0,
					       5,  5,  0,  0,  5, 10,  0,  0,  0,
					     5,  5,  5,  0,  5, 10,  0,  0  ,0,  0,
					    5,  5,  5,  5,  5, 10,  0, 10,  0,  0,  5,
					     5,  5,  5,  0,  5, 10,  0,  0,  0,  0,
					       5,  5,  0,  0,  5, 10,  0,  0,  0,
					         5,  0,  0,  0,  5, 10,  0,  0,
					           0,  0,  0,  5,  0, 10,  0,
					             5,  0,  0,  0,  0,  5, },
				new long[] { //BISHOP
					         -20,-10,-10,-10,-10,-20,
					        -10, 5, 10,  5,  0,  0,-10,
					      -10,  0, 10, 10,  5,  0,  0,-10,
					     -10,  0,  0, 10, 10,  5,  0,  0,-10,
					   -10,  0,  0,  0, 10, 10, 10,  0  ,0,-10,
					 -20,  0,  0,  0,  0, 10, 10, 10,  0,  0,-20,
					   -10,  0,  0,  0, 10, 10, 10,  0,  0,-10,
					     -10,  0,  0, 10, 10,  5,  0,  0,-10,
					       -10,  0, 10, 10,  5,  0,  0,-10,
					         -10,  5, 10,  5,  0,  0,-10,
					          -20,-10,-10,-10,-10,-20, },
				new long[] { //QUEEN
					          -20,-10, -5, -5,  0,-20,
					         -10, 0,  0,  0,  0,  0,-10,
					       -10,  0,  5,  0,  0,  0,  0,-10,
					     -10,  0,  5,  5,  5,  5,  0,  0,-10,
					   -10,  5,  0,  5,  5,  5,  5,  0,  -5,-10,
					    0,  0,  0,  5,  5,  5,  5,  5,  0,  -5,-20,
					   -10,  0,  0,  5,  5,  5,  5,  0,  -5,-10,
					      -5,  0,  0,  5,  5,  5,  0,  0,-10,
					        -5,  0,  0,  0,  0,  0,  0,-10,
					         -10,  0,  0,  0,  0,  0,-10,
					          -20,-10,-5, -5,-10,-20, },
				new long[] { //KING START
					           -30,-30,-30,-30,-30,-30,
					         -20,-20,-30,-30,-30,-40,-40,
					        20,-20,-20,-30,-30,-30,-40,-40,
					      30, 20,-20,-20,-30,-30,-30,-40,-50,
					     0,  0, 20,-20,-20,-30,-30,-40,-50,-50,
					   0,  0,  0,  0,-20,-20,-30,-40,-50,-50,-50,
					     0, 20, 20,-20,-20,-30,-30,-40,-50,-50,
					      30, 20,-20,-20,-30,-30,-30,-40,-50,
					        20,-20,-20,-30,-30,-30,-40,-40,
					         -20,-20,-30,-30,-30,-40,-40,
					           -30,-30,-30,-30,-30,-30, },
				new long[] { //KING END
					          -50,-40,-30,-30,-40,-50,
					        -40,-20,  0,  5,  0,-20,-40,
					      -30,  0, 10,  0,  0, 10,  0,-30,
					     -30,  5,  0, 20, 20, 20,  0,  5,-30,
					   -40,  0,  0, 20, 40, 40, 20,  0  ,0,-40,
					 -50,-20,  0, 20, 40, 50, 40, 20,  0,-20,-50,
					   -40,  0,  0, 20, 40, 40, 20,  0,  0,-40,
					     -30,  5,  0, 20, 20, 20,  0,  5,-30,
					       -30,  0, 10,  0,  0, 10,  0,-30,
					         -40,-20,  0,  5,  0,-20,-40,
					          -50,-40,-30,-30,-40,-50, },
			};

		/// <summary>
		/// Measure the Board State
		/// </summary>
		/// <param name="hexEngine"></param>
		/// <returns></returns>
		public static long Hueristic(HexEngineSharp hexEngine)
		{
			//ENDSTATE
			if(hexEngine._getGameOverStatus())
			{
				if(hexEngine._getGameInCheck())
				{
					if(hexEngine._getIsWhiteTurn()) return long.MaxValue;
					else return long.MinValue;
				}
				else return 0; // StaleMate
			}

			long H = 0;
			//Check
			if(hexEngine._getGameInCheck())
			{
				if(hexEngine._getIsWhiteTurn()) H += CHECK_VAL;
				else H -= CHECK_VAL;
			}
			//Simple Material and their Position
			foreach(PIECES piecetype in hexEngine.GetAPs()[(int)SIDES.BLACK].Keys)
				foreach(Vector2I piece in hexEngine.GetAPs()[(int)SIDES.BLACK][piecetype])
				{
					H += PIECE_VALUES[(int)piecetype];
					H += PIECE_BOARDS[(int)piecetype][QRToIndex(piece.X * -1,piece.Y * -1)];
				}
			foreach(PIECES piecetype in hexEngine.GetAPs()[(int)SIDES.WHITE].Keys)
				foreach(Vector2I piece in hexEngine.GetAPs()[(int)SIDES.WHITE][piecetype])
				{
					H -= PIECE_VALUES[(int)piecetype];
					H -= PIECE_BOARDS[(int)piecetype][QRToIndex(piece.X,piece.Y)];
				}
			//Material Bonuses & Penalties
			if(hexEngine.GetAPs()[(int)SIDES.BLACK][PIECES.BISHOP].Count == 3)
				H += PIECE_VALUES[(int)PIECES.BISHOP];
			if(hexEngine.GetAPs()[(int)SIDES.WHITE][PIECES.BISHOP].Count == 3)
				H -= PIECE_VALUES[(int)PIECES.BISHOP];
			if(hexEngine.GetAPs()[(int)SIDES.BLACK][PIECES.ROOK].Count == 2)
				H -= PIECE_VALUES[(int)PIECES.ROOK] / 3;
			if(hexEngine.GetAPs()[(int)SIDES.WHITE][PIECES.ROOK].Count == 2)
				H +=  PIECE_VALUES[(int)PIECES.ROOK] / 3;
			if(hexEngine.GetAPs()[(int)SIDES.BLACK][PIECES.KNIGHT].Count == 2)
				H -= PIECE_VALUES[(int)PIECES.KNIGHT] / 3;
			if(hexEngine.GetAPs()[(int)SIDES.WHITE][PIECES.KNIGHT].Count == 2)
				H +=  PIECE_VALUES[(int)PIECES.KNIGHT] / 3;
			if(hexEngine.GetAPs()[(int)SIDES.BLACK][PIECES.PAWN].Count == 0)
				H -= NOPAWNPEN_VAL;
			if(hexEngine.GetAPs()[(int)SIDES.WHITE][PIECES.PAWN].Count == 0)
				H +=  NOPAWNPEN_VAL;
			return H;
		}


}
}